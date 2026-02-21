import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests to verify that all recipe ingredients match items in materialListe.
/// This prevents typos like "O-Saft" vs "Orangen Saft (Kaufland)".
void main() {
  late Map<String, dynamic> cocktailData;
  late Set<String> materialNames;
  late List<Map<String, dynamic>> recipes;

  setUpAll(() {
    final file = File('assets/data/cocktail_data.json');
    final content = file.readAsStringSync();
    cocktailData = jsonDecode(content) as Map<String, dynamic>;

    // Build set of all material names from materialListe
    final materials = cocktailData['materialListe'] as List<dynamic>;
    materialNames = materials
        .map((m) => (m as Map<String, dynamic>)['artikel'] as String)
        .toSet();

    recipes = (cocktailData['rezepte'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  });

  group('Ingredient Matching', () {
    test('all recipe ingredients exist in materialListe', () {
      final missingIngredients = <String, List<String>>{};

      for (final recipe in recipes) {
        final recipeName = recipe['name'] as String;
        final ingredients = (recipe['zutaten'] as List<dynamic>).cast<String>();

        for (final ingredient in ingredients) {
          if (!materialNames.contains(ingredient)) {
            missingIngredients.putIfAbsent(recipeName, () => []).add(ingredient);
          }
        }
      }

      if (missingIngredients.isNotEmpty) {
        final message = StringBuffer('Missing ingredients:\n');
        for (final entry in missingIngredients.entries) {
          message.writeln('  ${entry.key}:');
          for (final ingredient in entry.value) {
            message.writeln('    - "$ingredient"');
          }
        }
        fail(message.toString());
      }

      expect(missingIngredients, isEmpty);
    });

    test('no duplicate material keys (name|unit)', () {
      // Materials can have the same name but different units (e.g., "Wasser 24er Pack" vs "Wasser 6x1.5L")
      // So we check for duplicate keys (name|unit) instead of just names
      final materials = cocktailData['materialListe'] as List<dynamic>;
      final seen = <String>{};
      final duplicates = <String>[];

      for (final m in materials) {
        final mat = m as Map<String, dynamic>;
        final name = mat['artikel'] as String;
        final unit = mat['menge'] as String;
        final key = '$name|$unit';
        if (seen.contains(key)) {
          duplicates.add(key);
        }
        seen.add(key);
      }

      expect(duplicates, isEmpty,
          reason: 'Found duplicate material keys: $duplicates');
    });

    test('all ingredients have correct naming convention', () {
      // Common naming issues to check
      final badPatterns = <String, String>{
        'O-Saft': 'Should be "Orangen Saft (Kaufland)"',
        'Orangensaft': 'Should be "Orangen Saft (Kaufland)"',
        'Maracujasaft': 'Should be "Maracuja Saft (Kaufland)"',
        'Grenadinesirup': 'Should be "Grenadine Sirup (Monin)"',
        'Kokossirup': 'Should be "Kokos Sirup (Monin)"',
      };

      final violations = <String, List<String>>{};

      for (final recipe in recipes) {
        final recipeName = recipe['name'] as String;
        final ingredients = (recipe['zutaten'] as List<dynamic>).cast<String>();

        for (final ingredient in ingredients) {
          if (badPatterns.containsKey(ingredient)) {
            violations.putIfAbsent(recipeName, () => []).add(
                  '"$ingredient" -> ${badPatterns[ingredient]}',
                );
          }
        }
      }

      if (violations.isNotEmpty) {
        final message = StringBuffer('Naming convention violations:\n');
        for (final entry in violations.entries) {
          message.writeln('  ${entry.key}:');
          for (final violation in entry.value) {
            message.writeln('    - $violation');
          }
        }
        fail(message.toString());
      }

      expect(violations, isEmpty);
    });

    test('each recipe has at least one ingredient', () {
      final emptyRecipes = <String>[];

      for (final recipe in recipes) {
        final recipeName = recipe['name'] as String;
        final ingredients = (recipe['zutaten'] as List<dynamic>).cast<String>();

        if (ingredients.isEmpty) {
          emptyRecipes.add(recipeName);
        }
      }

      expect(emptyRecipes, isEmpty,
          reason: 'Recipes without ingredients: $emptyRecipes');
    });

    test('recipe count matches expected', () {
      expect(recipes.length, 25, reason: 'Expected 25 recipes');
    });

    test('material list has reasonable count', () {
      final materials = cocktailData['materialListe'] as List<dynamic>;
      // Just ensure we have a reasonable number of materials (70-90)
      expect(materials.length, greaterThanOrEqualTo(70),
          reason: 'Expected at least 70 materials');
      expect(materials.length, lessThanOrEqualTo(100),
          reason: 'Expected at most 100 materials');
    });
  });
}
