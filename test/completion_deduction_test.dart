import 'package:cocktail_planer/data/stock_repository.dart';
import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/shopping_list/completion_deduction.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialItem _mat(String name) => MaterialItem(
  unit: 'Fl',
  name: name,
  price: 10,
  currency: 'CHF',
  note: '',
);

final _catalog = [
  (id: 'rum', item: _mat('Rum')),
  (id: 'gin', item: _mat('Gin')),
];

StockEntry _entry(String m, String loc, StockOrigin o, double q) => StockEntry(
  id: StockEntry.buildId(m, loc, o),
  materialId: m,
  materialName: m,
  locationId: loc,
  origin: o,
  quantity: q,
);

SavedOrder _order(
  List<Map<String, dynamic>> items, {
  bool stockApplied = false,
  bool restRecorded = false,
}) => SavedOrder(
  id: 'o1',
  name: 'Test',
  date: DateTime(2026, 1, 1),
  items: items,
  total: 0,
  personCount: 10,
  drinkerType: 'normal',
  currency: 'CHF',
  status: OrderStatus.accepted,
  stockApplied: stockApplied,
  restRecorded: restRecorded,
);

Map<String, dynamic> _stockItem(String name, num qty, {String loc = 'l1'}) => {
  'name': name,
  'unit': 'Fl',
  'quantity': qty,
  'source': 'stock',
  'sourceLocationId': loc,
};

