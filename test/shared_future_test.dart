import 'dart:async';

import 'package:cocktail_planer/utils/shared_future.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent calls share one run', () async {
    final shared = SharedFuture<int>();
    final completer = Completer<int>();
    var runs = 0;
    final a = shared.run(() {
      runs++;
      return completer.future;
    });
    final b = shared.run(() {
      runs++;
      return completer.future;
    });
    completer.complete(7);
    expect(await a, 7);
    expect(await b, 7);
    expect(runs, 1);
  });

  test('a later call starts a new run', () async {
    final shared = SharedFuture<int>();
    var runs = 0;
    await shared.run(() async => ++runs);
    await shared.run(() async => ++runs);
    expect(runs, 2);
  });

  test('slot is cleared after an error', () async {
    final shared = SharedFuture<int>();
    await expectLater(
      shared.run(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await shared.run(() async => 1), 1);
  });
}
