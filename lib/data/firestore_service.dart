import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Shared Firestore service for accessing collections.
class FirestoreService {
  FirebaseFirestore? _firestoreInstance;
  bool _available = false;

  /// Whether Firestore is available.
  bool get isAvailable => _available;

  /// Data source label for UI display.
  String get dataSourceLabel => _available ? 'Firebase' : 'Local JSON';

  FirebaseFirestore get firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  CollectionReference<Map<String, dynamic>> get materialsCollection =>
      firestore.collection('materials');

  CollectionReference<Map<String, dynamic>> get recipesCollection =>
      firestore.collection('recipes');

  CollectionReference<Map<String, dynamic>> get fixedValuesCollection =>
      firestore.collection('fixedValues');

  CollectionReference<Map<String, dynamic>> get ordersCollection =>
      firestore.collection('orders');

  CollectionReference<Map<String, dynamic>> get employeesCollection =>
      firestore.collection('employees');
      
  CollectionReference<Map<String, dynamic>> get settingsCollection =>
      firestore.collection('settings');

  /// Initialize Firestore connection.
  Future<bool> initialize() async {
    try {
      await materialsCollection.limit(1).get();
      _available = true;
      return true;
    } catch (e) {
      debugPrint('Firestore initialization failed: $e');
      _available = false;
      return false;
    }
  }

  /// Delete all documents in a collection.
  Future<void> deleteCollection(CollectionReference collection) async {
    final snapshot = await collection.get();
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final firestoreService = FirestoreService();
