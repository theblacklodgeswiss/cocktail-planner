# Admin-Managed Additional Services Catalog

Date: 2026-09-15
Status: Design approved, not yet planned

## Problem

The "Zusatzleistungen" (additional services — 360 Booth, PhotoBox, Catering,
DJs, etc.) a customer can request on the order form are a hardcoded list of
button IDs (`lib/screens/forms/modern_order_form_screen.dart:2533-2594`) whose
display labels and prices live in a static translation map
(`_additionalServiceLabelsDe`/`_additionalServiceLabelsEn` in
`lib/utils/order_option_labels.dart:53-79`). Adding, renaming, re-pricing, or
retiring a service today requires a code change and a redeploy. There is also
no way to show a photo of the service, and closely related offerings that are
really just variants of one service (`photobox_print` "inkl. 300 Druck" vs.
`photobox_qr` "Digital mit QR Code" — the same real-world PhotoBox, two price
points) are modeled as two unrelated flat entries with no shared identity.

## Goals

- Admins manage the service catalog themselves: name, image, and one or more
  priced variants per service — no code change needed to add/edit/retire one.
- The order form shows one tile per service (with its image); tapping a tile
  opens its variants and the customer picks exactly one.
- Existing orders, already carrying the old flat string IDs
  (`'booth_360'`, `'dj'`, …), keep rendering correctly everywhere (order form
  prefill, offer generation, PDFs) with no backfill.

## Non-goals

- Migrating the 11 existing legacy entries into the new catalog as data. They
  keep working via the existing static label map (see "Backward
  compatibility" below); an admin can optionally re-create them as catalog
  entries at their own pace, at which point the legacy IDs simply stop being
  selectable on the form (new orders use catalog variant IDs) while old
  orders' stored IDs still resolve via the static map.
- Any change to `catering`/`choreographer`/etc.'s "Preis auf Anfrage"
  billing flow beyond representing it as a variant with no price — the offer
  screen already lets staff freely edit price on any auto-generated position,
  which continues to work unchanged.

## 1. Data model

New Firestore collection `additionalServices`, following the same shape and
admin-CRUD conventions already used for `employees`:

```
additionalServices/{serviceId}
  name:        "BlackLodge PhotoBox"
  imageUrl:    "https://..." | null
  sortOrder:   0
  variants: [
    { id: "v1", name: "inkl. 300 Druck", price: 500.0 },
    { id: "v2", name: "Digital mit QR-Code", price: 300.0 },
  ]
  createdAt, createdBy, updatedAt, updatedBy   // same audit fields as `employees`
```

`variants` is an inline array on the service document, not a subcollection —
there is no use case for querying variants independently of their parent
service, and an array keeps add/edit/delete/reorder a single-document write
(matching the `employees` roster's own simplicity; no batch/mirror complexity
needed here, unlike the `employeeAccess` mirror — nothing else needs to look
up a service by anything other than its own document ID).

A variant's `price` is nullable: `null` means "Preis auf Anfrage" (matches
today's `catering`/`choreographer`/`dj`/`led_screen`/`security` entries,
confirmed to keep working exactly as today per the answered design question).

Dart models, new file `lib/models/additional_service.dart`:

```dart
class ServiceVariant {
  const ServiceVariant({
    required this.id,
    required this.name,
    this.price,
  });

  final String id;
  final String name;
  final double? price;

  factory ServiceVariant.fromMap(Map<String, dynamic> map) => ServiceVariant(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (price != null) 'price': price,
      };
}

class AdditionalService {
  const AdditionalService({
    required this.id,
    required this.name,
    this.imageUrl,
    this.sortOrder = 0,
    this.variants = const [],
  });

  final String id;
  final String name;
  final String? imageUrl;
  final int sortOrder;
  final List<ServiceVariant> variants;

  factory AdditionalService.fromFirestore(String id, Map<String, dynamic> data) {
    return AdditionalService(
      id: id,
      name: data['name'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      sortOrder: data['sortOrder'] as int? ?? 0,
      variants: (data['variants'] as List<dynamic>? ?? [])
          .map((v) => ServiceVariant.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList(),
    );
  }
}
```

## 2. Repository

New file `lib/data/additional_service_repository.dart`, mirroring
`EmployeeRepository`'s shape exactly (same `watch`/`add`/`update`/`delete`/
`reorder` method names and error-handling style, so anyone who has read that
file already knows this one):

```dart
Stream<List<AdditionalService>> watchServices();
Future<bool> addService({required String name, String? imageUrl, List<ServiceVariant> variants = const []});
Future<bool> updateService({required String id, required String name, String? imageUrl, List<ServiceVariant> variants = const []});
Future<bool> deleteService(String id);
Future<bool> reorderServices(List<AdditionalService> services);
```

