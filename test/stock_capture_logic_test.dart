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
  StockOrigin? hint,
}) => RestLine(
  parsed: ParsedLine(quantity: q, spokenName: id ?? '', originHint: hint),
  candidates: const [],
  location: location,
  origin: hint ?? StockOrigin.order,
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
  group('planCountLine', () {
    CountPlan plan(double counted, {StockOrigin? origin}) => planCountLine(
      counted: counted,
      origin: origin,
      currentOrder: 3,
      currentInvestment: 2,
    );

    test('no hint: Auftrag := counted − Investition', () {
      final p = plan(6);
      expect((p.newOrder, p.newInvestment), (4.0, 2.0));
      expect((p.oldTotal, p.newTotal), (5.0, 6.0));
      expect(p.writes, [(StockOrigin.order, 4.0)]);
      expect(p.valid, isTrue);
    });

    test('hint Auftrag sets only Auftrag', () {
      final p = plan(1, origin: StockOrigin.order);
      expect((p.newOrder, p.newInvestment), (1.0, 2.0));
      expect(p.writes, [(StockOrigin.order, 1.0)]);
    });

    test('hint Investition sets only Investition', () {
      final p = plan(7, origin: StockOrigin.investment);
      expect((p.newOrder, p.newInvestment), (3.0, 7.0));
      expect(p.writes, [(StockOrigin.investment, 7.0)]);
    });

    test('counted == total: nothing to write', () {
      final p = plan(5);
      expect(p.newTotal, 5);
      expect(p.writes, isEmpty);
      expect(p.valid, isTrue);
    });

    test('counted 0 with nothing invested empties Auftrag', () {
      final p = planCountLine(
        counted: 0,
        currentOrder: 3,
        currentInvestment: 0,
      );
      expect(p.valid, isTrue);
      expect(p.writes, [(StockOrigin.order, 0.0)]);
    });

    test('counted below Investition without hint is invalid', () {
      final p = plan(1);
      expect(p.problem, CountProblem.belowInvestment);
      expect(plan(0).problem, CountProblem.belowInvestment);
      expect(
        plan(0, origin: StockOrigin.investment).valid,
        isTrue,
        reason: 'with the hint 0 is fine',
      );
    });

    test('duplicate is invalid', () {
      expect(
        planCountLine(
          counted: 1,
          currentOrder: 0,
          currentInvestment: 0,
          duplicate: true,
        ).problem,
        CountProblem.duplicate,
      );
    });
  });

  test('countDuplicates: same article and location clash unless both '
      'name different origins', () {
    final x1 = _line('m1', 2);
    final x2 = _line('m1', 1);
    final other = _line('m1', 4, location: _b);
    final order = _line('m2', 1, hint: StockOrigin.order);
    final inv = _line('m2', 1, hint: StockOrigin.investment);
    final unresolved1 = _line(null, 1);
    final unresolved2 = _line(null, 1);
    expect(
      countDuplicates([x1, x2, other, order, inv, unresolved1, unresolved2]),
      {x1, x2},
    );
    final plain = _line('m2', 1);
    expect(countDuplicates([order, plain]), {order, plain});
  });

  test('planCountFor reads the snapshot per origin', () {
    final stock = [
      _e('m1', 'a', StockOrigin.order, 3),
      _e('m1', 'a', StockOrigin.investment, 2),
      _e('m1', 'b', StockOrigin.order, 9),
    ];
    final p = planCountFor(_line('m1', 5), stock);
    expect((p.oldOrder, p.oldInvestment, p.newOrder), (3.0, 2.0, 3.0));
    final picked = _line('m1', 1)
      ..origin = StockOrigin.investment
      ..originExplicit = true;
    expect(planCountFor(picked, stock).writes, [
      (StockOrigin.investment, 1.0),
    ]);
  });

  test('quantity rule per mode', () {
    expect(isValidLineQuantity(0, CaptureMode.count), isTrue);
    expect(isValidLineQuantity(0, CaptureMode.add), isFalse);
    expect(isValidLineQuantity(-1, CaptureMode.count), isFalse);
    expect(isValidLineQuantity(2, CaptureMode.add), isTrue);
  });

  test('line ids are unique and the manual movement id is stable', () {
    final a = _line('m1', 1);
    final b = _line('m1', 1);
    expect(a.id, isNot(b.id));
    expect(a.id, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(manualMovementId(a), 'manual|${a.id}|m1|a|order');
    expect(manualMovementId(a), manualMovementId(a));
  });

  test('parser: "Auftrag" is an explicit origin, name stays clean', () {
    final line = parseRestText('3 Bacardi Auftrag').single;
    expect(line.originHint, StockOrigin.order);
    expect(line.spokenName, 'Bacardi');
    expect(parseRestText('0 Bacardi').single.quantity, 0);
  });
}
