import '../../models/order.dart';

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

/// Accepted orders ([SavedOrder.isAccepted], so completed ones too) whose
/// event day is today or later, soonest first (by day, then time; ties keep
/// the input order).
List<SavedOrder> upcomingAppointments(List<SavedOrder> orders, DateTime now) {
  final today = _day(now);
  final upcoming = [
    for (final o in orders)
      if (o.isAccepted && !_day(o.date).isBefore(today)) o,
  ];
  // List.sort is not stable; sort indices to keep ties in input order.
  final indexed = [for (var i = 0; i < upcoming.length; i++) i];
  indexed.sort((a, b) {
    final c = eventStart(upcoming[a]).compareTo(eventStart(upcoming[b]));
    return c != 0 ? c : a.compareTo(b);
  });
  return [for (final i in indexed) upcoming[i]];
}

/// The next accepted appointment from today on, or null.
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

/// Groups [orders] by event month without re-sorting: orders keep their
/// input order inside a month, and months appear in the order of their
/// first order. With the overview's createdAt-descending stream the newest
/// created order's month comes first.
List<MonthGroup> groupByMonth(List<SavedOrder> orders) {
  final groups = <int, List<SavedOrder>>{};
  for (final o in orders) {
    groups.putIfAbsent(o.date.year * 100 + o.date.month, () => []).add(o);
  }
  return [
    for (final e in groups.entries)
      MonthGroup(e.key ~/ 100, e.key % 100, e.value),
  ];
}
