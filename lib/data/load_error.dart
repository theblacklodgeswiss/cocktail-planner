import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

/// Longest raw error text shown to the user.
const loadErrorMaxLength = 200;

/// Translation key, code and extra text of a failed load, without the
/// localization applied (see [describeLoadError]).
class LoadErrorInfo {
  const LoadErrorInfo({required this.key, this.code, this.detail, this.link});

  /// Translation key of the cause (`load_error.*`).
  final String key;

  /// Firestore error code, e.g. `permission-denied`.
  final String? code;

  /// Error type and (truncated) message for causes without a known code.
  final String? detail;

  /// Index creation link from a failed-precondition message.
  final String? link;
}

final _url = RegExp(r'https://\S+');

String _truncate(String s) => s.length <= loadErrorMaxLength
    ? s
    : '${s.substring(0, loadErrorMaxLength)}…';

/// Classifies a stream or future error of a Firestore read. Web codes may
/// carry a `firestore/` prefix, which is stripped.
LoadErrorInfo classifyLoadError(Object error) {
  if (error is TimeoutException) {
    return const LoadErrorInfo(key: 'load_error.timeout');
  }
  if (error is FirebaseException) {
    final code = error.code.split('/').last;
    switch (code) {
      case 'permission-denied':
        return LoadErrorInfo(key: 'load_error.permission_denied', code: code);
      case 'failed-precondition':
        final link = _url.firstMatch(error.message ?? '')?.group(0);
        return LoadErrorInfo(
          key: 'load_error.index_missing',
          code: code,
          link: link,
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return LoadErrorInfo(key: 'load_error.unavailable', code: code);
      case 'unauthenticated':
        return LoadErrorInfo(key: 'load_error.unauthenticated', code: code);
    }
    return LoadErrorInfo(
      key: 'load_error.other',
      code: code,
      detail: _truncate('${error.runtimeType} [$code]: ${error.message ?? ''}'),
    );
  }
  return LoadErrorInfo(
    key: 'load_error.other',
    detail: _truncate('${error.runtimeType}: $error'),
  );
}

/// One-line, localized cause of a failed load for the second line of an
/// error state, e.g. "Keine Berechtigung (permission-denied)". [translate]
/// defaults to easy_localization.
String describeLoadError(
  Object error, {
  String Function(String key)? translate,
}) {
  final t = translate ?? (String k) => k.tr();
  final info = classifyLoadError(error);
  final parts = <String>[
    info.code == null || info.detail != null
        ? t(info.key)
        : '${t(info.key)} (${info.code})',
    ?info.detail,
    ?info.link,
  ];
  return parts.join('\n');
}
