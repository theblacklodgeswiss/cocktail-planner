import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../order_status_helpers.dart';
import 'order_info_chip.dart';

/// Displays orders in either a DataTable (desktop) or card list (mobile).
class OrdersTable extends StatelessWidget {
  const OrdersTable({
    super.key,
    required this.orders,
    required this.colorScheme,
    required this.selectedYear,
    required this.onOrderTap,
    this.showMonthSubtitle = false,
    this.sortColumn,
    this.sortAscending = false,
    this.onSort,
  });

  final List<SavedOrder> orders;
  final ColorScheme colorScheme;
  final int selectedYear;
  final void Function(SavedOrder order) onOrderTap;
  final bool showMonthSubtitle;
  final int? sortColumn;
  final bool sortAscending;
  final void Function(int column, bool ascending)? onSort;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return isWide ? _buildDataTable() : _buildCardList(context);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '${'orders.no_orders'.tr()} $selectedYear',
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            colorScheme.primaryContainer.withValues(alpha: 0.4),
          ),
          showCheckboxColumn: false,
          sortColumnIndex: sortColumn,
          sortAscending: sortAscending,
          columns: [
            DataColumn(
              label: Text('orders.status'.tr()),
              onSort: onSort != null ? (columnIndex, ascending) => onSort!(0, ascending) : null,
            ),
            DataColumn(
              label: Text('orders.date'.tr()),
              onSort: onSort != null ? (columnIndex, ascending) => onSort!(1, ascending) : null,
            ),
            DataColumn(
              label: const Text('Name'),
              onSort: onSort != null ? (columnIndex, ascending) => onSort!(2, ascending) : null,
            ),
            DataColumn(
              label: Text('orders.persons'.tr()),
              numeric: true,
              onSort: onSort != null ? (columnIndex, ascending) => onSort!(3, ascending) : null,
            ),
            DataColumn(
              label: Text('orders.articles'.tr()),
              numeric: true,
            ),
            DataColumn(
              label: Text('orders.total'.tr()),
              numeric: true,
            ),
            DataColumn(
              label: Text('orders.created_at'.tr()),
              onSort: onSort != null ? (columnIndex, ascending) => onSort!(4, ascending) : null,
            ),
          ],
          rows: orders.map((order) => _buildDataRow(order)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(SavedOrder order) {
    final dateStr = formatDate(order.date);
    return DataRow(
      onSelectChanged: (_) => onOrderTap(order),
      cells: [
        DataCell(_buildStatusBadge(order.status)),
        DataCell(Text(dateStr)),
        DataCell(_buildNameCell(order)),
        DataCell(Text(order.personCount.toString())),
        DataCell(Text(order.items.length.toString())),
        DataCell(
            Text('${order.total.toStringAsFixed(2)} ${order.currency}')),
        DataCell(Text(formatDate(order.createdAt ?? order.date))),
      ],
    );
  }

  Widget _buildNameCell(SavedOrder order) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(order.name)),
        if (order.isFromForm) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: order.needsShoppingList
                ? 'orders.no_shopping_list'.tr()
                : 'orders.from_form'.tr(),
            child: Icon(
              order.needsShoppingList
                  ? Icons.shopping_cart_outlined
                  : Icons.description_outlined,
              size: 16,
              color: order.needsShoppingList ? Colors.orange : Colors.blue,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 14, color: statusColor(status)),
          const SizedBox(width: 4),
          Text(
            statusLabel(status),
            style: TextStyle(
              color: statusColor(status),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardList(BuildContext context) {
    return Column(
      children: orders.map((order) => _buildOrderCard(context, order)).toList(),
    );
  }

  Widget _buildOrderCard(BuildContext context, SavedOrder order) {
    final dateStr = formatDate(order.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOrderTap(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge + date row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(order.status),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Name with form indicator
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (showMonthSubtitle) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatMonthYear(order.date),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (order.isFromForm) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.needsShoppingList
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order.needsShoppingList
                                ? Icons.shopping_cart_outlined
                                : Icons.description_outlined,
                            size: 14,
                            color: order.needsShoppingList
                                ? Colors.orange
                                : Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.needsShoppingList
                                ? 'orders.no_shopping_list'.tr()
                                : 'orders.from_form'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: order.needsShoppingList
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OrderInfoChip(
                    icon: Icons.people,
                    label: '${order.personCount}',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  OrderInfoChip(
                    icon: Icons.shopping_cart,
                    label: '${order.items.length} ${'orders.articles'.tr()}',
                    colorScheme: colorScheme,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${order.total.toStringAsFixed(2)} ${order.currency}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                    ),
                  ),
                  // Show createdAt on the far right, then chevron
                  Row(
                    children: [
                      Text(
                        formatDate(order.createdAt ?? order.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: colorScheme.outline),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
    const monthNames = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }
}
