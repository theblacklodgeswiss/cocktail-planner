import 'package:cocktail_planer/data/stock_repository.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> fields(String? note) => stockEntryFields(
    materialId: 'm',
    materialName: 'n',
    locationId: 'l',
    origin: StockOrigin.order,
    quantity: 1,
    note: note,
  );

  test('includes a non-empty note, trimmed', () {
    expect(fields(' Haltbar bis 12.12.24 ')['note'], 'Haltbar bis 12.12.24');
  });

  test('omits null or blank note so a merge keeps the old one', () {
    expect(fields(null).containsKey('note'), isFalse);
    expect(fields('  ').containsKey('note'), isFalse);
  });
}
