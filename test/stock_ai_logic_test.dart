import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/rest_lines.dart';
import 'package:cocktail_planer/screens/inventory/stock_ai_logic.dart';
import 'package:cocktail_planer/services/stock_ai_interpreter.dart';
import 'package:cocktail_planer/services/voice_inventory_parser.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialItem _item(String name) =>
    MaterialItem(unit: 'Fl.', name: name, price: 1, currency: 'EUR', note: '');

const _mine = StorageLocation(id: 'a', name: 'Prince');
const _mario = StorageLocation(id: 'b', name: 'Mario');

final _catalog = [
  ('m1', _item('Bacardi')),
  ('m2', _item('Orangensaft')),
  ('m3', _item('Sprite')),
  ('m4', _item('Sprite Zero')),
];

StockEntry _stock(String m, String loc, StockOrigin o, double q) => StockEntry(
  id: StockEntry.buildId(m, loc, o),
  materialId: m,
  materialName: m,
  locationId: loc,
  origin: o,
  quantity: q,
);

RestLine _line(
  double quantity, {
  String? material = 'm1',
  StorageLocation location = _mine,
  StockOrigin? origin,
  List<CatalogMatch> candidates = const [],
}) => RestLine(
  parsed: ParsedLine(
    quantity: quantity,
    spokenName: 'x',
    originHint: origin,
  ),
  candidates: candidates,
  chosenMaterialId: material,
  chosenMaterialName: material,
  location: location,
  origin: origin ?? StockOrigin.order,
  quantity: quantity,
);

