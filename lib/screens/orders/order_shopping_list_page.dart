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
import '../shopping_list/stock_logic.dart';
import 'order_shopping_list_view.dart';

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
    this.stockApplied,
    this.items,
    this.onItemsChanged,
  });

  final SavedOrder order;

  /// Overrides `order.stockApplied` (the opened order may be outdated).
  final bool? stockApplied;
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
      // The same catalog as the stock deduction (ingredients + consumables).
      final catalog = await adminRepository.getMaterialsWithIdsOrThrow();
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

  /// Saves the whole items list; a concurrent edit elsewhere is
  /// overwritten (last write wins), like the existing shopping-list editor.
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

  bool get _applied => widget.stockApplied ?? widget.order.stockApplied;

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

  Widget _buildPage(
    BuildContext context,
    List<StockEntry> entries,
    List<StorageLocation> locations,
  ) {
    return OrderShoppingListView(
      items: _items,
      currency: Currency.fromCode(widget.order.currency),
      staff: _staff,
      applied: _applied,
      saving: _saving,
      entries: entries,
      locations: locations,
      catalog: _catalog,
      ownLocationId: _ownLocationId,
      onSetSource: _setSource,
      onBack: () => Navigator.of(context).pop(),
      onEdit: () => Navigator.of(context).pop(true),
    );
  }
}
