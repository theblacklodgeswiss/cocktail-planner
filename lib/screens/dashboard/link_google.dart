import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// Links the anonymous account with Google and reports the result in a
/// snackbar. Takes the messenger (not a context) so callers can capture it
/// before closing a sheet. A cancelled dialog (null result) shows nothing.
/// [link] is only overridden in tests.
Future<void> linkGoogleAccount(
  ScaffoldMessengerState messenger, {
  Future<UserCredential?> Function()? link,
}) async {
  try {
    final result = await (link ?? authService.linkWithGoogle)();
    if (result == null) return;
    messenger.showSnackBar(SnackBar(content: Text('drawer.link_success'.tr())));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('${'common.error'.tr()}: $e')),
    );
  }
}
