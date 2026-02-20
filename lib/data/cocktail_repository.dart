import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/cocktail_data.dart';
import '../models/material_item.dart';
import '../models/order.dart' show SavedOrder;
import '../models/recipe.dart';
import '../services/auth_service.dart';

class CocktailRepository {
  CocktailRepository({
    this.assetPath = 'assets/data/cocktail_data.json',
    this.wertigkeitenPath = 'assets/data/wertigkeiten.json',
  });

  final String assetPath;
  final String wertigkeitenPath;
  CocktailData? _cached;
  bool _firebaseAvailable = false;

  /// Gibt true zurück wenn Firebase verwendet wird, false bei lokalem Fallback
  bool get isUsingFirebase => _firebaseAvailable;
  
  /// Datenquelle als String für UI-Anzeige
  String get dataSourceLabel => _firebaseAvailable ? 'Firebase' : 'Local JSON';

  FirebaseFirestore? _firestoreInstance;
  
  FirebaseFirestore get _firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  CollectionReference<Map<String, dynamic>> get _materialsCollection =>
      _firestore.collection('materials');

  CollectionReference<Map<String, dynamic>> get _recipesCollection =>
      _firestore.collection('recipes');

  CollectionReference<Map<String, dynamic>> get _fixedValuesCollection =>
      _firestore.collection('fixedValues');

  /// Initialize repository - seeds Firestore if empty
  Future<void> initialize() async {
    try {
      final materialsSnapshot = await _materialsCollection.limit(1).get();
      _firebaseAvailable = true;
      
      if (materialsSnapshot.docs.isEmpty) {
        await _seedFirestoreFromAssets();
      }
    } catch (e) {
      debugPrint('Firestore initialization failed, using local fallback: $e');
      _firebaseAvailable = false;
    }
  }

  /// Force reseed Firestore from local JSON (deletes existing data)
  Future<void> forceReseed() async {
    if (!_firebaseAvailable) return;
    
    // Delete all documents in collections
    await _deleteCollection(_materialsCollection);
    await _deleteCollection(_recipesCollection);
    await _deleteCollection(_fixedValuesCollection);
    
    // Reseed from assets
    await _seedFirestoreFromAssets();
    
    // Clear cache
    _cached = null;
  }

