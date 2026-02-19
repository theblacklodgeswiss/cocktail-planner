import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Admin email - only this user has admin privileges
const String adminEmail = 'the.blacklodge@outlook.com';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;

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

  /// Check if current user is admin
  bool get isAdmin {
    final userEmail = email;
    return userEmail != null && userEmail.toLowerCase() == adminEmail.toLowerCase();
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
        // Web uses popup
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        return await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        // Mobile/Desktop uses GoogleSignIn package
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
        
        return await user.linkWithPopup(googleProvider);
      } else {
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

  /// Get list of allowed users (admin only)
  Future<List<AllowedUser>> getAllowedUsers() async {
    if (!isAdmin) return [];
    
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

  /// Add allowed user (admin only)
  Future<bool> addAllowedUser(String email, {String? name, bool isAdmin = false}) async {
    if (!this.isAdmin) return false;
    
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
