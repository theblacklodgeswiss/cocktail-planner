import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StockEntry id combines material, location and origin', () {
    expect(
      StockEntry.buildId('m1', 'l1', StockOrigin.investment),
      'm1|l1|investment',
    );
  });

  test('StockEntry round-trips a decimal quantity', () {
    const entry = StockEntry(
      id: 'm1|l1|order',
      materialId: 'm1',
      materialName: 'Rum',
      locationId: 'l1',
      origin: StockOrigin.order,
      quantity: 2.8,
      note: 'half open',
    );
    final back = StockEntry.fromMap(entry.id, entry.toMap());
    expect(back.quantity, 2.8);
    expect(back.materialName, 'Rum');
    expect(back.origin, StockOrigin.order);
    expect(back.note, 'half open');
  });

  test('StockOrigin.fromString parses and falls back to order', () {
    expect(StockOrigin.fromString('investment'), StockOrigin.investment);
    expect(StockOrigin.fromString('bogus'), StockOrigin.order);
    expect(StockOrigin.fromString(null), StockOrigin.order);
  });

  test('StockMovement round-trips', () {
    final at = DateTime.utc(2026, 10, 26, 12);
    final m = StockMovement(
      id: 'x',
      materialId: 'm1',
      locationId: 'l1',
      origin: StockOrigin.investment,
      delta: -1.5,
      reason: 'take',
      orderId: 'o1',
      byEmail: 'a@b.de',
      at: at,
    );
    final map = m.toMap();
    expect(map['at'], isA<Timestamp>());
    final back = StockMovement.fromMap('x', map);
    expect(back.delta, -1.5);
    expect(back.orderId, 'o1');
    expect(back.at.toUtc(), at);
  });

  test('StorageLocation round-trips with optional owner', () {
    final loc = StorageLocation.fromMap('l1', {'name': 'Keller'});
    expect(loc.ownerEmail, isNull);
    expect(loc.toMap(), {'name': 'Keller'});
  });
}
