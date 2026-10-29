import '../../models/order.dart';
import '../../utils/currency.dart';

/// Pure list rules of the staff order screens (overview, pending, years,
/// dashboard). Moved unchanged out of the screens so they can be tested;
/// see test/screens/orders_logic_test.dart.

/// Status filter (pills) of the orders overview. Declined orders only show
/// under [all].
enum OrderStatusFilter { all, quotes, accepted, completed }

/// Number of latest orders shown on the main overview before the user has
/// to open the full year-by-year archive.
const latestOrdersLimit = 10;

/// Initial filter for the `?status=` query parameter of `/orders`.
OrderStatusFilter statusFilterFromQuery(String? status) {
  switch (status) {
    case 'accepted':
      return OrderStatusFilter.accepted;
    case 'offer':
    case 'quote':
      return OrderStatusFilter.quotes;
    case 'completed':
      return OrderStatusFilter.completed;
    case 'all':
      return OrderStatusFilter.all;
  }
  return OrderStatusFilter.quotes;
}

/// Search rule of the orders overview: name, guest count or guest range.
bool matchesOrderSearch(SavedOrder o, String query) {
  final q = query.toLowerCase();
  final nameMatch = o.name.toLowerCase().contains(q);
  final guestMatch =
      o.personCount.toString().contains(q) ||
      o.guestCountRange.toLowerCase().contains(q);
  return nameMatch || guestMatch;
}

/// Applies the status filter (and search) and, when not searching, caps
/// the result to the most recently created [latestOrdersLimit] orders.
/// [orders] is expected to already be sorted by createdAt descending.
List<SavedOrder> filterLatestOrders(
  List<SavedOrder> orders, {
  required String query,
  required OrderStatusFilter filter,
}) {
  // Filter by search query (searches across all orders, ignores status)
  if (query.isNotEmpty) {
    return orders.where((o) => matchesOrderSearch(o, query)).toList();
  }

  final filtered = orders.where((o) {
    switch (filter) {
      case OrderStatusFilter.quotes:
        return o.status == OrderStatus.quote;
      case OrderStatusFilter.accepted:
        return o.isAccepted;
      case OrderStatusFilter.completed:
        return o.status == OrderStatus.completed;
      case OrderStatusFilter.all:
        return true;
    }
  }).toList();

  return filtered.take(latestOrdersLimit).toList();
}

/// Sort options for pending orders.
enum PendingSortOption { eventDate, createdAt, guests, name }

/// Search and sort of the pending list (orders with total = 0).
List<SavedOrder> filterAndSortPending(
  List<SavedOrder> orders, {
  required String query,
  required PendingSortOption sort,
  required bool ascending,
}) {
  var filtered = orders;
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    filtered = orders.where((o) {
      final nameMatch = o.name.toLowerCase().contains(q);
      final locationMatch = o.location.toLowerCase().contains(q);
      final guestMatch =
          o.personCount.toString().contains(q) ||
          o.guestCountRange.toLowerCase().contains(q);
      return nameMatch || locationMatch || guestMatch;
    }).toList();
  } else {
    filtered = List.of(orders);
  }

  filtered.sort((a, b) {
    int comparison;
    switch (sort) {
      case PendingSortOption.eventDate:
        comparison = a.date.compareTo(b.date);
        break;
      case PendingSortOption.createdAt:
        final aCreated = a.formCreatedAt ?? a.createdAt ?? a.date;
        final bCreated = b.formCreatedAt ?? b.createdAt ?? b.date;
        comparison = aCreated.compareTo(bCreated);
        break;
      case PendingSortOption.guests:
        comparison = a.personCount.compareTo(b.personCount);
        break;
      case PendingSortOption.name:
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        break;
    }
    return ascending ? comparison : -comparison;
  });

  return filtered;
}

/// Order count per event year, newest year first.
Map<int, int> ordersPerYear(List<SavedOrder> orders) {
  final counts = <int, int>{};
  for (final order in orders) {
    counts[order.year] = (counts[order.year] ?? 0) + 1;
  }
  final years = counts.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final y in years) y: counts[y]!};
}

/// Orders whose event is in [year], in stream order.
List<SavedOrder> ordersOfYear(List<SavedOrder> orders, int year) =>
    orders.where((o) => o.year == year).toList();

