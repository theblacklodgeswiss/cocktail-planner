import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/inventory_rows.dart';
import 'package:flutter_test/flutter_test.dart';

StockEntry _e(
  String material,
  String location,
  StockOrigin origin,
  double q, {
  String? name,
  String? note,
}) => StockEntry(
  id: StockEntry.buildId(material, location, origin),
  materialId: material,
  materialName: name ?? material,
  locationId: location,
  origin: origin,
  quantity: q,
  note: note,
);

const _a = StorageLocation(id: 'a', name: 'A');
const _b = StorageLocation(id: 'b', name: 'B');

void main() {
  test('sums over locations and origins', () {
    final rows = buildInventoryRows(
      [
        _e('m1', 'a', StockOrigin.order, 1),
        _e('m1', 'a', StockOrigin.investment, 2),
        _e('m1', 'b', StockOrigin.order, 4),
      ],
      [_a, _b],
    );
    expect(rows, hasLength(1));
    expect(rows.single.total, 7);
    expect(rows.single.perLocation['a']![StockOrigin.investment], 2);
    expect(rows.single.perLocation['b']![StockOrigin.order], 4);
    expect(rows.single.perLocation['b']![StockOrigin.investment], 0);
  });

  test('Excel example 2.8 + 10 = 12.8', () {
    final rows = buildInventoryRows(
      [
        _e('m1', 'a', StockOrigin.order, 2.8),
        _e('m1', 'b', StockOrigin.investment, 10),
      ],
      [_a, _b],
    );
    expect(rows.single.total, closeTo(12.8, 1e-9));
  });

  test('catalog article without stock yields a zero row', () {
    final rows = buildInventoryRows(
      [],
      [_a],
      catalog: [(id: 'm9', name: 'Rum')],
    );
    expect(rows.single.materialName, 'Rum');
    expect(rows.single.total, 0);
    expect(rows.single.perLocation['a']![StockOrigin.order], 0);
  });

  test('orphaned stock entry still yields a row with its stored name', () {
    final rows = buildInventoryRows(
      [_e('gone', 'a', StockOrigin.order, 3, name: 'Old Gin')],
      [_a],
      catalog: [(id: 'm9', name: 'Rum')],
    );
    final orphan = rows.firstWhere((r) => r.materialId == 'gone');
    expect(orphan.materialName, 'Old Gin');
    expect(orphan.total, 3);
  });

  test('catalog name wins over stored name after a rename', () {
    final rows = buildInventoryRows(
      [_e('m1', 'a', StockOrigin.order, 1, name: 'Old')],
      [_a],
      catalog: [(id: 'm1', name: 'New')],
    );
    expect(rows.single.materialName, 'New');
  });

  test('note is passed through', () {
    final rows = buildInventoryRows(
      [
        _e('m1', 'a', StockOrigin.order, 1),
        _e('m1', 'b', StockOrigin.order, 1, note: 'angebrochen'),
      ],
      [_a, _b],
    );
    expect(rows.single.note, 'angebrochen');
  });

  test('formatQuantity uses comma and drops trailing zero', () {
    expect(formatQuantity(2.8), '2,8');
    expect(formatQuantity(12.8), '12,8');
    expect(formatQuantity(10), '10');
    expect(formatQuantity(2.8 + 10), '12,8');
  });
}
