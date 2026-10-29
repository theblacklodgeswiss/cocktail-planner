import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Shared Firestore service for accessing collections.
class FirestoreService {
  FirebaseFirestore? _firestoreInstance;
  bool _available = false;
  bool _checkPending = false;
  Future<bool>? _backgroundCheck;

  /// Whether Firestore is available. While the startup connection test started
  /// via [startBackgroundCheck] is still running the state is "not yet known"
  /// and is treated as available (optimistic); once the test completes it
  /// reflects the real result, so the local fallback semantics are unchanged.
  bool get isAvailable => _available || _checkPending;

  /// Completes with the connection test result, starting the (single) test if
  /// nobody has yet. Use instead of [initialize] where the screen only needs
  /// the flag to be known, so no extra test query is issued.
  Future<bool> get availabilityKnown => startBackgroundCheck();

  /// Starts the connection test without blocking the caller. Idempotent.
  Future<bool> startBackgroundCheck() {
    return _backgroundCheck ??= () {
      _checkPending = true;
      return initialize();
    }();
  }

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

  CollectionReference<Map<String, dynamic>> get shareLinksCollection =>
      firestore.collection('shareLinks');

  CollectionReference<Map<String, dynamic>> get storageLocationsCollection =>
      firestore.collection('storageLocations');

  CollectionReference<Map<String, dynamic>> get stockEntriesCollection =>
      firestore.collection('stockEntries');

  CollectionReference<Map<String, dynamic>> get stockMovementsCollection =>
      firestore.collection('stockMovements');

  /// Initialize Firestore connection.
  Future<bool> initialize() async {
    try {
      debugPrint('🔧 Testing Firestore connection with materials collection...');
      final testDoc = await materialsCollection.limit(1).get();
      debugPrint('✅ Firestore available - fetched ${testDoc.docs.length} test docs');
      _available = true;
      _checkPending = false;
      return true;
    } catch (e) {
      debugPrint('❌ Firestore initialization failed: $e');
      debugPrint('📋 Error type: ${e.runtimeType}');
      _available = false;
      _checkPending = false;
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
