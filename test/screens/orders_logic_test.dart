import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/orders/orders_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Characterization of the order list rules as they were before the
/// redesign (moved verbatim out of the orders, pending, year and dashboard
/// screens). These must not change.
SavedOrder order(
  String id, {
  String name = 'Order',
  DateTime? date,
  double total = 100,
  OrderStatus status = OrderStatus.quote,
  int persons = 50,
  String guestRange = '',
  String location = '',
  bool dismissed = false,
  DateTime? createdAt,
  DateTime? formCreatedAt,
}) => SavedOrder(
  id: id,
  name: name,
  date: date ?? DateTime(2026, 6, 1),
  items: const [],
  total: total,
  personCount: persons,
  drinkerType: 'normal',
  currency: 'CHF',
  status: status,
  guestCountRange: guestRange,
  location: location,
  isPendingDismissed: dismissed,
  createdAt: createdAt,
  formCreatedAt: formCreatedAt,
);

List<String> ids(List<SavedOrder> orders) => [for (final o in orders) o.id];

void main() {
  // Stream order: createdAt descending (as `watchOrders` delivers it).
  final sample = [
    order('q1', name: 'Hochzeit Meier', status: OrderStatus.quote),
    order('a1', name: 'Firmenfest', status: OrderStatus.accepted, persons: 120),
    order('c1', name: 'Geburtstag', status: OrderStatus.completed),
    order('d1', name: 'Absage', status: OrderStatus.declined),
    order('q2', name: 'Sommerfest', status: OrderStatus.quote, guestRange: '80-100'),
    order('a2', name: 'Jubiläum', status: OrderStatus.accepted),
  ];

  group('statusFilterFromQuery (?status=)', () {
    test('accepted selects accepted', () {
      expect(statusFilterFromQuery('accepted'), OrderStatusFilter.accepted);
    });
    test('offer and quote select quotes', () {
      expect(statusFilterFromQuery('offer'), OrderStatusFilter.quotes);
      expect(statusFilterFromQuery('quote'), OrderStatusFilter.quotes);
    });
    test('missing or unknown values fall back to quotes', () {
      expect(statusFilterFromQuery(null), OrderStatusFilter.quotes);
      expect(statusFilterFromQuery('bogus'), OrderStatusFilter.quotes);
    });
  });

  group('filterLatestOrders', () {
    test('quotes keeps OrderStatus.quote only, in stream order', () {
      final r = filterLatestOrders(
        sample,
        query: '',
        filter: OrderStatusFilter.quotes,
      );
      expect(ids(r), ['q1', 'q2']);
    });

    test('accepted uses isAccepted (includes completed)', () {
      final r = filterLatestOrders(
        sample,
        query: '',
        filter: OrderStatusFilter.accepted,
      );
      expect(ids(r), ['a1', 'c1', 'a2']);
    });

    test('all keeps every order', () {
      final r = filterLatestOrders(
        sample,
        query: '',
        filter: OrderStatusFilter.all,
      );
      expect(ids(r), ids(sample));
    });

    test('caps to the latest 10 when not searching', () {
      final many = [
        for (var i = 0; i < 25; i++) order('o$i', status: OrderStatus.quote),
      ];
      final r = filterLatestOrders(
        many,
        query: '',
        filter: OrderStatusFilter.quotes,
      );
      expect(latestOrdersLimit, 10);
      expect(ids(r), [for (var i = 0; i < 10; i++) 'o$i']);
    });

    test('search ignores the status filter and the cap', () {
      final many = [
        for (var i = 0; i < 25; i++)
          order('o$i', name: 'Fest $i', status: OrderStatus.declined),
      ];
      final r = filterLatestOrders(
        many,
        query: 'fest',
        filter: OrderStatusFilter.accepted,
      );
      expect(r.length, 25);
    });

    test('search matches name (case-insensitive), guests and range', () {
      expect(
        ids(filterLatestOrders(
          sample,
          query: 'MEIER',
          filter: OrderStatusFilter.accepted,
        )),
        ['q1'],
      );
      expect(
        ids(filterLatestOrders(
          sample,
          query: '120',
          filter: OrderStatusFilter.quotes,
        )),
        ['a1'],
      );
      expect(
        ids(filterLatestOrders(
          sample,
          query: '80-1',
          filter: OrderStatusFilter.accepted,
        )),
        ['q2'],
      );
    });
  });

  group('filterAndSortPending', () {
    final pending = [
      order(
        'p1',
        name: 'beta',
        date: DateTime(2026, 9, 1),
        persons: 30,
        location: 'Bern',
        createdAt: DateTime(2026, 1, 3),
      ),
      order(
        'p2',
        name: 'Alpha',
        date: DateTime(2026, 7, 1),
        persons: 90,
        location: 'Zürich',
        createdAt: DateTime(2026, 1, 1),
        formCreatedAt: DateTime(2026, 1, 5),
      ),
      order(
        'p3',
        name: 'gamma',
        date: DateTime(2026, 8, 1),
        persons: 60,
        createdAt: DateTime(2026, 1, 2),
      ),
    ];

    test('default: event date ascending', () {
      expect(
        ids(filterAndSortPending(
          pending,
          query: '',
          sort: PendingSortOption.eventDate,
          ascending: true,
        )),
        ['p2', 'p3', 'p1'],
      );
    });

    test('descending flips the order', () {
      expect(
        ids(filterAndSortPending(
          pending,
          query: '',
          sort: PendingSortOption.eventDate,
          ascending: false,
        )),
        ['p1', 'p3', 'p2'],
      );
    });

    test('created uses formCreatedAt ?? createdAt ?? date', () {
      expect(
        ids(filterAndSortPending(
          pending,
          query: '',
          sort: PendingSortOption.createdAt,
          ascending: true,
        )),
        ['p3', 'p1', 'p2'],
      );
    });

    test('guests and name (case-insensitive)', () {
      expect(
        ids(filterAndSortPending(
          pending,
          query: '',
          sort: PendingSortOption.guests,
          ascending: true,
        )),
        ['p1', 'p3', 'p2'],
      );
      expect(
        ids(filterAndSortPending(
          pending,
          query: '',
          sort: PendingSortOption.name,
          ascending: true,
        )),
        ['p2', 'p1', 'p3'],
      );
    });

    test('search also matches the location', () {
      expect(
        ids(filterAndSortPending(
          pending,
          query: 'zür',
          sort: PendingSortOption.eventDate,
          ascending: true,
        )),
        ['p2'],
      );
    });
  });

  group('ordersPerYear', () {
    test('counts per event year, years newest first', () {
      final r = ordersPerYear([
        order('a', date: DateTime(2025, 3, 1)),
        order('b', date: DateTime(2026, 3, 1)),
        order('c', date: DateTime(2026, 5, 1)),
        order('d', date: DateTime(2024, 5, 1)),
      ]);
      expect(r.keys.toList(), [2026, 2025, 2024]);
      expect(r.values.toList(), [2, 1, 1]);
    });

    test('ordersOfYear keeps stream order', () {
      final r = ordersOfYear([
        order('a', date: DateTime(2025, 3, 1)),
        order('b', date: DateTime(2026, 3, 1)),
        order('c', date: DateTime(2026, 1, 1)),
      ], 2026);
      expect(ids(r), ['b', 'c']);
    });
  });

  group('dashboardCounts (stream: includePending, current year)', () {
    test('pending = total 0 and not dismissed; status counts need total > 0',
        () {
      final c = dashboardCounts([
        order('p1', total: 0, status: OrderStatus.quote),
        order('p2', total: 0, status: OrderStatus.accepted),
        order('p3', total: 0, dismissed: true),
        order('q1', status: OrderStatus.quote),
        order('q2', status: OrderStatus.quote),
        order('a1', status: OrderStatus.accepted),
        order('c1', status: OrderStatus.completed),
        order('d1', status: OrderStatus.declined),
      ]);
      expect(c.pending, 2);
      expect(c.openOffers, 2);
      expect(c.accepted, 2);
    });
  });

  group('listCounts (orders overview, stream without pending)', () {
    test('quotes, accepted (isAccepted) and total', () {
      final c = listCounts(sample);
      expect(c.all, 6);
      expect(c.quotes, 2);
      expect(c.accepted, 3);
    });
  });
}
