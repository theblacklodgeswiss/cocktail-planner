import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Super Admin email - always has admin privileges (hardcoded fallback)
const String superAdminEmail = 'the.blacklodge@outlook.com';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  bool? _cachedIsAdmin;

  FirebaseAuth get _firebaseAuth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
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

  /// Check if current user is admin (sync - uses cache)
  bool get isAdmin {
    final userEmail = email;
    if (userEmail == null) return false;
    return _cachedIsAdmin ?? false;
  }

  /// Check if current user can manage users (admin or super admin)
  bool get canManageUsers {
    final userEmail = email;
    if (userEmail == null) return false;
    if (userEmail.toLowerCase() == superAdminEmail.toLowerCase()) return true;
    return _cachedIsAdmin ?? false;
  }

  /// Check admin status from Firestore (async - call on login)
  Future<bool> checkIsAdmin() async {
    final userEmail = email;
    if (userEmail == null) {
      _cachedIsAdmin = false;
      return false;
    }

    // Super admin can manage users but is not a data admin
    if (userEmail.toLowerCase() == superAdminEmail.toLowerCase()) {
      _cachedIsAdmin = false;
      return false;
    }
    
    // Check Firestore allowedUsers collection
    try {
      final doc = await FirebaseFirestore.instance
          .collection('allowedUsers')
          .doc(userEmail.toLowerCase())
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        _cachedIsAdmin = data?['isAdmin'] == true;
      } else {
        _cachedIsAdmin = false;
      }
    } catch (e) {
      debugPrint('Failed to check admin status: $e');
      _cachedIsAdmin = false;
    }
    
    return _cachedIsAdmin ?? false;
  }

  /// User display name
  String? get displayName => currentUser?.displayName;

  /// User email
  String? get email => currentUser?.email;

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

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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
      
      return snapshot.docs.map((doc) => AllowedUser.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Failed to get allowed users: $e');
      return [];
    }
  }

  /// Add allowed user (admin or super admin only)
  Future<bool> addAllowedUser(String email, {String? name, bool isAdmin = false}) async {
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
}

final authService = AuthService();
