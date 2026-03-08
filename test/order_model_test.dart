import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/models/order.dart';

void main() {
  group('OrderStatus Enum', () {
    test('has correct values', () {
      expect(OrderStatus.quote.value, 'quote');
      expect(OrderStatus.accepted.value, 'accepted');
      expect(OrderStatus.declined.value, 'declined');
    });

    test('has correct labels', () {
      expect(OrderStatus.quote.label, 'Angebot');
      expect(OrderStatus.accepted.label, 'Angenommen');
      expect(OrderStatus.declined.label, 'Abgelehnt');
    });

    test('fromString returns correct enum', () {
      expect(OrderStatus.fromString('quote'), OrderStatus.quote);
      expect(OrderStatus.fromString('accepted'), OrderStatus.accepted);
      expect(OrderStatus.fromString('declined'), OrderStatus.declined);
    });

    test('fromString defaults to quote for invalid values', () {
      expect(OrderStatus.fromString('invalid'), OrderStatus.quote);
      expect(OrderStatus.fromString(null), OrderStatus.quote);
      expect(OrderStatus.fromString(''), OrderStatus.quote);
    });
  });

  group('OrderSource Enum', () {
    test('has correct values', () {
      expect(OrderSource.app.value, 'app');
      expect(OrderSource.form.value, 'form');
    });

    test('fromString returns correct enum', () {
      expect(OrderSource.fromString('app'), OrderSource.app);
      expect(OrderSource.fromString('form'), OrderSource.form);
    });

    test('fromString defaults to app for invalid values', () {
      expect(OrderSource.fromString('invalid'), OrderSource.app);
      expect(OrderSource.fromString(null), OrderSource.app);
      expect(OrderSource.fromString(''), OrderSource.app);
    });
  });

  group('SavedOrder Model', () {
    test('year getter returns correct year from date', () {
      final order2024 = SavedOrder(
        id: 'o1',
        name: 'Order 2024',
        date: DateTime(2024, 1, 1),
        items: [],
        total: 100.0,
        personCount: 50,
        drinkerType: 'minimal',
        currency: 'CHF',
        status: OrderStatus.quote,
      );

      final order2025 = SavedOrder(
        id: 'o2',
        name: 'Order 2025',
        date: DateTime(2025, 6, 15),
        items: [],
        total: 200.0,
        personCount: 75,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.accepted,
      );

      final order2026 = SavedOrder(
        id: 'o3',
        name: 'Order 2026',
        date: DateTime(2026, 12, 31),
        items: [],
        total: 300.0,
        personCount: 100,
        drinkerType: 'heavy',
        currency: 'CHF',
        status: OrderStatus.declined,
      );

      expect(order2024.year, 2024);
      expect(order2025.year, 2025);
      expect(order2026.year, 2026);
    });

    test('pending order has total 0 and isPendingDismissed false', () {
      final pendingOrder = SavedOrder(
        id: 'pending1',
        name: 'Pending Form Submission',
        date: DateTime(2026, 3, 15),
        items: [],
        total: 0, // Pending orders have total == 0
        personCount: 0,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.quote,
        source: OrderSource.form, // From Microsoft Forms
        isPendingDismissed: false,
      );

      expect(pendingOrder.total, 0);
      expect(pendingOrder.isPendingDismissed, false);
      expect(pendingOrder.source, OrderSource.form);
      expect(pendingOrder.isFromForm, true);
      expect(pendingOrder.needsShoppingList, true); // Has no shopping list yet
    });

    test('completed order has total > 0', () {
      final completedOrder = SavedOrder(
        id: 'completed1',
        name: 'Completed Order',
        date: DateTime(2026, 3, 20),
        items: [
          {'name': 'Mojito', 'quantity': 50, 'price': 10.0}
        ],
        total: 500.0,
        personCount: 50,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.accepted,
        source: OrderSource.app,
        hasShoppingList: true,
      );

      expect(completedOrder.total, greaterThan(0));
      expect(completedOrder.source, OrderSource.app);
      expect(completedOrder.isAccepted, true);
      expect(completedOrder.isFromForm, false);
      expect(completedOrder.needsShoppingList, false); // Already has shopping list
    });

    test('fromFirestore deserializes correctly', () {
      final firestoreData = {
        'name': 'Birthday Party',
        'date': '2026-08-20T20:00:00.000',
        'items': [
          {'name': 'Aperol Spritz', 'quantity': 50}
        ],
        'total': 789.0,
        'personCount': 50,
        'drinkerType': 'light',
        'currency': 'CHF',
        'status': 'accepted',
        'phone': '+41 79 999 88 77',
        'location': 'Basel',
        'eventTime': '20:00',
        'source': 'app',
        'isPendingDismissed': false,
        'cocktails': ['Aperol Spritz', 'Mojito'],
        'hasShoppingList': true,
      };

      final order = SavedOrder.fromFirestore('doc123', firestoreData);

      expect(order.id, 'doc123');
      expect(order.name, 'Birthday Party');
      expect(order.date.year, 2026);
      expect(order.date.month, 8);
      expect(order.date.day, 20);
      expect(order.total, 789.0);
      expect(order.personCount, 50);
      expect(order.status, OrderStatus.accepted);
      expect(order.source, OrderSource.app);
      expect(order.isPendingDismissed, false);
      expect(order.cocktails, ['Aperol Spritz', 'Mojito']);
      expect(order.hasShoppingList, true);
    });

    test('fromFirestore handles missing optional fields', () {
      final minimalData = {
        'name': 'Minimal Order',
        'date': '2026-01-01',
        'items': [],
        'total': 0,
        'personCount': 0,
        'drinkerType': 'normal',
        'currency': 'CHF',
        'status': 'quote',
      };

      final order = SavedOrder.fromFirestore('minimal123', minimalData);

      expect(order.id, 'minimal123');
      expect(order.name, 'Minimal Order');
      expect(order.total, 0);
      expect(order.status, OrderStatus.quote);
      expect(order.source, OrderSource.app); // Default value
      expect(order.isPendingDismissed, false); // Default value
      expect(order.cocktails, []); // Default empty list
      expect(order.phone, ''); // Default empty string
    });

    test('isAccepted returns true for accepted status', () {
      final acceptedOrder = SavedOrder(
        id: 'acc1',
        name: 'Accepted',
        date: DateTime.now(),
        items: [],
        total: 100,
        personCount: 10,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.accepted,
      );

      final quoteOrder = SavedOrder(
        id: 'q1',
        name: 'Quote',
        date: DateTime.now(),
        items: [],
        total: 100,
        personCount: 10,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.quote,
      );

      expect(acceptedOrder.isAccepted, true);
      expect(quoteOrder.isAccepted, false);
    });
  });

  group('Order Filtering Logic', () {
    late List<SavedOrder> testOrders;

    setUp(() {
      testOrders = [
        // Pending orders (total == 0)
        SavedOrder(
          id: 'p1',
          name: 'Pending 2025',
          date: DateTime(2025, 1, 15),
          items: [],
          total: 0,
          personCount: 0,
          drinkerType: 'normal',
          currency: 'CHF',
          status: OrderStatus.quote,
          source: OrderSource.form,
          isPendingDismissed: false,
        ),
        SavedOrder(
          id: 'p2',
          name: 'Pending 2026',
          date: DateTime(2026, 3, 20),
          items: [],
          total: 0,
          personCount: 0,
          drinkerType: 'normal',
          currency: 'CHF',
          status: OrderStatus.quote,
          source: OrderSource.form,
          isPendingDismissed: false,
        ),
        // Dismissed pending order (should not appear in pending list)
        SavedOrder(
          id: 'p3',
          name: 'Dismissed Pending',
          date: DateTime(2026, 2, 10),
          items: [],
          total: 0,
          personCount: 0,
          drinkerType: 'normal',
          currency: 'CHF',
          status: OrderStatus.quote,
          source: OrderSource.form,
          isPendingDismissed: true, // Dismissed
        ),
        // Completed orders 2026
        SavedOrder(
          id: 'c1',
          name: 'Completed Offer 2026',
          date: DateTime(2026, 6, 1),
          items: [
            {'name': 'Mojito', 'quantity': 10}
          ],
          total: 250.0,
          personCount: 30,
          drinkerType: 'normal',
          currency: 'CHF',
          status: OrderStatus.quote,
          source: OrderSource.app,
        ),
        SavedOrder(
          id: 'c2',
          name: 'Accepted Order 2026',
          date: DateTime(2026, 7, 15),
          items: [
            {'name': 'Caipirinha', 'quantity': 20}
          ],
          total: 500.0,
          personCount: 50,
          drinkerType: 'viel',
          currency: 'CHF',
          status: OrderStatus.accepted,
          source: OrderSource.app,
        ),
        // Completed orders 2025 (should not be included in 2026 list)
        SavedOrder(
          id: 'c3',
          name: 'Old Order 2025',
          date: DateTime(2025, 12, 31),
          items: [
            {'name': 'Aperol Spritz', 'quantity': 15}
          ],
          total: 300.0,
          personCount: 40,
          drinkerType: 'normal',
          currency: 'CHF',
          status: OrderStatus.accepted,
          source: OrderSource.app,
        ),
      ];
    });

    test('pending filter includes only orders with total == 0 and not dismissed', () {
      // Dashboard pending logic: total == 0 && !isPendingDismissed
      final pendingOrders = testOrders.where((o) => 
        o.total == 0 && !o.isPendingDismissed
      ).toList();

      expect(pendingOrders.length, 2); // p1, p2 (not p3 because dismissed)
      expect(pendingOrders.map((o) => o.id).toList(), containsAll(['p1', 'p2']));
      expect(pendingOrders.map((o) => o.id).toList(), isNot(contains('p3'))); // Dismissed
    });

    test('completed orders filter excludes pending (total == 0)', () {
      // Orders with total > 0 are completed/real orders
      final completedOrders = testOrders.where((o) => o.total > 0).toList();

      expect(completedOrders.length, 3); // c1, c2, c3
      expect(completedOrders.map((o) => o.id).toList(), containsAll(['c1', 'c2', 'c3']));
      expect(completedOrders.every((o) => o.total > 0), true);
    });

    test('year filter with pending inclusion logic (repository + dashboard)', () {
      // Repository logic: (o.year == year) || (o.total == 0)
      // Returns ALL orders from year + ALL pending orders (including dismissed)
      final year = 2026;
      final fromRepository = testOrders.where((o) => 
        o.year == year || o.total == 0
      ).toList();

      // Repository returns 5: p1, p2, p3, c1, c2
      expect(fromRepository.length, 5);

      // Dashboard then filters out dismissed pending: o.total > 0 || !o.isPendingDismissed
      final dashboardView = fromRepository.where((o) => 
        o.total > 0 || !o.isPendingDismissed
      ).toList();

      // Dashboard shows 4: p1, p2, c1, c2 (p3 dismissed)
      expect(dashboardView.length, 4);
      expect(dashboardView.map((o) => o.id).toList(), containsAll(['p1', 'p2', 'c1', 'c2']));
      expect(dashboardView.map((o) => o.id).toList(), isNot(contains('c3'))); // Wrong year
      expect(dashboardView.map((o) => o.id).toList(), isNot(contains('p3'))); // Dismissed
    });

    test('dashboard counts: pending, offers, accepted for year 2026', () {
      final year = 2026;
      
      // Step 1: Repository filter - year match OR pending (total == 0)
      final fromRepository = testOrders.where((o) => 
        o.year == year || o.total == 0
      ).toList();

      // Step 2: Dashboard filter - remove dismissed pending
      final relevantOrders = fromRepository.where((o) => 
        o.total > 0 || !o.isPendingDismissed
      ).toList();

      // Pending count: total == 0 && !dismissed
      final pendingCount = relevantOrders.where((o) => 
        o.total == 0 && !o.isPendingDismissed
      ).length;

      // Only count completed orders (total > 0) for status cards
      final completedOrders = relevantOrders.where((o) => o.total > 0).toList();
      
      final offersCount = completedOrders.where((o) => 
        o.status == OrderStatus.quote
      ).length;

      final acceptedCount = completedOrders.where((o) => 
        o.status == OrderStatus.accepted
      ).length;

      expect(pendingCount, 2); // p1 (2025), p2 (2026) - both pending from any year
      expect(offersCount, 1); // c1 (quote, 2026)
      expect(acceptedCount, 1); // c2 (accepted, 2026)
    });
  });
}
