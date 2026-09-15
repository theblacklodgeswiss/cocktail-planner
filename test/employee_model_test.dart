import 'package:cocktail_planer/data/employee_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAccessEmail', () {
    test('lowercases and trims', () {
      expect(normalizeAccessEmail('  Foo@Example.COM  '), 'foo@example.com');
    });

    test('returns null for null input', () {
      expect(normalizeAccessEmail(null), isNull);
    });

    test('returns null for empty/whitespace-only input', () {
      expect(normalizeAccessEmail(''), isNull);
      expect(normalizeAccessEmail('   '), isNull);
    });
  });
}
