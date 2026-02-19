import 'package:flutter/material.dart';

import '../data/cocktail_repository.dart';
import '../models/order.dart';

class OrdersOverviewScreen extends StatefulWidget {
  const OrdersOverviewScreen({super.key});

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {
  late Future<List<Order>> _ordersFuture;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = cocktailRepository.getOrders(year: _selectedYear);
    });
  }

  String _drinkerLabel(String type) {
    switch (type) {
      case 'light':
        return 'Wenig';
      case 'heavy':
        return 'Viel';
      default:
        return 'Normal';
    }
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
                  _selectedYear = year;
                  _loadOrders();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards(List<Order> orders) {
    final totalOrders = orders.length;
    final totalRevenue = orders.fold<double>(0, (sum, o) => sum + o.total);
    final totalPersons = orders.fold<int>(0, (sum, o) => sum + o.personCount);
    final avgTotal = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final cards = [
          _SummaryCard(
            icon: Icons.receipt_long,
            label: 'Bestellungen',
            value: totalOrders.toString(),
            color: Theme.of(context).colorScheme.primary,
          ),
          _SummaryCard(
            icon: Icons.attach_money,
            label: 'Gesamtumsatz',
            value: '${totalRevenue.toStringAsFixed(2)} CHF',
            color: Colors.green.shade700,
          ),
          _SummaryCard(
            icon: Icons.people,
            label: 'Personen gesamt',
            value: totalPersons.toString(),
            color: Colors.blue.shade700,
          ),
          _SummaryCard(
            icon: Icons.trending_up,
            label: 'Ø pro Bestellung',
            value: '${avgTotal.toStringAsFixed(2)} CHF',
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

  Widget _buildOrdersTable(List<Order> orders, ColorScheme colorScheme) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Keine Bestellungen für $_selectedYear',
                style: TextStyle(color: colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            colorScheme.primaryContainer.withValues(alpha: 0.4),
          ),
          columns: const [
            DataColumn(label: Text('Datum')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Personen'), numeric: true),
            DataColumn(label: Text('Trinkverhalten')),
            DataColumn(label: Text('Artikel'), numeric: true),
            DataColumn(label: Text('Gesamt'), numeric: true),
          ],
          rows: orders.map((order) {
            final dateStr =
                '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}.${order.date.year}';
            return DataRow(cells: [
              DataCell(Text(dateStr)),
              DataCell(Text(order.name)),
              DataCell(Text(order.personCount.toString())),
              DataCell(Text(_drinkerLabel(order.drinkerType))),
              DataCell(Text(order.items.length.toString())),
              DataCell(Text('${order.total.toStringAsFixed(2)} CHF')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bestellungsübersicht'),
      ),
      body: FutureBuilder<List<Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
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
                      'Bestellungen $_selectedYear',
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

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
          ],
        ),
      ),
    );
  }
}
