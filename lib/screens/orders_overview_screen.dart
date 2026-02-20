import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/order_repository.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/invoice_pdf_generator.dart';
import '../services/pdf_generator.dart';
import '../utils/currency.dart';

class OrdersOverviewScreen extends StatefulWidget {
  const OrdersOverviewScreen({super.key});

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {
  int _selectedYear = DateTime.now().year;

  Stream<List<SavedOrder>> get _ordersStream =>
      orderRepository.watchOrders(year: _selectedYear);

  void _changeYear(int year) {
    setState(() {
      _selectedYear = year;
    });
  }

  String _drinkerLabel(String type) {
    switch (type) {
      case 'light':
        return 'orders.drinker_light'.tr();
      case 'heavy':
        return 'orders.drinker_heavy'.tr();
      default:
        return 'orders.drinker_normal'.tr();
    }
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.quote:
        return 'orders.status_quote'.tr();
      case OrderStatus.accepted:
        return 'orders.status_accepted'.tr();
      case OrderStatus.declined:
        return 'orders.status_declined'.tr();
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.quote:
        return Colors.orange;
      case OrderStatus.accepted:
        return Colors.green;
      case OrderStatus.declined:
        return Colors.red;
    }
  }

  IconData _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.quote:
        return Icons.hourglass_empty;
      case OrderStatus.accepted:
        return Icons.check_circle;
      case OrderStatus.declined:
        return Icons.cancel;
    }
  }

  void _showOrderDetails(SavedOrder order) {
    final dateStr = '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}.${order.date.year}';
    final colorScheme = Theme.of(context).colorScheme;
    final currency = Currency.fromCode(order.currency);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          var currentStatus = order.status;
          
          Future<void> updateStatus(OrderStatus newStatus) async {
            final success = await orderRepository.updateStatus(order.id, newStatus.value);
            if (success) {
              setSheetState(() => currentStatus = newStatus);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('orders.status_changed'.tr(namedArgs: {'status': _statusLabel(newStatus)}))),
                );
              }
            }
          }
          
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Scaffold(
              appBar: AppBar(
                title: Text(order.name),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  // Angebot erstellen
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/create-offer', extra: order);
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: Text('orders.offer'.tr()),
                  ),
                  // Rechnung erstellen (nur bei angenommenen Aufträgen)
                  if (currentStatus == OrderStatus.accepted)
                    TextButton.icon(
                      onPressed: () async {
                        // Sprachauswahl Dialog
                        final language = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('orders.select_language'.tr()),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Text('🇩🇪', style: TextStyle(fontSize: 24)),
                                  title: const Text('Deutsch'),
                                  onTap: () => Navigator.pop(ctx, 'de'),
                                ),
                                ListTile(
                                  leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                                  title: const Text('English'),
                                  onTap: () => Navigator.pop(ctx, 'en'),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('common.cancel'.tr()),
                              ),
                            ],
                          ),
                        );
                        if (language == null || !context.mounted) return;
                        
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => AlertDialog(
                            content: Row(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(width: 20),
                                Text('orders.generating_invoice'.tr()),
                              ],
                            ),
                          ),
                        );
                        
                        try {
                          await InvoicePdfGenerator.generateAndDownload(order, language: language);
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('orders.invoice_created'.tr())),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('common.error'.tr())),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: Text('orders.invoice'.tr()),
                    ),
                  // Einkaufsliste PDF
                  FilledButton.icon(
                    onPressed: () async {
                      await PdfGenerator.generateFromSavedOrder(order);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('orders.pdf_created'.tr())),
                        );
                      }
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: Text('orders.shopping_list'.tr()),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Status section
                  Card(
                    color: _statusColor(currentStatus).withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_statusIcon(currentStatus), color: _statusColor(currentStatus)),
                              const SizedBox(width: 8),
                              Text(
                                '${"orders.status".tr()}: ${_statusLabel(currentStatus)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _statusColor(currentStatus),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('orders.change_status'.tr(), style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (currentStatus != OrderStatus.accepted)
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => updateStatus(OrderStatus.accepted),
                                    icon: const Icon(Icons.check),
                                    label: Text('orders.accept'.tr()),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                ),
                              if (currentStatus != OrderStatus.accepted && currentStatus != OrderStatus.declined)
                                const SizedBox(width: 8),
                              if (currentStatus != OrderStatus.declined)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => updateStatus(OrderStatus.declined),
                                    icon: const Icon(Icons.close),
                                    label: Text('orders.decline'.tr()),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ),
                              if (currentStatus != OrderStatus.quote) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => updateStatus(OrderStatus.quote),
                                    icon: const Icon(Icons.undo),
                                    label: Text('orders.status_quote'.tr()),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Order info header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: colorScheme.outline),
                              const SizedBox(width: 8),
                              Text(dateStr),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  currency.format(order.total),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _OrderInfoChip(
                                icon: Icons.people,
                                label: '${order.personCount} ${'orders.persons'.tr()}',
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(width: 8),
                              _OrderInfoChip(
                                icon: Icons.local_bar,
                                label: _drinkerLabel(order.drinkerType),
                                colorScheme: colorScheme,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Items list header
                  Text(
                    '${order.items.length} ${'orders.articles'.tr()}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Items list
                  ...order.items.map((item) {
                    final name = item['name'] as String? ?? '';
                    final unit = item['unit'] as String? ?? '';
                    final price = (item['price'] as num?)?.toDouble() ?? 0;
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                    final note = item['note'] as String? ?? '';
                    final total = price * quantity;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            '${quantity}x',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text('$unit • ${currency.format(price)}${note.isNotEmpty ? ' • $note' : ''}'),
                        trailing: Text(
                          currency.format(total),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }),
                  
                  // Super Admin: Delete order
                  if (AuthService().isSuperAdmin) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('orders.delete_confirm_title'.tr()),
                              content: Text('orders.delete_confirm_message'.tr(namedArgs: {'name': order.name})),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('common.cancel'.tr()),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  child: Text('common.delete'.tr()),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final success = await orderRepository.deleteOrder(order.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('orders.deleted'.tr())),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('orders.delete_failed'.tr())),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_forever),
                        label: Text('orders.delete_order'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
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

  Widget _buildSummaryCards(List<SavedOrder> orders) {
    final totalOrders = orders.length;
    final acceptedOrders = orders.where((o) => o.isAccepted).toList();
    final quoteOrders = orders.where((o) => o.status == OrderStatus.quote).toList();
    final totalRevenue = acceptedOrders.fold<double>(0, (sum, o) => sum + o.total);
    final totalPersons = acceptedOrders.fold<int>(0, (sum, o) => sum + o.personCount);
    final avgTotal = acceptedOrders.isNotEmpty ? totalRevenue / acceptedOrders.length : 0.0;
    
    // Get most common currency from accepted orders
    final currencyCounts = <String, int>{};
    for (final order in acceptedOrders) {
      currencyCounts[order.currency] = (currencyCounts[order.currency] ?? 0) + 1;
    }
    final dominantCurrency = currencyCounts.entries.isEmpty 
        ? 'CHF'
        : currencyCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final cards = [
          _SummaryCard(
            icon: Icons.receipt_long,
            label: 'orders.open_quotes'.tr(),
            value: '${quoteOrders.length} / $totalOrders',
            color: Colors.orange.shade700,
          ),
          _SummaryCard(
            icon: Icons.attach_money,
            label: 'orders.total_revenue'.tr(),
            value: '${totalRevenue.toStringAsFixed(2)} $dominantCurrency',
            subtitle: '${acceptedOrders.length} ${'orders.accepted_only'.tr()}',
            color: Colors.green.shade700,
          ),
          _SummaryCard(
            icon: Icons.people,
            label: 'orders.persons'.tr(),
            value: totalPersons.toString(),
            color: Colors.blue.shade700,
          ),
          _SummaryCard(
            icon: Icons.trending_up,
            label: 'orders.avg_order'.tr(),
            value: '${avgTotal.toStringAsFixed(2)} $dominantCurrency',
            color: Colors.purple.shade700,
          ),
        ];
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

  Widget _buildOrdersTable(List<SavedOrder> orders, ColorScheme colorScheme) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                '${'orders.no_orders'.tr()} $_selectedYear',
                style: TextStyle(color: colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        
        if (isWide) {
          // Desktop: DataTable
          return Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  colorScheme.primaryContainer.withValues(alpha: 0.4),
                ),
                showCheckboxColumn: false,
                columns: [
                  DataColumn(label: Text('orders.status'.tr())),
                  DataColumn(label: Text('orders.date'.tr())),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('orders.persons'.tr()), numeric: true),
                  DataColumn(label: Text('orders.articles'.tr()), numeric: true),
                  DataColumn(label: Text('orders.total'.tr()), numeric: true),
                ],
                rows: orders.map((order) {
                  final dateStr =
                      '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}.${order.date.year}';
                  return DataRow(
                    onSelectChanged: (_) => _showOrderDetails(order),
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(order.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon(order.status), size: 14, color: _statusColor(order.status)),
                              const SizedBox(width: 4),
                              Text(
                                _statusLabel(order.status),
                                style: TextStyle(
                                  color: _statusColor(order.status),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(dateStr)),
                      DataCell(Text(order.name)),
                      DataCell(Text(order.personCount.toString())),
                      DataCell(Text(order.items.length.toString())),
                      DataCell(Text('${order.total.toStringAsFixed(2)} ${order.currency}')),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        }
        
        // Mobile: Card list
        return Column(
          children: orders.map((order) {
            final dateStr =
                '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}.${order.date.year}';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showOrderDetails(order),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge + date row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(order.status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(order.status), size: 14, color: _statusColor(order.status)),
                                const SizedBox(width: 4),
                                Text(
                                  _statusLabel(order.status),
                                  style: TextStyle(
                                    color: _statusColor(order.status),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Name
                      Text(
                        order.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _OrderInfoChip(
                            icon: Icons.people,
                            label: '${order.personCount}',
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 8),
                          _OrderInfoChip(
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          Icon(Icons.chevron_right, color: colorScheme.outline),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.title'.tr()),
      ),
      body: StreamBuilder<List<SavedOrder>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildYearSelector(),
                    const SizedBox(height: 20),
                    _buildSummaryCards(orders),
                    const SizedBox(height: 20),
                    Text(
                      '${'orders.order_count'.tr()} $_selectedYear',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildOrdersTable(orders, colorScheme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderInfoChip extends StatelessWidget {
  const _OrderInfoChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
