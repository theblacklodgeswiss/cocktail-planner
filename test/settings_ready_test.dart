import 'dart:async';

import 'package:cocktail_planer/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('awaitReady is immediate (true) when nothing is tracked', () async {
    expect(await SettingsRepository().awaitReady(), isTrue);
  });

  test('awaitReady waits for the tracked load and reports true', () async {
    final repo = SettingsRepository();
    final c = Completer<void>();
    repo.trackReady(c.future);
    bool? done;
    final f = repo.awaitReady().then((v) => done = v);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isNull);
    c.complete();
    await f;
    expect(done, isTrue);
  });

  test('awaitReady reports false on timeout and on error', () async {
    final repo = SettingsRepository();
    repo.trackReady(Completer<void>().future);
    expect(
      await repo.awaitReady(timeout: const Duration(milliseconds: 20)),
      isFalse,
    );
    repo.trackReady(Future<void>.error(Exception('x')));
    expect(await repo.awaitReady(), isFalse);
  });

  group('authoritative flag / ensureLoaded', () {
    test('false before load, false after failed load, true after success',
        () async {
      final repo = SettingsRepository();
      expect(repo.currentIsAuthoritative, isFalse);

      repo.fetchOverride = () async => throw Exception('down');
      expect(await repo.ensureLoaded(), isFalse);
      expect(repo.currentIsAuthoritative, isFalse);

      repo.fetchOverride = () async => {'companyName': 'ACME'};
      expect(await repo.ensureLoaded(), isTrue);
      expect(repo.currentIsAuthoritative, isTrue);
      expect(repo.current.companyName, 'ACME');
    });

    test('ensureLoaded does not reload when already authoritative', () async {
      final repo = SettingsRepository();
      var calls = 0;
      repo.fetchOverride = () async {
        calls++;
        return {'companyName': 'A'};
      };
      await repo.ensureLoaded();
      await repo.ensureLoaded();
      expect(calls, 1);
    });

    test('unavailable Firestore without override stays non-authoritative',
        () async {
      final repo = SettingsRepository();
      expect(await repo.ensureLoaded(), isFalse);
    });
  });
}
