import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import 'order_detail_sheet.dart';
import 'widgets/orders_table.dart';

/// Sort options for pending orders.
enum PendingSortOption { eventDate, createdAt, guests, name }

/// Screen displaying orders with pending issues (total = 0).
class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  String _searchQuery = '';
  PendingSortOption _sortOption = PendingSortOption.eventDate;
  bool _sortAscending = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SavedOrder> _filterAndSortOrders(List<SavedOrder> orders) {
    // Filter by search query
    var filtered = orders;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = orders.where((o) {
        final nameMatch = o.name.toLowerCase().contains(query);
        final locationMatch = o.location.toLowerCase().contains(query);
        final guestMatch = o.personCount.toString().contains(query) ||
            o.guestCountRange.toLowerCase().contains(query);
        return nameMatch || locationMatch || guestMatch;
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      int comparison;
      switch (_sortOption) {
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
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.pending_title'.tr()),
      ),
      body: StreamBuilder<List<SavedOrder>>(
        stream: orderRepository.watchPendingOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data ?? [];

          if (allOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'orders.no_pending'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          final orders = _filterAndSortOrders(allOrders);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Card(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'orders.pending_info'.tr(),
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search and sort controls
                    _buildSearchBar(colorScheme),
                    const SizedBox(height: 12),
                    _buildSortChips(colorScheme),
                    const SizedBox(height: 16),
                    Text(
                      'orders.pending_count'.tr(args: [orders.length.toString()]),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    OrdersTable(
                      orders: orders,
                      colorScheme: colorScheme,
                      selectedYear: DateTime.now().year,
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

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return SearchBar(
      hintText: 'orders.search_hint'.tr(),
      leading: const Icon(Icons.search),
      trailing: _searchQuery.isNotEmpty
          ? [
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ]
          : null,
      elevation: WidgetStateProperty.all(0),
      backgroundColor: WidgetStateProperty.all(
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          // Direction toggle
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
          _buildSortChip(PendingSortOption.eventDate, 'orders.sort_event_date'.tr(), Icons.event, colorScheme),
          _buildSortChip(PendingSortOption.createdAt, 'orders.sort_created_at'.tr(), Icons.schedule, colorScheme),
          _buildSortChip(PendingSortOption.guests, 'orders.sort_guests'.tr(), Icons.people, colorScheme),
          _buildSortChip(PendingSortOption.name, 'orders.sort_name'.tr(), Icons.sort_by_alpha, colorScheme),
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

  Widget _buildSortChip(PendingSortOption option, String label, IconData icon, ColorScheme colorScheme) {
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
      ),
    );
  }
}
