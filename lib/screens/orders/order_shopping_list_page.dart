import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../data/order_repository.dart';
import '../../data/stock_repository.dart';
import '../../models/material_item.dart';
import '../../models/order.dart';
import '../../models/stock.dart';
import '../../services/auth_service.dart';
import '../../utils/currency.dart';
import '../inventory/inventory_rows.dart';
import '../shopping_list/stock_logic.dart';

/// Read-only overview of an order's shopping list. Pops with `true` when
/// the user taps "Bearbeiten", so the caller can start the existing
/// shopping-list editor.
///
/// Employees additionally choose per item whether it is bought in the shop
/// or taken from a storage location (internal only, customers never see
/// it). The choice is saved on the item map right here, because the editor
/// rebuilds items from the catalog. [items] overrides `order.items` and
/// [onItemsChanged] reports the saved list back to the caller.
class OrderShoppingListPage extends StatefulWidget {
  const OrderShoppingListPage({
    super.key,
    required this.order,
    this.items,
    this.onItemsChanged,
  });

  final SavedOrder order;
  final List<Map<String, dynamic>>? items;
  final void Function(List<Map<String, dynamic>> items)? onItemsChanged;

  @override
  State<OrderShoppingListPage> createState() => _OrderShoppingListPageState();
}

class _OrderShoppingListPageState extends State<OrderShoppingListPage> {
  late List<Map<String, dynamic>> _items = List.of(
    widget.items ?? widget.order.items,
  );
  final bool _staff = authService.isEmployeeOrHigher;
  Stream<List<StockEntry>>? _stock;
  Stream<List<StorageLocation>>? _locations;
  List<({String id, MaterialItem item})> _catalog = const [];
  String? _ownLocationId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!_staff) return;
    _stock = stockRepository.watchStock();
    _locations = stockRepository.watchLocations();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    try {
      final catalog = await adminRepository.getMaterialsWithIds(
        isFixedValue: false,
      );
      final own = await stockRepository.ownLocation();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _ownLocationId = own?.id;
      });
    } catch (e) {
      debugPrint('Loading stock source data failed: $e');
    }
  }

  Future<void> _setSource(int index, ItemSource source) async {
    if (_saving) return;
    final previous = _items;
    final next = List<Map<String, dynamic>>.of(_items)
      ..[index] = withItemSource(_items[index], source);
    setState(() {
      _items = next;
      _saving = true;
    });
    final ok = await orderRepository.updateOrder(widget.order.id, {
      'items': next,
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _items = previous;
    });
    if (ok) {
      widget.onItemsChanged?.call(next);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('orders.source_save_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = _stock;
    final locations = _locations;
    if (stock == null || locations == null) {
      return _buildPage(context, const [], const []);
    }
    return StreamBuilder<List<StockEntry>>(
      stream: stock,
      builder: (context, stockSnap) => StreamBuilder<List<StorageLocation>>(
        stream: locations,
        builder: (context, locSnap) => _buildPage(
          context,
          stockSnap.data ?? const [],
          locSnap.data ?? const [],
        ),
      ),
    );
  }

  Widget _sourceRow(
    int index,
    Map<String, dynamic> item,
    List<StockEntry> entries,
    List<StorageLocation> locations,
    Currency currency,
  ) {
    final source = ItemSource.fromItem(item);
    final materialId = resolveMaterialId(item, _catalog);
    final canStock = materialId != null && locations.isNotEmpty;
    final locationId = source.locationId;
    final selected = locations.any((l) => l.id == locationId)
        ? locationId
        : null;
    final available = selected != null && materialId != null
        ? availableAt(entries, materialId, selected)
        : null;
    final cost = itemInternalCost(item, entries, _catalog);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('orders.source_shop'.tr()),
              Switch(
                value: source.isStock,
                onChanged: canStock && !_saving
                    ? (on) {
                        final first =
                            locations.any((l) => l.id == _ownLocationId)
                            ? _ownLocationId!
                            : locations.first.id;
                        _setSource(
                          index,
                          on
                              ? ItemSource.stock(first)
                              : const ItemSource.shop(),
                        );
                      }
                    : null,
              ),
              Text('orders.source_stock'.tr()),
              if (source.isStock) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selected,
                    hint: Text('orders.source_location'.tr()),
                    items: [
                      for (final l in locations)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: _saving
                        ? null
                        : (id) {
                            if (id != null) {
                              _setSource(index, ItemSource.stock(id));
                            }
                          },
                  ),
                ),
              ],
            ],
          ),
          if (!canStock)
            Text(
              materialId == null
                  ? 'orders.source_unresolved'.tr()
                  : 'orders.source_no_location'.tr(),
              style: theme.textTheme.bodySmall,
            ),
          if (available != null)
            Text(
              'orders.source_available'.tr(
                namedArgs: {
                  'order': formatQuantity(available.order),
                  'investment': formatQuantity(available.investment),
                },
              ),
              style: theme.textTheme.bodySmall,
            ),
          Text(
            '${'orders.internal_cost'.tr()}: ${currency.format(cost)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _itemTile(
    Map<String, dynamic> item,
    Currency currency,
    ColorScheme scheme,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          '${(item['quantity'] as num?)?.toInt() ?? 1}x',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(item['name'] as String? ?? ''),
      subtitle: Text(
        '${item['unit'] as String? ?? ''} • '
        '${currency.format((item['price'] as num?)?.toDouble() ?? 0)}'
        '${(item['note'] as String? ?? '').isNotEmpty ? ' • ${item['note']}' : ''}',
      ),
      trailing: Text(
        currency.format(
          ((item['price'] as num?)?.toDouble() ?? 0) *
              ((item['quantity'] as num?)?.toInt() ?? 1),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    List<StockEntry> entries,
    List<StorageLocation> locations,
  ) {
    final order = widget.order;
    final currency = Currency.fromCode(order.currency);
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    final total = customerTotal(items);
    final internalTotal = items.fold<double>(
      0,
      (sum, item) => sum + itemInternalCost(item, entries, _catalog),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.shopping_list_title'.tr()),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit),
            label: Text('orders.edit_shopping_list'.tr()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${items.length} ${'orders.articles'.tr()}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  _itemTile(items[i], currency, scheme),
                  if (_staff)
                    _sourceRow(i, items[i], entries, locations, currency),
                ],
              ),
            ),

          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'orders.shopping_list_total'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                currency.format(total),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_staff) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('orders.internal_cost_total'.tr()),
                Text(currency.format(internalTotal)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit),
            label: Text('orders.edit_shopping_list'.tr()),
          ),
        ],
      ),
    );
  }
}
