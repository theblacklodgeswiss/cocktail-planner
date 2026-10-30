import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/material_item.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import 'firestore_service.dart';

/// Callback to clear the data cache after modifications.
typedef ClearCacheCallback = void Function();

/// Readable catalog materials and the number of skipped documents.
typedef MaterialCatalog = ({
  List<({String id, MaterialItem item})> items,
  int skipped,
});

/// Parses each material document on its own: a malformed one is skipped and
/// logged instead of failing the whole catalog.
MaterialCatalog parseMaterialCatalog(
  Iterable<({String id, Map<String, dynamic> data})> docs,
) {
  final items = <({String id, MaterialItem item})>[];
  var skipped = 0;
  for (final d in docs) {
    try {
      items.add((id: d.id, item: MaterialItem.fromJson(d.data)));
    } catch (e) {
      skipped++;
      debugPrint('Skipping malformed materials/${d.id}: $e');
    }
  }
  return (items: items, skipped: skipped);
}

/// Repository for admin operations (materials/recipes CRUD).
class AdminRepository {
  ClearCacheCallback? onCacheCleared;

  void _clearCache() => onCacheCleared?.call();

  // ============ Materials ============

  /// Add a new material item.
  Future<bool> addMaterial({
    required String name,
    required String unit,
    required double price,
    required String currency,
    required String note,
    required bool isFixedValue,
    bool active = true,
    bool visible = true,
    String? category,
  }) async {
    if (!firestoreService.isAvailable) {
      debugPrint('Firebase not available, cannot add material');
      return false;
    }

    try {
      final collection = isFixedValue
          ? firestoreService.fixedValuesCollection
          : firestoreService.materialsCollection;
      await collection.add({
        'name': name,
        'unit': unit,
        'price': price,
        'currency': currency,
        'note': note,
        'active': active,
        'visible': visible,
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': authService.email ?? authService.currentUser?.uid,
      });

      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to add material: $e');
      return false;
    }
  }

  /// Update a material item.
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
    String? category,
  }) async {
    if (!firestoreService.isAvailable) return false;

    try {
      final collection = isFixedValue
          ? firestoreService.fixedValuesCollection
          : firestoreService.materialsCollection;
      await collection.doc(docId).update({
        'name': name,
        'unit': unit,
        'price': price,
        'currency': currency,
        'note': note,
        'active': active,
        'visible': visible,
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': authService.email ?? authService.currentUser?.uid,
      });
      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to update material: $e');
      return false;
    }
  }

  /// Delete a material.
  Future<bool> deleteMaterial({
    required String docId,
    required bool isFixedValue,
  }) async {
    if (!firestoreService.isAvailable) return false;

    try {
      final collection = isFixedValue
          ? firestoreService.fixedValuesCollection
          : firestoreService.materialsCollection;
      await collection.doc(docId).delete();
      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to delete material: $e');
      return false;
    }
  }

  /// Get materials with their Firestore document IDs.
  Future<List<({String id, MaterialItem item})>> getMaterialsWithIds({
    required bool isFixedValue,
  }) async {
    if (!firestoreService.isAvailable) return [];

    try {
      final collection = isFixedValue
          ? firestoreService.fixedValuesCollection
          : firestoreService.materialsCollection;
      final snapshot = await collection.get();
      return snapshot.docs
          .map((doc) => (id: doc.id, item: MaterialItem.fromJson(doc.data())))
          .toList();
    } catch (e) {
      debugPrint('Failed to get materials with IDs: $e');
      return [];
    }
  }

  /// Like [getMaterialsWithIds] for the catalog, but throws instead of
  /// returning an empty list when Firestore is unavailable or the query
  /// fails. Malformed documents are skipped (see [getMaterialCatalogOrThrow]).
  Future<List<({String id, MaterialItem item})>>
  getMaterialsWithIdsOrThrow() async =>
      (await getMaterialCatalogOrThrow()).items;

  /// The material catalog with the number of documents that could not be
  /// read. Throws only for query-level failures (unavailable, permission,
  /// offline); one malformed document never hides the others.
  Future<MaterialCatalog> getMaterialCatalogOrThrow() async {
    if (!firestoreService.isAvailable) {
      throw StateError('Firestore not available');
    }
    // Ingredients plus the consumables (straws, cups, ... = fixed values of
    // the category 'purchase'); staff, services and equipment stay out. The
    // ids are Firestore auto-ids, so they do not collide.
    final snapshots = await Future.wait([
      firestoreService.materialsCollection.get(),
      firestoreService.fixedValuesCollection.get(),
    ]);
    return parseMaterialCatalog([
      for (final doc in snapshots[0].docs) (id: doc.id, data: doc.data()),
      for (final doc in snapshots[1].docs)
        if (doc.data()['category'] == 'purchase')
          (id: doc.id, data: doc.data()),
    ]);
  }

  /// Update sort order for fixed values.
  Future<bool> updateFixedValueSortOrders(List<String> orderedDocIds) async {
    if (!firestoreService.isAvailable) return false;

    try {
      final batch = firestoreService.firestore.batch();
      for (var i = 0; i < orderedDocIds.length; i++) {
        batch.update(
          firestoreService.fixedValuesCollection.doc(orderedDocIds[i]),
          {'sortOrder': i},
        );
      }
      await batch.commit();
      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to update sort orders: $e');
      return false;
    }
  }

  // ============ Recipes ============

  /// Add a new recipe.
  Future<bool> addRecipe({
    required String name,
    required List<String> ingredients,
  }) async {
    if (!firestoreService.isAvailable) {
      debugPrint('Firebase not available, cannot add recipe');
      return false;
    }

    try {
      final type = name.toLowerCase().contains('shot') ? 'shot' : 'cocktail';
      await firestoreService.recipesCollection.add({
        'name': name,
        'ingredients': ingredients,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': authService.email ?? authService.currentUser?.uid,
      });

      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to add recipe: $e');
      return false;
    }
  }

  /// Update a recipe.
  Future<bool> updateRecipe({
    required String docId,
    required String name,
    required List<String> ingredients,
  }) async {
    if (!firestoreService.isAvailable) return false;

    try {
      final type = name.toLowerCase().contains('shot') ? 'shot' : 'cocktail';
      await firestoreService.recipesCollection.doc(docId).update({
        'name': name,
        'ingredients': ingredients,
        'type': type,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': authService.email ?? authService.currentUser?.uid,
      });
      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to update recipe: $e');
      return false;
    }
  }

  /// Save AI-generated ingredient amounts to a recipe.
  Future<bool> updateRecipeAmounts({
    required String docId,
    required Map<String, String> amounts,
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      await firestoreService.recipesCollection.doc(docId).update({
        'ingredientAmounts': amounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to update recipe amounts: $e');
      return false;
    }
  }

  /// Delete a recipe.
  Future<bool> deleteRecipe({required String docId}) async {
    if (!firestoreService.isAvailable) return false;

    try {
      await firestoreService.recipesCollection.doc(docId).delete();
      _clearCache();
      return true;
    } catch (e) {
      debugPrint('Failed to delete recipe: $e');
      return false;
    }
  }

  /// Get recipes with their Firestore document IDs.
  Future<List<({String id, Recipe item})>> getRecipesWithIds() async {
    if (!firestoreService.isAvailable) return [];

    try {
      final snapshot = await firestoreService.recipesCollection.get();
      return snapshot.docs
          .map((doc) => (id: doc.id, item: Recipe.fromJson(doc.data())))
          .toList();
    } catch (e) {
      debugPrint('Failed to get recipes with IDs: $e');
      return [];
    }
  }
}

final adminRepository = AdminRepository();
