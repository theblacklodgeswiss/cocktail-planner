import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/services/distance_calculator.dart';

void main() {
  group('DistanceCalculator.haversineKm', () {
    final calculator = DistanceCalculator();

    test('returns 0 for identical coordinates', () {
      final distance = calculator.haversineKm(47.5459, 7.5410, 47.5459, 7.5410);
      expect(distance, closeTo(0, 0.001));
    });

    test('matches known real-world distance (New York to Los Angeles)', () {
      // Straight-line distance between these two well-known coordinate
      // pairs is ~3936 km (per common geodesic references).
      const nyLat = 40.7128, nyLng = -74.0060;
      const laLat = 34.0522, laLng = -118.2437;

      final distance = calculator.haversineKm(nyLat, nyLng, laLat, laLng);

      expect(distance, closeTo(3936, 30));
    });

    test('matches known real-world distance (London to Paris)', () {
      // Straight-line distance London <-> Paris is ~344 km.
      const londonLat = 51.5074, londonLng = -0.1278;
      const parisLat = 48.8566, parisLng = 2.3522;

      final distance = calculator.haversineKm(
        londonLat,
        londonLng,
        parisLat,
        parisLng,
      );

      expect(distance, closeTo(344, 10));
    });

    test('is symmetric regardless of point order', () {
      const aLat = 47.5459, aLng = 7.5410;
      const bLat = 46.9480, bLng = 7.4474; // Bern, Switzerland

      final forward = calculator.haversineKm(aLat, aLng, bLat, bLng);
      final backward = calculator.haversineKm(bLat, bLng, aLat, aLng);

      expect(forward, closeTo(backward, 0.001));
    });
  });

  group('DistanceCalculator.distanceKmFromAddress', () {
    final calculator = DistanceCalculator();

    test('returns null for an empty address without making a network call', () {
      expect(calculator.distanceKmFromAddress(''), completion(isNull));
    });

    test('returns null for a whitespace-only address', () {
      expect(calculator.distanceKmFromAddress('   '), completion(isNull));
    });

    // NOTE: this codebase has no existing precedent for injecting a fake
    // `http.Client` into a service class (searched lib/ and test/ for
    // `http.Client` usage - none found), and DistanceCalculator is
    // implemented exactly per the design spec's section 1, which takes no
    // injectable client. Per the design spec's Testing section
    // ("if [an injection precedent] is not [present], test what's
    // practically testable and say so"), the four network-outcome cases
    // (found address, empty results array, non-200 status, malformed JSON)
    // are not covered here: they all require either hitting the real
    // Nominatim endpoint (unavailable/unreliable in CI) or introducing a
    // new DI seam into DistanceCalculator that the spec's given
    // implementation does not include. The empty/whitespace short-circuit
    // above is covered because it returns before any network call.
  });
}
