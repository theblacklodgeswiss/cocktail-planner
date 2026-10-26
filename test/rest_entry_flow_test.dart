import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/rest_lines.dart';
import 'package:cocktail_planer/services/voice_inventory_parser.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialItem _item(String name) => MaterialItem(
  unit: 'Fl.',
  name: name,
  price: 1,
  currency: 'EUR',
  note: '',
);

void main() {
  const mine = StorageLocation(id: 'a', name: 'Prince', ownerEmail: 'p@x.de');
  const mario = StorageLocation(id: 'b', name: 'Mario');
  final catalog = [
    ('m1', _item('Orangensaft')),
    ('m2', _item('Sprite')),
    ('m3', _item('Sprite Zero')),
  ];

  List<RestLine> build(List<ParsedLine> lines) =>
      buildRestLines(lines, catalog, [mine, mario], mine);

  test('sets default location and default origin order', () {
    final line = build([
      const ParsedLine(quantity: 6, spokenName: 'Orangensaft'),
    ]).single;
    expect(line.location, mine);
    expect(line.origin, StockOrigin.order);
    expect(line.quantity, 6);
    expect(line.chosenMaterialId, 'm1');
  });

  test('locationHint overrides default, case-insensitively', () {
    final line = build([
      const ParsedLine(
        quantity: 3,
        spokenName: 'Orangensaft',
        locationHint: 'mario',
      ),
    ]).single;
    expect(line.location, mario);
    expect(line.locationUnresolved, isFalse);
  });

  test('unknown locationHint falls back to default and is flagged', () {
    final line = build([
      const ParsedLine(
        quantity: 3,
        spokenName: 'Orangensaft',
        locationHint: 'Peter',
      ),
    ]).single;
    expect(line.location, mine);
    expect(line.locationUnresolved, isTrue);
  });

  test('unsure match leaves chosenMaterialId null with candidates', () {
    final line = build([
      const ParsedLine(quantity: 1, spokenName: 'Sprite Zer'),
      const ParsedLine(quantity: 1, spokenName: 'Whisky'),
    ]);
    expect(line[1].chosenMaterialId, isNull);
    expect(line[1].candidates, isEmpty);
    final sprite = buildRestLines(
      [const ParsedLine(quantity: 1, spokenName: 'Spri')],
      catalog,
      [mine],
      mine,
    ).single;
    expect(sprite.chosenMaterialId, isNull);
    expect(sprite.candidates, isNotEmpty);
  });

  test('originHint investment is taken over', () {
    final line = build([
      const ParsedLine(
        quantity: 1,
        spokenName: 'Orangensaft',
        originHint: StockOrigin.investment,
      ),
    ]).single;
    expect(line.origin, StockOrigin.investment);
  });
}
