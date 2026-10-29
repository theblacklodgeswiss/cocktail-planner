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
  String currency = 'CHF',
}) => SavedOrder(
  id: id,
  name: name,
  date: date ?? DateTime(2026, 6, 1),
  items: const [],
  total: total,
  personCount: persons,
  drinkerType: 'normal',
  currency: currency,
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
    order(
      'q2',
      name: 'Sommerfest',
      status: OrderStatus.quote,
      guestRange: '80-100',
    ),
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
        ids(
          filterLatestOrders(
            sample,
            query: 'MEIER',
            filter: OrderStatusFilter.accepted,
          ),
        ),
        ['q1'],
      );
      expect(
        ids(
          filterLatestOrders(
            sample,
            query: '120',
            filter: OrderStatusFilter.quotes,
          ),
        ),
        ['a1'],
      );
      expect(
        ids(
          filterLatestOrders(
            sample,
            query: '80-1',
            filter: OrderStatusFilter.accepted,
          ),
        ),
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
        ids(
          filterAndSortPending(
            pending,
            query: '',
            sort: PendingSortOption.eventDate,
            ascending: true,
          ),
        ),
        ['p2', 'p3', 'p1'],
      );
    });

    test('descending flips the order', () {
      expect(
        ids(
          filterAndSortPending(
            pending,
            query: '',
            sort: PendingSortOption.eventDate,
            ascending: false,
          ),
        ),
        ['p1', 'p3', 'p2'],
      );
    });

    test('created uses formCreatedAt ?? createdAt ?? date', () {
      expect(
        ids(
          filterAndSortPending(
            pending,
            query: '',
            sort: PendingSortOption.createdAt,
            ascending: true,
          ),
        ),
        ['p3', 'p1', 'p2'],
      );
    });

    test('guests and name (case-insensitive)', () {
      expect(
        ids(
          filterAndSortPending(
            pending,
            query: '',
            sort: PendingSortOption.guests,
            ascending: true,
          ),
        ),
        ['p1', 'p3', 'p2'],
      );
      expect(
        ids(
          filterAndSortPending(
            pending,
            query: '',
            sort: PendingSortOption.name,
            ascending: true,
          ),
        ),
        ['p2', 'p1', 'p3'],
      );
    });

    test('search also matches the location', () {
      expect(
        ids(
          filterAndSortPending(
            pending,
            query: 'zür',
            sort: PendingSortOption.eventDate,
            ascending: true,
          ),
        ),
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
    test(
      'pending = total 0 and not dismissed; status counts need total > 0',
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
      },
    );
  });

  group('listCounts (orders overview, stream without pending)', () {
    test('quotes, accepted (isAccepted) and total', () {
      final c = listCounts(sample);
      expect(c.all, 6);
      expect(c.quotes, 2);
      expect(c.accepted, 3);
    });
  });

  group('redesign filters', () {
    test('?status=completed and all select their pills', () {
      expect(statusFilterFromQuery('completed'), OrderStatusFilter.completed);
      expect(statusFilterFromQuery('all'), OrderStatusFilter.all);
    });

    test('completed pill keeps OrderStatus.completed only', () {
      expect(
        ids(
          filterLatestOrders(
            sample,
            query: '',
            filter: OrderStatusFilter.completed,
          ),
        ),
        ['c1'],
      );
    });

    test('pill counts', () {
      final c = listCounts(sample);
      expect(c.completed, 1);
      expect(c.of(OrderStatusFilter.all), 6);
      expect(c.of(OrderStatusFilter.quotes), 2);
      expect(c.of(OrderStatusFilter.accepted), 3);
      expect(c.of(OrderStatusFilter.completed), 1);
    });
  });

  group('nextAppointment', () {
    final now = DateTime(2026, 10, 27, 15, 30);

    test('picks the soonest accepted order from today on', () {
      final r = nextAppointment([
        order(
          'late',
          status: OrderStatus.accepted,
          date: DateTime(2026, 12, 1),
        ),
        order(
          'soon',
          status: OrderStatus.accepted,
          date: DateTime(2026, 11, 2),
        ),
        order('quote', status: OrderStatus.quote, date: DateTime(2026, 10, 28)),
        order(
          'declined',
          status: OrderStatus.declined,
          date: DateTime(2026, 10, 28),
        ),
        order(
          'past',
          status: OrderStatus.accepted,
          date: DateTime(2026, 10, 26),
        ),
        order(
          'donePast',
          status: OrderStatus.completed,
          date: DateTime(2026, 10, 1),
        ),
      ], now);
      expect(r?.id, 'soon');
    });

    test('today counts even after its start time', () {
      final r = nextAppointment([
        order(
          'tomorrow',
          status: OrderStatus.accepted,
          date: DateTime(2026, 10, 28),
        ),
        order(
          'today',
          status: OrderStatus.accepted,
          date: DateTime(2026, 10, 27),
        ),
      ], now);
      expect(r?.id, 'today');
      expect(daysUntil(r!.date, now), 0);
    });

    test('same day: earlier event time first', () {
      final evening = SavedOrder(
        id: 'evening',
        name: 'E',
        date: DateTime(2026, 11, 5),
        items: const [],
        total: 10,
        personCount: 1,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.accepted,
        eventTime: '19:00',
      );
      final noon = SavedOrder(
        id: 'noon',
        name: 'N',
        date: DateTime(2026, 11, 5),
        items: const [],
        total: 10,
        personCount: 1,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.accepted,
        offerEventTime: '12.00',
        eventTime: '20:00',
      );
      expect(nextAppointment([evening, noon], now)?.id, 'noon');
    });

    test('completed orders are not "next" (already done)', () {
      expect(
        nextAppointment([
          order(
            'c',
            status: OrderStatus.completed,
            date: DateTime(2026, 11, 1),
          ),
        ], now),
        isNull,
      );
    });

    test('accepted orders without a total are ignored', () {
      expect(
        nextAppointment([
          order(
            'zero',
            status: OrderStatus.accepted,
            total: 0,
            date: DateTime(2026, 10, 28),
          ),
          order('a', status: OrderStatus.accepted, date: DateTime(2026, 11, 3)),
        ], now)?.id,
        'a',
      );
    });

    test('none -> null', () {
      expect(nextAppointment([], now), isNull);
      expect(
        nextAppointment([order('q', date: DateTime(2027, 1, 1))], now),
        isNull,
      );
    });

    test('daysUntil counts calendar days', () {
      expect(daysUntil(DateTime(2026, 10, 28), now), 1);
      expect(daysUntil(DateTime(2026, 11, 6), now), 10);
      // Across the DST switch (25 Oct / 29 Mar) still whole days.
      expect(daysUntil(DateTime(2027, 3, 30), DateTime(2027, 3, 27, 23)), 3);
    });
  });

  group('acceptedThisWeek', () {
    test('Monday to Sunday of now, accepted with total > 0', () {
      final now = DateTime(2026, 10, 28); // Wednesday
      expect(
        acceptedThisWeek([
          order(
            'mon',
            status: OrderStatus.accepted,
            date: DateTime(2026, 10, 26),
          ),
          order(
            'sun',
            status: OrderStatus.completed,
            date: DateTime(2026, 11, 1),
          ),
          order(
            'nextMon',
            status: OrderStatus.accepted,
            date: DateTime(2026, 11, 2),
          ),
          order(
            'prevSun',
            status: OrderStatus.accepted,
            date: DateTime(2026, 10, 25),
          ),
          order(
            'quote',
            status: OrderStatus.quote,
            date: DateTime(2026, 10, 29),
          ),
          order(
            'zero',
            status: OrderStatus.accepted,
            total: 0,
            date: DateTime(2026, 10, 29),
          ),
        ], now),
        2,
      );
    });
  });

  group('groupByMonth', () {
    test('month groups by event date, newest first; newest event first', () {
      final groups = groupByMonth([
        order('a', date: DateTime(2026, 6, 20)),
        order('b', date: DateTime(2026, 7, 1)),
        order('c', date: DateTime(2026, 6, 2)),
        order('d', date: DateTime(2025, 6, 2)),
        order('e', date: DateTime(2026, 6, 25)),
      ]);
      expect(
        [for (final g in groups) '${g.year}-${g.month}'],
        ['2026-7', '2026-6', '2025-6'],
      );
      expect(ids(groups[1].orders), ['e', 'a', 'c']);
    });

    test('empty input -> no groups', () {
      expect(groupByMonth([]), isEmpty);
    });
  });

  // Expected values computed by hand from the formulas at 8c17f84
  // (dashboard stats bar / overview summary cards).
  group('dashboardStats (old dashboard stats bar)', () {
    test(
      'accepted with total > 0; currency of the first order with a total',
      () {
        final s = dashboardStats([
          order('p0', total: 0, status: OrderStatus.accepted, persons: 999),
          order(
            'a1',
            total: 1000,
            status: OrderStatus.accepted,
            persons: 80,
            currency: 'EUR',
          ),
          order('q1', total: 300, persons: 40),
          order('c1', total: 500, status: OrderStatus.completed, persons: 20),
          order('d1', total: 200, status: OrderStatus.declined),
        ]);
        expect(s.offers, 1);
        expect(s.offersOf, 2); // "open offers / accepted"
        expect(s.accepted, 2);
        expect(s.revenue, 1500);
        expect(s.persons, 100);
        expect(s.average, 750);
        expect(s.currency, 'EUR');
        expect(kpiMoney(s.revenue, s.currency), '1500.00 EUR');
      },
    );

    test('empty: zeros and the default currency', () {
      final s = dashboardStats([]);
      expect(s.revenue, 0);
      expect(s.average, 0);
      expect(s.currency, 'CHF');
    });
  });

  group('overviewTotals (old overview summary cards)', () {
    test('quotes / total, isAccepted, dominant currency of accepted', () {
      final s = overviewTotals([
        order('q1', total: 300, persons: 40),
        order(
          'a1',
          total: 1000,
          status: OrderStatus.accepted,
          persons: 80,
          currency: 'EUR',
        ),
        order('c1', total: 500, status: OrderStatus.completed, persons: 20),
        order('a2', total: 250, status: OrderStatus.accepted, persons: 10),
        order('d1', total: 200, status: OrderStatus.declined, currency: 'EUR'),
      ]);
      expect(s.offers, 1);
      expect(s.offersOf, 5); // "open quotes / all orders"
      expect(s.accepted, 3);
      expect(s.revenue, 1750);
      expect(s.persons, 110);
      expect(kpiMoney(s.average, s.currency), '583.33 CHF');
      expect(s.currency, 'CHF');
    });

    test('currency tie: the later currency wins (reduce keeps b)', () {
      final s = overviewTotals([
        order('a', status: OrderStatus.accepted, currency: 'EUR'),
        order('b', status: OrderStatus.accepted, currency: 'CHF'),
      ]);
      expect(s.currency, 'CHF');
    });

    test('no accepted orders: default currency, average 0', () {
      final s = overviewTotals([order('q')]);
      expect(s.currency, 'CHF');
      expect(s.average, 0);
      expect(s.offersOf, 1);
    });
  });
}
