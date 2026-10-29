import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'package:cocktail_planer/screens/shopping_list/completion_deduction.dart';
import 'admin_repository.dart';
import 'firestore_service.dart';
import 'order_repository.dart';

/// Returns the location owned by [email] (case-insensitive), or null.
StorageLocation? pickOwn(List<StorageLocation> locations, String email) {
  final wanted = email.toLowerCase();
  for (final location in locations) {
    if (location.ownerEmail?.toLowerCase() == wanted) return location;
  }
  return null;
}

/// An ownerless location (no or empty ownerEmail) whose name equals [name]
/// (trimmed, case-insensitive), or null. Used to offer claiming it instead of
/// creating a duplicate.
StorageLocation? findClaimableLocation(
  List<StorageLocation> locations,
  String name,
) {
  final wanted = name.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final l in locations) {
    final ownerless = (l.ownerEmail ?? '').trim().isEmpty;
    if (ownerless && l.name.trim().toLowerCase() == wanted) return l;
  }
  return null;
}

String normalizeOwnerEmail(String raw) => raw.trim().toLowerCase();

/// An owner email is optional; if given it must contain '@'.
bool isValidOwnerEmail(String raw) {
  final v = raw.trim();
  return v.isEmpty || v.contains('@');
}

/// Fields written to a stock entry document. [note] is only included when
/// non-empty, so merging never clears an existing note.
Map<String, dynamic> stockEntryFields({
  required String materialId,
  required String materialName,
  required String locationId,
  required StockOrigin origin,
  required double quantity,
  String? note,
}) {
  final trimmed = note?.trim();
  return {
    'materialId': materialId,
    'materialName': materialName,
    'locationId': locationId,
    'origin': origin.name,
    'quantity': quantity,
    if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
  };
}

/// A movement with an explicit id is only applied if no movement with that id
/// exists yet, which makes retries and double submits no-ops.
bool shouldApplyMovement({required String? movementId, required bool exists}) =>
    movementId == null || !exists;

/// Parses each document with [parse]; a document that throws is skipped and
/// logged instead of failing the whole list (a stream error would hide every
/// other row behind an error message).
List<T> parseTolerant<T>(
  Iterable<({String id, Map<String, dynamic> data})> docs,
  T Function(String id, Map<String, dynamic> data) parse, {
  required String collection,
}) {
  final result = <T>[];
  for (final d in docs) {
    try {
      result.add(parse(d.id, d.data));
    } catch (e) {
      debugPrint('Skipping malformed $collection/${d.id}: $e');
    }
  }
  return result;
}

Iterable<({String id, Map<String, dynamic> data})> _docs(
  QuerySnapshot<Map<String, dynamic>> snap,
) => snap.docs.map((d) => (id: d.id, data: d.data()));

/// Repository for storage locations, stock quantities and stock movements.
class StockRepository {
  CollectionReference<Map<String, dynamic>> get _locations =>
      firestoreService.storageLocationsCollection;
  CollectionReference<Map<String, dynamic>> get _stock =>
      firestoreService.stockEntriesCollection;
  CollectionReference<Map<String, dynamic>> get _movements =>
      firestoreService.stockMovementsCollection;

