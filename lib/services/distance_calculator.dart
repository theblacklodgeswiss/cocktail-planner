import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Computes straight-line distance from the business origin (Allschwil,
/// Switzerland) to a customer-supplied address, geocoded via OpenStreetMap
/// Nominatim.
///
/// See docs/superpowers/specs/2026-09-15-auto-distance-calculation-design.md
/// for the design this implements.
class DistanceCalculator {
  /// Business origin: Allschwil, Switzerland (same origin already used for
  /// the Google Maps directions link elsewhere in the order form).
  static const _originLat = 47.5459; // geocoded once at design time
  static const _originLng = 7.5410;

  static const _nominatimEndpoint =
      'https://nominatim.openstreetmap.org/search';

  /// Geocodes [address] via OpenStreetMap Nominatim and returns the
  /// straight-line (Haversine) distance in whole km from the business
  /// origin, or null if the address could not be resolved.
  Future<int?> distanceKmFromAddress(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(_nominatimEndpoint).replace(queryParameters: {
        'q': address,
        'format': 'json',
        'limit': '1',
      });
      final response = await http.get(
        uri,
        // Nominatim's usage policy requires a descriptive User-Agent
        // identifying the application, not a browser UA string.
        headers: {
          'User-Agent': 'CocktailPlaner/1.0 (order form distance lookup)',
        },
      );
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) return null;
      final lat = double.tryParse(results.first['lat'] as String? ?? '');
      final lng = double.tryParse(results.first['lon'] as String? ?? '');
      if (lat == null || lng == null) return null;
      return haversineKm(_originLat, _originLng, lat, lng).round();
    } catch (_) {
      return null;
    }
  }

  /// Exposed with `@visibleForTesting` (rather than kept private) so unit
  /// tests can verify the Haversine calculation directly against a known
  /// coordinate pair, per the design spec's Testing section.
  @visibleForTesting
  double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * (pi / 180);
}

final distanceCalculator = DistanceCalculator();
