import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../services/microsoft_graph_service.dart';
import 'order_detail_sheet.dart';
import 'widgets/orders_table.dart';
import 'widgets/summary_card.dart';

/// Sorting options for orders.
enum OrderSortOption { eventDate, createdAt, guests, name, status }

/// Screen displaying an overview of all orders with filtering and summaries.
class OrdersOverviewScreen extends StatefulWidget {
  const OrdersOverviewScreen({super.key});

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {
  int _selectedYear = DateTime.now().year;
  bool _isSyncing = false;
  String _searchQuery = '';
  OrderSortOption _sortOption = OrderSortOption.eventDate;
  bool _sortAscending = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<SavedOrder>> get _ordersStream =>
      orderRepository.watchOrders(year: _selectedYear);

  void _changeYear(int year) {
    setState(() => _selectedYear = year);
  }

  List<SavedOrder> _filterAndSortOrders(List<SavedOrder> orders) {
    // Filter by search query
    var filtered = orders;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = orders.where((o) {
        final nameMatch = o.name.toLowerCase().contains(query);
        final guestMatch = o.personCount.toString().contains(query) ||
            o.guestCountRange.toLowerCase().contains(query);
        return nameMatch || guestMatch;
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      int comparison;
      switch (_sortOption) {
        case OrderSortOption.eventDate:
          comparison = a.date.compareTo(b.date);
          break;
        case OrderSortOption.createdAt:
          final aCreated = a.createdAt ?? a.date;
          final bCreated = b.createdAt ?? b.date;
          comparison = aCreated.compareTo(bCreated);
          break;
        case OrderSortOption.guests:
          comparison = a.personCount.compareTo(b.personCount);
          break;
        case OrderSortOption.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case OrderSortOption.status:
          // Sort order: accepted (0), quote (1), declined (2)
          int statusOrder(OrderStatus s) => switch (s) {
            OrderStatus.accepted => 0,
            OrderStatus.quote => 1,
            OrderStatus.declined => 2,
          };
          comparison = statusOrder(a.status).compareTo(statusOrder(b.status));
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  static const _excelFileName = 'Cocktail- & Barservice Anftragformular.xlsx';

  Future<void> _syncForms() async {
    if (!microsoftGraphService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders.sync_login_required'.tr())),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      // Read Excel data from OneDrive
      final rows = await microsoftGraphService.readExcelFromOneDrive(
        oneDrivePath: _excelFileName,
        startRow: 2, // Skip header row
      );

      if (!mounted) return;

      if (rows == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.sync_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Pass rows to repository for syncing
      final count = await orderRepository.syncFormSubmissions(rows: rows);
      if (!mounted) return;

      if (count == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.sync_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      } else if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('orders.sync_no_new'.tr())),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.sync_success'.tr(args: [count.toString()])),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _resetAndSyncForms() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('orders.reset_sync_title'.tr()),
        content: Text('orders.reset_sync_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('orders.reset_sync_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSyncing = true);

    try {
      // Delete all form submissions first
      final deletedCount = await orderRepository.deleteAllFormSubmissions();
      debugPrint('Deleted $deletedCount old form submissions');

      // Now sync fresh
      await _syncForms();
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.title'.tr()),
        actions: [
          if (microsoftGraphService.isSupported)
            _isSyncing
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
                          _syncForms();
                          break;
                        case 'reset_sync':
                          _resetAndSyncForms();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
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
          final orders = _filterAndSortOrders(allOrders);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildYearSelector(),
                    const SizedBox(height: 12),
                    _buildPendingOrdersBanner(),
                    const SizedBox(height: 20),
                    _SummaryCardsSection(orders: orders),
                    const SizedBox(height: 20),
                    _buildSearchAndSortBar(),
                    const SizedBox(height: 16),
                    Text(
                      '${'orders.order_count'.tr()} $_selectedYear',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    OrdersTable(
                      orders: orders,
                      colorScheme: colorScheme,
                      selectedYear: _selectedYear,
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

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: years.map((year) {
          final isSelected = year == _selectedYear;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(year.toString()),
              selected: isSelected,
              onSelected: (_) {
                if (_selectedYear != year) {
                  _changeYear(year);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchAndSortBar() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern search field
        _buildSearchField(colorScheme),
        const SizedBox(height: 12),
        // Sort chips row
        _buildSortChips(colorScheme),
      ],
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return SearchBar(
      hintText: 'orders.search_hint'.tr(),
      leading: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
      trailing: _searchQuery.isNotEmpty
          ? [
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ]
          : null,
      elevation: WidgetStateProperty.all(0),
      backgroundColor: WidgetStateProperty.all(
        colorScheme.surfaceContainerHigh,
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16),
      ),
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildSortChips(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Direction toggle - prominent at the start
          _buildDirectionChip(colorScheme),
          const SizedBox(width: 12),
          Text(
            'Sortieren:',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          _buildSortChip(OrderSortOption.eventDate, 'orders.sort_event_date'.tr(), Icons.event, colorScheme),
          _buildSortChip(OrderSortOption.createdAt, 'orders.sort_created_at'.tr(), Icons.schedule, colorScheme),
          _buildSortChip(OrderSortOption.guests, 'orders.sort_guests'.tr(), Icons.people, colorScheme),
          _buildSortChip(OrderSortOption.name, 'orders.sort_name'.tr(), Icons.sort_by_alpha, colorScheme),
          _buildSortChip(OrderSortOption.status, 'orders.sort_status'.tr(), Icons.flag, colorScheme),
        ],
      ),
    );
  }

  Widget _buildDirectionChip(ColorScheme colorScheme) {
    return ActionChip(
      avatar: Icon(
        _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        size: 18,
        color: colorScheme.primary,
      ),
      label: Text(
        _sortAscending ? 'orders.sort_asc'.tr() : 'orders.sort_desc'.tr(),
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onPressed: () => setState(() => _sortAscending = !_sortAscending),
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
    );
  }

  Widget _buildSortChip(OrderSortOption option, String label, IconData icon, ColorScheme colorScheme) {
    final isSelected = _sortOption == option;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _sortOption = option),
        showCheckmark: false,
        selectedColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        labelStyle: TextStyle(
          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
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
                    'orders.pending_banner'.tr(args: [pendingOrders.length.toString()]),
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onErrorContainer,
                ),
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
    final quoteOrders =
        orders.where((o) => o.status == OrderStatus.quote).toList();
    final totalRevenue =
        acceptedOrders.fold<double>(0, (sum, o) => sum + o.total);
    final totalPersons =
        acceptedOrders.fold<int>(0, (sum, o) => sum + o.personCount);
    final avgTotal =
        acceptedOrders.isNotEmpty ? totalRevenue / acceptedOrders.length : 0.0;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        if (isWide) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: cards,
        );
      },
    );
  }

  String _getDominantCurrency(List<SavedOrder> orders) {
    final currencyCounts = <String, int>{};
    for (final order in orders) {
      currencyCounts[order.currency] =
          (currencyCounts[order.currency] ?? 0) + 1;
    }
    if (currencyCounts.isEmpty) return 'CHF';
    return currencyCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}
