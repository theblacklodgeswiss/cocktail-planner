import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_list/models/cocktail_data.dart';
import 'package:shopping_list/models/material_item.dart';
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
}
