import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/material_item.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import 'firestore_service.dart';

/// Callback to clear the data cache after modifications.
typedef ClearCacheCallback = void Function();

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
          .map((doc) => (
                id: doc.id,
                item: MaterialItem.fromJson(doc.data()),
              ))
          .toList();
    } catch (e) {
      debugPrint('Failed to get materials with IDs: $e');
      return [];
    }
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
          .map((doc) => (
                id: doc.id,
                item: Recipe.fromJson(doc.data()),
              ))
          .toList();
    } catch (e) {
      debugPrint('Failed to get recipes with IDs: $e');
      return [];
    }
  }
}

final adminRepository = AdminRepository();
