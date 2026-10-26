import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'firestore_service.dart';

/// Returns the location owned by [email] (case-insensitive), or null.
StorageLocation? pickOwn(List<StorageLocation> locations, String email) {
  final wanted = email.toLowerCase();
  for (final location in locations) {
    if (location.ownerEmail?.toLowerCase() == wanted) return location;
  }
  return null;
}

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
          (snap) => snap.docs
              .map((d) => StorageLocation.fromMap(d.id, d.data()))
              .toList(),
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

  Future<void> renameLocation(String id, String name) {
    return _locations.doc(id).update({'name': name});
  }

  Stream<List<StockEntry>> watchStock() {
    return _stock.snapshots().map(
      (snap) =>
          snap.docs.map((d) => StockEntry.fromMap(d.id, d.data())).toList(),
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
  }) {
    final entryRef = _stock.doc(
      StockEntry.buildId(materialId, locationId, origin),
    );
    final movementRef = _movements.doc();
    return firestoreService.firestore.runTransaction((tx) async {
      final snap = await tx.get(entryRef);
      final old = snap.exists ? _toDouble(snap.data()?['quantity']) : 0.0;
      final next = math.max(0.0, old + delta);
      final applied = next - old;
      tx.set(entryRef, {
        'materialId': materialId,
        'materialName': materialName,
        'locationId': locationId,
        'origin': origin.name,
        'quantity': next,
      }, SetOptions(merge: true));
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

  Stream<List<StockMovement>> watchMovements({String? materialId}) {
    Query<Map<String, dynamic>> query = _movements;
    if (materialId != null) {
      query = query.where('materialId', isEqualTo: materialId);
    }
    return query
        .orderBy('at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => StockMovement.fromMap(d.id, d.data()))
              .toList(),
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
