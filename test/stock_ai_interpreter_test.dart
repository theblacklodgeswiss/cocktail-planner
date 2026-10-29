import 'dart:convert';

import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/services/stock_ai_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialItem _item(String name, [String unit = 'Fl.']) =>
    MaterialItem(unit: unit, name: name, price: 1, currency: 'EUR', note: '');

const _mine = StorageLocation(
  id: 'a',
  name: 'Prince',
  ownerEmail: 'prince@example.com',
);
const _mario = StorageLocation(
  id: 'b',
  name: 'Mario',
  ownerEmail: 'mario@example.com',
);

final _catalog = [
  ('m1', _item('Bacardi')),
  ('m2', _item('Orangensaft', 'Packung')),
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

StockInterpretRequest _request({
  String text = '2 Bacardi bei Mario',
  StockAiMode mode = StockAiMode.add,
  List<StockEntry>? stock,
}) => StockInterpretRequest(
  text: text,
  mode: mode,
  catalog: _catalog,
  locations: const [_mine, _mario],
  defaultLocation: _mine,
  stock:
      stock ??
      [
        _stock('m1', 'a', StockOrigin.order, 3),
        _stock('m1', 'a', StockOrigin.investment, 2),
        _stock('m1', 'b', StockOrigin.order, 1),
      ],
);

StockAiResult? _parse(String s) =>
    parseStockInterpretation(s, _catalog, const [_mine, _mario]);

String _json(List<Map<String, Object?>> lines) => jsonEncode({'lines': lines});

void main() {
  group('buildStockInterpretPrompt', () {
    test('is deterministic', () {
      expect(
        buildStockInterpretPrompt(_request()),
        buildStockInterpretPrompt(_request()),
      );
    });

    test('contains catalog, locations, default and the stock summary', () {
      final p = buildStockInterpretPrompt(_request());
      expect(p, contains('m1 | Bacardi | Fl.'));
      expect(p, contains('m2 | Orangensaft | Packung'));
      expect(p, contains('Prince (Standard)'));
      expect(p, contains('Mario'));
      expect(
        p,
        contains('m1: gesamt 6 – Prince: Auftrag 3, Investition 2; Mario: '
            'Auftrag 1'),
      );
      // Articles without stock are not listed in the summary.
      expect(p, isNot(contains('m2: gesamt')));
      expect(p, contains('2 Bacardi bei Mario'));
      expect(p, contains('{"lines":['));
    });

    test('never contains e-mail addresses', () {
      final p = buildStockInterpretPrompt(_request());
      expect(p, isNot(contains('@')));
      expect(p, isNot(contains('example.com')));
    });

    test('names the mode', () {
      expect(buildStockInterpretPrompt(_request()), contains('MODUS: DAZU'));
      expect(
        buildStockInterpretPrompt(_request(mode: StockAiMode.count)),
        contains('MODUS: ZÄHLUNG'),
      );
    });

    test('caps the text at 500 characters', () {
      final long = 'x' * 900;
      final p = buildStockInterpretPrompt(_request(text: long));
      expect(p, contains('x' * stockAiMaxTextLength));
      expect(p, isNot(contains('x' * (stockAiMaxTextLength + 1))));
    });

    test('an empty stock is stated', () {
      final p = buildStockInterpretPrompt(_request(stock: const []));
      expect(p, contains('(kein Bestand)'));
    });
  });

  group('parseStockInterpretation', () {
    test('valid JSON', () {
      final r = _parse(
        _json([
          {
            'text': '2 Bacardi bei Mario',
            'materialId': 'm1',
            'candidateIds': [],
            'quantity': 2,
            'location': 'Mario',
            'origin': null,
            'note': null,
            'confidence': 0.9,
          },
        ]),
      )!;
      final l = r.lines.single;
      expect(l.spokenText, '2 Bacardi bei Mario');
      expect(l.materialId, 'm1');
      expect(l.quantity, 2.0);
      expect(l.location, _mario);
      expect(l.locationHint, 'Mario');
      expect(l.origin, isNull);
      expect(l.note, isNull);
      expect(l.confidence, 0.9);
      expect(l.fromAi, isTrue);
    });

    test('fenced JSON', () {
      final r = _parse(
        '```json\n${_json([
          {'text': 'drei Sprite', 'materialId': 'm3', 'quantity': 3},
        ])}\n```',
      )!;
      expect(r.lines.single.materialId, 'm3');
      expect(r.lines.single.quantity, 3.0);
    });

    test('prose around the JSON', () {
      final r = _parse(
        'Hier ist das Ergebnis: ${_json([
          {'text': 'Bacardi', 'materialId': 'm1', 'quantity': 0.5},
        ])} Viel Erfolg!',
      )!;
      expect(r.lines.single.quantity, 0.5);
    });

    test('malformed JSON gives null', () {
      expect(_parse('{"lines": [ {"text": '), isNull);
      expect(_parse('Ich kann das nicht.'), isNull);
      expect(_parse(''), isNull);
      expect(_parse('{"items": []}'), isNull);
      expect(_parse('[1, 2]'), isNull);
    });

    test('empty lines list is a valid, empty result', () {
      expect(_parse('{"lines": []}')!.lines, isEmpty);
    });

    test('unknown materialId becomes null; only known candidates kept', () {
      final l = _parse(
        _json([
          {
            'text': 'Sprit',
            'materialId': 'x9',
            'candidateIds': ['m3', 'nope', 'm4', 'm3'],
            'quantity': 1,
          },
        ]),
      )!.lines.single;
      expect(l.materialId, isNull);
      expect(l.candidateIds, ['m3', 'm4']);
    });

    test('candidates exclude the chosen id and are capped at 3', () {
      final l = _parse(
        _json([
          {
            'text': 'Sprite',
            'materialId': 'm3',
            'candidateIds': ['m3', 'm4', 'm1', 'm2'],
            'quantity': 1,
          },
        ]),
      )!.lines.single;
      expect(l.candidateIds, ['m4', 'm1', 'm2']);
    });

    test('negative, NaN, non-number and huge quantities are dropped', () {
      final r = _parse(
        '{"lines":['
        '{"text":"a","materialId":"m1","quantity":-2},'
        '{"text":"b","materialId":"m1","quantity":"NaN"},'
        '{"text":"c","materialId":"m1","quantity":"drei"},'
        '{"text":"d","materialId":"m1","quantity":10001},'
        '{"text":"e","materialId":"m1","quantity":1e400},'
        '{"text":"f","materialId":"m1","quantity":10000}'
        ']}',
      )!;
      expect(r.lines.map((l) => l.quantity), [
        null,
        null,
        null,
        null,
        null,
        10000.0,
      ]);
    });

    test('unknown location becomes null but keeps the hint; case-insensitive '
        'match', () {
      final r = _parse(
        _json([
          {'text': 'a', 'materialId': 'm1', 'quantity': 1, 'location': 'Peter'},
          {'text': 'b', 'materialId': 'm2', 'quantity': 1, 'location': 'mario'},
          {'text': 'c', 'materialId': 'm3', 'quantity': 1, 'location': 7},
        ]),
      )!;
      expect(r.lines[0].location, isNull);
      expect(r.lines[0].locationHint, 'Peter');
      expect(r.lines[1].location, _mario);
      expect(r.lines[2].location, isNull);
      expect(r.lines[2].locationHint, isNull);
    });

    test('origin only order or investment', () {
      final r = _parse(
        _json([
          {'text': 'a', 'materialId': 'm1', 'quantity': 1, 'origin': 'order'},
          {
            'text': 'b',
            'materialId': 'm2',
            'quantity': 1,
            'origin': 'investment',
          },
          {'text': 'c', 'materialId': 'm3', 'quantity': 1, 'origin': 'gift'},
        ]),
      )!;
      expect(r.lines.map((l) => l.origin), [
        StockOrigin.order,
        StockOrigin.investment,
        null,
      ]);
    });

    test('note is trimmed and capped; confidence clamped', () {
      final r = _parse(
        _json([
          {
            'text': 'a',
            'materialId': 'm1',
            'quantity': 20,
            'note': '  Im System sind 2  ',
            'confidence': 3,
          },
          {
            'text': 'b',
            'materialId': 'm2',
            'quantity': 1,
            'note': 'n' * 400,
            'confidence': -1,
          },
          {'text': 'c', 'materialId': 'm3', 'quantity': 1, 'note': ''},
        ]),
      )!;
      expect(r.lines[0].note, 'Im System sind 2');
      expect(r.lines[0].confidence, 1.0);
      expect(r.lines[1].note!.length, stockAiMaxNoteLength);
      expect(r.lines[1].confidence, 0.0);
      expect(r.lines[2].note, isNull);
    });

    test('duplicates are removed, order kept', () {
      final line = {'text': '2 Bacardi', 'materialId': 'm1', 'quantity': 2};
      final r = _parse(
        _json([
          line,
          {'text': '6 Orangensaft', 'materialId': 'm2', 'quantity': 6},
          line,
        ]),
      )!;
      expect(r.lines.map((l) => l.materialId), ['m1', 'm2']);
    });

    test('more than 40 lines are capped', () {
      final r = _parse(
        _json([
          for (var i = 0; i < 60; i++)
            {'text': 'Zeile $i', 'materialId': 'm1', 'quantity': i},
        ]),
      )!;
      expect(r.lines, hasLength(stockAiMaxLines));
      expect(r.lines.last.spokenText, 'Zeile 39');
    });

    test('non-object lines and lines without text or article are skipped', () {
      final r = _parse(
        '{"lines":[1,"x",null,{"quantity":2},'
        '{"text":"","materialId":null},'
        '{"materialId":"m1","quantity":2}]}',
      )!;
      // A known article without text keeps its name as text.
      expect(r.lines.single.materialId, 'm1');
      expect(r.lines.single.spokenText, 'Bacardi');
    });
  });

  group('isModelNotFoundError', () {
    test('404 not_found_error naming the model', () {
      expect(
        isModelNotFoundError(
          404,
          '{"type":"error","error":{"type":"not_found_error",'
          '"message":"model: claude-haiku-5-5"}}',
        ),
        isTrue,
      );
    });

    test('400 invalid model', () {
      expect(
        isModelNotFoundError(
          400,
          '{"type":"error","error":{"type":"invalid_request_error",'
          '"message":"Invalid model name"}}',
        ),
        isTrue,
      );
    });

    test('other errors are not', () {
      expect(isModelNotFoundError(429, 'rate_limit_error model'), isFalse);
      expect(
        isModelNotFoundError(
          400,
          '{"error":{"type":"invalid_request_error","message":"max_tokens"}}',
        ),
        isFalse,
      );
      expect(isModelNotFoundError(500, 'model'), isFalse);
    });
  });
}