No mirror collection is needed here (unlike `employeeAccess`) — there is no
security-rule reason to duplicate this data; see rules below.

## 3. Image handling

The app has no image upload path today (no `firebase_storage` dependency, no
`storage.rules`, no `image_picker`). Per the answered design question, support
**both**:

- **Upload**: add `firebase_storage` and `image_picker` to `pubspec.yaml`.
  Admin picks an image from their device; it uploads to
  `gs://<bucket>/service_images/{serviceId}/{timestamp}_{filename}`, and the
  resulting download URL is stored in `imageUrl`.
- **URL field**: a plain text field ("oder Bild-URL einfügen") that sets
  `imageUrl` directly, for an admin who already has the image hosted
  elsewhere. Whichever the admin used last wins — they are the same field,
  just two ways to fill it.

New `storage.rules` (this project currently has no Storage security rules at
all — confirm in the Firebase console that the Storage bucket is provisioned
for `cocktail-planer-dev`/`cocktail-planner-bl` before implementing; if it
is not, provisioning it is a prerequisite step, not a code change):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /service_images/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null; // tightened below
    }
  }
}
```

Tightened to admin-only write once wired to the same `canManageUsers()`-style
check Firestore rules use — Storage rules cannot call Firestore, so this needs
a custom claim or a second `allowedUsers` read via `firestore.get()` inside
the Storage rule (Storage rules support cross-service reads via
`firestore.get(path)`), e.g.:

```
allow write: if request.auth != null &&
  firestore.get(/databases/(default)/documents/allowedUsers/$(request.auth.token.email.lower())).data.isAdmin == true;
