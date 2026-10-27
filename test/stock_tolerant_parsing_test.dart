import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocktail_planer/data/stock_repository.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StockEntry tolerates wrong types and missing fields', () {
    final e = StockEntry.fromMap('id', {
      'materialId': 42,
      'quantity': '2,5',
      'note': 7,
      'origin': 3,
    });
    expect(e.materialId, '42');
    expect(e.materialName, '');
    expect(e.locationId, '');
    expect(e.quantity, 2.5);
    expect(e.note, '7');
    expect(e.origin, StockOrigin.order);

    final empty = StockEntry.fromMap('id', {});
    expect(empty.quantity, 0);
    expect(StockEntry.fromMap('id', {'quantity': 3}).quantity, 3.0);
    expect(StockEntry.fromMap('id', {'quantity': 'abc'}).quantity, 0);
    expect(StockEntry.fromMap('id', {'quantity': double.nan}).quantity, 0);
  });

  test('StorageLocation tolerates a non-string name', () {
    final l = StorageLocation.fromMap('l', {'name': 12, 'ownerEmail': null});
    expect(l.name, '12');
    expect(l.ownerEmail, isNull);
  });

  test('StockMovement accepts Timestamp, DateTime, millis and garbage', () {
    final t = DateTime(2026, 10, 1, 12);
    expect(StockMovement.fromMap('m', {'at': Timestamp.fromDate(t)}).at, t);
    expect(StockMovement.fromMap('m', {'at': t}).at, t);
    expect(StockMovement.fromMap('m', {'at': t.millisecondsSinceEpoch}).at, t);
    expect(
      StockMovement.fromMap('m', {'at': 'yesterday', 'delta': '1'}).at,
      DateTime.fromMillisecondsSinceEpoch(0),
    );
  });

  test('parseTolerant skips a document that throws', () {
    final docs = [
      (id: 'a', data: <String, dynamic>{'name': 'A'}),
      (id: 'bad', data: <String, dynamic>{'name': 'B'}),
      (id: 'c', data: <String, dynamic>{'name': 'C'}),
    ];
    final parsed = parseTolerant(
      docs,
      (id, data) => id == 'bad'
          ? throw const FormatException('broken')
          : StorageLocation.fromMap(id, data),
      collection: 'storageLocations',
    );
    expect(parsed.map((l) => l.id), ['a', 'c']);
  });
}