/// Counts of the staff dashboard. Input is
/// `watchOrders(includePending: true, year: <current year>)`.
class DashboardCounts {
  const DashboardCounts({
    required this.pending,
    required this.openOffers,
    required this.accepted,
  });

  /// total == 0 and not dismissed, regardless of status.
  final int pending;

  /// total > 0 and status quote.
  final int openOffers;

  /// total > 0 and [SavedOrder.isAccepted] (includes completed).
  final int accepted;
}

DashboardCounts dashboardCounts(List<SavedOrder> orders) {
  final pendingCount = orders
      .where((o) => o.total == 0 && !o.isPendingDismissed)
      .length;
  // Only count orders with total > 0 for status counts
  final completedOrders = orders.where((o) => o.total > 0).toList();
  return DashboardCounts(
    pending: pendingCount,
    openOffers: completedOrders
        .where((o) => o.status == OrderStatus.quote)
        .length,
    accepted: completedOrders.where((o) => o.isAccepted).length,
  );
}

/// Counts of the orders overview (input: `watchOrders()`, i.e. without
/// pending orders).
class ListCounts {
  const ListCounts({
    required this.all,
    required this.quotes,
    required this.accepted,
    required this.completed,
  });

  final int all;
  final int quotes;

  /// [SavedOrder.isAccepted], so completed orders are included.
  final int accepted;
  final int completed;

  int of(OrderStatusFilter filter) => switch (filter) {
    OrderStatusFilter.all => all,
    OrderStatusFilter.quotes => quotes,
    OrderStatusFilter.accepted => accepted,
    OrderStatusFilter.completed => completed,
  };
}

ListCounts listCounts(List<SavedOrder> orders) => ListCounts(
  all: orders.length,
  quotes: orders.where((o) => o.status == OrderStatus.quote).length,
  accepted: orders.where((o) => o.isAccepted).length,
  completed: orders.where((o) => o.status == OrderStatus.completed).length,
);

// ---------------------------------------------------------------------------
// Appointments (redesign)
// ---------------------------------------------------------------------------

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

final _timePattern = RegExp(r'(\d{1,2})[:.](\d{2})');

/// Event start: the event day plus [SavedOrder.effectiveEventTime] when it
/// holds a time like "18:00" or "9.30"; otherwise the start of the day.
DateTime eventStart(SavedOrder o) {
  final day = _day(o.date);
  final m = _timePattern.firstMatch(o.effectiveEventTime);
  if (m == null) return day;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return day;
  return day.add(Duration(hours: h, minutes: min));
}

/// Accepted, not yet completed orders with a total whose event day is
/// today or later, soonest first (by day, then time; ties keep the input
/// order). A completed event is never "next".
List<SavedOrder> upcomingAppointments(List<SavedOrder> orders, DateTime now) {
  final today = _day(now);
  final upcoming = [
    for (final o in orders)
      if (o.isAccepted &&
          o.status != OrderStatus.completed &&
          o.total > 0 &&
          !_day(o.date).isBefore(today))
        o,
  ];
  // List.sort is not stable; sort indices to keep ties in input order.
  final indexed = [for (var i = 0; i < upcoming.length; i++) i];
  indexed.sort((a, b) {
    final c = eventStart(upcoming[a]).compareTo(eventStart(upcoming[b]));
    return c != 0 ? c : a.compareTo(b);
  });
  return [for (final i in indexed) upcoming[i]];
}

/// The next appointment from today on (see [upcomingAppointments]), or
/// null.
SavedOrder? nextAppointment(List<SavedOrder> orders, DateTime now) {
  final upcoming = upcomingAppointments(orders, now);
  return upcoming.isEmpty ? null : upcoming.first;
}

/// Whole calendar days from [now] until [date] (0 = today).
int daysUntil(DateTime date, DateTime now) {
  final a = DateTime.utc(date.year, date.month, date.day);
  final b = DateTime.utc(now.year, now.month, now.day);
  return a.difference(b).inDays;
}

/// Accepted orders (total > 0, like the dashboard counts) whose event falls
/// in the week (Monday to Sunday) of [now].
int acceptedThisWeek(List<SavedOrder> orders, DateTime now) {
  final today = _day(now);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
  return orders.where((o) {
    if (o.total <= 0 || !o.isAccepted) return false;
    final d = _day(o.date);
    return !d.isBefore(monday) && d.isBefore(nextMonday);
  }).length;
}

