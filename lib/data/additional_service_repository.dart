import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/additional_service.dart';
import 'firestore_service.dart';

/// Repository for the admin-managed `additionalServices` catalog CRUD
/// operations. Mirrors `EmployeeRepository`'s shape (same method names and
/// error-handling style) - see `lib/data/employee_repository.dart`.
///
/// Unlike `employees`/`employeeAccess`, there is no mirror collection here:
/// nothing else needs to look up a service by anything other than its own
/// document ID, so a single-document array field (`variants`) is enough.
class AdditionalServiceRepository {
  CollectionReference<Map<String, dynamic>> get _collection =>
      firestoreService.firestore.collection('additionalServices');

  Stream<List<AdditionalService>> watchServices() {
    if (!firestoreService.isAvailable) return Stream.value([]);
    // Sort locally to handle docs without sortOrder field.
    return _collection
        .snapshots()
        .map((s) {
          final services = s.docs
              .map((d) => AdditionalService.fromFirestore(d.id, d.data()))
              .toList();
          services.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return services;
        })
        .handleError((e) {
      debugPrint('Failed to watch additional services: $e');
      return <AdditionalService>[];
    });
  }

  Future<int> _getNextSortOrder() async {
    try {
      final snapshot = await _collection.get();
      if (snapshot.docs.isEmpty) return 0;
      int maxOrder = 0;
      for (final doc in snapshot.docs) {
        final order = doc.data()['sortOrder'] as int? ?? 0;
        if (order > maxOrder) maxOrder = order;
      }
      return maxOrder + 1;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> addService({
    required String name,
    String? imageUrl,
    List<ServiceVariant> variants = const [],
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final sortOrder = await _getNextSortOrder();
      final data = <String, dynamic>{
        'name': name,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'variants': variants.map((v) => v.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      await _collection.add(data);
      return true;
    } catch (e) {
      debugPrint('Failed to add additional service: $e');
      return false;
    }
  }

  Future<bool> updateService({
    required String id,
    required String name,
    String? imageUrl,
    List<ServiceVariant> variants = const [],
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final data = <String, dynamic>{
        'name': name,
        'variants': variants.map((v) => v.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      if (imageUrl != null && imageUrl.isNotEmpty) {
        data['imageUrl'] = imageUrl;
      } else {
        data['imageUrl'] = FieldValue.delete();
      }
      await _collection.doc(id).update(data);
      return true;
    } catch (e) {
      debugPrint('Failed to update additional service: $e');
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    if (!firestoreService.isAvailable) return false;
    try {
      await _collection.doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Failed to delete additional service: $e');
      return false;
    }
  }

  /// Reorder services by updating their sortOrder values.
  Future<bool> reorderServices(List<AdditionalService> services) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final batch = firestoreService.firestore.batch();
      for (var i = 0; i < services.length; i++) {
        final ref = _collection.doc(services[i].id);
        batch.update(ref, {'sortOrder': i});
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to reorder additional services: $e');
      return false;
    }
  }
}

final additionalServiceRepository = AdditionalServiceRepository();
