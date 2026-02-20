import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import 'order_detail_sheet.dart';
import 'widgets/orders_table.dart';
import 'widgets/summary_card.dart';

/// Screen displaying an overview of all orders with filtering and summaries.
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
    setState(() => _selectedYear = year);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('orders.title'.tr())),
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
                    _SummaryCardsSection(orders: orders),
                    const SizedBox(height: 20),
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
