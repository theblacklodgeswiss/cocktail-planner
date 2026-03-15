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
