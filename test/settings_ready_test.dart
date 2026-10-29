import 'dart:async';

import 'package:cocktail_planer/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('awaitReady is immediate when nothing is tracked', () async {
    await SettingsRepository().awaitReady();
  });

  test('awaitReady waits for the tracked load', () async {
    final repo = SettingsRepository();
    final c = Completer<void>();
    repo.trackReady(c.future);
    var done = false;
    final f = repo.awaitReady().then((_) => done = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isFalse);
    c.complete();
    await f;
    expect(done, isTrue);
  });

  test('awaitReady times out and swallows errors', () async {
    final repo = SettingsRepository();
    repo.trackReady(Completer<void>().future);
    await repo.awaitReady(timeout: const Duration(milliseconds: 20));
    repo.trackReady(Future<void>.error(Exception('x')));
    await repo.awaitReady();
  });
}