void main() {
  group('plausibilityFlags', () {
    final stock = [
      _stock('m1', 'a', StockOrigin.order, 3),
      _stock('m1', 'a', StockOrigin.investment, 2),
      _stock('m1', 'b', StockOrigin.order, 1),
    ];

    // (description, line, mode, expected)
    final table = <(String, RestLine, CaptureMode, List<PlausibilityFlag>)>[
      ('Dazu normal', _line(4), CaptureMode.add, []),
      // total 6: limit max(10, 30) = 30
      ('Dazu at limit', _line(30), CaptureMode.add, []),
      (
        'Dazu above 5x total',
        _line(31),
        CaptureMode.add,
        [PlausibilityFlag.unusuallyHigh],
      ),
      (
        'Dazu no stock, above 10',
        _line(11, material: 'm2'),
        CaptureMode.add,
        [PlausibilityFlag.unusuallyHigh, PlausibilityFlag.noStockYet],
      ),
      (
        'Dazu no stock, small',
        _line(10, material: 'm2'),
        CaptureMode.add,
        [PlausibilityFlag.noStockYet],
      ),
      // location a: old 5, limit max(10, 15) = 15
      ('Zählung close', _line(18), CaptureMode.count, []),
      (
        'Zählung jump',
        _line(21),
        CaptureMode.count,
        [PlausibilityFlag.unusuallyHigh],
      ),
      (
        'Zählung below Investition',
        _line(1),
        CaptureMode.count,
        [PlausibilityFlag.belowInvestment],
      ),
      (
        'Zählung below Investition said with origin is fine',
        _line(1, origin: StockOrigin.investment),
        CaptureMode.count,
        [],
      ),
      (
        'Zählung at Mario (old 1): 11 is ok, limit max(10, 3)',
        _line(11, location: _mario),
        CaptureMode.count,
        [],
      ),
      (
        'Zählung at Mario 12',
        _line(12, location: _mario),
        CaptureMode.count,
        [PlausibilityFlag.unusuallyHigh],
      ),
      (
        'not unique',
        _line(
          1,
          material: null,
          candidates: const [
            CatalogMatch(materialId: 'm3', name: 'Sprite', score: 0.7),
            CatalogMatch(materialId: 'm4', name: 'Sprite Zero', score: 0.7),
          ],
        ),
        CaptureMode.add,
        [PlausibilityFlag.notUnique],
      ),
      (
        'unresolved with one candidate',
        _line(
          1,
          material: null,
          candidates: const [
            CatalogMatch(materialId: 'm3', name: 'Sprite', score: 0.7),
          ],
        ),
        CaptureMode.add,
        [],
      ),
      ('invalid quantity: only stock flags', _line(-1), CaptureMode.add, []),
    ];

    for (final (name, line, mode, expected) in table) {
      test(name, () {
        expect(plausibilityFlags(line, stock, mode), expected);
      });
    }

    test('a trailing-number quantity is flagged unsure', () {
      final line = RestLine(
        parsed: const ParsedLine(
          quantity: 80,
          spokenName: 'Stroh',
          quantityUnsure: true,
        ),
        candidates: const [],
        chosenMaterialId: 'm1',
        location: _mine,
        origin: StockOrigin.order,
        quantity: 80,
      );
      expect(
        plausibilityFlags(line, stock, CaptureMode.add),
        contains(PlausibilityFlag.quantityUnsure),
      );
    });

    test('every flag has a de/en key', () {
      for (final f in PlausibilityFlag.values) {
        expect(f.key, startsWith('inventory_list.flag_'));
      }
    });
  });

  group('chooseInterpretation', () {
    const someRules = ParseResult(
      lines: [ParsedLine(quantity: 2, spokenName: 'Bacardi')],
      unparsed: [],
    );
    const noRules = ParseResult(lines: [], unparsed: []);
    const aiLines = StockAiResult([
      StockAiLine(spokenText: '2 Bacardi', materialId: 'm1', quantity: 2),
    ]);
    const aiEmpty = StockAiResult([]);

    test('AI ok uses the AI lines', () {
      final c = chooseInterpretation(const AiAttempt.ok(aiLines), someRules);
      expect(c.useAi, isTrue);
      expect(c.fallbackHint, isFalse);
    });

    test('AI ok also when the rules found nothing', () {
      final c = chooseInterpretation(const AiAttempt.ok(aiLines), noRules);
      expect(c.useAi, isTrue);
    });

    test('AI error falls back with a hint', () {
      final c = chooseInterpretation(const AiAttempt.failed(), someRules);
      expect(c.useAi, isFalse);
      expect(c.fallbackHint, isTrue);
    });

    test('AI empty while rules found lines: rules with a hint', () {
      final c = chooseInterpretation(const AiAttempt.ok(aiEmpty), someRules);
      expect(c.useAi, isFalse);
      expect(c.fallbackHint, isTrue);
    });

    test('AI empty and rules empty: rules (empty state), no hint', () {
      final c = chooseInterpretation(const AiAttempt.ok(aiEmpty), noRules);
      expect(c.useAi, isFalse);
      expect(c.fallbackHint, isFalse);
    });

    test('not configured / switched off: rules, no hint', () {
      final c = chooseInterpretation(const AiAttempt.skipped(), someRules);
      expect(c.useAi, isFalse);
      expect(c.fallbackHint, isFalse);
    });
  });

  group('buildAiRestLines', () {
    List<RestLine> build(List<StockAiLine> lines) => buildAiRestLines(
      StockAiResult(lines),
      _catalog,
      _mine,
    );

    test('a confident line is pre-selected with location and origin', () {
      final l = build([
        const StockAiLine(
          spokenText: '2 Bacardi Investition bei Mario',
          materialId: 'm1',
          quantity: 2,
          location: _mario,
          locationHint: 'Mario',
          origin: StockOrigin.investment,
          note: 'Im System sind 1',
          confidence: 0.9,
        ),
      ]).single;
      expect(l.fromAi, isTrue);
      expect(l.aiNote, 'Im System sind 1');
      expect(l.chosenMaterialId, 'm1');
      expect(l.chosenMaterialName, 'Bacardi');
      expect(l.quantity, 2);
      expect(l.location, _mario);
      expect(l.locationUnresolved, isFalse);
      expect(l.origin, StockOrigin.investment);
      expect(l.originExplicit, isTrue);
    });

    test('no origin said: order, not explicit', () {
      final l = build([
        const StockAiLine(spokenText: 'a', materialId: 'm1', quantity: 1),
      ]).single;
      expect(l.origin, StockOrigin.order);
      expect(l.originExplicit, isFalse);
      expect(l.location, _mine);
    });

    test('ambiguous line keeps the pick flow with AI candidates', () {
      final l = build([
        const StockAiLine(
          spokenText: 'Sprite',
          candidateIds: ['m3', 'm4'],
          quantity: 1,
        ),
      ]).single;
      expect(l.chosenMaterialId, isNull);
      expect(l.candidates.map((c) => c.materialId), ['m3', 'm4']);
      expect(l.candidates.map((c) => c.name), ['Sprite', 'Sprite Zero']);
    });

    test('unknown article without candidates uses the catalog matcher', () {
      final l = build([
        const StockAiLine(spokenText: 'Spri', quantity: 1),
      ]).single;
      expect(l.chosenMaterialId, isNull);
      expect(l.candidates, isNotEmpty);
    });

    test('low confidence is not pre-selected', () {
      final l = build([
        const StockAiLine(
          spokenText: 'Bacardi?',
          materialId: 'm1',
          candidateIds: ['m2'],
          quantity: 1,
          confidence: 0.3,
        ),
      ]).single;
      expect(l.chosenMaterialId, isNull);
      expect(l.candidates.map((c) => c.materialId), ['m1', 'm2']);
    });

    test('missing quantity stays empty (user types it)', () {
      final l = build([
        const StockAiLine(spokenText: 'Bacardi', materialId: 'm1'),
      ]).single;
      expect(l.quantity, -1);
    });

    test('unknown location: default, flagged with the hint', () {
      final l = build([
        const StockAiLine(
          spokenText: 'a',
          materialId: 'm1',
          quantity: 1,
          locationHint: 'Peter',
        ),
      ]).single;
      expect(l.location, _mine);
      expect(l.locationUnresolved, isTrue);
      expect(l.parsed.locationHint, 'Peter');
    });
  });

  test('capture mode maps to the AI mode', () {
    expect(stockAiModeOf(CaptureMode.add), StockAiMode.add);
    expect(stockAiModeOf(CaptureMode.count), StockAiMode.count);
  });
}
