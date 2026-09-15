import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A geocoded coordinate pair.
class _LatLng {
  const _LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Computes the round-trip driving distance from the business origin
/// (Allschwil, Switzerland) to a customer-supplied address: the actual road
/// route (not straight-line), doubled to cover the drive there AND back.
///
/// Geocoding via OpenStreetMap Nominatim, routing via the free public OSRM
/// demo server — both free, no API key. If routing fails for any reason
/// (network error, no route found), falls back to a straight-line
/// (Haversine) estimate rather than returning nothing.
///
/// See docs/superpowers/specs/2026-09-15-auto-distance-calculation-design.md
/// for the original design; the switch from straight-line-only to
/// route-based-with-round-trip was a follow-up refinement.
class DistanceCalculator {
  /// Business origin: Allschwil, Switzerland (same origin already used for
  /// the Google Maps directions link elsewhere in the order form).
  static const _originLat = 47.5459; // geocoded once at design time
  static const _originLng = 7.5410;

  static const _nominatimEndpoint =
      'https://nominatim.openstreetmap.org/search';
  static const _osrmEndpoint = 'https://router.project-osrm.org/route/v1/driving';

  /// Geocodes [address] and returns the round-trip (there-and-back) driving
  /// distance in whole km from the business origin, or null if the address
  /// could not be resolved.
  Future<int?> distanceKmFromAddress(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final destination = await _geocode(address);
      if (destination == null) return null;
      final oneWayKm = await _routeDistanceKm(destination) ??
          haversineKm(_originLat, _originLng, destination.lat, destination.lng);
      return (oneWayKm * 2).round();
    } catch (_) {
      return null;
    }
  }

  Future<_LatLng?> _geocode(String address) async {
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
    return _LatLng(lat, lng);
  }

  /// Actual one-way road distance in km via OSRM, or null if the routing
  /// call fails/finds no route (caller falls back to straight-line).
  Future<double?> _routeDistanceKm(_LatLng destination) async {
    try {
      final uri = Uri.parse(
        '$_osrmEndpoint/$_originLng,$_originLat;${destination.lng},${destination.lat}',
      ).replace(queryParameters: {'overview': 'false'});
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final meters = (routes.first['distance'] as num?)?.toDouble();
      if (meters == null) return null;
      return meters / 1000;
    } catch (_) {
      return null;
    }
  }

  /// Exposed with `@visibleForTesting` (rather than kept private) so unit
  /// tests can verify the Haversine calculation directly against a known
  /// coordinate pair. Used only as a fallback when OSRM routing fails.
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