  Future<void> _deleteCollection(CollectionReference collection) async {
    final snapshot = await collection.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Seeds Firestore with data from local JSON assets
  Future<void> _seedFirestoreFromAssets() async {
    // Load cocktail data (includes materialListe, rezepte, fixedValues)
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    // Seed materials
    final materialList =
        decoded['materialListe'] as List<dynamic>? ?? <dynamic>[];
    final batch1 = _firestore.batch();
    for (final item in materialList) {
      final docRef = _materialsCollection.doc();
      batch1.set(docRef, _normalizeMaterialItem(item as Map<String, dynamic>));
    }
    await batch1.commit();

    // Seed recipes
    final recipeList = decoded['rezepte'] as List<dynamic>? ?? <dynamic>[];
    final batch2 = _firestore.batch();
    for (final item in recipeList) {
      final docRef = _recipesCollection.doc();
      batch2.set(docRef, _normalizeRecipe(item as Map<String, dynamic>));
    }
    await batch2.commit();

    // Seed fixed values from cocktail_data.json (or fallback to wertigkeiten.json)
    List<dynamic> fixedValuesList = decoded['fixedValues'] as List<dynamic>? ?? <dynamic>[];
    
    if (fixedValuesList.isEmpty) {
      // Fallback to wertigkeiten.json for backwards compatibility
      try {
        final wertigkeitenRaw = await rootBundle.loadString(wertigkeitenPath);
        final wertigkeitenDecoded =
            jsonDecode(wertigkeitenRaw) as Map<String, dynamic>;
        fixedValuesList =
            wertigkeitenDecoded['fixedValues'] as List<dynamic>? ??
            wertigkeitenDecoded['wertigkeiten'] as List<dynamic>? ??
            <dynamic>[];
      } catch (_) {
        // Ignore if file doesn't exist
      }
    }
    
    final batch3 = _firestore.batch();
    for (final item in fixedValuesList) {
      final docRef = _fixedValuesCollection.doc();
      batch3.set(docRef, _normalizeMaterialItem(item as Map<String, dynamic>));
    }
    await batch3.commit();
  }

  /// Normalize material item to English keys
  Map<String, dynamic> _normalizeMaterialItem(Map<String, dynamic> item) {
    return {
      'unit': item['unit'] ?? item['menge'] ?? '',
      'name': item['name'] ?? item['artikel'] ?? '',
      'price': (item['price'] ?? item['preis'] ?? 0).toDouble(),
      'currency': item['currency'] ?? item['waehrung'] ?? 'CHF',
      'note': item['note'] ?? item['bemerkung'] ?? '',
      'active': item['active'] ?? true,
      'visible': item['visible'] ?? true,
    };
  }

  /// Normalize recipe to English keys
  Map<String, dynamic> _normalizeRecipe(Map<String, dynamic> item) {
    return {
      'name': item['name'] ?? item['cocktail'] ?? '',
      'ingredients': item['ingredients'] ?? item['zutaten'] ?? <dynamic>[],
      'type': item['type'] ?? _inferType(item['name'] ?? item['cocktail'] ?? ''),
    };
  }

  String _inferType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.startsWith('shot')) return 'shot';
    return 'cocktail';
  }

  /// Load data - tries Firestore first, falls back to local JSON
  Future<CocktailData> load() async {
    if (_cached != null) {
      return _cached!;
    }

    // Use local fallback if Firebase is not available
    if (!_firebaseAvailable) {
      return _loadFromLocalAssets();
    }

    // Try Firestore
    try {
      final materialsSnapshot = await _materialsCollection.get();
      final recipesSnapshot = await _recipesCollection.get();
      final fixedValuesSnapshot = await _fixedValuesCollection.get();

      final materials = materialsSnapshot.docs
          .map((doc) => MaterialItem.fromJson(doc.data()))
          .toList();

      final recipes = recipesSnapshot.docs
          .map((doc) => Recipe.fromJson(doc.data()))
          .toList();

      final fixedValues = fixedValuesSnapshot.docs
          .map((doc) => MaterialItem.fromJson(doc.data()))
          .toList();

      _cached = CocktailData(
        materials: materials,
        recipes: recipes,
        fixedValues: fixedValues,
      );

      return _cached!;
    } catch (e) {
      debugPrint('Firestore load failed, using local fallback: $e');
      return _loadFromLocalAssets();
    }
  }

  /// Load data from local JSON assets
  Future<CocktailData> _loadFromLocalAssets() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final wertigkeitenRaw = await rootBundle.loadString(wertigkeitenPath);
    final wertigkeitenDecoded =
        jsonDecode(wertigkeitenRaw) as Map<String, dynamic>;

    _cached = CocktailData.fromJson({
      ...decoded,
      'fixedValues':
          wertigkeitenDecoded['fixedValues'] ??
          wertigkeitenDecoded['wertigkeiten'] ??
          const [],
    });
    return _cached!;
  }

  /// Clear cache to force reload
  void clearCache() {
    _cached = null;
  }

  /// Collection for saved orders
  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      _firestore.collection('orders');

  /// Save an order to Firestore
  /// Returns the order ID if successful, null if Firebase unavailable
  Future<String?> saveOrder({
    required String name,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double total,
    required String currency,
    int personCount = 0,
    String drinkerType = 'normal',
    String status = 'quote',
    List<String> cocktails = const [],
    List<String> shots = const [],
    String bar = '',
    int distanceKm = 0,
    double thekeCost = 0,
  }) async {
    if (!_firebaseAvailable) {
      debugPrint('Firebase not available, order not saved to cloud');
      return null;
    }

    try {
      final docRef = await _ordersCollection.add({
        'name': name,
        'date': date.toIso8601String(),
        'items': items,
        'total': total,
        'currency': currency,
        'personCount': personCount,
        'drinkerType': drinkerType,
        'status': status,
        'cocktails': cocktails,
        'shots': shots,
        'bar': bar,
        'distanceKm': distanceKm,
        'thekeCost': thekeCost,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': authService.email ?? authService.currentUser?.uid,
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Failed to save order: $e');
      return null;
    }
  }

  /// Update order status in Firestore
  Future<bool> updateOrderStatus(String orderId, String status) async {
    if (!_firebaseAvailable) return false;

    try {
      await _ordersCollection.doc(orderId).update({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to update order status: $e');
      return false;
    }
  }

  /// Update order with offer-related data in Firestore
  Future<bool> updateOrderOfferData({
    required String orderId,
    required String clientName,
    required String clientContact,
    required String eventTime,
    required List<String> eventTypes,
    required double discount,
    required String language,
  }) async {
    if (!_firebaseAvailable) return false;

    try {
      await _ordersCollection.doc(orderId).update({
        'offerClientName': clientName,
        'offerClientContact': clientContact,
        'offerEventTime': eventTime,
        'offerEventTypes': eventTypes,
        'offerDiscount': discount,
        'offerLanguage': language,
        'offerUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Failed to update order offer data: $e');
      return false;
    }
  }

  /// Fetch saved orders from Firestore, optionally filtered by [year].
  /// Returns an empty list if Firebase is unavailable.
  Future<List<SavedOrder>> getOrders({int? year}) async {
    if (!_firebaseAvailable) return [];

    try {
      final snapshot = await _ordersCollection
          .orderBy('createdAt', descending: true)
          .get();
      final orders = snapshot.docs
          .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
          .toList();
      if (year != null) {
        return orders.where((o) => o.year == year).toList();
      }
      return orders;
    } catch (e) {
      debugPrint('Failed to fetch orders: $e');
      return [];
    }
  }

  /// Watch orders as a real-time stream from Firestore.
  /// Returns an empty stream if Firebase is unavailable.
  Stream<List<SavedOrder>> watchOrders({int? year}) {
    if (!_firebaseAvailable) {
      return Stream.value([]);
    }

    return _ordersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
          .toList();
      if (year != null) {
        return orders.where((o) => o.year == year).toList();
      }
      return orders;
    }).handleError((e) {
      debugPrint('Failed to watch orders: $e');
      return <SavedOrder>[];
    });
  }

  /// Delete an order from Firestore (super admin only)
  Future<bool> deleteOrder(String orderId) async {
    if (!_firebaseAvailable) return false;

    // Only super admin can delete orders
    if (!authService.isSuperAdmin) {
      debugPrint('Delete order denied: not super admin');
      return false;
    }

    try {
      await _ordersCollection.doc(orderId).delete();
      return true;
    } catch (e) {
      debugPrint('Failed to delete order: $e');
      return false;
    }
  }

  /// Add a new material item to Firestore
  Future<bool> addMaterial({
    required String name,
    required String unit,
    required double price,
    required String currency,
    required String note,
    required bool isFixedValue,
    bool active = true,
    bool visible = true,
  }) async {
    if (!_firebaseAvailable) {
      debugPrint('Firebase not available, cannot add material');
      return false;
    }

    try {
      final collection = isFixedValue ? _fixedValuesCollection : _materialsCollection;
      await collection.add({
        'name': name,
        'unit': unit,
        'price': price,
        'currency': currency,
        'note': note,
        'active': active,
        'visible': visible,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': authService.email ?? authService.currentUser?.uid,
      });
      
      // Clear cache to reload data
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to add material: $e');
      return false;
    }
  }

  /// Add a new recipe to Firestore
  Future<bool> addRecipe({
    required String name,
    required List<String> ingredients,
  }) async {
    if (!_firebaseAvailable) {
      debugPrint('Firebase not available, cannot add recipe');
      return false;
    }

    try {
      final type = name.toLowerCase().contains('shot') ? 'shot' : 'cocktail';
      await _recipesCollection.add({
        'name': name,
        'ingredients': ingredients,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': authService.email ?? authService.currentUser?.uid,
      });
      
      // Clear cache to reload data
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to add recipe: $e');
      return false;
    }
  }

  // ============ Update Methods ============

  /// Update a material item in Firestore
  Future<bool> updateMaterial({
    required String docId,
    required String name,
    required String unit,
    required double price,
    required String currency,
    required String note,
    required bool isFixedValue,
    bool active = true,
    bool visible = true,
  }) async {
    if (!_firebaseAvailable) return false;

    try {
      final collection = isFixedValue ? _fixedValuesCollection : _materialsCollection;
      await collection.doc(docId).update({
        'name': name,
        'unit': unit,
        'price': price,
        'currency': currency,
        'note': note,
        'active': active,
        'visible': visible,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': authService.email ?? authService.currentUser?.uid,
      });
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to update material: $e');
      return false;
    }
  }

  /// Update a recipe in Firestore
  Future<bool> updateRecipe({
    required String docId,
    required String name,
    required List<String> ingredients,
  }) async {
    if (!_firebaseAvailable) return false;

    try {
      final type = name.toLowerCase().contains('shot') ? 'shot' : 'cocktail';
      await _recipesCollection.doc(docId).update({
        'name': name,
        'ingredients': ingredients,
        'type': type,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': authService.email ?? authService.currentUser?.uid,
      });
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to update recipe: $e');
      return false;
    }
  }

  // ============ Delete Methods ============

  /// Delete a material from Firestore
  Future<bool> deleteMaterial({
    required String docId,
    required bool isFixedValue,
  }) async {
    if (!_firebaseAvailable) return false;

    try {
      final collection = isFixedValue ? _fixedValuesCollection : _materialsCollection;
      await collection.doc(docId).delete();
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to delete material: $e');
      return false;
    }
  }

  /// Persist a new manual sort order for fixed-value (Verbrauch) items.
  /// [orderedDocIds] is the list of document IDs in the desired display order.
  Future<bool> updateFixedValueSortOrders(List<String> orderedDocIds) async {
    if (!_firebaseAvailable) return false;

    try {
      final batch = _firestore.batch();
      for (var i = 0; i < orderedDocIds.length; i++) {
        batch.update(_fixedValuesCollection.doc(orderedDocIds[i]), {
          'sortOrder': i,
        });
      }
      await batch.commit();
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to update sort orders: $e');
      return false;
    }
  }

  /// Delete a recipe from Firestore
  Future<bool> deleteRecipe({required String docId}) async {
    if (!_firebaseAvailable) return false;

    try {
      await _recipesCollection.doc(docId).delete();
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to delete recipe: $e');
      return false;
    }
  }

  // ============ Get with Document IDs ============

  /// Get materials with their Firestore document IDs
  Future<List<({String id, MaterialItem item})>> getMaterialsWithIds({
    required bool isFixedValue,
  }) async {
    if (!_firebaseAvailable) return [];

    try {
      final collection = isFixedValue ? _fixedValuesCollection : _materialsCollection;
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) => (
        id: doc.id,
        item: MaterialItem.fromJson(doc.data()),
      )).toList();
    } catch (e) {
      debugPrint('Failed to get materials with IDs: $e');
      return [];
    }
  }

  /// Get recipes with their Firestore document IDs
  Future<List<({String id, Recipe item})>> getRecipesWithIds() async {
    if (!_firebaseAvailable) return [];

    try {
      final snapshot = await _recipesCollection.get();
      return snapshot.docs.map((doc) => (
        id: doc.id,
        item: Recipe.fromJson(doc.data()),
      )).toList();
    } catch (e) {
      debugPrint('Failed to get recipes with IDs: $e');
      return [];
    }
  }
}

final CocktailRepository cocktailRepository = CocktailRepository();
