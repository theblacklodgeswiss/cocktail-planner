import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/services/inventory_import.dart';
import 'package:flutter_test/flutter_test.dart';

const _locs = ['Biri', 'Tuji', 'Mario', 'Biri', 'Tuji', 'Mario'];
const _origins = [
  StockOrigin.order,
  StockOrigin.order,
  StockOrigin.order,
  StockOrigin.investment,
  StockOrigin.investment,
  StockOrigin.investment,
];

List<ImportRow> parse(String s) =>
    parseInventoryPaste(s, columnLocations: _locs, columnOrigins: _origins);

void main() {
  test('places quantities in the right location/origin, ignores Gesamt', () {
    final rows = parse('0.7L\tWeisser Rum (Bacardi)\t\t2,8\t\t\t\t10\t12,8');
    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.unit, '0.7L');
    expect(r.name, 'Weisser Rum (Bacardi)');
    expect(r.cells, hasLength(2));
    expect(r.cells[0].column, 1);
    expect(r.cells[0].location, 'Tuji');
    expect(r.cells[0].origin, StockOrigin.order);
    expect(r.cells[0].quantity, 2.8);
    expect(r.cells[1].column, 5);
    expect(r.cells[1].location, 'Mario');
    expect(r.cells[1].origin, StockOrigin.investment);
    expect(r.cells[1].quantity, 10.0);
    expect(r.invalidColumns, isEmpty);
  });

  test('real row: only investment Mario', () {
    final r = parse('1L\tWhiskey (BlackLabel)\t\t\t\t\t\t6\t6').single;
    expect(r.cells, hasLength(1));
    expect(r.cells.single.location, 'Mario');
    expect(r.cells.single.origin, StockOrigin.investment);
    expect(r.cells.single.quantity, 6.0);
  });

  test('real row: Rose Lillet with three order cells', () {
    final r = parse('0.7L\tRose Lillet\t2\t4,5\t2\t\t\t\t8,5').single;
    expect(r.cells.map((c) => c.column), [0, 1, 2]);
    expect(r.cells.map((c) => c.quantity), [2.0, 4.5, 2.0]);
    expect(r.cells.map((c) => c.location), ['Biri', 'Tuji', 'Mario']);
  });

  test('empty and zero cells yield no movement', () {
    final r = parse('1L\tGin\t0\t\t0,0\t\t\t').single;
    expect(r.cells, isEmpty);
  });

  test('skips both header lines and blank lines, handles CRLF', () {
    const text =
        '\t\tLagerbestand aus Auftrag\t\t\tLagerbestand aus Investition\t\t\t\tBemerkung\r\n'
        'Einheit/Größe\tArtikelname\tBiri\tInthusan\tMario\tBiri\tInthusan\tMario\tGesamt\r\n'
        '\r\n'
        '1L\tGin\t1\r\n'
        '   \r\n'
        '1L\tVodka\t\t2\r\n';
    final rows = parse(text);
    expect(rows.map((r) => r.name), ['Gin', 'Vodka']);
    expect(rows[1].cells.single.column, 1);
  });

  test('quoted cell containing comma and tab-free quotes', () {
    final r = parse('0.7L\t"Rum, weiss ""X"""\t3').single;
    expect(r.name, 'Rum, weiss "X"');
    expect(r.cells.single.quantity, 3.0);
  });

  test('non-numeric cell is flagged and not booked', () {
    final r = parse('1L\tGin\tabc\t2\t-1').single;
    expect(r.invalidColumns, [0, 2]);
    expect(r.cells.map((c) => c.column), [1]);
  });

  test('short rows, extra tabs and note columns do not crash', () {
    expect(parse('1L'), isEmpty);
    final r = parse(
      '1L\tGin\t1\t\t\t\t\t\t1\tTuji: Haltbar bis 12.12.24\tmehr\t\t\t',
    ).single;
    expect(r.note, 'Tuji: Haltbar bis 12.12.24 mehr');
    expect(r.cells.single.quantity, 1.0);
    expect(parse('1L\tGin').single.note, isNull);
  });

  test('quoted cell containing a tab stays one cell', () {
    final r = parse('1L\t"Gin\tTonic"\t2').single;
    expect(r.name, 'Gin\tTonic');
    expect(r.cells.single.quantity, 2.0);
  });
}
