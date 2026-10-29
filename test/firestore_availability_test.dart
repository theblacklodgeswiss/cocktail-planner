import 'package:cocktail_planer/data/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('optimistic while pending, real result after, single probe on success',
      () async {
    final s = FirestoreService();
    var probes = 0;
    s.probeOverride = () async => probes++;
    expect(s.isAvailable, isFalse);
    final f = s.availabilityKnown;
    expect(s.isAvailable, isTrue);
    expect(await f, isTrue);
    expect(await s.availabilityKnown, isTrue);
    expect(probes, 1);
  });

  test('failed check is retried only after retryAfter', () async {
    final s = FirestoreService();
    var t = DateTime(2026);
    s.now = () => t;
    var probes = 0;
    var fail = true;
    s.probeOverride = () async {
      probes++;
      if (fail) throw Exception('down');
    };
    expect(await s.availabilityKnown, isFalse);
    expect(s.isAvailable, isFalse);
    expect(await s.availabilityKnown, isFalse);
    expect(probes, 1);
    t = t.add(const Duration(seconds: 11));
    fail = false;
    expect(await s.availabilityKnown, isTrue);
    expect(probes, 2);
    expect(s.isAvailable, isTrue);
  });
}
