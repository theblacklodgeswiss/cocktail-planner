import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/utils/short_code.dart';

void main() {
  group('generateShortCode', () {
    test('returns an 8-character string', () {
      final code = generateShortCode();
      expect(code.length, 8);
    });

    test('only contains base62 characters', () {
      final code = generateShortCode();
      expect(RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(code), isTrue);
    });

    test('two calls return different codes', () {
      final a = generateShortCode();
      final b = generateShortCode();
      expect(a, isNot(equals(b)));
    });
  });
}