void main() {
  test('movements are Auftrag first, then Investition', () {
    final plan = planOrderDeduction(
      _order([_stockItem('Rum', 3)]),
      [
        _entry('rum', 'l1', StockOrigin.investment, 5),
        _entry('rum', 'l1', StockOrigin.order, 2),
      ],
      _catalog,
    );
    expect(plan.movements.map((m) => m.origin), [
      StockOrigin.order,
      StockOrigin.investment,
    ]);
    expect(plan.movements.map((m) => m.delta), [-2, -1]);
    expect(plan.movements.first.materialName, 'Rum');
    expect(plan.shortfalls, isEmpty);
  });

  test('stockApplied produces nothing', () {
    final plan = planOrderDeduction(
      _order([_stockItem('Rum', 3)], stockApplied: true),
      [_entry('rum', 'l1', StockOrigin.order, 9)],
      _catalog,
    );
    expect(plan.movements, isEmpty);
    expect(plan.shortfalls, isEmpty);
  });

  test('shortfall is clamped and reported', () {
    final plan = planOrderDeduction(
      _order([_stockItem('Rum', 10)]),
      [_entry('rum', 'l1', StockOrigin.order, 4)],
      _catalog,
    );
    expect(plan.movements.single.delta, -4);
    expect(plan.shortfalls.single.name, 'Rum');
    expect(plan.shortfalls.single.quantity, 6);
  });

  test('shop items produce nothing', () {
    final plan = planOrderDeduction(
      _order([
        {'name': 'Rum', 'unit': 'Fl', 'quantity': 2, 'source': 'shop'},
        {'name': 'Gin', 'unit': 'Fl', 'quantity': 2},
      ]),
      [_entry('rum', 'l1', StockOrigin.order, 9)],
      _catalog,
    );
    expect(plan.movements, isEmpty);
    expect(plan.shortfalls, isEmpty);
  });

  test('unresolved items are reported and skipped', () {
    final plan = planOrderDeduction(
      _order([_stockItem('Unbekannt', 2), _stockItem('Gin', 1)]),
      [_entry('gin', 'l1', StockOrigin.order, 3)],
      _catalog,
    );
    expect(plan.unresolved, ['Unbekannt']);
    expect(plan.movements.single.materialId, 'gin');
  });

  test('same material twice is aggregated and cannot overdraw', () {
    final plan = planOrderDeduction(
      _order([_stockItem('Rum', 2), _stockItem('Rum', 2)]),
      [_entry('rum', 'l1', StockOrigin.order, 3)],
      _catalog,
    );
    expect(plan.movements.single.delta, -3);
    expect(plan.shortfalls.single.quantity, 1);
    expect(plan.movements.map((m) => m.id).toSet().length, 1);
  });

  test('ids are deterministic and unique per material/location/origin', () {
    final items = [_stockItem('Rum', 3), _stockItem('Rum', 1, loc: 'l2')];
    final entries = [
      _entry('rum', 'l1', StockOrigin.order, 2),
      _entry('rum', 'l1', StockOrigin.investment, 5),
      _entry('rum', 'l2', StockOrigin.order, 5),
    ];
    final a = planOrderDeduction(_order(items), entries, _catalog);
    final b = planOrderDeduction(_order(items), entries, _catalog);
    expect(a.movements.map((m) => m.id), b.movements.map((m) => m.id));
    expect(a.movements.map((m) => m.id).toSet().length, 3);
    expect(a.movements.first.id, 'o1|rum|l1|order');
    expect(orderMovementId('o1', 'rum', 'l1', StockOrigin.investment),
        'o1|rum|l1|investment');
  });

  test('retry after partial failure plans the same split (no over-deduct)', () {
    final items = [_stockItem('Rum', 3)];
    // First attempt booked only the Auftrag part (-2): stock now 0 / 5.
    final plan = planOrderDeduction(
      _order(items),
      [
        _entry('rum', 'l1', StockOrigin.order, 0),
        _entry('rum', 'l1', StockOrigin.investment, 5),
      ],
      _catalog,
      booked: {'o1|rum|l1|order': -2},
    );
    final byOrigin = {for (final m in plan.movements) m.origin: m.delta};
    expect(byOrigin[StockOrigin.investment], -1);
    expect(plan.shortfalls, isEmpty);
  });

  test('applyMovement idempotency decision', () {
    expect(shouldApplyMovement(movementId: null, exists: false), isTrue);
    expect(shouldApplyMovement(movementId: null, exists: true), isTrue);
    expect(shouldApplyMovement(movementId: 'x', exists: false), isTrue);
    expect(shouldApplyMovement(movementId: 'x', exists: true), isFalse);
  });

  group('prepareOrderDeduction', () {
    final staleShop = _order([
      {'name': 'Rum', 'unit': 'Fl', 'quantity': 3, 'source': 'shop'},
    ]);
    final freshStock = _order([_stockItem('Rum', 3)]);
    final entries = [_entry('rum', 'l1', StockOrigin.order, 5)];

    Future<OrderDeductionPlan> run({
      required Future<SavedOrder?> Function() fetch,
      Future<List<({String id, MaterialItem item})>> Function()? catalog,
    }) => prepareOrderDeduction(
      fetchOrder: fetch,
      loadCatalog: catalog ?? () async => _catalog,
      loadEntries: () async => entries,
      loadBooked: (_) async => {},
    );

    test('plans from the fresh order, not the stale one', () async {
      expect(staleShop.items.single['source'], 'shop');
      final plan = await run(fetch: () async => freshStock);
      expect(plan.movements.single.delta, -3);
    });

    test('fresh order missing or failing to load fails closed', () async {
      expect(run(fetch: () async => null), throwsStateError);
      expect(run(fetch: () async => throw Exception('x')), throwsStateError);
    });

    test('empty or failing catalog with stock items fails closed', () async {
      expect(
        run(fetch: () async => freshStock, catalog: () async => []),
        throwsStateError,
      );
      expect(
        run(
          fetch: () async => freshStock,
          catalog: () async => throw Exception('offline'),
        ),
        throwsException,
      );
    });

    test('exposes restRecorded of the fresh order on every path', () async {
      final applied = await run(
        fetch: () async => _order(
          [_stockItem('Rum', 3)],
          stockApplied: true,
          restRecorded: true,
        ),
      );
      expect(applied.alreadyApplied, isTrue);
      expect(applied.restRecorded, isTrue);
      final noStock = await run(
        fetch: () async => _order([
          {'name': 'Rum', 'unit': 'Fl', 'quantity': 3, 'source': 'shop'},
        ], restRecorded: true),
      );
      expect(noStock.restRecorded, isTrue);
      final planned = await run(fetch: () async => freshStock);
      expect(planned.restRecorded, isFalse);
    });

    test('catalog is not needed without stock items', () async {
      final plan = await run(
        fetch: () async => staleShop,
        catalog: () async => throw Exception('must not be called'),
      );
      expect(plan.movements, isEmpty);
      expect(plan.alreadyApplied, isFalse);
    });

    test('fresh stockApplied is reported as already applied', () async {
      final plan = await run(
        fetch: () async => _order([_stockItem('Rum', 3)], stockApplied: true),
      );
      expect(plan.alreadyApplied, isTrue);
      expect(plan.movements, isEmpty);
    });

    test('loaded catalog: unresolved items are listed, not an error', () async {
      final plan = await run(
        fetch: () async => _order([_stockItem('Unbekannt', 1)]),
      );
      expect(plan.unresolved, ['Unbekannt']);
    });
  });

  test('shouldOfferRest only when known not recorded (fail closed)', () {
    expect(shouldOfferRest(freshRestRecorded: false), isTrue);
    expect(shouldOfferRest(freshRestRecorded: true), isFalse);
    expect(shouldOfferRest(freshRestRecorded: null), isFalse);
  });
}
