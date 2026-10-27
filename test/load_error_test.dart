import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cocktail_planer/data/load_error.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Looks a dotted key up in the real translation file.
String Function(String) translator(String lang) {
  final m =
      jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>;
  return (key) {
    Object? node = m;
    for (final part in key.split('.')) {
      node = (node as Map<String, dynamic>)[part];
    }
    return node! as String;
  };
}

FirebaseException fx(String code, [String? message]) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: message);

void main() {
  final de = translator('de');
  final en = translator('en');

  test('permission-denied', () {
    final e = fx('permission-denied', 'Missing or insufficient permissions.');
    expect(
      describeLoadError(e, translate: de),
      'Keine Berechtigung (permission-denied)',
    );
    expect(
      describeLoadError(e, translate: en),
      'No permission (permission-denied)',
    );
  });

  test('web code prefix is stripped', () {
    expect(
      classifyLoadError(fx('firestore/permission-denied')).code,
      'permission-denied',
    );
  });

  test('failed-precondition: index missing plus the creation link', () {
    const link =
        'https://console.firebase.google.com/v1/r/project/x/firestore/indexes?create_composite=abc';
    final e = fx(
      'failed-precondition',
      'The query requires an index. You can create it here: $link',
    );
    final info = classifyLoadError(e);
    expect(info.link, link);
    expect(
      describeLoadError(e, translate: de),
      'Index fehlt (failed-precondition)\n$link',
    );
  });

  test('failed-precondition without link', () {
    expect(
      describeLoadError(fx('failed-precondition', 'x'), translate: de),
      'Index fehlt (failed-precondition)',
    );
  });

  test('unavailable and deadline-exceeded mean no connection', () {
    expect(
      describeLoadError(fx('unavailable'), translate: de),
      'Keine Verbindung (unavailable)',
    );
    expect(
      describeLoadError(fx('deadline-exceeded'), translate: de),
      'Keine Verbindung (deadline-exceeded)',
    );
  });

  test('timeout', () {
    final text = describeLoadError(
      TimeoutException('x', const Duration(seconds: 12)),
      translate: de,
    );
    expect(text, startsWith('Zeitüberschreitung'));
  });

  test('unknown Firebase code shows type, code and message', () {
    final text = describeLoadError(
      fx('internal', 'boom happened'),
      translate: de,
    );
    expect(text, startsWith('Unbekannter Fehler\n'));
    expect(text, contains('[internal]'));
    expect(text, contains('boom happened'));
  });

  test('other errors: type and truncated message', () {
    final text = describeLoadError(TypeError(), translate: de);
    expect(text, contains('TypeError'));
    final long = describeLoadError(StateError('x' * 1000), translate: de);
    final detail = long.split('\n')[1];
    expect(detail.length, lessThanOrEqualTo(loadErrorMaxLength + 1));
    expect(detail, endsWith('…'));
  });
}
