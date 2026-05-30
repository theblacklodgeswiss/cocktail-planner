import 'package:flutter/foundation.dart';

import '../models/cocktail_data.dart';
import '../models/material_item.dart';
import '../models/recipe.dart';
import 'admin_repository.dart';
import 'firestore_service.dart';

/// Repository for loading cocktail data from Firestore.
class CocktailRepository {
  CocktailRepository() {
    adminRepository.onCacheCleared = clearCache;
  }

  CocktailData? _cached;

  /// Initialize repository.
  Future<void> initialize() async {
    await firestoreService.initialize();
  }

  /// Load data from Firestore.
  Future<CocktailData> load() async {
    if (_cached != null) return _cached!;

    try {
      final results = await Future.wait([
        firestoreService.materialsCollection.get(),
        firestoreService.recipesCollection.get(),
        firestoreService.fixedValuesCollection.get(),
      ]);
      final materialsSnapshot = results[0];
      final recipesSnapshot = results[1];
      final fixedValuesSnapshot = results[2];

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
      debugPrint('Firestore load failed: $e');
      rethrow;
    }
  }

  /// Clear cache to force reload.
  void clearCache() {
    _cached = null;
  }
}

final CocktailRepository cocktailRepository = CocktailRepository();
