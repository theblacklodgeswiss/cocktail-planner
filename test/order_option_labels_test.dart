import 'package:cocktail_planer/models/additional_service.dart';
import 'package:cocktail_planer/utils/order_option_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = [
    AdditionalService.fromFirestore('s1', {
      'name': 'BlackLodge PhotoBox',
      'variants': [
        {'id': 'v1', 'name': 'inkl. 300 Druck', 'price': 500.0},
        {'id': 'v2', 'name': 'Digital mit QR-Code'},
      ],
    }),
  ];

  group('resolveAdditionalServiceLabel', () {
    test('resolves a composite serviceId:variantId against the catalog', () {
      final label = resolveAdditionalServiceLabel(
        's1:v1',
        catalog: catalog,
        currencyCode: 'CHF',
      );
      expect(label, 'BlackLodge PhotoBox - inkl. 300 Druck (500 CHF)');
    });

    test('renders "Preis auf Anfrage" for a variant with no price (de)', () {
      final label = resolveAdditionalServiceLabel(
        's1:v2',
        catalog: catalog,
      );
      expect(label, contains('Preis auf Anfrage'));
    });

    test('renders "price on request" for a variant with no price (en)', () {
      final label = resolveAdditionalServiceLabel(
        's1:v2',
        catalog: catalog,
        isEnglish: true,
      );
      expect(label, contains('price on request'));
    });

    test(
        'falls back to the legacy static map when the service was deleted',
        () {
      final label = resolveAdditionalServiceLabel(
        'deleted_service:v1',
        catalog: catalog,
        currencyCode: 'CHF',
      );
      // Unresolvable composite id: falls back to
      // formatOrderAdditionalServiceLabel, which returns the raw value
      // unchanged since it isn't in the legacy static map either.
      expect(label, 'deleted_service:v1');
    });

    test(
        'falls back to the legacy static map for a legacy bare ID, '
        'byte-identical to formatOrderAdditionalServiceLabel', () {
      final resolved = resolveAdditionalServiceLabel(
        'booth_360',
        catalog: catalog,
        currencyCode: 'CHF',
      );
      final legacy = formatOrderAdditionalServiceLabel(
        'booth_360',
        currencyCode: 'CHF',
      );
      expect(resolved, legacy);
      expect(resolved, contains('360 Booth'));
    });

    test('falls back for a value with no catalog entry and no colon', () {
      final label = resolveAdditionalServiceLabel(
        'unknown_value',
        catalog: catalog,
      );
      expect(label, 'unknown_value');
    });
  });

  group('resolveAdditionalServicePrice', () {
    test('returns the resolved variant price for a composite id', () {
      expect(
        resolveAdditionalServicePrice('s1:v1', catalog: catalog),
        500.0,
      );
    });

    test('returns null for a variant with no price (Preis auf Anfrage)', () {
      expect(resolveAdditionalServicePrice('s1:v2', catalog: catalog), isNull);
    });

    test('returns null for a legacy bare ID', () {
      expect(
        resolveAdditionalServicePrice('booth_360', catalog: catalog),
        isNull,
      );
    });

    test('returns null when the service was deleted from the catalog', () {
      expect(
        resolveAdditionalServicePrice('deleted:v1', catalog: catalog),
        isNull,
      );
    });
  });
}
