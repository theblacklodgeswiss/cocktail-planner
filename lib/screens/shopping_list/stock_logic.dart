import 'dart:math' as math;

import '../../models/material_item.dart';
import '../../models/stock.dart';

/// How a needed quantity is covered: from Auftrag stock, Investition stock
/// or bought in the shop.
class DeductionPlan {
  const DeductionPlan({
    required this.fromOrder,
    required this.fromInvestment,
    required this.fromShop,
  });

  final double fromOrder;
  final double fromInvestment;
  final double fromShop;
}

/// Draws Auftrag stock first, then Investition; the remainder is bought.
/// Needs <= 0 plan nothing; negative stock counts as empty.
DeductionPlan planDeduction({
  required double needed,
  required double stockOrder,
  required double stockInvestment,
}) {
  final need = math.max(0.0, needed);
  final fromOrder = math.min(need, math.max(0.0, stockOrder));
  final fromInvestment = math.min(
    need - fromOrder,
    math.max(0.0, stockInvestment),
  );
  return DeductionPlan(
    fromOrder: fromOrder,
    fromInvestment: fromInvestment,
    fromShop: need - fromOrder - fromInvestment,
  );
}

/// Internal cost only: Auftrag stock is free, Investition stock costs the
/// catalog price, the rest the shop price. Never used for customer prices.
double internalCost({
  required DeductionPlan plan,
  required double catalogPrice,
  required double shopPrice,
}) =>
    // Auftrag stock is free by spec; the term stays to mirror the formula.
    plan.fromOrder * 0 +
    plan.fromInvestment * catalogPrice +
    plan.fromShop * shopPrice;

/// Where a shopping-list item comes from. Items without the fields (all old
/// orders) are bought in the shop.
class ItemSource {
  const ItemSource.shop() : isStock = false, locationId = null;
  const ItemSource.stock(String this.locationId) : isStock = true;

  final bool isStock;
  final String? locationId;

  factory ItemSource.fromItem(Map<String, dynamic> item) {
    final location = item['sourceLocationId'] as String?;
    if (item['source'] == 'stock' && location != null && location.isNotEmpty) {
      return ItemSource.stock(location);
    }
    return const ItemSource.shop();
  }
}

/// Copy of [item] with the source fields set; shop drops the location.
Map<String, dynamic> withItemSource(
  Map<String, dynamic> item,
  ItemSource source,
) {
  final copy = Map<String, dynamic>.from(item)
    ..remove('sourceLocationId')
    ..['source'] = source.isStock ? 'stock' : 'shop';
  if (source.isStock) copy['sourceLocationId'] = source.locationId;
  return copy;
}

/// Material id of a saved item: its own `materialId` if present, otherwise
/// the catalog entry with the same name and unit (name alone if unambiguous).
/// Null when the item is not a catalog material (it can only be bought).
String? resolveMaterialId(
  Map<String, dynamic> item,
  List<({String id, MaterialItem item})> catalog,
) {
  final own = item['materialId'] as String?;
  if (own != null && own.isNotEmpty) return own;
  final name = item['name'] as String? ?? '';
  final unit = item['unit'] as String? ?? '';
  final byName = catalog.where((c) => c.item.name == name).toList();
  if (byName.isEmpty) return null;
  final exact = byName.where((c) => c.item.unit == unit).toList();
  if (exact.length == 1) return exact.single.id;
  if (exact.isEmpty && byName.length == 1) return byName.single.id;
  return null;
}

/// Stock of one material at one location, per origin.
({double order, double investment}) availableAt(
  List<StockEntry> entries,
  String materialId,
  String locationId,
) {
  var order = 0.0;
  var investment = 0.0;
  for (final e in entries) {
    if (e.materialId != materialId || e.locationId != locationId) continue;
    if (e.origin == StockOrigin.investment) {
      investment += e.quantity;
    } else {
      order += e.quantity;
    }
  }
  return (order: order, investment: investment);
}

/// Deduction plan of a saved item for its chosen source. Shop (or an item
/// that cannot be resolved) is bought completely.
DeductionPlan planForItem(
  Map<String, dynamic> item,
  List<StockEntry> entries,
  List<({String id, MaterialItem item})> catalog,
) {
  final needed = (item['quantity'] as num?)?.toDouble() ?? 1;
  final source = ItemSource.fromItem(item);
  final materialId = resolveMaterialId(item, catalog);
  if (!source.isStock || materialId == null) {
    return planDeduction(needed: needed, stockOrder: 0, stockInvestment: 0);
  }
  final stock = availableAt(entries, materialId, source.locationId!);
  return planDeduction(
    needed: needed,
    stockOrder: stock.order,
    stockInvestment: stock.investment,
  );
}

/// Internal cost of a saved item. Catalog and shop price are both the
/// item's stored `price` (the spec has no separate purchase price).
double itemInternalCost(
  Map<String, dynamic> item,
  List<StockEntry> entries,
  List<({String id, MaterialItem item})> catalog,
) {
  final price = (item['price'] as num?)?.toDouble() ?? 0;
  return internalCost(
    plan: planForItem(item, entries, catalog),
    catalogPrice: price,
    shopPrice: price,
  );
}

/// Customer-facing total of a saved shopping list (price * quantity). The
/// chosen source never enters this.
double customerTotal(List<Map<String, dynamic>> items) => items.fold<double>(
  0,
  (sum, item) =>
      sum +
      ((item['price'] as num?)?.toDouble() ?? 0) *
          ((item['quantity'] as num?)?.toInt() ?? 1),
);

/// The source switch may always be turned off for a stock item (even when
/// it can no longer be resolved); turning it on needs a resolvable material.
/// Once the order's stock was booked, the source is frozen (corrections are
/// made in the inventory).
bool canToggleSource({
  required bool canStock,
  required bool isStock,
  required bool saving,
  bool stockApplied = false,
}) => (canStock || isStock) && !saving && !stockApplied;