/// Orders of one event month.
class MonthGroup {
  const MonthGroup(this.year, this.month, this.orders);

  final int year;
  final int month;
  final List<SavedOrder> orders;
}

/// Groups [orders] by event month for the year archive: months newest
/// first, inside a month the latest event first (by [eventStart]; ties keep
/// the input order). This deliberately replaces the createdAt order there.
List<MonthGroup> groupByMonth(List<SavedOrder> orders) {
  final indexed = [for (var i = 0; i < orders.length; i++) i];
  indexed.sort((a, b) {
    final c = eventStart(orders[b]).compareTo(eventStart(orders[a]));
    return c != 0 ? c : a.compareTo(b);
  });
  final groups = <MonthGroup>[];
  for (final i in indexed) {
    final o = orders[i];
    if (groups.isEmpty ||
        groups.last.year != o.date.year ||
        groups.last.month != o.date.month) {
      groups.add(MonthGroup(o.date.year, o.date.month, []));
    }
    groups.last.orders.add(o);
  }
  return groups;
}

// ---------------------------------------------------------------------------
// KPIs (formulas copied 1:1 from the pre-redesign screens, 8c17f84)
// ---------------------------------------------------------------------------

/// Revenue, persons and average of accepted orders.
class KpiStats {
  const KpiStats({
    required this.offers,
    required this.offersOf,
    required this.accepted,
    required this.revenue,
    required this.persons,
    required this.average,
    required this.currency,
  });

  /// Open offers (quotes).
  final int offers;

  /// Second number of the offers tile: accepted count ([dashboardStats]) or
  /// all orders ([overviewTotals]), as the old tiles showed it.
  final int offersOf;
  final int accepted;
  final double revenue;
  final int persons;
  final double average;
  final String currency;
}

/// "1234.50 CHF", as the old cards formatted money.
String kpiMoney(double value, String currency) =>
    '${value.toStringAsFixed(2)} $currency';

/// Old dashboard stats bar. Input: the dashboard stream
/// (`watchOrders(includePending: true, year: <current year>)`).
KpiStats dashboardStats(List<SavedOrder> orders) {
  final completedOrders = orders.where((o) => o.total > 0).toList();
  final acceptedOrders = completedOrders.where((o) => o.isAccepted).toList();
  final totalRevenue = acceptedOrders.fold<double>(
    0,
    (sum, o) => sum + o.total,
  );
  final totalPersons = acceptedOrders.fold<int>(
    0,
    (sum, o) => sum + o.personCount,
  );
  return KpiStats(
    offers: completedOrders.where((o) => o.status == OrderStatus.quote).length,
    offersOf: acceptedOrders.length,
    accepted: acceptedOrders.length,
    revenue: totalRevenue,
    persons: totalPersons,
    average: acceptedOrders.isNotEmpty
        ? totalRevenue / acceptedOrders.length
        : 0.0,
    currency: completedOrders.firstOrNull?.currency ?? defaultCurrency.code,
  );
}

/// Old orders overview summary cards. Input: `watchOrders()` (all years,
/// without pending orders).
KpiStats overviewTotals(List<SavedOrder> orders) {
  final acceptedOrders = orders.where((o) => o.isAccepted).toList();
  final totalRevenue = acceptedOrders.fold<double>(
    0,
    (sum, o) => sum + o.total,
  );
  final totalPersons = acceptedOrders.fold<int>(
    0,
    (sum, o) => sum + o.personCount,
  );
  return KpiStats(
    offers: orders.where((o) => o.status == OrderStatus.quote).length,
    offersOf: orders.length,
    accepted: acceptedOrders.length,
    revenue: totalRevenue,
    persons: totalPersons,
    average: acceptedOrders.isNotEmpty
        ? totalRevenue / acceptedOrders.length
        : 0.0,
    currency: _dominantCurrency(acceptedOrders),
  );
}

/// Most common currency of [orders]; on a tie the later one wins (as the
/// old `reduce`).
String _dominantCurrency(List<SavedOrder> orders) {
  final currencyCounts = <String, int>{};
  for (final order in orders) {
    currencyCounts[order.currency] = (currencyCounts[order.currency] ?? 0) + 1;
  }
  if (currencyCounts.isEmpty) return defaultCurrency.code;
  return currencyCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
}
