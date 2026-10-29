import '../../data/stock_repository.dart';
import '../../models/stock.dart';
import '../../services/auth_service.dart';
import 'inventory_article_editor.dart';
import 'inventory_rows.dart';

Future<void> _defaultSetQuantity({
  required String materialId,
  required String materialName,
  required String locationId,
  required StockOrigin origin,
  required double quantity,
}) => stockRepository.setQuantity(
  materialId: materialId,
  materialName: materialName,
  locationId: locationId,
  origin: origin,
  quantity: quantity,
);

Future<void> _defaultSetArticleNote({
  required String materialId,
  required String materialName,
  required String note,
  required String fallbackLocationId,
}) => stockRepository.setArticleNote(
  materialId: materialId,
  materialName: materialName,
  note: note,
  fallbackLocationId: fallbackLocationId,
);

Future<void> _defaultApplyMovement({
  required String materialId,
  required String materialName,
  required String locationId,
  required StockOrigin origin,
  required double delta,
  required String reason,
}) => stockRepository.applyMovement(
  materialId: materialId,
  materialName: materialName,
  locationId: locationId,
  origin: origin,
  delta: delta,
  reason: reason,
);

String? _defaultEmail() => authService.email;

/// Repository calls of the inventory page's sheets, bundled so tests can
/// check the wiring with fakes. The defaults delegate to the singletons.
class InventoryServices {
  const InventoryServices({
    this.setQuantity = _defaultSetQuantity,
    this.setArticleNote = _defaultSetArticleNote,
    this.applyMovement = _defaultApplyMovement,
    this.email = _defaultEmail,
  });

  final Future<void> Function({
    required String materialId,
    required String materialName,
    required String locationId,
    required StockOrigin origin,
    required double quantity,
  })
  setQuantity;
  final Future<void> Function({
    required String materialId,
    required String materialName,
    required String note,
    required String fallbackLocationId,
  })
  setArticleNote;
  final Future<void> Function({
    required String materialId,
    required String materialName,
    required String locationId,
    required StockOrigin origin,
    required double delta,
    required String reason,
  })
  applyMovement;

  /// The signed-in user's email (picks the note's fallback location).
  final String? Function() email;
}

/// What the article editor and the take-out sheet book for one [row].
class InventoryActions {
  const InventoryActions(this.services);

  final InventoryServices services;

  /// One changed cell: an absolute correction (logged as `correction`).
  Future<void> saveQuantity(InventoryRow row, QuantityChange change) =>
      services.setQuantity(
        materialId: row.materialId,
        materialName: row.materialName,
        locationId: change.locationId,
        origin: change.origin,
        quantity: change.quantity,
      );

  /// The note; without stock it goes to [noteFallbackLocation].
  Future<void> saveNote(
    InventoryRow row,
    List<StorageLocation> locations,
    String note,
  ) async {
    final fallback = noteFallbackLocation(locations, services.email());
    if (fallback == null) return;
    await services.setArticleNote(
      materialId: row.materialId,
      materialName: row.materialName,
      note: note,
      fallbackLocationId: fallback.id,
    );
  }

  /// Takes [amount] out (negative movement, reason `take`).
  Future<void> take(
    InventoryRow row,
    String locationId,
    StockOrigin origin,
    double amount,
  ) => services.applyMovement(
    materialId: row.materialId,
    materialName: row.materialName,
    locationId: locationId,
    origin: origin,
    delta: -amount,
    reason: 'take',
  );
}
