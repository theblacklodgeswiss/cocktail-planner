import 'package:cocktail_planer/data/admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _material(String name) => {
  'unit': 'Fl',
  'name': name,
  'price': 12.5,
  'currency': 'CHF',
  'note': '',
};

void main() {
  test('one malformed material is skipped, the others are listed', () {
    final result = parseMaterialCatalog([
      (id: 'm1', data: _material('Rum')),
      // Price as text and no name: the strict fromJson throws.
      (id: 'bad', data: {'unit': 'Fl', 'price': 'zwölf'}),
      (id: 'm2', data: _material('Gin')),
    ]);
    expect([for (final m in result.items) m.id], ['m1', 'm2']);
    expect(result.items.first.item.name, 'Rum');
    expect(result.skipped, 1);
  });

  test('all good -> nothing skipped', () {
    final result = parseMaterialCatalog([(id: 'm1', data: _material('Rum'))]);
    expect(result.items, hasLength(1));
    expect(result.skipped, 0);
  });
}
