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

  group('internal fields stay out of share links', () {
    test('invoice snapshot strips item source and stock flags', () {
      final order = SavedOrder(
        id: 'x',
        name: 'Test',
        date: DateTime(2026, 1, 1),
        items: const [
          {
            'name': 'Rum',
            'price': 12,
            'quantity': 2,
            'source': 'stock',
            'sourceLocationId': 'l1',
          },
        ],
        total: 24,
        personCount: 1,
        drinkerType: 'normal',
        currency: 'EUR',
        status: OrderStatus.quote,
        stockApplied: true,
        restRecorded: true,
      );
      final snapshot = ShareLinkRepository.invoiceSnapshotFields(order.toJson());
      final item = (snapshot['items'] as List).single as Map<String, dynamic>;
      expect(item.containsKey('source'), isFalse);
      expect(item.containsKey('sourceLocationId'), isFalse);
      expect(item['name'], 'Rum');
      expect(item['quantity'], 2);
      expect(snapshot.containsKey('stockApplied'), isFalse);
      expect(snapshot.containsKey('restRecorded'), isFalse);
      // The order itself is untouched.
      expect(order.items.single['source'], 'stock');
    });

    test('withoutInternalItemFields leaves other keys alone', () {
      expect(
        withoutInternalItemFields({'name': 'a', 'source': 'shop'}),
        {'name': 'a'},
      );
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
