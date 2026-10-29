import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/recipe.dart';
import 'package:cocktail_planer/screens/admin/material_logic.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialRecord m(
  String id,
  String name, {
  int? order,
  bool visible = true,
  String note = '',
}) => (
  id: id,
  item: MaterialItem(
    unit: '',
    name: name,
    price: 0,
    currency: 'CHF',
    note: note,
    sortOrder: order,
    visible: visible,
  ),
);

RecipeRecord r(String name) =>
    (id: name, item: Recipe(id: name, name: name, ingredients: const []));

void main() {
  group('sortMaterials', () {
    test('materials by name', () {
      final out = sortMaterials([m('1', 'B'), m('2', 'A')], isFixedValue: false);
      expect(out.map((e) => e.id), ['2', '1']);
    });
    test('fixed values: sorted first by order, unsorted by name', () {
      final out = sortMaterials([
        m('x', 'Z'),
        m('a', 'A'),
        m('o2', 'Q', order: 2),
        m('o1', 'R', order: 1),
      ], isFixedValue: true);
      expect(out.map((e) => e.id), ['o1', 'o2', 'a', 'x']);
    });
  });

  group('filterMaterials', () {
    final items = [
      m('1', 'Vodka', note: 'Denner'),
      m('2', 'Rum', visible: false),
    ];
    test('hides archived by default', () {
      expect(filterMaterials(items).map((e) => e.id), ['1']);
    });
    test('shows archived on request', () {
      expect(filterMaterials(items, showHidden: true).length, 2);
    });
    test('matches name and note case-insensitively', () {
      expect(filterMaterials(items, query: 'VOD').length, 1);
      expect(filterMaterials(items, query: 'denn').length, 1);
      expect(filterMaterials(items, query: 'xyz'), isEmpty);
    });
  });

  group('reorderMaterials', () {
    test('moves down with the ReorderableList index shift', () {
      final all = [m('a', 'a'), m('b', 'b'), m('c', 'c')];
      final out = reorderMaterials(all, all, 0, 2);
      expect(out.map((e) => e.id), ['b', 'a', 'c']);
    });
    test('keeps hidden ones at the end exactly once', () {
      final all = [m('a', 'a'), m('h', 'h', visible: false), m('b', 'b')];
      final visible = filterMaterials(all);
      expect(reorderMaterials(all, visible, 1, 0).map((e) => e.id), [
        'b',
        'a',
        'h',
      ]);
      expect(reorderMaterials(all, all, 2, 0).map((e) => e.id), [
        'b',
        'a',
        'h',
      ]);
    });
  });

  test('filterRecipes sorts and filters by name', () {
    final out = filterRecipes([r('Mojito'), r('Aperol')], '');
    expect(out.map((e) => e.id), ['Aperol', 'Mojito']);
    expect(filterRecipes([r('Mojito'), r('Aperol')], 'moj').single.id, 'Mojito');
  });

  test('filterIngredients puts selected first', () {
    final out = filterIngredients(['Rum', 'Gin', 'Eis'], {'Rum'}, '');
    expect(out, ['Rum', 'Eis', 'Gin']);
    expect(filterIngredients(['Rum', 'Gin'], {}, 'g'), ['Gin']);
  });
}
