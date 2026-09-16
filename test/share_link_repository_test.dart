import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/data/share_link_repository.dart';
import 'package:cocktail_planer/models/order.dart';

void main() {
  group('ShareLinkRepository invoice snapshot allowlist', () {
    test('invoiceSnapshotFields excludes PII and internal-only fields, keeps invoice fields', () {
      final order = SavedOrder(
        id: 'x',
        name: 'Test',
        date: DateTime(2026, 1, 1),
        items: const [],
        total: 0,
        personCount: 1,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.quote,
        userId: 'uid-123',
        userEmail: 'customer@example.com',
        createdBy: 'staff@example.com',
        phone: '+41 79 000 00 00',
      );

      final snapshot = ShareLinkRepository.invoiceSnapshotFields(order.toJson());

      expect(snapshot.containsKey('userId'), isFalse);
      expect(snapshot.containsKey('userEmail'), isFalse);
      expect(snapshot.containsKey('createdBy'), isFalse);
      expect(snapshot.containsKey('phone'), isFalse);
      expect(snapshot['name'], 'Test');
      expect(snapshot['total'], 0);
    });
  });

  group('ShareLinkResult', () {
    test('not-found result exposes found=false with no data', () {
      const result = ShareLinkResult.notFound();
      expect(result.found, isFalse);
      expect(result.type, isNull);
      expect(result.snapshot, isNull);
    });
  });
}
