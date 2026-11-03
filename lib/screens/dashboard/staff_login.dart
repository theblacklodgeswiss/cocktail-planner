import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// Signs in with Google (staff login from the user menu, there is no login
/// screen) and reports a failure in a snackbar. Returns true when signed in.
/// Takes the messenger so callers can capture it before closing a sheet; a
/// closed Google dialog shows nothing. [signIn] is only overridden in tests.
Future<bool> staffGoogleLogin(
  ScaffoldMessengerState messenger, {
  Future<UserCredential?> Function()? signIn,
}) async {
  try {
    final result = await (signIn ?? authService.signInWithGoogle)();
    if (result == null) return false;
    await authService.checkIsAdmin();
    return true;
  } on FirebaseAuthException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(_errorKeyFor(e.code).tr())),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text('login.error_failed'.tr())),
    );
  }
  return false;
}

String _errorKeyFor(String code) => switch (code) {
  'popup-closed-by-user' => 'login.error_cancelled',
  'account-exists-with-different-credential' => 'login.error_exists',
  'invalid-credential' => 'login.error_invalid',
  'operation-not-allowed' => 'login.error_not_enabled',
  'user-disabled' => 'login.error_disabled',
  _ => 'login.error_failed',
};
