import 'package:cocktail_planer/services/auth_service.dart';

/// Mock AuthService for testing that doesn't require Firebase
class MockAuthService implements AuthService {
  bool _isAdmin = false;
  
  void setIsAdmin(bool value) {
    _isAdmin = value;
  }

  @override
  Future<bool> checkIsAdmin() async {
    return _isAdmin;
  }

  @override
  bool? get isAdmin => _isAdmin;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isAnonymous => false;

  @override
  String? get currentUserEmail => 'test@example.com';

  @override
  String? get currentUserId => 'test-user-id';

  @override
  String? get currentUserDisplayName => 'Test User';

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  void initialize({String? googleClientId}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Global mock instance for tests
final mockAuthService = MockAuthService();
