import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/rest_lines.dart';
import 'package:cocktail_planer/services/voice_inventory_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = StorageLocation(id: 'a', name: 'A');
const _b = StorageLocation(id: 'b', name: 'B');

RestLine _line(
  String? id,
  double q, {
  StorageLocation location = _a,
  StockOrigin origin = StockOrigin.order,
}) => RestLine(
  parsed: ParsedLine(quantity: q, spokenName: id ?? ''),
  candidates: const [],
  location: location,
  origin: origin,
  quantity: q,
  chosenMaterialId: id,
  chosenMaterialName: id,
);

StockEntry _e(String m, String l, StockOrigin o, double q) => StockEntry(
  id: StockEntry.buildId(m, l, o),
  materialId: m,
  materialName: m,
  locationId: l,
  origin: o,
  quantity: q,
);

void main() {
  test('count targets sum lines of the same entry, skip unresolved', () {
    final targets = countTargets([
      _line('m1', 2),
      _line('m1', 1),
      _line('m1', 4, location: _b),
      _line('m1', 5, origin: StockOrigin.investment),
      _line(null, 9),
    ]);
    expect(targets, {
      'm1|a|order': 3,
      'm1|b|order': 4,
      'm1|a|investment': 5,
    });
  });

  test('current quantity of the entry a line books into', () {
    final entries = [
      _e('m1', 'a', StockOrigin.order, 3),
      _e('m1', 'b', StockOrigin.order, 7),
      _e('m1', 'a', StockOrigin.investment, 1),
    ];
    expect(currentQuantityFor(_line('m1', 2), entries), 3);
    expect(currentQuantityFor(_line('m1', 2, location: _b), entries), 7);
    expect(
      currentQuantityFor(
        _line('m1', 2, origin: StockOrigin.investment),
        entries,
      ),
      1,
    );
    expect(currentQuantityFor(_line('m2', 2), entries), 0);
    expect(currentQuantityFor(_line(null, 2), entries), 0);
  });
}
