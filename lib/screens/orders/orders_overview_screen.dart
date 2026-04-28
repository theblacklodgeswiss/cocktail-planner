import 'package:cocktail_planer/data/firestore_service.dart';
import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'package:cocktail_planer/services/microsoft_graph_service.dart';
import 'package:cocktail_planer/utils/currency.dart';
import 'package:cocktail_planer/widgets/admin_protected_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_detail_sheet.dart';
import 'widgets/orders_table.dart';
import 'widgets/summary_card.dart';

/// Sorting options for orders.
enum OrderSortOption { eventDate, createdAt, guests, name, status }

/// Status filter for orders
enum OrderStatusFilter { all, quotes, accepted, declined }

/// Screen displaying an overview of all orders with filtering and summaries.
class OrdersOverviewScreen extends StatefulWidget {
  final String? initialStatus;

  const OrdersOverviewScreen({super.key, this.initialStatus});

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth; // null = all months
  bool _isSyncing = false;
  bool _firestoreReady = false;
  String _searchQuery = '';
  OrderSortOption _sortOption = OrderSortOption.createdAt;
  bool _sortAscending = false;
  OrderStatusFilter _statusFilter = OrderStatusFilter.all;
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
        case 'declined':
          _statusFilter = OrderStatusFilter.declined;
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
    // If searching, get all orders regardless of year
    if (_searchQuery.isNotEmpty) {
      return orderRepository.watchOrders(); // No year filter
    }
    // Otherwise, filter by selected year
    return orderRepository.watchOrders(year: _selectedYear);
  }

  List<SavedOrder> _filterAndSortOrders(List<SavedOrder> orders) {
    var filtered = orders;

    // Filter by month (if selected and not searching globally)
    if (_selectedMonth != null && _searchQuery.isEmpty) {
      filtered = filtered.where((o) => o.date.month == _selectedMonth).toList();
    }

    // Filter by status
    if (_statusFilter != OrderStatusFilter.all) {
      filtered = filtered.where((o) {
        switch (_statusFilter) {
          case OrderStatusFilter.quotes:
            return o.status == OrderStatus.quote;
          case OrderStatusFilter.accepted:
            return o.status == OrderStatus.accepted;
          case OrderStatusFilter.declined:
            return o.status == OrderStatus.declined;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        final nameMatch = o.name.toLowerCase().contains(query);
        final guestMatch =
            o.personCount.toString().contains(query) ||
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

  int? _getSortColumnIndex() {
    switch (_sortOption) {
      case OrderSortOption.status:
        return 0;
      case OrderSortOption.eventDate:
        return 1;
      case OrderSortOption.name:
        return 2;
      case OrderSortOption.guests:
        return 3;
      case OrderSortOption.createdAt:
        return 4;
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortAscending = ascending;
      switch (columnIndex) {
        case 0:
          _sortOption = OrderSortOption.status;
          break;
        case 1:
          _sortOption = OrderSortOption.eventDate;
          break;
        case 2:
          _sortOption = OrderSortOption.name;
          break;
        case 3:
          _sortOption = OrderSortOption.guests;
          break;
        case 4:
          _sortOption = OrderSortOption.createdAt;
          break;
      }
    });
  }

  static const _excelFileName = 'Cocktail- & Barservice Anftragformular.xlsx';

  Future<void> _loginAndSync() async {
    final account = await microsoftGraphService.login();
    if (!mounted) return;
    if (account != null) {
      setState(() {});
      _syncForms();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders.sync_login_required'.tr())),
      );
    }
  }

  Future<void> _syncForms() async {
    if (!microsoftGraphService.isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('orders.sync_login_required'.tr()),
          content: const Text(
            'Bitte melde dich mit dem Microsoft-Konto an, um Formulare zu synchronisieren.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Mit Microsoft anmelden'),
              onPressed: () {
                Navigator.pop(ctx);
                _loginAndSync();
              },
            ),
          ],
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('orders.sync_no_new'.tr())));
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
    return AdminProtectedScreen(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.title'.tr()),
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
                        case 'onedrive':
                          launchUrl(
                            Uri.parse(
                              'https://1drv.ms/x/c/80c90daf53662538/IQAw81_OoMv4QpDZTEsq13cvAf3yftB-9O812MAPGRy6mfs?e=FfusWZ',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
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
                            const Expanded(
                              child: Text(
                                'Excel muss zuerst im Browser geöffnet werden (mit dem Microsoft Blacklodge-Konto), damit die neuesten Anträge ins OneDrive geladen werden. Dann hier synchronisieren.',
                                style: TextStyle(fontSize: 12, height: 1.4),
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
                          title: const Text('Formular OneDrive'),
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
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPendingOrdersBanner(),
                    const SizedBox(height: 20),
                    _SummaryCardsSection(orders: orders),
                    const SizedBox(height: 20),
                    _buildFilterDropdowns(colorScheme),
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
                      selectedYear: _selectedYear,
                      showMonthSubtitle:
                          _searchQuery.isNotEmpty || _selectedMonth == null,
                      onOrderTap: (order) => showOrderDetails(context, order),
                      sortColumn: _getSortColumnIndex(),
                      sortAscending: _sortAscending,
                      onSort: _onSort,
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

  /// Compact status dropdown menu (kept for potential reuse)
  // ignore: unused_element
  Widget _buildStatusDropdown(ColorScheme colorScheme) {
    // Map status to icon and color
    IconData getIcon(OrderStatusFilter status) {
      switch (status) {
        case OrderStatusFilter.all:
          return Icons.filter_list;
        case OrderStatusFilter.quotes:
          return Icons.description;
        case OrderStatusFilter.accepted:
          return Icons.check_circle;
        case OrderStatusFilter.declined:
          return Icons.cancel;
      }
    }

    Color? getColor(OrderStatusFilter status) {
      switch (status) {
        case OrderStatusFilter.quotes:
          return Colors.orange;
        case OrderStatusFilter.accepted:
          return Colors.green;
        case OrderStatusFilter.declined:
          return Colors.red;
        default:
          return null;
      }
    }

    String getLabel(OrderStatusFilter status) {
      switch (status) {
        case OrderStatusFilter.all:
          return 'Alle';
        case OrderStatusFilter.quotes:
          return 'Angebote';
        case OrderStatusFilter.accepted:
          return 'Angenommen';
        case OrderStatusFilter.declined:
          return 'Abgelehnt';
      }
    }

    final currentColor = getColor(_statusFilter);

    return MenuAnchor(
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: Icon(getIcon(_statusFilter), size: 18, color: currentColor),
          label: Text(
            getLabel(_statusFilter),
            style: TextStyle(color: currentColor),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
      menuChildren: OrderStatusFilter.values.map((status) {
        final icon = getIcon(status);
        final color = getColor(status);
        final label = getLabel(status);
        final isSelected = _statusFilter == status;

        return MenuItemButton(
          leadingIcon: Icon(icon, size: 18, color: color),
          trailingIcon: isSelected ? const Icon(Icons.check, size: 18) : null,
          onPressed: () => setState(() => _statusFilter = status),
          child: Text(label),
        );
      }).toList(),
    );
  }

  Widget _buildListHeader(List<SavedOrder> orders) {
    String title;
    if (_searchQuery.isNotEmpty) {
      title = '${orders.length} ${'orders.search_results'.tr()}';
    } else if (_selectedMonth != null) {
      const monthNames = [
        'Januar',
        'Februar',
        'März',
        'April',
        'Mai',
        'Juni',
        'Juli',
        'August',
        'September',
        'Oktober',
        'November',
        'Dezember',
      ];
      title = '${monthNames[_selectedMonth! - 1]} $_selectedYear';
    } else {
      title = '${'orders.order_count'.tr()} $_selectedYear';
    }

    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildFilterDropdowns(ColorScheme colorScheme) {
    final currentYear = DateTime.now().year;
    const futureYears = 2;
    const pastYears = 4;
    final years = List.generate(
      futureYears + pastYears + 1,
      (i) => currentYear + futureYears - i,
    );

    const monthNames = [
      'Alle',
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];

    // Sort dropdown items
    const sortItems = [
      (OrderSortOption.createdAt, 'Erstellt am'),
      (OrderSortOption.eventDate, 'Eventdatum'),
      (OrderSortOption.guests, 'Gäste'),
      (OrderSortOption.name, 'Name'),
      (OrderSortOption.status, 'Status'),
    ];

    // Status filter items
    const statusItems = [
      (OrderStatusFilter.all, 'Alle'),
      (OrderStatusFilter.quotes, 'Angebote'),
      (OrderStatusFilter.accepted, 'Angenommen'),
      (OrderStatusFilter.declined, 'Abgelehnt'),
    ];

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      isDense: true,
    );

    return Row(
      children: [
        // Jahr
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: inputDecoration.copyWith(
              labelText: 'Jahr',
              prefixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            isExpanded: true,
            items: years.map((year) => DropdownMenuItem(
              value: year,
              child: Text('$year'),
            )).toList(),
            onChanged: (year) {
              if (year != null) {
                setState(() => _selectedYear = year);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        // Monat
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int?>(
            initialValue: _selectedMonth,
            decoration: inputDecoration.copyWith(
              labelText: 'Monat',
              prefixIcon: const Icon(Icons.calendar_month, size: 18),
            ),
            isExpanded: true,
            items: List.generate(13, (index) => DropdownMenuItem(
              value: index == 0 ? null : index,
              child: Text(monthNames[index]),
            )),
            onChanged: (month) {
              setState(() => _selectedMonth = month);
            },
          ),
        ),
        const SizedBox(width: 10),
        // Sortierung
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<OrderSortOption>(
            initialValue: _sortOption,
            decoration: inputDecoration.copyWith(
              labelText: 'Sortierung',
              prefixIcon: GestureDetector(
                onTap: () => setState(() => _sortAscending = !_sortAscending),
                child: Tooltip(
                  message: _sortAscending ? 'Aufsteigend' : 'Absteigend',
                  child: Icon(
                    _sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            isExpanded: true,
            items: sortItems
                .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _sortOption = val);
            },
          ),
        ),
        const SizedBox(width: 10),
        // Status
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<OrderStatusFilter>(
            initialValue: _statusFilter,
            decoration: inputDecoration.copyWith(
              labelText: 'Status',
              prefixIcon: const Icon(Icons.flag_outlined, size: 18),
            ),
            isExpanded: true,
            items: statusItems
                .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _statusFilter = val);
            },
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
