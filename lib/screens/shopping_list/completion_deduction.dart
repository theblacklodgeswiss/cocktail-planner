import '../../models/material_item.dart';
import '../../models/order.dart';
import '../../models/stock.dart';
import 'stock_logic.dart';

/// One stock booking planned for a completed order. [id] is deterministic, so
/// booking it twice (retry, double click, reload) is a no-op.
class PlannedMovement {
  const PlannedMovement({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.locationId,
    required this.origin,
    required this.delta,
  });

  final String id;
  final String materialId;
  final String materialName;
  final String locationId;
  final StockOrigin origin;

  /// Always negative.
  final double delta;
}

/// Quantity of [name] that stock could not cover (bought in the shop instead).
class DeductionShortfall {
  const DeductionShortfall({required this.name, required this.quantity});

  final String name;
  final double quantity;
}

class OrderDeductionPlan {
  const OrderDeductionPlan({
    this.movements = const [],
    this.shortfalls = const [],
    this.unresolved = const [],
    this.alreadyApplied = false,
    this.restRecorded,
  });

  final List<PlannedMovement> movements;
  final List<DeductionShortfall> shortfalls;

  /// Names of stock items that no longer resolve to a catalog material.
  final List<String> unresolved;

  /// The fresh order already had stockApplied set; nothing to book.
  final bool alreadyApplied;

  /// `restRecorded` of the FRESH order the plan was made from; null = unknown.
  final bool? restRecorded;

  bool get hasNotes => shortfalls.isNotEmpty || unresolved.isNotEmpty;
}

/// Movement document id: stable for the same order, material, location, origin.
String orderMovementId(
  String orderId,
  String materialId,
  String locationId,
  StockOrigin origin,
) => '$orderId|$materialId|$locationId|${origin.name}';

/// Plans the stock deduction of a completed order. Only items with source
/// 'stock' are considered; the same material at the same location is summed
/// over all items so the stock cannot be drawn twice. Per material the Auftrag
/// origin is drawn before Investition. A shortfall is not booked (stock never
/// goes below 0) but reported.
///
/// [booked] maps movement ids that were already booked for this order (an
/// earlier, partly failed attempt) to their applied delta. That quantity is
/// added back to [entries] so a retry plans the same split as the first
/// attempt instead of drawing the remainder from Investition.
OrderDeductionPlan planOrderDeduction(
  SavedOrder order,
  List<StockEntry> entries,
  List<({String id, MaterialItem item})> catalog, {
  Map<String, double> booked = const {},
}) {
  if (order.stockApplied) return const OrderDeductionPlan();

  final needs = <(String, String), double>{};
  final names = <(String, String), String>{};
  final unresolved = <String>[];
  for (final item in order.items) {
    final source = ItemSource.fromItem(item);
    if (!source.isStock) continue;
    final materialId = resolveMaterialId(item, catalog);
    if (materialId == null) {
      unresolved.add(item['name'] as String? ?? '');
      continue;
    }
    final needed = (item['quantity'] as num?)?.toDouble() ?? 1;
    if (needed <= 0) continue;
    final key = (materialId, source.locationId!);
    needs[key] = (needs[key] ?? 0) + needed;
    names.putIfAbsent(key, () {
      for (final c in catalog) {
        if (c.id == materialId) return c.item.name;
      }
      return item['name'] as String? ?? '';
    });
  }

  final movements = <PlannedMovement>[];
  final shortfalls = <DeductionShortfall>[];
  for (final e in needs.entries) {
    final (materialId, locationId) = e.key;
    final available = availableAt(entries, materialId, locationId);
    final orderId = orderMovementId(
      order.id,
      materialId,
      locationId,
      StockOrigin.order,
    );
    final investId = orderMovementId(
      order.id,
      materialId,
      locationId,
      StockOrigin.investment,
    );
    final plan = planDeduction(
      needed: e.value,
      stockOrder: available.order - (booked[orderId] ?? 0),
      stockInvestment: available.investment - (booked[investId] ?? 0),
    );
    final name = names[e.key]!;
    if (plan.fromOrder > 0) {
      movements.add(
        PlannedMovement(
          id: orderId,
          materialId: materialId,
          materialName: name,
          locationId: locationId,
          origin: StockOrigin.order,
          delta: -plan.fromOrder,
        ),
      );
    }
    if (plan.fromInvestment > 0) {
      movements.add(
        PlannedMovement(
          id: investId,
          materialId: materialId,
          materialName: name,
          locationId: locationId,
          origin: StockOrigin.investment,
          delta: -plan.fromInvestment,
        ),
      );
    }
    if (plan.fromShop > 0) {
      shortfalls.add(DeductionShortfall(name: name, quantity: plan.fromShop));
    }
  }
  return OrderDeductionPlan(
    movements: movements,
    shortfalls: shortfalls,
    unresolved: unresolved,
    restRecorded: order.restRecorded,
  );
}

/// Whether the leftover sheet may open right after completing. Fails closed:
/// only when the fresh order is known to have no recorded leftovers (a reopened
/// and re-completed order must not book its leftovers a second time).
bool shouldOfferRest({required bool? freshRestRecorded}) =>
    freshRestRecorded == false;

/// Reads everything needed from the sources (injectable for tests) and plans
/// from the FRESH order, never from an order object opened earlier: source
/// choices are saved on another page after the sheet was opened. Fails closed:
/// throws if the fresh order cannot be read, or if it has stock items and the
/// catalog cannot be loaded or is empty (otherwise every item would look
/// unresolved and be skipped for good).
Future<OrderDeductionPlan> prepareOrderDeduction({
  required Future<SavedOrder?> Function() fetchOrder,
  required Future<List<({String id, MaterialItem item})>> Function()
  loadCatalog,
  required Future<List<StockEntry>> Function() loadEntries,
  required Future<Map<String, double>> Function(List<String> ids) loadBooked,
}) async {
  final SavedOrder? fresh;
  try {
    fresh = await fetchOrder();
  } catch (e) {
    throw StateError('order could not be read: $e');
  }
  if (fresh == null) throw StateError('order could not be read');
  if (fresh.stockApplied) {
    return OrderDeductionPlan(
      alreadyApplied: true,
      restRecorded: fresh.restRecorded,
    );
  }
  final hasStockItems = fresh.items.any((i) => ItemSource.fromItem(i).isStock);
  if (!hasStockItems) {
    return OrderDeductionPlan(restRecorded: fresh.restRecorded);
  }

  final catalog = await loadCatalog();
  if (catalog.isEmpty) throw StateError('catalog is empty or not loaded');

  // Entries must be read BEFORE the already booked movements: a movement
  // booked in between would otherwise be subtracted twice (stock already
  // reduced, delta added back too little), which can over-deduct.
  final entries = await loadEntries();
  final ids = <String>{};
  for (final item in fresh.items) {
    final source = ItemSource.fromItem(item);
    final materialId = resolveMaterialId(item, catalog);
    if (!source.isStock || materialId == null) continue;
    for (final origin in StockOrigin.values) {
      ids.add(
        orderMovementId(fresh.id, materialId, source.locationId!, origin),
      );
    }
  }
  final booked = await loadBooked(ids.toList());
  return planOrderDeduction(fresh, entries, catalog, booked: booked);
}
