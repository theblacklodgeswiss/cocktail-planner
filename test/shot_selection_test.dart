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

    test(
      'requestedShotsTotal is available as the default when offerShotsCount is not yet set',
      () {
        final order = SavedOrder.fromFirestore('o4', {
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

        // No admin override yet: offerShotsCount defaults to 0, and the
        // customer's requested total is available to seed the offer's Shots
        // position from.
        expect(order.offerShotsCount, 0);
        expect(order.requestedShotsTotal, 30);
      },
    );

    test(
      'offerShotsCount is independent of requestedShotsTotal once an admin override is set',
      () {
        final order = SavedOrder.fromFirestore('o5', {
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
          'offerShotsCount': 100,
        });

        // Both fields coexist correctly: the admin's override does not
        // mutate or clamp the customer's originally requested total, so UI
        // code reading both can implement "admin override takes precedence
        // over requestedShotsTotal" without either field corrupting the
        // other.
        expect(order.offerShotsCount, 100);
        expect(order.requestedShotsTotal, 30);
      },
    );
  });
}
