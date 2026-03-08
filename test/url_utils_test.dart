import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/utils/url_utils.dart';

void main() {
  group('URL Utils', () {
    test('updateBrowserUrl does not throw on non-web platforms', () {
      // On non-web platforms (like test environment), this should be a no-op
      expect(
        () => updateBrowserUrl('/test-path'),
        returnsNormally,
      );
    });

    test('updateBrowserUrl accepts various path formats', () {
      expect(() => updateBrowserUrl('/'), returnsNormally);
      expect(() => updateBrowserUrl('/orders'), returnsNormally);
      expect(() => updateBrowserUrl('/order-form?step=1'), returnsNormally);
      expect(() => updateBrowserUrl('/orders?status=accepted'), returnsNormally);
    });

    test('handles paths with multiple query parameters', () {
      expect(
        () => updateBrowserUrl('/order-form?step=2&edit=true'),
        returnsNormally,
      );
    });

    test('handles paths with special characters', () {
      expect(
        () => updateBrowserUrl('/orders?name=Test%20Order'),
        returnsNormally,
      );
    });

    test('handles empty and root paths', () {
      expect(() => updateBrowserUrl(''), returnsNormally);
      expect(() => updateBrowserUrl('/'), returnsNormally);
    });

    test('handles paths with fragments', () {
      expect(
        () => updateBrowserUrl('/orders#section-1'),
        returnsNormally,
      );
    });

    test('handles deeply nested paths', () {
      expect(
        () => updateBrowserUrl('/admin/settings/users'),
        returnsNormally,
      );
    });
  });

  group('URL Path Parsing', () {
    test('query parameter extraction patterns', () {
      // These test the URL patterns used in the app
      final uri1 = Uri.parse('http://localhost:52229/order-form?step=1');
      expect(uri1.queryParameters['step'], '1');

      final uri2 = Uri.parse('http://localhost:52229/orders?status=accepted');
      expect(uri2.queryParameters['status'], 'accepted');

      final uri3 = Uri.parse(
          'http://localhost:52229/order-form?step=3&edit=true&orderId=abc123');
      expect(uri3.queryParameters['step'], '3');
      expect(uri3.queryParameters['edit'], 'true');
      expect(uri3.queryParameters['orderId'], 'abc123');
    });

    test('handles missing query parameters', () {
      final uri = Uri.parse('http://localhost:52229/orders');
      expect(uri.queryParameters['status'], isNull);
      expect(uri.queryParameters.isEmpty, true);
    });

    test('handles encoded query parameters', () {
      final uri = Uri.parse(
          'http://localhost:52229/orders?name=Test%20Order&location=Z%C3%BCrich');
      expect(uri.queryParameters['name'], 'Test Order');
      expect(uri.queryParameters['location'], 'Zürich');
    });
  });

  group('Route Patterns', () {
    test('form step URLs follow correct pattern', () {
      for (int step = 0; step <= 6; step++) {
        final url = '/order-form?step=$step';
        final uri = Uri.parse('http://localhost$url');
        expect(uri.path, '/order-form');
        expect(uri.queryParameters['step'], step.toString());
      }
    });

    test('orders filter URLs follow correct pattern', () {
      final statuses = ['quote', 'accepted', 'declined', 'all'];
      for (final status in statuses) {
        final url = '/orders?status=$status';
        final uri = Uri.parse('http://localhost$url');
        expect(uri.path, '/orders');
        expect(uri.queryParameters['status'], status);
      }
    });

    test('validates clean URLs without query params', () {
      final routes = [
        '/',
        '/login',
        '/orders',
        '/pending-orders',
        '/shopping-list',
        '/admin',
        '/settings',
      ];

      for (final route in routes) {
        final uri = Uri.parse('http://localhost$route');
        expect(uri.path, route);
        expect(uri.queryParameters.isEmpty, true);
      }
    });
  });

  group('Browser History Behavior', () {
    test('URL changes should not affect navigation stack', () {
      // This documents the expected behavior:
      // updateBrowserUrl should change the URL in the browser
      // without affecting GoRouter's navigation stack
      
      // On the test platform, this is a no-op, but we verify
      // it doesn't throw or cause issues
      expect(
        () {
          updateBrowserUrl('/order-form?step=0');
          updateBrowserUrl('/order-form?step=1');
          updateBrowserUrl('/order-form?step=2');
        },
        returnsNormally,
      );
    });

    test('supports rapid URL updates', () {
      // Simulates user clicking through form steps quickly
      expect(
        () {
          for (int i = 0; i < 10; i++) {
            updateBrowserUrl('/order-form?step=$i');
          }
        },
        returnsNormally,
      );
    });
  });
}
