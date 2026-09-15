# Automatic Distance Calculation from Address

Date: 2026-09-15
Status: Design approved, not yet planned

## Problem

The order form's "Deine Präferenzen" step lets the customer set travel
distance themselves with a bare 0–1000 km slider
(`_buildDistanceSlider()`, `lib/screens/forms/modern_order_form_screen.dart:1684-1731`,
called from `_buildPreferencesStep` at line 1618). A guest customer has no
way to know the actual driving distance from their venue to the business
(Allschwil, CH — already referenced as the fixed origin for a Google Maps
directions link at line 1543), so this number is effectively a guess, yet it
directly drives travel-cost calculation later in the offer
(`create_offer_screen.dart`'s `travelCostPerKm * distanceKm`).

The form already collects the event address in an earlier step
(`_addressController`, bound at line 1368, already triggering a rebuild on
every keystroke via a listener at line 96).

## Goals

- A guest customer never sees or touches a distance slider. Distance is
  computed automatically from the address they already typed, and updates as
  they keep editing that address.
- An employee or admin can still see and manually override the number — the
  existing slider stays, just gated to employee-or-higher instead of shown to
  everyone.
- No paid API, no API key to provision or rotate.

## Non-goals

- Real driving-route distance. The chosen approach (see below) computes
  straight-line distance, not the actual road route — accepted trade-off per
  the "no cost" requirement; a follow-up could swap in a paid routing API
  later without changing the UI, since the calculation is isolated behind one
  function (see "Isolation" below).
- Blocking form submission on a failed lookup — a guest whose address can't
  be geocoded (typo, an address the geocoder doesn't recognize) is not
  stopped from continuing; distance simply stays at its default and staff
  correct it later, per the answered design question.

## 1. Geocoding and distance calculation

New file `lib/services/distance_calculator.dart`:

```dart
class DistanceCalculator {
  /// Business origin: Allschwil, Switzerland (same origin already used for
  /// the Google Maps directions link elsewhere in the order form).
  static const _originLat = 47.5459; // geocoded once at design time
  static const _originLng = 7.5410;

  static const _nominatimEndpoint = 'https://nominatim.openstreetmap.org/search';

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
        headers: {'User-Agent': 'CocktailPlaner/1.0 (order form distance lookup)'},
      );
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) return null;
      final lat = double.tryParse(results.first['lat'] as String? ?? '');
      final lng = double.tryParse(results.first['lon'] as String? ?? '');
      if (lat == null || lng == null) return null;
      return _haversineKm(_originLat, _originLng, lat, lng).round();
    } catch (_) {
      return null;
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * (pi / 180);
}

final distanceCalculator = DistanceCalculator();
```

**Isolation**: every caller only ever calls `distanceKmFromAddress(address)`
and gets an `int?` back. Swapping Nominatim+Haversine for a paid routing API
later is a change entirely inside this one file/class — no caller changes.

**Nominatim usage policy**: max ~1 request/second, no heavy/bulk use, a
descriptive `User-Agent` header (not a generic HTTP client default) — the
debounce in section 2 keeps this comfortably within policy for a single
customer typing an address; this is not a bulk-geocoding use case.

## 2. Wiring into the order form

In `_ModernOrderFormScreenState`:

- Add `Timer? _distanceLookupDebounce;` and cancel it in `dispose()`.
- In the `_addressController`'s existing listener (line 96, currently just
  `setState(() {})`), add: if the current user is NOT employee-or-higher
  (guests only — an employee's manually-set value should never be
  silently overwritten by a background lookup), cancel any pending debounce
  timer and start a new 800ms one that calls
  `distanceCalculator.distanceKmFromAddress(_addressController.text)` and,
  on a non-null result, `setState(() => _distanceKm = result)`. On a null
  result (lookup failed or still empty), leave `_distanceKm` untouched — per
  the answered design question, this is not an error state that blocks
  anything, it just means the field keeps whatever value it already had
  (its existing default).
- `_buildDistanceSlider()` (line 1684) is gated behind
  `authService.isEmployeeOrHigher` (the same getter already used elsewhere in
  this file as `_isAdminUser`, e.g. line 226) exactly like the other
  staff-only sections of this form (line 2968's pattern:
  `if (MediaQuery.of(context).size.width >= 600 && _isAdminUser)`). When
  hidden, replace it with a small read-only row for guests:
  ```dart
  Widget _buildDistanceDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('order_setup.distance_label'.tr(), style: /* same style as today */),
        Text(
          _distanceKm > 0 ? '$_distanceKm km' : 'order_setup.distance_calculating'.tr(),
          style: /* same badge style as today */,
        ),
      ],
    );
  }
  ```
  Shows "wird berechnet..." style text while `_distanceKm` is still its
  pre-lookup default (0) and the debounce hasn't resolved yet, or simply the
  computed value once available. No progress spinner needed — the lookup is
  sub-second in the common case and this field is not on the critical path
  the customer is staring at.
- `_buildPreferencesStep` (wherever it composes `_buildDistanceSlider()` at
  line 1618) becomes:
  ```dart
  authService.isEmployeeOrHigher ? _buildDistanceSlider() : _buildDistanceDisplay(),
  ```

## 3. Prefill / staff-edit path

When staff reopen an existing order (`_loadCocktailData`/prefill, already
setting `_distanceKm = order.distanceKm` when `> 0` at line 208), nothing
changes here — an employee always sees the slider (never the read-only
display) and the prefilled value is exactly what's already stored, editable
as today. The auto-calculation listener only ever fires for a non-employee
session, so it never fights with a staff member's manual edit on the same
order.

## 4. Translation keys

Add to both `assets/translations/de.json` and `assets/translations/en.json`
under the existing `order_setup` section:
- `distance_calculating`: "wird berechnet…" / "calculating…"

(`order_setup.distance_label` already exists and needs no change.)

## Testing

- `DistanceCalculator._haversineKm` (expose as `@visibleForTesting` or test
  indirectly via a known pair of coordinates with a known real-world
  distance, asserting the result is within a small tolerance).
- `distanceKmFromAddress`: cannot hit the real Nominatim endpoint in a unit
  test (no network in CI); if `package:http`'s `Client` is already injectable
  elsewhere in this codebase for testing, follow that pattern to inject a
  fake client returning canned JSON (found address, empty results array,
  non-200 status, malformed JSON) and assert the four outcomes (a resolved
  km value; `null` for empty results; `null` for a non-200 response; `null`
  for malformed JSON) — search the codebase for an existing `http.Client`
  injection precedent before introducing a new DI pattern for this one class.
- Widget-level: to whatever extent the existing `AuthService`/network DI
  limitations in this test suite allow (same caveat as other widget tests in
  this codebase touching these singletons) — confirm the slider is hidden and
  the read-only display shown for a non-employee session, and vice versa for
  an employee session.

## Suggested implementation order

1. `DistanceCalculator` + its unit tests (pure logic, no UI).
2. Wire the debounced listener + read-only display into the order form,
   gated on `authService.isEmployeeOrHigher`.
3. Translation keys.
4. Manual verification: fill in a real address as a guest, confirm a
   plausible km value appears within ~1 second of stopping typing; confirm
   an employee session still sees and can drag the slider.
