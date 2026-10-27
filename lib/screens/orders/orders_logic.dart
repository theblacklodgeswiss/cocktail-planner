import '../../models/order.dart';

/// Pure list rules of the staff order screens (overview, pending, years,
/// dashboard). Moved unchanged out of the screens so they can be tested;
/// see test/screens/orders_logic_test.dart.

/// Status filter for orders
enum OrderStatusFilter { all, quotes, accepted, declined }

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
      default:
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
  });

  final int all;
  final int quotes;

  /// [SavedOrder.isAccepted], so completed orders are included.
  final int accepted;
}

ListCounts listCounts(List<SavedOrder> orders) => ListCounts(
  all: orders.length,
  quotes: orders.where((o) => o.status == OrderStatus.quote).length,
  accepted: orders.where((o) => o.isAccepted).length,
);
