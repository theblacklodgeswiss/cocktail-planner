import 'package:cocktail_planer/data/firestore_service.dart';
import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'order_detail_sheet.dart';
import 'widgets/orders_table.dart';

/// Screen showing all orders grouped by year as tiles. Tapping a year tile
/// reveals the full list of orders (accepted / declined / offer) for that
/// year.
class OrdersYearOverviewScreen extends StatefulWidget {
  const OrdersYearOverviewScreen({super.key});

  @override
  State<OrdersYearOverviewScreen> createState() =>
      _OrdersYearOverviewScreenState();
}

class _OrdersYearOverviewScreenState extends State<OrdersYearOverviewScreen> {
  bool _firestoreReady = false;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    firestoreService.initialize().then((_) {
      if (mounted) setState(() => _firestoreReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedYear == null
              ? 'orders.years_overview_title'.tr()
              : '${'orders.order_count'.tr()} $_selectedYear',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedYear != null) {
              setState(() => _selectedYear = null);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: StreamBuilder<List<SavedOrder>>(
        stream: _firestoreReady || firestoreService.isAvailable
            ? orderRepository.watchOrders()
            : const Stream.empty(),
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
                child: _selectedYear == null
                    ? _buildYearTiles(context, colorScheme, orders)
                    : _buildYearList(context, colorScheme, orders),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearTiles(
    BuildContext context,
    ColorScheme colorScheme,
    List<SavedOrder> orders,
  ) {
    final counts = <int, int>{};
    for (final order in orders) {
      counts[order.year] = (counts[order.year] ?? 0) + 1;
    }
    final years = counts.keys.toList()..sort((a, b) => b.compareTo(a));

    if (years.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'orders.no_orders'.tr(),
            style: TextStyle(color: colorScheme.outline),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        final count = counts[year]!;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedYear = year),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$year',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count ${'orders.order_count'.tr()}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearList(
    BuildContext context,
    ColorScheme colorScheme,
    List<SavedOrder> orders,
  ) {
    final yearOrders = orders.where((o) => o.year == _selectedYear).toList();
    return OrdersTable(
      orders: yearOrders,
      colorScheme: colorScheme,
      selectedYear: _selectedYear!,
      showMonthSubtitle: true,
      onOrderTap: (order) => showOrderDetails(context, order),
    );
  }
}
