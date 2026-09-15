import 'package:cocktail_planer/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShotSelection', () {
    test('holds a name and quantity', () {
      const selection = ShotSelection(name: 'Aarewasser', quantity: 20);
      expect(selection.name, 'Aarewasser');
      expect(selection.quantity, 20);
    });
  });

  group('SavedOrder.requestedShotsTotal', () {
    test('sums quantities across selections', () {
      final order = SavedOrder.fromFirestore('o1', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
        'shotQuantities': [
          {'name': 'Aarewasser', 'quantity': 20},
          {'name': 'Tequila', 'quantity': 10},
        ],
      });

      expect(order.requestedShotsTotal, 30);
      expect(order.shotSelections.map((s) => s.name), ['Aarewasser', 'Tequila']);
    });

    test('is zero when shotQuantities is missing', () {
      final order = SavedOrder.fromFirestore('o2', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
      });

      expect(order.requestedShotsTotal, 0);
      expect(order.shotSelections, isEmpty);
    });

    test('skips malformed entries (empty name or non-positive quantity)', () {
      final order = SavedOrder.fromFirestore('o3', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
        'shotQuantities': [
          {'name': '', 'quantity': 5},
          {'name': 'Valid', 'quantity': 0},
          {'name': 'Valid', 'quantity': -1},
          {'name': 'Tequila', 'quantity': 10},
        ],
      });

      expect(order.shotSelections, [const ShotSelection(name: 'Tequila', quantity: 10)]);
      expect(order.requestedShotsTotal, 10);
    });
  });
}
