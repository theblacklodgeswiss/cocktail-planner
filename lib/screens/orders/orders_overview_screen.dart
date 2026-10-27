import 'package:cocktail_planer/data/firestore_service.dart';
import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'package:cocktail_planer/services/microsoft_graph_service.dart';
import 'package:cocktail_planer/models/app_role.dart';
import 'package:cocktail_planer/utils/currency.dart';
import 'package:cocktail_planer/ui/widgets/staff_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:cocktail_planer/widgets/role_protected_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'form_sync.dart';
import 'order_detail_sheet.dart';
import 'widgets/orders_table.dart';
import 'widgets/summary_card.dart';

/// Status filter for orders
enum OrderStatusFilter { all, quotes, accepted, declined }

/// Screen displaying an overview of all orders with filtering and summaries.
class OrdersOverviewScreen extends StatefulWidget {
  final String? initialStatus;

  /// False on the staff home (`/`) and when opened from the staff bar, where
  /// "back to home" would only lead to another tab.
  final bool showBack;

  const OrdersOverviewScreen({
    super.key,
    this.initialStatus,
    this.showBack = true,
  });

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

/// Number of latest orders shown on the main overview before the user has
/// to open the full year-by-year archive.
const _latestOrdersLimit = 10;

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {
  bool _firestoreReady = false;
  String _searchQuery = '';
  OrderStatusFilter _statusFilter = OrderStatusFilter.quotes;
  List<SavedOrder> _latestOrders = [];

  @override
  void initState() {
    super.initState();
    // Ensure Firestore is initialized (screen can be reached directly without going through dashboard)
    firestoreService.initialize().then((_) {
      if (mounted) setState(() => _firestoreReady = true);
    });
    // Set initial status filter based on query parameter
    if (widget.initialStatus != null) {
      switch (widget.initialStatus) {
        case 'accepted':
          _statusFilter = OrderStatusFilter.accepted;
          break;
        case 'offer':
        case 'quote':
          _statusFilter = OrderStatusFilter.quotes;
          break;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openSearch() async {
    final result = await showSearch<String>(
      context: context,
      delegate: _OrderSearchDelegate(
        orders: _latestOrders,
        initialQuery: _searchQuery,
      ),
    );
    if (result != null && mounted) {
      setState(() => _searchQuery = result);
    }
  }

  Stream<List<SavedOrder>> get _ordersStream {
    if (!_firestoreReady && !firestoreService.isAvailable) {
      return const Stream.empty();
    }
    // No year filter - always fetch all orders, sorted by createdAt desc.
    return orderRepository.watchOrders();
  }

  /// Applies the status filter (and search) and, when not searching, caps
  /// the result to the most recently created [_latestOrdersLimit] orders.
  /// [orders] is expected to already be sorted by createdAt descending.
  List<SavedOrder> _filterAndSortOrders(List<SavedOrder> orders) {
    var filtered = orders;

    // Filter by search query (searches across all orders, ignores status)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      return filtered.where((o) {
        final nameMatch = o.name.toLowerCase().contains(query);
        final guestMatch =
            o.personCount.toString().contains(query) ||
            o.guestCountRange.toLowerCase().contains(query);
        return nameMatch || guestMatch;
      }).toList();
    }

    // Filter by status (only quotes / accepted are selectable here)
    filtered = filtered.where((o) {
      switch (_statusFilter) {
        case OrderStatusFilter.quotes:
          return o.status == OrderStatus.quote;
        case OrderStatusFilter.accepted:
          return o.isAccepted;
        default:
          return true;
      }
    }).toList();

    return filtered.take(_latestOrdersLimit).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      minimumRole: AppRole.employee,
      child: StaffFrame(tab: StaffTab.orders, child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.title'.tr()),
        automaticallyImplyLeading: false,
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              )
            : null,
        actions: [
          IconButton(
            icon: _searchQuery.isNotEmpty
                ? const Icon(Icons.search_off)
                : const Icon(Icons.search),
            tooltip: 'orders.search_hint'.tr(),
            onPressed: _openSearch,
          ),
          if (authService.isAdmin)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Dashboard',
              onPressed: () => context.push('/dashboard'),
            ),
          if (microsoftGraphService.isSupported)
            ListenableBuilder(
              listenable: formSync,
              builder: (context, _) => formSync.isSyncing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.sync),
                      tooltip: 'orders.sync_forms_tooltip'.tr(),
                      onSelected: (value) {
                        switch (value) {
                          case 'sync':
                            formSync.sync(context);
                            break;
                          case 'reset_sync':
                            formSync.resetAndSync(context);
                            break;
                          case 'onedrive':
                            formSync.openOneDriveForm();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        // Info hint – non-interactive
                        PopupMenuItem(
                          enabled: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'orders.sync_excel_hint'.tr(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'onedrive',
                          child: ListTile(
                            leading: const Icon(Icons.table_chart_outlined),
                            title: Text('orders.sync_onedrive_form'.tr()),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'sync',
                          child: ListTile(
                            leading: const Icon(Icons.sync),
                            title: Text('orders.sync_forms'.tr()),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reset_sync',
                          child: ListTile(
                            leading: const Icon(Icons.refresh),
                            title: Text('orders.reset_sync'.tr()),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
      body: StreamBuilder<List<SavedOrder>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data ?? [];
          _latestOrders = allOrders;
          final orders = _filterAndSortOrders(allOrders);

          return SingleChildScrollView(
            // Bottom: room to scroll the last row clear of the "+" button.
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + staffFrameFabClearance(context),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPendingOrdersBanner(),
                    const SizedBox(height: 20),
                    _SummaryCardsSection(orders: allOrders),
                    const SizedBox(height: 20),
                    _buildFilterRow(colorScheme),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InputChip(
                            avatar: const Icon(Icons.search, size: 16),
                            label: Text(_searchQuery),
                            onDeleted: () => setState(() => _searchQuery = ''),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildListHeader(orders),
                    const SizedBox(height: 12),
                    OrdersTable(
                      orders: orders,
                      colorScheme: colorScheme,
                      selectedYear: DateTime.now().year,
                      showMonthSubtitle: true,
                      onOrderTap: (order) => showOrderDetails(context, order),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListHeader(List<SavedOrder> orders) {
    final title = _searchQuery.isNotEmpty
        ? '${orders.length} ${'orders.search_results'.tr()}'
        : '${'orders.order_count'.tr()} · ${orders.length}';

    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  /// Two-state filter (Angebot offen / Angenommen) plus a compact icon
  /// button that opens the full year-by-year archive.
  Widget _buildFilterRow(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<OrderStatusFilter>(
            segments: [
              ButtonSegment(
                value: OrderStatusFilter.quotes,
                label: Text('orders.filter_open_quotes'.tr()),
              ),
              ButtonSegment(
                value: OrderStatusFilter.accepted,
                label: Text('orders.filter_accepted'.tr()),
              ),
            ],
            selected: {_statusFilter},
            onSelectionChanged: (selection) {
              setState(() => _statusFilter = selection.first);
            },
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => context.push('/orders/years'),
          icon: const Icon(Icons.calendar_month),
          tooltip: 'orders.show_more'.tr(),
          style: IconButton.styleFrom(
            side: BorderSide(color: colorScheme.outline),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingOrdersBanner() {
    return StreamBuilder<List<SavedOrder>>(
      stream: orderRepository.watchPendingOrders(),
      builder: (context, snapshot) {
        final pendingOrders = snapshot.data ?? [];
        if (pendingOrders.isEmpty) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        return InkWell(
          onTap: () => context.push('/orders/pending'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'orders.pending_banner'.tr(
                      args: [pendingOrders.length.toString()],
                    ),
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onErrorContainer),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Section displaying summary statistics cards.
class _SummaryCardsSection extends StatelessWidget {
  const _SummaryCardsSection({required this.orders});

  final List<SavedOrder> orders;

  @override
  Widget build(BuildContext context) {
    final totalOrders = orders.length;
    final acceptedOrders = orders.where((o) => o.isAccepted).toList();
    final quoteOrders = orders
        .where((o) => o.status == OrderStatus.quote)
        .toList();
    final totalRevenue = acceptedOrders.fold<double>(
      0,
      (sum, o) => sum + o.total,
    );
    final totalPersons = acceptedOrders.fold<int>(
      0,
      (sum, o) => sum + o.personCount,
    );
    final avgTotal = acceptedOrders.isNotEmpty
        ? totalRevenue / acceptedOrders.length
        : 0.0;

    // Get most common currency from accepted orders
    final dominantCurrency = _getDominantCurrency(acceptedOrders);

    final cards = [
      SummaryCard(
        icon: Icons.receipt_long,
        label: 'orders.open_quotes'.tr(),
        value: '${quoteOrders.length} / $totalOrders',
        color: Colors.orange.shade700,
      ),
      SummaryCard(
        icon: Icons.attach_money,
        label: 'orders.total_revenue'.tr(),
        value: '${totalRevenue.toStringAsFixed(2)} $dominantCurrency',
        subtitle: '${acceptedOrders.length} ${'orders.accepted_only'.tr()}',
        color: Colors.green.shade700,
      ),
      SummaryCard(
        icon: Icons.people,
        label: 'orders.persons'.tr(),
        value: totalPersons.toString(),
        color: Colors.blue.shade700,
      ),
      SummaryCard(
        icon: Icons.trending_up,
        label: 'orders.avg_order'.tr(),
        value: '${avgTotal.toStringAsFixed(2)} $dominantCurrency',
        color: Colors.purple.shade700,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < cards.length - 1 ? 8 : 0),
              child: cards[i],
            ),
          ),
      ],
    );
  }

  String _getDominantCurrency(List<SavedOrder> orders) {
    final currencyCounts = <String, int>{};
    for (final order in orders) {
      currencyCounts[order.currency] =
          (currencyCounts[order.currency] ?? 0) + 1;
    }
    if (currencyCounts.isEmpty) return defaultCurrency.code;
    return currencyCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

// ---------------------------------------------------------------------------
// Search delegate
// ---------------------------------------------------------------------------

class _OrderSearchDelegate extends SearchDelegate<String> {
  _OrderSearchDelegate({required this.orders, String initialQuery = ''}) {
    // Pre-fill the search field with the current active query
    if (initialQuery.isNotEmpty) {
      query = initialQuery;
    }
  }

  final List<SavedOrder> orders;

  List<SavedOrder> _filter(String q) {
    if (q.isEmpty) return orders.take(20).toList();
    final lower = q.toLowerCase();
    return orders
        .where(
          (o) =>
              o.name.toLowerCase().contains(lower) ||
              o.personCount.toString().contains(lower) ||
              o.guestCountRange.toLowerCase().contains(lower),
        )
        .toList();
  }

  @override
  String get searchFieldLabel => 'Name oder Gästeanzahl';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.close), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, query),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = _filter(query);
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Keine Ergebnisse',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final order = results[i];
        return ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(order.name),
          subtitle: Text(
            '${order.personCount} Gäste · ${DateFormat('dd.MM.yyyy').format(order.date)}',
          ),
          onTap: () => close(context, order.name),
        );
      },
    );
  }
}