  Stream<List<StorageLocation>> watchLocations() {
    return _locations
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => parseTolerant(
            _docs(snap),
            StorageLocation.fromMap,
            collection: 'storageLocations',
          ),
        );
  }

  Future<StorageLocation> createLocation(
    String name, {
    String? ownerEmail,
  }) async {
    final location = StorageLocation(
      id: '',
      name: name,
      ownerEmail: ownerEmail,
    );
    final ref = await _locations.add(location.toMap());
    return StorageLocation(id: ref.id, name: name, ownerEmail: ownerEmail);
  }

  /// The storage location of the current user, or null if none exists yet.
  Future<StorageLocation?> ownLocation() async {
    final email = authService.email;
    if (email == null) return null;
    final snap = await _locations.where('ownerEmail', isEqualTo: email).get();
    final owned = snap.docs
        .map((d) => StorageLocation.fromMap(d.id, d.data()))
        .toList();
    if (owned.isNotEmpty) return owned.first;
    // Firestore has no case-insensitive query and the collection is tiny
    // (a few locations), so a full read is cheap.
    // Fall back to a case-insensitive match for differently cased owners.
    final all = await _locations.get();
    return pickOwn(
      all.docs.map((d) => StorageLocation.fromMap(d.id, d.data())).toList(),
      email,
    );
  }

  /// Renames a location and, if [ownerEmail] is given, sets its owner. Both
  /// need admin rights in the rules unless the caller already owns it.
  Future<void> renameLocation(String id, String name, {String? ownerEmail}) {
    return _locations.doc(id).update({
      'name': name,
      if (ownerEmail != null && ownerEmail.isNotEmpty)
        'ownerEmail': normalizeOwnerEmail(ownerEmail),
    });
  }

  /// Sets the owner of a location (admin only per the rules).
  Future<void> setLocationOwner(String id, String ownerEmail) {
    return _locations.doc(id).update({
      'ownerEmail': normalizeOwnerEmail(ownerEmail),
    });
  }

  /// True if at least one movement with reason `import` exists. A single
  /// equality filter plus limit(1) needs no composite index.
  Future<bool> hasImportMovements() async {
    final snap = await _movements
        .where('reason', isEqualTo: 'import')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Stream<List<StockEntry>> watchStock() {
    return _stock.snapshots().map(
      (snap) => parseTolerant(
        _docs(snap),
        StockEntry.fromMap,
        collection: 'stockEntries',
      ),
    );
  }

  /// Changes a quantity by [delta] in one transaction. The quantity never
  /// drops below 0; the logged movement holds the delta actually applied.
  Future<void> applyMovement({
    required String materialId,
    required String materialName,
    required String locationId,
    required StockOrigin origin,
    required double delta,
    required String reason,
    String? orderId,
    String? note,
    String? movementId,
  }) {
    final entryRef = _stock.doc(
      StockEntry.buildId(materialId, locationId, origin),
    );
    final movementRef = movementId == null
        ? _movements.doc()
        : _movements.doc(movementId);
    return firestoreService.firestore.runTransaction((tx) async {
      // Reads before writes: an already booked movement id means this call is
      // a retry, so nothing may change.
      final existing = movementId == null ? null : await tx.get(movementRef);
      if (!shouldApplyMovement(
        movementId: movementId,
        exists: existing?.exists ?? false,
      )) {
        return;
      }
      final snap = await tx.get(entryRef);
      final old = snap.exists ? _toDouble(snap.data()?['quantity']) : 0.0;
      final next = math.max(0.0, old + delta);
      final applied = next - old;
      tx.set(
        entryRef,
        stockEntryFields(
          materialId: materialId,
          materialName: materialName,
          locationId: locationId,
          origin: origin,
          quantity: next,
          note: note,
        ),
        SetOptions(merge: true),
      );
      tx.set(
        movementRef,
        _movement(
          materialId: materialId,
          locationId: locationId,
          origin: origin,
          delta: applied,
          reason: reason,
          orderId: orderId,
        ),
      );
    });
  }

  /// Books the stock deduction of a completed order, then marks the order
  /// `stockApplied`. Idempotent: returns without booking if the order is
  /// already applied, and every movement uses a deterministic id, so a retry
  /// after a partial failure books only what is still missing. Throws if a
  /// booking or the final flag write fails (the caller must not complete the
  /// order then). Returns the plan so the caller can report shortfalls.
  Future<OrderDeductionPlan> deductForOrder(String orderId) async {
    final plan = await prepareOrderDeduction(
      fetchOrder: () => orderRepository.getOrderById(orderId),
      loadCatalog: () => adminRepository.getMaterialsWithIdsOrThrow(),
      loadEntries: () async => (await _stock.get()).docs
          .map((d) => StockEntry.fromMap(d.id, d.data()))
          .toList(),
      loadBooked: (ids) async {
        final booked = <String, double>{};
        for (final id in ids) {
          final doc = await _movements.doc(id).get();
          if (doc.exists) booked[id] = _toDouble(doc.data()?['delta']);
        }
        return booked;
      },
    );
    if (plan.alreadyApplied) return plan;
    for (final m in plan.movements) {
      await applyMovement(
        materialId: m.materialId,
        materialName: m.materialName,
        locationId: m.locationId,
        origin: m.origin,
        delta: m.delta,
        reason: 'order_deduction',
        orderId: orderId,
        movementId: m.id,
      );
    }
    final ok = await orderRepository.updateOrder(orderId, {
      'stockApplied': true,
    });
    if (!ok) throw StateError('stockApplied could not be saved');
    return plan;
  }

  /// Sets an absolute quantity and logs the difference as a correction.
  Future<void> setQuantity({
    required String materialId,
    required String materialName,
    required String locationId,
    required StockOrigin origin,
    required double quantity,
  }) {
    final entryRef = _stock.doc(
      StockEntry.buildId(materialId, locationId, origin),
    );
    final movementRef = _movements.doc();
    final target = math.max(0.0, quantity);
    return firestoreService.firestore.runTransaction((tx) async {
      final snap = await tx.get(entryRef);
      final old = snap.exists ? _toDouble(snap.data()?['quantity']) : 0.0;
      tx.set(entryRef, {
        'materialId': materialId,
        'materialName': materialName,
        'locationId': locationId,
        'origin': origin.name,
        'quantity': target,
      }, SetOptions(merge: true));
      tx.set(
        movementRef,
        _movement(
          materialId: materialId,
          locationId: locationId,
          origin: origin,
          delta: target - old,
          reason: 'correction',
        ),
      );
    });
  }

  /// Sets the note of an article on all its stock entries (an empty note
  /// removes it). Without any entry yet, the note goes onto a new entry with
  /// quantity 0 at [fallbackLocationId] ("Auftrag"). Notes are not logged as
  /// movements (no quantity change).
  Future<void> setArticleNote({
    required String materialId,
    required String materialName,
    required String note,
    required String fallbackLocationId,
  }) async {
    final trimmed = note.trim();
    final snap = await _stock.where('materialId', isEqualTo: materialId).get();
    final batch = firestoreService.firestore.batch();
    if (snap.docs.isEmpty) {
      if (trimmed.isEmpty) return;
      batch.set(
        _stock.doc(
          StockEntry.buildId(materialId, fallbackLocationId, StockOrigin.order),
        ),
        stockEntryFields(
          materialId: materialId,
          materialName: materialName,
          locationId: fallbackLocationId,
          origin: StockOrigin.order,
          quantity: 0,
          note: trimmed,
        ),
        SetOptions(merge: true),
      );
    } else {
      for (final d in snap.docs) {
        batch.update(d.reference, {
          'note': trimmed.isEmpty ? FieldValue.delete() : trimmed,
        });
      }
    }
    await batch.commit();
  }

  Stream<List<StockMovement>> watchMovements({String? materialId}) {
    Query<Map<String, dynamic>> query = _movements;
    if (materialId != null) {
      query = query.where('materialId', isEqualTo: materialId);
    }
    return query
        .orderBy('at', descending: true)
        .snapshots()
        .map(
          (snap) => parseTolerant(
            _docs(snap),
            StockMovement.fromMap,
            collection: 'stockMovements',
          ),
        );
  }

  Map<String, dynamic> _movement({
    required String materialId,
    required String locationId,
    required StockOrigin origin,
    required double delta,
    required String reason,
    String? orderId,
  }) {
    return StockMovement(
      id: '',
      materialId: materialId,
      locationId: locationId,
      origin: origin,
      delta: delta,
      reason: reason,
      orderId: orderId,
      byEmail: authService.email ?? '',
      at: DateTime.now(),
    ).toMap();
  }

  static double _toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0;
}

final stockRepository = StockRepository();
