import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_role.dart';
import '../models/employee.dart';

/// Super Admin email - always has admin privileges (hardcoded fallback)
const String superAdminEmail = 'the.blacklodge@outlook.com';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal()
    : lookupAllowedUserIsAdmin = _defaultLookupAllowedUserIsAdmin,
      lookupEmployeeAccess = _defaultLookupEmployeeAccess {
    _firebaseAuth.authStateChanges().listen((user) {
      if (user != null && !user.isAnonymous) {
        _cachedRole = null; // Clear cache, force a fresh resolve
        _cachedEmployeeRole = null;
        checkRole();
      } else {
        // No user, or an anonymous one: always a customer, and can never
        // become admin/employee, so resolve immediately instead of leaving
        // _cachedRole null forever (which would hang roleResolved/
        // RoleProtectedScreen for guests).
        _cachedRole = AppRole.customer;
        _cachedEmployeeRole = null;
        debugPrint('⏱ role resolved: $_cachedRole (guest)');
        _roleChangesController.add(_cachedRole!);
      }
    });
  }

  /// Test seam: builds an instance with fake lookups. Skips the Firebase auth
  /// listener (only [checkRole] is meant to be exercised on such instances).
  @visibleForTesting
  AuthService.forTesting({
    required this.lookupAllowedUserIsAdmin,
    required this.lookupEmployeeAccess,
    required String? Function() emailProvider,
  }) : _emailOverride = emailProvider;

  final Future<bool> Function(String normalizedEmail) lookupAllowedUserIsAdmin;
  final Future<({bool exists, EmployeeRole? role})> Function(
    String normalizedEmail,
  )
  lookupEmployeeAccess;
  String? Function()? _emailOverride;

  static Future<bool> _defaultLookupAllowedUserIsAdmin(String email) async {
    final doc = await FirebaseFirestore.instance
        .collection('allowedUsers')
        .doc(email)
        .get();
    return doc.data()?['isAdmin'] == true;
  }

  static Future<({bool exists, EmployeeRole? role})> _defaultLookupEmployeeAccess(
    String email,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('employeeAccess')
        .doc(email)
        .get();
    if (!doc.exists) return (exists: false, role: null);
    // Existence alone grants the employee tier (matches the rules), so a
    // malformed role must not fail the lookup.
    EmployeeRole? role;
    try {
      final raw = doc.data()?['role'];
      role = EmployeeRole.fromFirestore(raw is String ? raw : null);
    } catch (e) {
      debugPrint('Unparseable employeeAccess role: $e');
    }
    return (exists: true, role: role);
  }

  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  AppRole? _cachedRole;
  EmployeeRole? _cachedEmployeeRole;
  // Intentionally never closed: AuthService is an app-lifetime singleton, so
  // there is no point in the app's life where this controller should stop
  // accepting listeners/emissions.
  final StreamController<AppRole> _roleChangesController =
      StreamController<AppRole>.broadcast();

  FirebaseAuth get _firebaseAuth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  void initialize({String? googleClientId}) {
    if (googleClientId != null && googleClientId.isNotEmpty) {
      _googleSignIn = GoogleSignIn(
        clientId: googleClientId,
        scopes: ['email', 'profile'],
      );
    }
  }

  GoogleSignIn get _google {
    _googleSignIn ??= GoogleSignIn(scopes: ['email', 'profile']);
    return _googleSignIn!;
  }

  /// Current user stream for auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Current user (returns null if Firebase not initialized)
  User? get currentUser {
    try {
      return _firebaseAuth.currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is signed in (not anonymous)
  bool get isSignedIn {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Check if user is anonymous
  bool get isAnonymous {
    final user = currentUser;
    return user?.isAnonymous ?? true;
  }

  /// Current resolved role (sync - uses cache; defaults to customer until
  /// [checkRole] has completed at least once for this session).
  AppRole get role => _cachedRole ?? AppRole.customer;

  /// True once [checkRole] has resolved for the current auth state. Use this
  /// to distinguish "definitely a customer" from "still checking" in UI
  /// gates - see [role_protected_screen.dart].
  bool get roleResolved => _cachedRole != null;

  /// True if [role] is employee, admin, or super admin.
  bool get isEmployeeOrHigher => role.atLeast(AppRole.employee);

  /// Emits every time [checkRole] resolves a (possibly unchanged) role.
  Stream<AppRole> get roleChanges => _roleChangesController.stream;

  /// The employee roster role backing an employee-tier grant, for display
  /// only (e.g. "Angemeldet als Supervisor"). Never used for gating - gating
  /// always goes through [role] / [isEmployeeOrHigher].
  EmployeeRole? get employeeRole => _cachedEmployeeRole;

  /// Check if current user is admin (sync - uses cache). Super admin has a
  /// synchronous fast path via [isSuperAdmin] so this is never false for the
  /// super-admin account during the async gap before [checkRole] resolves.
  bool get isAdmin => isSuperAdmin || role.atLeast(AppRole.admin);

  /// Check if current user can manage users (admin or super admin). See
  /// [isAdmin] for why [isSuperAdmin] is checked synchronously first.
  bool get canManageUsers => isSuperAdmin || role.atLeast(AppRole.admin);

  /// Check if current user is super admin
  bool get isSuperAdmin {
    final userEmail = email;
    if (userEmail == null) return false;
    return userEmail.toLowerCase() == superAdminEmail.toLowerCase();
  }

  /// Resolve the current user's [AppRole] from Firestore (async - call on
  /// login). Reads `allowedUsers/{email}` first; if that does not resolve to
  /// admin, reads `employeeAccess/{email}` - a single document get by known
  /// path, not a query.
  Future<AppRole> checkRole() async {
    final userEmail = email;
    if (userEmail == null) {
      _cachedRole = AppRole.customer;
      _cachedEmployeeRole = null;
      debugPrint('⏱ role resolved: $_cachedRole (no email)');
      _roleChangesController.add(_cachedRole!);
      return _cachedRole!;
    }

    final normalizedEmail = userEmail.toLowerCase();
    final isSuperAdminEmail = normalizedEmail == superAdminEmail.toLowerCase();

    bool allowedUserIsAdmin = false;
    bool hasEmployeeAccessDoc = false;
    EmployeeRole? employeeRoleFromMirror;

    if (!isSuperAdminEmail) {
      // Both reads are independent single-document gets: run them
      // concurrently (one round trip instead of two). Precedence is applied
      // afterwards exactly as before: an admin flag from allowedUsers wins and
      // the employeeAccess result is then ignored.
      final results = await Future.wait<Object?>([
        Future.sync(() => lookupAllowedUserIsAdmin(normalizedEmail)).then<Object?>(
          (v) => v,
          onError: (Object e) {
            debugPrint('Failed to check admin status: $e');
            return false;
          },
        ),
        Future.sync(() => lookupEmployeeAccess(normalizedEmail)).then<Object?>(
          (v) => v,
          onError: (Object e) {
            debugPrint('Failed to check employee access: $e');
            return (exists: false, role: null);
          },
        ),
      ]);
      allowedUserIsAdmin = results[0] as bool;
      if (!allowedUserIsAdmin) {
        final mirror = results[1] as ({bool exists, EmployeeRole? role});
        hasEmployeeAccessDoc = mirror.exists;
        employeeRoleFromMirror = mirror.role;
      }
    }

    _cachedRole = resolveAppRole(
      isSuperAdminEmail: isSuperAdminEmail,
      allowedUserIsAdmin: allowedUserIsAdmin,
      hasEmployeeAccessDoc: hasEmployeeAccessDoc,
    );
    _cachedEmployeeRole = employeeRoleFromMirror;
    debugPrint('⏱ role resolved: $_cachedRole');
    _roleChangesController.add(_cachedRole!);
    return _cachedRole!;
  }

  /// Kept for source compatibility with existing call sites; delegates to
  /// [checkRole].
  Future<bool> checkIsAdmin() async {
    final resolved = await checkRole();
    return resolved.atLeast(AppRole.admin);
  }

  /// User display name
  String? get displayName => currentUser?.displayName;

  /// User email
  String? get email => _emailOverride != null
      ? _emailOverride!()
      : currentUser?.email;

  /// User photo URL
  String? get photoUrl => currentUser?.photoURL;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web uses popup - always show account selection
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({
          'prompt': 'select_account', // Force account selection
        });

        return await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        // Mobile/Desktop - sign out first to force account selection
        await _google.signOut();
        final GoogleSignInAccount? googleUser = await _google.signIn();
        if (googleUser == null) {
          return null; // User cancelled
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _firebaseAuth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign in anonymously (guest mode)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _firebaseAuth.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _google.signOut();
      }
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Sign-out failed: $e');
      rethrow;
    }
  }

  /// Link anonymous account with Google
  Future<UserCredential?> linkWithGoogle() async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      return null;
    }

    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({
          'prompt': 'select_account', // Force account selection
        });

        return await user.linkWithPopup(googleProvider);
      } else {
        await _google.signOut(); // Force account selection
        final GoogleSignInAccount? googleUser = await _google.signIn();
        if (googleUser == null) {
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await user.linkWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Link with Google failed: $e');
      rethrow;
    }
  }

  // ============ Admin Functions ============

  /// Get list of allowed users (admin or super admin only)
  Future<List<AllowedUser>> getAllowedUsers() async {
    if (!canManageUsers) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('allowedUsers')
          .get();

      return snapshot.docs
          .map((doc) => AllowedUser.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Failed to get allowed users: $e');
      return [];
    }
  }

  /// Add allowed user (admin or super admin only)
  Future<bool> addAllowedUser(
    String email, {
    String? name,
    bool isAdmin = false,
  }) async {
    if (!canManageUsers) return false;

    try {
      await FirebaseFirestore.instance
          .collection('allowedUsers')
          .doc(email.toLowerCase())
          .set({
            'email': email.toLowerCase(),
            'name': name ?? '',
            'isAdmin': isAdmin,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': this.email,
          });
      return true;
    } catch (e) {
      debugPrint('Failed to add allowed user: $e');
      return false;
    }
  }

  /// Update admin status of an allowed user
  Future<bool> updateAdminStatus(String email, bool isAdmin) async {
    if (!canManageUsers) return false;

    try {
      await FirebaseFirestore.instance
          .collection('allowedUsers')
          .doc(email.toLowerCase())
          .update({'isAdmin': isAdmin});
      return true;
    } catch (e) {
      debugPrint('Failed to update admin status: $e');
      return false;
    }
  }

  /// Remove allowed user (admin only)
  Future<bool> removeAllowedUser(String email) async {
    if (!isAdmin) return false;

    try {
      await FirebaseFirestore.instance
          .collection('allowedUsers')
          .doc(email.toLowerCase())
          .delete();
      return true;
    } catch (e) {
      debugPrint('Failed to remove allowed user: $e');
      return false;
    }
  }

  /// Check if email is in allowed users list
  Future<bool> isUserAllowed(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('allowedUsers')
          .doc(email.toLowerCase())
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Failed to check allowed user: $e');
      return false;
    }
  }
}

/// Model for allowed user
class AllowedUser {
  final String email;
  final String name;
  final bool isAdmin;
  final DateTime? createdAt;

  AllowedUser({
    required this.email,
    required this.name,
    required this.isAdmin,
    this.createdAt,
  });

  factory AllowedUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AllowedUser(
      email: data['email'] ?? doc.id,
      name: data['name'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  AllowedUser copyWith({
    String? email,
    String? name,
    bool? isAdmin,
    DateTime? createdAt,
  }) {
    return AllowedUser(
      email: email ?? this.email,
      name: name ?? this.name,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

final authService = AuthService();
