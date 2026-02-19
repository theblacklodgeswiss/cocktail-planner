import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/cocktail_data.dart';
import '../models/material_item.dart';
import '../models/recipe.dart';

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
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Failed to save order: $e');
      return null;
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
      });
      
      // Clear cache to reload data
      _cached = null;
      return true;
    } catch (e) {
      debugPrint('Failed to add recipe: $e');
      return false;
    }
  }
}

final CocktailRepository cocktailRepository = CocktailRepository();
