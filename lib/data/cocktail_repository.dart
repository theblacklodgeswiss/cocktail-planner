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
  bool _useLocalFallback = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

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
      
      if (materialsSnapshot.docs.isEmpty) {
        await _seedFirestoreFromAssets();
      }
    } catch (e) {
      debugPrint('Firestore initialization failed, using local fallback: $e');
      _useLocalFallback = true;
    }
  }

  /// Seeds Firestore with data from local JSON assets
  Future<void> _seedFirestoreFromAssets() async {
    // Load cocktail data
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    // Load wertigkeiten
    final wertigkeitenRaw = await rootBundle.loadString(wertigkeitenPath);
    final wertigkeitenDecoded =
        jsonDecode(wertigkeitenRaw) as Map<String, dynamic>;

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

    // Seed fixed values
    final fixedValuesList =
        wertigkeitenDecoded['fixedValues'] as List<dynamic>? ??
        wertigkeitenDecoded['wertigkeiten'] as List<dynamic>? ??
        <dynamic>[];
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

    // Use local fallback if Firebase init failed
    if (_useLocalFallback) {
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
}

final CocktailRepository cocktailRepository = CocktailRepository();
