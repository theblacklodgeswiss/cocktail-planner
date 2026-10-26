import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/shopping_list/stock_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planDeduction', () {
    test('draws Auftrag first, then Investition', () {
      final p = planDeduction(needed: 3, stockOrder: 2, stockInvestment: 5);
      expect([p.fromOrder, p.fromInvestment, p.fromShop], [2, 1, 0]);
    });

    test('remainder goes to the shop', () {
      final p = planDeduction(needed: 10, stockOrder: 2, stockInvestment: 1);
      expect([p.fromOrder, p.fromInvestment, p.fromShop], [2, 1, 7]);
    });

    test('need 0 and negative need plan nothing', () {
      for (final n in [0.0, -4.0]) {
        final p = planDeduction(needed: n, stockOrder: 2, stockInvestment: 1);
        expect([p.fromOrder, p.fromInvestment, p.fromShop], [0, 0, 0]);
      }
    });

    test('stock larger than need only uses what is needed', () {
      final p = planDeduction(needed: 1.5, stockOrder: 4, stockInvestment: 9);
      expect([p.fromOrder, p.fromInvestment, p.fromShop], [1.5, 0, 0]);
    });

    test('negative stock is treated as empty', () {
      final p = planDeduction(needed: 2, stockOrder: -1, stockInvestment: 1);
      expect([p.fromOrder, p.fromInvestment, p.fromShop], [0, 1, 1]);
    });
  });

  group('internalCost', () {
    test('Auftrag part is free, Investition at catalog, rest at shop', () {
      const onlyOrder = DeductionPlan(
        fromOrder: 3,
        fromInvestment: 0,
        fromShop: 0,
      );
      expect(internalCost(plan: onlyOrder, catalogPrice: 10, shopPrice: 12), 0);
      const mixed = DeductionPlan(fromOrder: 2, fromInvestment: 1, fromShop: 7);
      expect(
        internalCost(plan: mixed, catalogPrice: 10, shopPrice: 12),
        1 * 10 + 7 * 12,
      );
    });
  });

  group('item source', () {
    test('items without source fields are shop', () {
      final s = ItemSource.fromItem({'name': 'Rum', 'quantity': 2});
      expect(s.isStock, isFalse);
      expect(s.locationId, isNull);
    });

    test('stock without location falls back to shop', () {
      expect(ItemSource.fromItem({'source': 'stock'}).isStock, isFalse);
    });

    test('stock with location round-trips; shop removes the location', () {
      final item = {'name': 'Rum', 'quantity': 2};
      final stock = withItemSource(item, const ItemSource.stock('l1'));
      expect(stock['source'], 'stock');
      expect(ItemSource.fromItem(stock).locationId, 'l1');
      final shop = withItemSource(stock, const ItemSource.shop());
      expect(shop['source'], 'shop');
      expect(shop.containsKey('sourceLocationId'), isFalse);
    });
  });

  group('customer totals are independent of the source', () {
    test('customerTotal ignores source fields', () {
      final items = [
        {'name': 'Rum', 'price': 12.5, 'quantity': 3},
        {'name': 'Eis', 'price': 4, 'quantity': 2},
      ];
      final before = customerTotal(items);
      final switched = [
        withItemSource(items[0], const ItemSource.stock('l1')),
        withItemSource(items[1], const ItemSource.stock('l2')),
      ];
      expect(before, 45.5);
      expect(customerTotal(switched), before);
    });
  });

  group('resolveMaterialId', () {
    MaterialItem m(String name, String unit) => MaterialItem(
      name: name,
      unit: unit,
      price: 1,
      currency: 'EUR',
      note: '',
    );

    test('own materialId wins', () {
      expect(resolveMaterialId({'materialId': 'x', 'name': 'Rum'}, []), 'x');
    });

    test('name and unit match picks the right duplicate', () {
      final catalog = [
        (id: 'a', item: m('Rum', '0,7l')),
        (id: 'b', item: m('Rum', '1l')),
      ];
      expect(resolveMaterialId({'name': 'Rum', 'unit': '1l'}, catalog), 'b');
    });

    test('duplicate names without unit match are ambiguous', () {
      final catalog = [
        (id: 'a', item: m('Rum', '0,7l')),
        (id: 'b', item: m('Rum', '1l')),
      ];
      expect(resolveMaterialId({'name': 'Rum', 'unit': '2l'}, catalog), isNull);
    });

    test('unique name with different unit still resolves', () {
      final catalog = [(id: 'a', item: m('Rum', '0,7l'))];
      expect(resolveMaterialId({'name': 'Rum', 'unit': '1l'}, catalog), 'a');
    });

    test('fixed value not in the catalog is null', () {
      final catalog = [(id: 'a', item: m('Rum', '0,7l'))];
      expect(
        resolveMaterialId({'name': 'Barkeeper', 'unit': 'Std'}, catalog),
        isNull,
      );
    });
  });

  test('availableAt sums per origin for the right material and location', () {
    StockEntry e(String m, String l, StockOrigin o, double q) => StockEntry(
      id: '$m|$l|${o.name}',
      materialId: m,
      materialName: m,
      locationId: l,
      origin: o,
      quantity: q,
    );
    final entries = [
      e('m1', 'l1', StockOrigin.order, 2.5),
      e('m1', 'l1', StockOrigin.investment, 1),
      e('m1', 'l2', StockOrigin.order, 9),
      e('m2', 'l1', StockOrigin.order, 7),
    ];
    final a = availableAt(entries, 'm1', 'l1');
    expect(a.order, 2.5);
    expect(a.investment, 1);
    expect(availableAt(entries, 'm3', 'l1').order, 0);
  });

  test('canToggleSource only blocks switching on without a material', () {
    expect(
      canToggleSource(canStock: false, isStock: true, saving: false),
      isTrue,
    );
    expect(
      canToggleSource(canStock: false, isStock: false, saving: false),
      isFalse,
    );
    expect(
      canToggleSource(canStock: true, isStock: false, saving: false),
      isTrue,
    );
    expect(
      canToggleSource(canStock: true, isStock: true, saving: true),
      isFalse,
    );
  });
}
