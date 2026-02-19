import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_list/models/cocktail_data.dart';
import 'package:shopping_list/models/material_item.dart';
import 'package:shopping_list/models/offer.dart';
import 'package:shopping_list/models/recipe.dart';

void main() {
  test('parses recipe from json', () {
    final recipe = Recipe.fromJson({
      'name': 'Mojito - Classic',
      'ingredients': ['Limetten (54 Stk.)', 'Minze'],
    });

    expect(recipe.name, 'Mojito - Classic');
    expect(recipe.id, 'mojito_classic');
    expect(recipe.ingredients, ['Limetten (54 Stk.)', 'Minze']);
  });

  test('parses cocktail data from json', () {
    final data = CocktailData.fromJson({
      'materials': [
        {
          'unit': 'Stk',
          'name': 'Limetten (54 Stk.)',
          'price': 14.0,
          'currency': 'CHF',
          'note': 'Prodega',
        }
      ],
      'recipes': [
        {
          'name': 'Mojito - Classic',
          'ingredients': ['Limetten (54 Stk.)']
        }
      ]
    });

    expect(data.materials.length, 1);
    expect(data.materials.first, isA<MaterialItem>());
    expect(data.recipes.length, 1);
    expect(data.recipes.first.ingredients.first, 'Limetten (54 Stk.)');
  });

  group('Mojito - Mango Zutaten', () {
    late Map<String, dynamic> jsonData;
    late List<String> materialNames;
    late Map<String, dynamic> mangoMojitoRecipe;

    setUpAll(() {
      final file = File('assets/data/cocktail_data.json');
      final content = file.readAsStringSync();
      jsonData = json.decode(content) as Map<String, dynamic>;
      
      final materialListe = jsonData['materialListe'] as List<dynamic>;
      materialNames = materialListe
          .map((m) => (m as Map<String, dynamic>)['artikel'] as String)
          .toList();
      
      final rezepte = jsonData['rezepte'] as List<dynamic>;
      mangoMojitoRecipe = rezepte.firstWhere(
        (r) => (r as Map<String, dynamic>)['name'] == 'Mojito - Mango',
      ) as Map<String, dynamic>;
    });

    test('Mojito - Mango Rezept existiert', () {
      expect(mangoMojitoRecipe['name'], 'Mojito - Mango');
    });

    test('alle Zutaten vom Mango Mojito sind in der Materialliste', () {
      final zutaten = (mangoMojitoRecipe['zutaten'] as List<dynamic>)
          .cast<String>();
      
      final missingIngredients = <String>[];
      
      for (final zutat in zutaten) {
        if (!materialNames.contains(zutat)) {
          missingIngredients.add(zutat);
        }
      }
      
      expect(
        missingIngredients,
        isEmpty,
        reason: 'Fehlende Zutaten in materialListe: $missingIngredients',
      );
    });

    test('Mangostücke (tiefgefroren) ist in der Materialliste', () {
      expect(materialNames, contains('Mangostücke (tiefgefroren)'));
    });

    test('Rohrzucker ist in der Materialliste', () {
      expect(materialNames, contains('Rohrzucker'));
    });

    test('Minze ist in der Materialliste', () {
      expect(materialNames, contains('Minze'));
    });

    test('Weisser Rum (Bacardi) ist in der Materialliste', () {
      expect(materialNames, contains('Weisser Rum (Bacardi)'));
    });

    test('Ginger Ale (Kaufland) ist in der Materialliste', () {
      expect(materialNames, contains('Ginger Ale (Kaufland)'));
    });
  });

  group('OfferData', () {
    final offer = OfferData(
      orderName: 'Hochzeit Meyer',
      eventDate: DateTime(2026, 9, 12),
      eventTime: '17:30',
      currency: 'EUR',
      guestCount: 250,
      editorName: 'Mario Kantharoobarajah',
      clientName: 'Virusan Sinnathurai',
      clientContact: '+41 78 682 46 27',
      eventTypes: {EventType.wedding},
      cocktails: ['Mojito', 'Mango Mojito'],
      shots: [],
      barDescription: '',
      barServiceCost: 1600,
      distanceKm: 150,
      travelCostPerKm: 0.70,
      barCost: 100,
      discount: 0,
      additionalInfo: OfferData.defaultAdditionalInfoDe,
      language: 'de',
    );

    test('calculates travel cost total (return trip)', () {
      expect(offer.travelCostTotal, closeTo(210.0, 0.001));
    });

    test('calculates grand total', () {
      expect(offer.grandTotal, closeTo(1910.0, 0.001));
    });

    test('default additional info DE is not empty', () {
      expect(OfferData.defaultAdditionalInfoDe, isNotEmpty);
    });

    test('default additional info EN is not empty', () {
      expect(OfferData.defaultAdditionalInfoEn, isNotEmpty);
    });
  });
}