```

Add `firebase.json`'s `"storage": {"rules": "storage.rules"}` key alongside
the existing `"firestore"` key.

## 4. Admin UI

New screen `lib/screens/settings/services_screen.dart` (thin wrapper, same
pattern as `employees_screen.dart` wrapping `EmployeesTab`), backed by a new
`lib/screens/admin/services_tab.dart` widget. Route `/settings/services`,
added to `settings_screen.dart`'s admin section right after the existing
Employees `ListTile`, gated the same way
(`if (authService.canManageUsers) ...`).

Layout: a reorderable list of services (name + thumbnail + variant count),
add/edit dialog per service with:
- Name field
- Image: upload button + "oder URL einfügen" text field (see above)
- A variants sub-list: add/edit/delete a variant (name + optional price —
  leave price blank for "Preis auf Anfrage")

This is a config/management screen, so it stays admin-only, consistent with
`employees_screen.dart` and `user_management_screen.dart` — not
employee-or-higher, per the existing convention in this codebase (see the
2026-09-15 order-access-roles design's "which checks change, which stay"
table for the precedent).

## 5. Customer-facing order form

Replace the additional-services step in
`lib/screens/forms/modern_order_form_screen.dart` (currently the
`_buildServiceCheckbox` calls at lines 2533-2594 inside whatever step method
contains "Dienstleistern anbieten") with:

- A `GridView` of tiles, one per `AdditionalService` from
  `additionalServiceRepository.watchServices()`, each showing the service's
  `imageUrl` (or a placeholder icon if null) and name. A tile shows a
  check-badge and the selected variant's price/name once chosen.
- Tapping a tile opens a `showModalBottomSheet` listing that service's
  variants as a single-select list (radio-style — a customer picks at most
  one variant per service), each row showing the variant name and price (or
  "Preis auf Anfrage" when `price == null`). Confirming closes the sheet and
  updates the tile's badge.
- Selection state: replace `_selectedAdditionalServices` (currently a
  `Set<String>` of flat legacy IDs) with `Map<String, String>` — service ID to
  chosen variant ID — since a customer picks one variant per service, not the
  service itself. Persist to Firestore as a flattened
  `List<String>` of `"serviceId:variantId"` composite strings in the
  `additionalServices` order field, so the existing field's type
  (`List<String>`) and every existing reader of `order.additionalServices`
  keeps compiling unchanged — only the *shape* of the strings it may now
  contain changes (composite IDs for new orders, legacy bare IDs for old
  ones), which the label-resolution layer below is what tells them apart.

The "Sonstiges" ("Other") free-text checkbox stays exactly as it is today —
it is not a catalog service, just a flag with no price, and folding it into
the catalog would force every "Sonstiges" order into having a fabricated
catalog entry for no benefit.

## 6. Backward-compatible label resolution

New function in `lib/utils/order_option_labels.dart`,
`resolveAdditionalServiceLabel(String value, {required List<AdditionalService> catalog, bool isEnglish = false, String? currencyCode})`:

- If `value` contains `':'`, treat it as `serviceId:variantId`: look up the
  service and variant in `catalog`; if found, return
  `"${service.name} - ${variant.name}"` plus price (or "Preis auf Anfrage"
  when the variant's price is null) — mirroring the existing string format
  used by the static map so the visual result doesn't change.
- Otherwise (no `':'`, or lookup failed because the service was since
  deleted), fall back to today's `formatOrderAdditionalServiceLabel(value)` —
  this is the exact existing function, untouched, so every legacy value keeps
  resolving exactly as it does today.

Every current call site that renders additional-service labels switches to
this new function, threading the live catalog through: the order form's own
prefill/summary display, `create_offer_screen.dart:1762`'s
`_buildRequestDerivedOfferPositions` loop, and any PDF generator that renders
`order.additionalServices` (grep `formatOrderAdditionalServiceLabel` /
`formatOrderAdditionalServiceLabels` across `lib/services/*_pdf_generator.dart`
during implementation — do not assume the two call sites found during this
design pass are the only ones).

While updating `create_offer_screen.dart`'s loop, also seed the auto-generated
`ExtraPosition`'s `price` field from the resolved variant's price when
available (today it is hardcoded to `price: 0` regardless of the selected
service — see line 1772 — so staff always fill it in manually; this is the
same "seed the default, let staff still override" pattern already used for
the Shots position). Legacy bare-ID entries keep seeding `price: 0` exactly as
today, since there is no variant to read a price from.

## 7. Firestore rules

```
match /additionalServices/{document=**} {
  allow read: if true;   // matches materials/recipes: readable by anyone, including anonymous customers filling out the form
  allow write: if canManageUsers();
}
```

Placed alongside the existing `materials`/`recipes`/`fixedValues` blocks in
`firestore.rules`, which already use this exact `read: if true` /
`write: if isAdmin()`-style shape for other admin-managed catalogs the
customer form reads without authentication.

## 8. Migration and rollout

No backfill. Concretely:

- **Existing orders** keep their legacy flat-string `additionalServices`
  values forever; `resolveAdditionalServiceLabel`'s fallback path means they
  render identically to today, indefinitely, whether or not an admin ever
  creates catalog entries.
- **The static label map in `order_option_labels.dart` is not removed** — it
  is the permanent fallback for legacy data, not a temporary shim.
- **Rollout order**: ship the Storage bucket provisioning + `storage.rules`
  and the `additionalServices` Firestore rule first (additive, no risk to
  existing functionality), then the repository/model, then the admin screen
  (so admins can populate at least one service before the customer-facing
  change ships), then the customer-facing tile UI last.
- An admin should populate the catalog with at least the 11 existing
  offerings (ideally splitting the two PhotoBox variants into one service
  with two variants, and Security's per-hour rate into the variant's price
  field or its name — admin's call at data-entry time, not a code decision)
  before or shortly after the customer-facing UI ships, or new customers will
  see an empty tile grid.

## Testing

- `ServiceVariant`/`AdditionalService` `fromFirestore`/`fromMap`: well-formed
  data, missing optional fields (`imageUrl`, `price`), malformed variant
  entries.
- `resolveAdditionalServiceLabel`: a composite `serviceId:variantId` that
  resolves against a populated catalog; a composite ID whose service was
  deleted (falls back correctly); a legacy bare ID (resolves via the existing
  static map, byte-identical to today's `formatOrderAdditionalServiceLabel`
  output); price vs. "Preis auf Anfrage" rendering for both paths.
- Widget test for the tile grid → variant sheet → selection round-trip, to
  the extent the existing `AuthService`/`FirestoreService` DI limitations in
  this codebase's test suite allow (see the precedent skip pattern already
  used for other widget-level tests touching these singletons).

## Suggested implementation order

1. Confirm Firebase Storage is provisioned for the dev/prod projects (a
   console check, not code) — implementation cannot proceed on the image
   upload path without this.
2. `AdditionalService`/`ServiceVariant` models + `AdditionalServiceRepository`.
3. Firestore rule for `additionalServices` (additive, safe to deploy any time).
4. Admin UI (`services_screen.dart`/`services_tab.dart`), image URL field only
   first (defer the upload button to the next step so this lands without a
   new dependency yet).
5. `storage.rules` + `firebase_storage`/`image_picker` dependencies + the
   upload button in the admin UI.
6. `resolveAdditionalServiceLabel` + switching every render call site to it
   (order form, offer generation, PDFs) — this is safe to ship even before
   step 7, since it's purely additive (new composite-ID branch, unchanged
   legacy branch).
7. Customer-facing tile grid + variant picker in the order form, replacing
   the hardcoded button list. Ship last, after an admin has had the chance to
   populate the catalog.
