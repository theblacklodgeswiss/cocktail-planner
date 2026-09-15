import 'package:cocktail_planer/models/additional_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServiceVariant', () {
    test('fromMap parses well-formed data', () {
      final variant = ServiceVariant.fromMap({
        'id': 'v1',
        'name': 'inkl. 300 Druck',
        'price': 500.0,
      });
      expect(variant.id, 'v1');
      expect(variant.name, 'inkl. 300 Druck');
      expect(variant.price, 500.0);
    });

    test('fromMap treats missing price as null (Preis auf Anfrage)', () {
      final variant = ServiceVariant.fromMap({'id': 'v1', 'name': 'DJ'});
      expect(variant.price, isNull);
    });

    test('fromMap defaults missing id/name to empty string', () {
      final variant = ServiceVariant.fromMap(const {});
      expect(variant.id, '');
      expect(variant.name, '');
      expect(variant.price, isNull);
    });

    test('fromMap accepts an int price and converts to double', () {
      final variant = ServiceVariant.fromMap({
        'id': 'v1',
        'name': 'DJ',
        'price': 300,
      });
      expect(variant.price, 300.0);
    });

    test('toMap round-trips, omitting a null price', () {
      const variant = ServiceVariant(id: 'v1', name: 'DJ');
      final map = variant.toMap();
      expect(map.containsKey('price'), isFalse);
      expect(ServiceVariant.fromMap(map).name, 'DJ');
    });

    test('toMap includes a non-null price', () {
      const variant = ServiceVariant(id: 'v1', name: 'DJ', price: 300.0);
      expect(variant.toMap()['price'], 300.0);
    });
  });

  group('AdditionalService', () {
    test('fromFirestore parses well-formed data with variants', () {
      final service = AdditionalService.fromFirestore('s1', {
        'name': 'BlackLodge PhotoBox',
        'imageUrl': 'https://example.com/photo.png',
        'sortOrder': 2,
        'variants': [
          {'id': 'v1', 'name': 'inkl. 300 Druck', 'price': 500.0},
          {'id': 'v2', 'name': 'Digital mit QR-Code', 'price': 300.0},
        ],
      });

      expect(service.id, 's1');
      expect(service.name, 'BlackLodge PhotoBox');
      expect(service.imageUrl, 'https://example.com/photo.png');
      expect(service.sortOrder, 2);
      expect(service.variants, hasLength(2));
      expect(service.variants[0].name, 'inkl. 300 Druck');
    });

    test('fromFirestore defaults missing optional fields', () {
      final service = AdditionalService.fromFirestore('s1', {'name': 'DJ'});
      expect(service.imageUrl, isNull);
      expect(service.sortOrder, 0);
      expect(service.variants, isEmpty);
    });

    test('fromFirestore skips malformed variant entries', () {
      final service = AdditionalService.fromFirestore('s1', {
        'name': 'PhotoBox',
        'variants': [
          {'id': 'v1', 'name': 'Good variant'},
          'not a map',
          null,
          42,
        ],
      });
      expect(service.variants, hasLength(1));
      expect(service.variants.single.name, 'Good variant');
    });

    test('variantById finds a matching variant', () {
      final service = AdditionalService.fromFirestore('s1', {
        'name': 'PhotoBox',
        'variants': [
          {'id': 'v1', 'name': 'Print', 'price': 500.0},
          {'id': 'v2', 'name': 'QR', 'price': 300.0},
        ],
      });
      expect(service.variantById('v2')?.name, 'QR');
    });

    test('variantById returns null for an unknown variant id', () {
      final service = AdditionalService.fromFirestore('s1', {
        'name': 'PhotoBox',
        'variants': [
          {'id': 'v1', 'name': 'Print'},
        ],
      });
      expect(service.variantById('missing'), isNull);
    });

    test('toMap omits a null/empty imageUrl', () {
      const service = AdditionalService(id: 's1', name: 'DJ');
      expect(service.toMap().containsKey('imageUrl'), isFalse);
    });
  });
}
