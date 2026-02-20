import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/cocktail_data.dart';
import '../models/material_item.dart';
import '../models/recipe.dart';
import 'admin_repository.dart';
import 'firestore_service.dart';

/// Repository for loading cocktail data.
/// Delegates orders to [orderRepository] and CRUD to [adminRepository].
class CocktailRepository {
  CocktailRepository({
    this.assetPath = 'assets/data/cocktail_data.json',
    this.wertigkeitenPath = 'assets/data/wertigkeiten.json',
  }) {
    // Wire up cache clearing from admin repository
    adminRepository.onCacheCleared = clearCache;
  }

  final String assetPath;
  final String wertigkeitenPath;
  CocktailData? _cached;

  /// Whether Firebase is being used.
  bool get isUsingFirebase => firestoreService.isAvailable;

  /// Data source label for UI display.
  String get dataSourceLabel => firestoreService.dataSourceLabel;

  /// Initialize repository - seeds Firestore if empty.
  Future<void> initialize() async {
    final available = await firestoreService.initialize();
    if (available) {
      final snapshot =
          await firestoreService.materialsCollection.limit(1).get();
      if (snapshot.docs.isEmpty) {
        await _seedFirestoreFromAssets();
      }
    }
  }

  /// Force reseed Firestore from local JSON.
  Future<void> forceReseed() async {
    if (!firestoreService.isAvailable) return;

    await firestoreService.deleteCollection(firestoreService.materialsCollection);
    await firestoreService.deleteCollection(firestoreService.recipesCollection);
    await firestoreService.deleteCollection(firestoreService.fixedValuesCollection);

    await _seedFirestoreFromAssets();
    clearCache();
  }

  /// Load data - tries Firestore first, falls back to local JSON.
  Future<CocktailData> load() async {
    if (_cached != null) return _cached!;

    if (!firestoreService.isAvailable) {
      return _loadFromLocalAssets();
    }

    try {
      final materialsSnapshot =
          await firestoreService.materialsCollection.get();
      final recipesSnapshot = await firestoreService.recipesCollection.get();
      final fixedValuesSnapshot =
          await firestoreService.fixedValuesCollection.get();

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

  /// Load data from local JSON assets.
  Future<CocktailData> _loadFromLocalAssets() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final wertigkeitenRaw = await rootBundle.loadString(wertigkeitenPath);
    final wertigkeitenDecoded =
        jsonDecode(wertigkeitenRaw) as Map<String, dynamic>;

    _cached = CocktailData.fromJson({
      ...decoded,
      'fixedValues': wertigkeitenDecoded['fixedValues'] ??
          wertigkeitenDecoded['wertigkeiten'] ??
          const [],
    });
    return _cached!;
  }

  /// Clear cache to force reload.
  void clearCache() {
    _cached = null;
  }

  /// Seeds Firestore with data from local JSON assets.
  Future<void> _seedFirestoreFromAssets() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    // Seed materials
    final materialList =
        decoded['materialListe'] as List<dynamic>? ?? <dynamic>[];
    final batch1 = firestoreService.firestore.batch();
    for (final item in materialList) {
      final docRef = firestoreService.materialsCollection.doc();
      batch1.set(docRef, _normalizeMaterialItem(item as Map<String, dynamic>));
    }
    await batch1.commit();

    // Seed recipes
    final recipeList = decoded['rezepte'] as List<dynamic>? ?? <dynamic>[];
    final batch2 = firestoreService.firestore.batch();
    for (final item in recipeList) {
      final docRef = firestoreService.recipesCollection.doc();
      batch2.set(docRef, _normalizeRecipe(item as Map<String, dynamic>));
    }
    await batch2.commit();

    // Seed fixed values
    List<dynamic> fixedValuesList =
        decoded['fixedValues'] as List<dynamic>? ?? <dynamic>[];

    if (fixedValuesList.isEmpty) {
      try {
        final wertigkeitenRaw = await rootBundle.loadString(wertigkeitenPath);
        final wertigkeitenDecoded =
            jsonDecode(wertigkeitenRaw) as Map<String, dynamic>;
        fixedValuesList = wertigkeitenDecoded['fixedValues'] as List<dynamic>? ??
            wertigkeitenDecoded['wertigkeiten'] as List<dynamic>? ??
            <dynamic>[];
      } catch (_) {}
    }

    final batch3 = firestoreService.firestore.batch();
    for (final item in fixedValuesList) {
      final docRef = firestoreService.fixedValuesCollection.doc();
      batch3.set(docRef, _normalizeMaterialItem(item as Map<String, dynamic>));
    }
    await batch3.commit();
  }

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

  Map<String, dynamic> _normalizeRecipe(Map<String, dynamic> item) {
    return {
      'name': item['name'] ?? item['cocktail'] ?? '',
      'ingredients': item['ingredients'] ?? item['zutaten'] ?? <dynamic>[],
      'type':
          item['type'] ?? _inferType(item['name'] ?? item['cocktail'] ?? ''),
    };
  }

  String _inferType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.startsWith('shot')) return 'shot';
    return 'cocktail';
  }
}

final CocktailRepository cocktailRepository = CocktailRepository();
