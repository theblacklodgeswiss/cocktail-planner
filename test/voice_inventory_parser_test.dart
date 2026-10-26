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
}
