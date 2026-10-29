import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/services/voice_inventory_parser.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialItem _item(String name) => MaterialItem(
  unit: 'Flasche',
  name: name,
  price: 1,
  currency: 'EUR',
  note: '',
);

final _catalog = <(String, MaterialItem)>[
  ('rum', _item('Weisser Rum (Bacardi)')),
  ('v1', _item('Vodka (Grey Goose)')),
  ('v2', _item('Vodka (Ciroc)')),
  ('oj', _item('Orangen Saft')),
  ('sp', _item('Sprite')),
];

void main() {
  group('parseRestText', () {
    test('digits', () {
      final r = parseRestText('2 Bacardi');
      expect(r, hasLength(1));
      expect(r[0].quantity, 2);
      expect(r[0].spokenName, 'Bacardi');
      expect(r[0].locationHint, isNull);
      expect(r[0].originHint, isNull);
    });

    test('decimal with comma and dot', () {
      expect(parseRestText('2,8 Bacardi').single.quantity, 2.8);
      expect(parseRestText('2.8 Bacardi').single.quantity, 2.8);
      expect(parseRestText('2,8 Bacardi').single.spokenName, 'Bacardi');
    });

    test('spoken decimal', () {
      final r = parseRestText('zwei Komma acht Bacardi').single;
      expect(r.quantity, 2.8);
      expect(r.spokenName, 'Bacardi');
    });

    test('number words and halbe', () {
      expect(parseRestText('drei Sprite').single.quantity, 3);
      expect(parseRestText('zwanzig Sprite').single.quantity, 20);
      final h = parseRestText('halbe Flasche Kahlua').single;
      expect(h.quantity, 0.5);
      expect(h.spokenName, 'Kahlua');
    });

    test('splits on comma, und, semicolon and newline', () {
      expect(parseRestText('2 Bacardi, 6 Orangensaft'), hasLength(2));
      expect(parseRestText('2 Bacardi und 6 Orangensaft'), hasLength(2));
      expect(parseRestText('2 Bacardi; 6 Orangensaft'), hasLength(2));
      expect(parseRestText('2 Bacardi\n6 Orangensaft'), hasLength(2));
      final r = parseRestText('2 Bacardi und 6 Orangensaft');
      expect(r[1].quantity, 6);
      expect(r[1].spokenName, 'Orangensaft');
    });

    test('decimal comma does not split', () {
      final r = parseRestText('2,8 Bacardi, 1,5 Sprite');
      expect(r, hasLength(2));
      expect(r[1].quantity, 1.5);
    });

    test('location hint', () {
      final r = parseRestText('bei Mario 3 Sprite').single;
      expect(r.locationHint, 'Mario');
      expect(r.quantity, 3);
      expect(r.spokenName, 'Sprite');
    });

    test('origin hint', () {
      final r = parseRestText('2 Investition Bacardi').single;
      expect(r.originHint, StockOrigin.investment);
      expect(r.spokenName, 'Bacardi');
    });

    test('fragment without a number is skipped, not guessed', () {
      expect(parseRestText('Bacardi'), isEmpty);
      expect(parseRestText('Bacardi und 3 Sprite').single.spokenName, 'Sprite');
      expect(parseRestText(''), isEmpty);
      expect(parseRestText('2'), isEmpty);
    });
  });

  group('parseRestText quantity validation', () {
    test('negative and exponent forms are skipped', () {
      expect(parseRestText('-3 Sprite'), isEmpty);
      expect(parseRestText('1e3 Sprite'), isEmpty);
      expect(parseRestText('+3 Sprite'), isEmpty);
      expect(parseRestText('Infinity Sprite'), isEmpty);
      expect(parseRestText('NaN Sprite'), isEmpty);
      expect(parseRestText('1.2.3 Sprite'), isEmpty);
    });

    test('zero is valid: an empty bottle is a meaningful remainder', () {
      final r = parseRestText('0 Sprite').single;
      expect(r.quantity, 0);
      expect(parseRestText('null Sprite').single.quantity, 0);
    });
  });

  group('matchCatalog prefix strictness', () {
    List<(String, MaterialItem)> only(String n) => [('a', _item(n))];

    test('prefix hits alone are never confident', () {
      expect(isConfident(matchCatalog('Gin', only('Ginger Ale'))), isFalse);
      expect(isConfident(matchCatalog('Eis', only('Eistee'))), isFalse);
      expect(isConfident(matchCatalog('Sprite', only('Sprite Zero'))), isFalse);
      // Still offered as a candidate for manual confirmation.
      expect(matchCatalog('Sprite', only('Sprite Zero')), hasLength(1));
    });

    test('exact match wins outright over a longer name', () {
      final m = matchCatalog('Sprite', [
        ('z', _item('Sprite Zero')),
        ('s', _item('Sprite')),
      ]);
      expect(m.first.materialId, 's');
      expect(m.first.score, 1.0);
      expect(isConfident(m), isTrue);
    });

    test('two exact hits stay ambiguous', () {
      expect(isConfident(matchCatalog('Vodka', _catalog)), isFalse);
    });
  });

  group('matchCatalog', () {
    test('Bacardi matches via bracket addition, confident', () {
      final m = matchCatalog('Bacardi', _catalog);
      expect(m.first.materialId, 'rum');
      expect(m.first.name, 'Weisser Rum (Bacardi)');
      expect(isConfident(m), isTrue);
    });

    test('Vodka is ambiguous', () {
      final m = matchCatalog('Vodka', _catalog);
      expect(m.length, greaterThan(1));
      expect(isConfident(m), isFalse);
    });

    test('Orangensaft matches "Orangen Saft"', () {
      final m = matchCatalog('Orangensaft', _catalog);
      expect(m.first.materialId, 'oj');
      expect(isConfident(m), isTrue);
    });

    test('no hit gives empty, not confident', () {
      final m = matchCatalog('Tequila', _catalog);
      expect(m, isEmpty);
      expect(isConfident(m), isFalse);
    });

    test('max limits and sorts descending', () {
      final m = matchCatalog('Vodka', _catalog, max: 1);
      expect(m, hasLength(1));
      final all = matchCatalog('o', _catalog);
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].score, greaterThanOrEqualTo(all[i].score));
      }
    });
  });

  group('isConfident', () {
    CatalogMatch c(double s) =>
        CatalogMatch(materialId: 'x', name: 'x', score: s);
    test('rules', () {
      expect(isConfident([]), isFalse);
      expect(isConfident([c(0.9)]), isTrue);
      expect(isConfident([c(0.6)]), isFalse);
      expect(isConfident([c(0.9), c(0.85)]), isFalse);
      expect(isConfident([c(0.9), c(0.6)]), isTrue);
      expect(isConfident([c(0.7), c(0.6)]), isFalse);
    });
  });

  group('natural sentences', () {
    void one(String text, double q, String name, {String? loc}) {
      final l = parseRestText(text);
      expect(l, hasLength(1), reason: text);
      expect(l.single.quantity, q, reason: text);
      expect(l.single.spokenName, name, reason: text);
      expect(l.single.locationHint, loc, reason: text);
    }

    test('the reported sentence', () {
      one('Ich hab drei Flaschen Bacardi', 3, 'Bacardi');
    });

    test('leading fillers, any case, repeated, after a separator', () {
      for (final f in [
        'ich hab',
        'Ich habe',
        'ich hab noch',
        'wir haben',
        'Wir haben noch',
        'es sind',
        'Es sind noch',
        'da sind',
        'noch',
        'insgesamt',
        'ungefähr',
        'circa',
        'etwa',
        'so',
        'ca.',
        'ich hab noch ungefähr',
      ]) {
        one('$f drei Bacardi', 3, 'Bacardi');
      }
      final l = parseRestText('2 Vodka, ich hab noch 3 Gin');
      expect(l.map((e) => e.spokenName), ['Vodka', 'Gin']);
      expect(l[1].quantity, 3);
    });

    test('unit words are dropped, liter is kept', () {
      one('2 Packungen Schlagsahne', 2, 'Schlagsahne');
      for (final u in [
        'Flasche',
        'Flaschen',
        'Fl.',
        'Packung',
        'Pack',
        'Packs',
        'Kiste',
        'Kisten',
        'Karton',
        'Kartons',
        'Stück',
        'Stk',
        'x',
        'mal',
      ]) {
        one('4 $u Bacardi', 4, 'Bacardi');
      }
      one('2x Bacardi', 2, 'Bacardi');
      one('2 Orangen Saft 1L', 2, 'Orangen Saft 1L');
      one('3 Rum 0,7L', 3, 'Rum 0,7L');
    });

    test('articles and number words', () {
      one('eine Flasche Bacardi', 1, 'Bacardi');
      one('einen Gin', 1, 'Gin');
      one('einem Gin', 1, 'Gin');
      one('ein Sprite', 1, 'Sprite');
      one('eineinhalb Bacardi', 1.5, 'Bacardi');
      one('anderthalb Bacardi', 1.5, 'Bacardi');
      one('zweieinhalb Bacardi', 2.5, 'Bacardi');
      one('dreieinhalb Bacardi', 3.5, 'Bacardi');
      one('viereinhalb Bacardi', 4.5, 'Bacardi');
      one('dreißig Eis', 30, 'Eis');
      one('vierzig Eis', 40, 'Eis');
      one('fünfzig Eis', 50, 'Eis');
      one('halbe Flasche Bacardi', 0.5, 'Bacardi');
    });

    test('quantity after the name', () {
      one('Bacardi drei', 3, 'Bacardi');
      one('Bacardi 3 Flaschen', 3, 'Bacardi');
      one('Sprite zwei', 2, 'Sprite');
      one('Bacardi zwei Komma fünf', 2.5, 'Bacardi');
      // First number wins.
      one('3 Bacardi 5', 3, 'Bacardi 5');
    });

    test('location at the start, in the middle or at the end', () {
      one('bei Mario habe ich 3 Sprite', 3, 'Sprite', loc: 'Mario');
      one('bei Mario 3 Sprite', 3, 'Sprite', loc: 'Mario');
      one('3 Sprite bei Mario', 3, 'Sprite', loc: 'Mario');
    });

    test('origin word anywhere, punctuation tolerant', () {
      var l = parseRestText('3 Bacardi Investition').single;
      expect(l.originHint, StockOrigin.investment);
      expect(l.spokenName, 'Bacardi');
      l = parseRestText('Investition 3 Bacardi').single;
      expect(l.originHint, StockOrigin.investment);
      expect(l.spokenName, 'Bacardi');
      l = parseRestText('3 Bacardi Auftrag.').single;
      expect(l.originHint, StockOrigin.order);
      expect(l.spokenName, 'Bacardi');
      one('  3   Bacardi,  ', 3, 'Bacardi');
    });

    test('mixed sentences', () {
      var l = parseRestText(
        'Ich habe noch 2 Flaschen Vodka und 6 Packungen Orangensaft',
      );
      expect(l.map((e) => (e.quantity, e.spokenName)), [
        (2.0, 'Vodka'),
        (6.0, 'Orangensaft'),
      ]);
      l = parseRestText('ich hab drei Flaschen Bacardi und zwei Kahlua');
      expect(l.map((e) => (e.quantity, e.spokenName)), [
        (3.0, 'Bacardi'),
        (2.0, 'Kahlua'),
      ]);
      one('zwei Komma fünf Bacardi', 2.5, 'Bacardi');
      one('2,5 Bacardi', 2.5, 'Bacardi');
    });

    test('negative and garbage numbers are still rejected', () {
      expect(parseRestText('-3 Bacardi'), isEmpty);
      expect(parseRestText('1e5 Bacardi'), isEmpty);
      expect(parseRestText('NaN Bacardi'), isEmpty);
    });
  });

  group('parseRestTextDetailed', () {
    test('reports fragments without a number', () {
      final r = parseRestTextDetailed('Bacardi');
      expect(r.lines, isEmpty);
      expect(r.unparsed, ['Bacardi']);
    });

    test('mixes lines and unparsed fragments', () {
      final r = parseRestTextDetailed('2 Vodka, ich hab noch Kahlua');
      expect(r.lines.single.spokenName, 'Vodka');
      expect(r.unparsed, ['Kahlua']);
    });

    test('number without a name keeps the raw fragment', () {
      final r = parseRestTextDetailed('Ich hab drei');
      expect(r.lines, isEmpty);
      expect(r.unparsed, hasLength(1));
    });

    test('empty and filler-only input yields nothing', () {
      for (final t in ['', '   ', ',', 'ich habe noch']) {
        final r = parseRestTextDetailed(t);
        expect(r.lines, isEmpty, reason: t);
        expect(r.unparsed, isEmpty, reason: t);
      }
    });
  });

  group('matching natural names', () {
    final cat = <(String, MaterialItem)>[
      ('rum', _item('Weisser Rum (Bacardi)')),
      ('sprite', _item('Sprite')),
      ('spritez', _item('Sprite Zero')),
      ('os', _item('Orangen Saft')),
      ('kahlua', _item('Kahlua')),
      ('vodka1', _item('Vodka Absolut')),
      ('vodka2', _item('Vodka Smirnoff')),
    ];

    test('confident hits', () {
      for (final (q, id) in [
        ('Bacardi', 'rum'),
        ('Sprite', 'sprite'),
        ('Orangensaft', 'os'),
        ('Kahlua', 'kahlua'),
      ]) {
        final m = matchCatalog(q, cat);
        expect(isConfident(m), isTrue, reason: q);
        expect(m.first.materialId, id, reason: q);
      }
    });

    test('never guesses between two exact twins', () {
      final twins = [...cat, ('os2', _item('Orangensaft'))];
      expect(isConfident(matchCatalog('Orangensaft', twins)), isFalse);
      expect(isConfident(matchCatalog('Vodka', cat)), isFalse);
    });
  });
}
