import 'package:cocktail_planer/data/stock_repository.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/inventory_actions.dart';
import 'package:cocktail_planer/screens/inventory/inventory_rows.dart';
import 'package:flutter_test/flutter_test.dart';

const _z = StorageLocation(id: 'z', name: 'Zentrale');
const _m = StorageLocation(id: 'm', name: 'mario');
const _own = StorageLocation(id: 'o', name: 'Prince', ownerEmail: 'P@x.de');

class _Calls {
  final log = <String>[];

  InventoryServices services({String? email}) => InventoryServices(
    setQuantity:
        ({
          required materialId,
          required materialName,
          required locationId,
          required origin,
          required quantity,
        }) async => log.add(
          'set $materialId $materialName $locationId ${origin.name} $quantity',
        ),
    setArticleNote:
        ({
          required materialId,
          required materialName,
          required note,
          required fallbackLocationId,
        }) async => log.add('note $materialId "$note" $fallbackLocationId'),
    applyMovement:
        ({
          required materialId,
          required materialName,
          required locationId,
          required origin,
          required delta,
          required reason,
        }) async => log.add(
          'move $materialId $locationId ${origin.name} $delta $reason',
        ),
    email: () => email,
  );
}

final _row = buildInventoryRows(
  [],
  [_z, _m],
  catalog: [(id: 'm1', name: 'Rum')],
).single;

void main() {
  test('editor cell -> setQuantity with the row', () async {
    final c = _Calls();
    await InventoryActions(c.services()).saveQuantity(_row, (
      locationId: 'm',
      origin: StockOrigin.investment,
      quantity: 2.5,
    ));
    expect(c.log, ['set m1 Rum m investment 2.5']);
  });

  test('note -> setArticleNote at the own location, else the first by '
      'name', () async {
    final c = _Calls();
    await InventoryActions(
      c.services(email: 'p@x.de'),
    ).saveNote(_row, [_z, _m, _own], 'angebrochen');
    await InventoryActions(c.services()).saveNote(_row, [_z, _m], '');
    await InventoryActions(c.services()).saveNote(_row, [], 'x');
    expect(c.log, ['note m1 "angebrochen" o', 'note m1 "" m']);
  });

  test('take -> applyMovement(-amount, take)', () async {
    final c = _Calls();
    await InventoryActions(c.services()).take(_row, 'z', StockOrigin.order, 2);
    expect(c.log, ['move m1 z order -2.0 take']);
  });

  group('planArticleNote', () {
    ArticleNotePlan plan(List<String> ids, String note) => planArticleNote(
      existingEntryIds: ids,
      materialId: 'm1',
      materialName: 'Rum',
      note: note,
      fallbackLocationId: 'z',
    );

    test('updates every existing entry, trimmed', () {
      final p = plan(['m1|a|order', 'm1|b|investment'], '  bald leer ');
      expect(p.updates, {
        'm1|a|order': 'bald leer',
        'm1|b|investment': 'bald leer',
      });
      expect(p.create, isNull);
    });

    test('empty note removes it from existing entries', () {
      expect(plan(['m1|a|order'], ' ').updates, {'m1|a|order': null});
    });

    test('no entries: creates the Auftrag entry at the fallback with 0', () {
      final p = plan([], 'neu');
      expect(p.updates, isEmpty);
      expect(p.create!.id, 'm1|z|order');
      expect(p.create!.fields, {
        'materialId': 'm1',
        'materialName': 'Rum',
        'locationId': 'z',
        'origin': 'order',
        'quantity': 0.0,
        'note': 'neu',
      });
    });

    test('no entries and empty note: nothing', () {
      expect(plan([], '').isEmpty, isTrue);
    });
  });

  test('noteFallbackLocation: own (case-insensitive), else alphabetical', () {
    expect(noteFallbackLocation([_z, _m, _own], 'p@X.de'), _own);
    expect(noteFallbackLocation([_z, _m], 'p@x.de'), _m);
    expect(noteFallbackLocation([_z, _m], null), _m);
    expect(noteFallbackLocation([], null), isNull);
  });
}
