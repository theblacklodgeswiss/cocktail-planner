# Short-Lived Share Links for Offers & Invoices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken `blob:`-URL PDF sharing for offers and invoices with a real, short, 14-day-valid link that works for any recipient (no login), backed only by Firestore + Hosting (no Cloud Functions, no Storage — no Blaze plan required).

**Architecture:** A new `shareLinks/{code}` Firestore collection holds a JSON snapshot of exactly what a PDF generator needs plus an `expiresAt` timestamp; Firestore Security Rules enforce the 14-day expiry server-side. `code` (8-char random string) is both the Firestore doc ID and the URL path segment, so the link is short by construction — no separate shortener service. A new public route `/s/:code` reads the doc, regenerates the PDF client-side from the snapshot via the existing PDF generators, and renders it with `PdfPreview` (from the already-installed `printing` package). Sharing offers/invoices now creates one of these links instead of attaching raw PDF bytes.

**Tech Stack:** Flutter web, `cloud_firestore`, existing `printing` package (`PdfPreview` widget), `go_router`.

**Spec:** `docs/superpowers/specs/2026-09-16-share-links-design.md`

## Global Constraints

- No Cloud Functions, no Firebase Storage — every piece must work on the Firebase Spark (free) plan.
- The public `shareLinks/{code}` document must never contain `userId`, `userEmail`, `createdBy`, or `phone` — these are stripped before every write.
- The 14-day expiry is enforced by the Firestore rule (`resource.data.expiresAt > request.time`), not by client-side logic alone — the rule is the actual security boundary.
- `/s/:code` must be reachable by a signed-out visitor with no Firebase session at all (the current global router redirect sends any signed-out visitor to `/login` — this route is an explicit exception).
- Reuse the existing `OfferPdfGenerator` / `InvoicePdfGenerator` static methods to render the PDF from the snapshot — do not duplicate PDF-building logic.
- Run `flutter analyze` and `flutter test` after every task; commit with an explicit file list (never `-A`/`.`).

---

### Task 1: `shareLinks` Firestore collection — rule + collection accessor

**Files:**
- Modify: `firestore.rules`
- Modify: `lib/data/firestore_service.dart`

**Interfaces:**
- Produces: `firestoreService.shareLinksCollection` (`CollectionReference<Map<String, dynamic>>`), used by Task 5.

- [ ] **Step 1: Add the Firestore rule**

In `firestore.rules`, add this block right after the `employeeAccess` match block (after its closing `}`, before the `microsoftForms` match block):

```
    // Share links - short-lived, publicly readable links to a frozen
    // snapshot of an offer/invoice for external (signed-out) recipients.
    // Read has no auth check by design: the recipient clicking a WhatsApp
    // link has no Firebase session. The expiresAt check is the entire
    // security boundary. Documents are write-once (no update/delete).
    match /shareLinks/{code} {
      allow read: if resource.data.expiresAt > request.time;
      allow create: if isAuthenticated();
      allow update, delete: if false;
    }
```

- [ ] **Step 2: Add the collection accessor**

In `lib/data/firestore_service.dart`, add after the `settingsCollection` getter (after line 33):

```dart
  CollectionReference<Map<String, dynamic>> get shareLinksCollection =>
      firestore.collection('shareLinks');
```

- [ ] **Step 3: Verify rules compile**

Run: `firebase deploy --only firestore:rules --project development --dry-run` if your Firebase CLI version supports `--dry-run`; otherwise skip straight to Step 4 (the deploy in Task 9 will catch any syntax error).

- [ ] **Step 4: Commit**

```bash
git add firestore.rules lib/data/firestore_service.dart
git commit -m "feat: add shareLinks Firestore collection and rule"
```

---

### Task 2: Short-code generator

**Files:**
- Create: `lib/utils/short_code.dart`
- Test: `test/short_code_test.dart`

**Interfaces:**
- Produces: `String generateShortCode()` — used by Task 5.

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/short_code_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:cocktail_planer/utils/short_code.dart'"

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math';

const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Generates an 8-character random base62 code, used as both the Firestore
/// document ID and the URL path segment for a share link (`/s/<code>`).
/// Collision probability across the alphabet's ~2×10^14 combinations is
/// negligible for this document volume; [ShareLinkRepository] still retries
/// on a rare collision as cheap insurance (see Task 5).
String generateShortCode() {
  final random = Random.secure();
  return List.generate(
    8,
    (_) => _alphabet[random.nextInt(_alphabet.length)],
  ).join();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/short_code_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/utils/short_code.dart test/short_code_test.dart
git commit -m "feat: add short-code generator for share links"
```

---

### Task 3: `SavedOrder.toJson()`

**Files:**
- Modify: `lib/models/order.dart`
- Test: `test/order_model_test.dart`

**Interfaces:**
- Consumes: `SavedOrder` (all its fields, `lib/models/order.dart:55-193`), `ShotSelection` (existing model in the same file).
- Produces: `Map<String, dynamic> SavedOrder.toJson()` — used by Task 5's `createInvoiceShareLink`. Must round-trip with the existing `SavedOrder.fromFirestore(id, json)` factory: `SavedOrder.fromFirestore('x', order.toJson())` reproduces every field `order` had (id itself is not part of `toJson()`, matching `fromFirestore`'s separate `id` parameter).

- [ ] **Step 1: Write the failing test**

Add to `test/order_model_test.dart` (new top-level `group`, after the existing groups, before the final closing `}` of `main()`):

```dart
  group('SavedOrder.toJson round-trip', () {
    test('fromFirestore(id, order.toJson()) reproduces every field', () {
      final original = SavedOrder(
        id: 'ignored',
        name: 'Test Event',
        date: DateTime(2026, 10, 31),
        items: [
          {'name': 'Vodka', 'category': 'purchase', 'price': 20, 'quantity': 2, 'total': 40},
        ],
        total: 500.0,
        personCount: 100,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.accepted,
        cocktails: const ['Mojito'],
        shots: const ['Tequila'],
        shotSelections: const [ShotSelection(name: 'Tequila', quantity: 3)],
        bar: 'Whiskey',
        distanceKm: 260,
        thekeCost: 100.0,
        offerClientName: 'Jane Doe',
        offerClientContact: '+41 79 000 00 00',
        offerEventTime: '18:00',
        offerEventTypes: const ['wedding'],
        offerDiscount: 50.0,
        offerLanguage: 'de',
        offerExtraPositions: [
          {'name': 'Extrastunden', 'price': 50.0, 'quantity': 1, 'remark': '', 'date': ''},
        ],
        offerPositions: [
          {'name': 'Barservice', 'price': 1000.0, 'quantity': 1, 'remark': 'Inkl. 3x Barkeeper', 'date': '21.08.2026'},
        ],
        offerShotsCount: 3,
        offerShotsPricePerPiece: 1.5,
        offerExtraHours: 1,
        offerExtraHourRate: 50.0,
        assignedEmployees: const ['Mario'],
        location: 'Dortmund',
        eventTime: '18:00',
        serviceType: 'cocktail_barservice',
        barDrinks: const ['Bier'],
        alcoholPurchase: const ['Wodka'],
        additionalServices: const ['photobooth'],
        remarks: 'Welcomedrinks',
      );

      final rebuilt = SavedOrder.fromFirestore('new-id', original.toJson());

      expect(rebuilt.name, original.name);
      expect(rebuilt.date, original.date);
      expect(rebuilt.items, original.items);
      expect(rebuilt.total, original.total);
      expect(rebuilt.personCount, original.personCount);
      expect(rebuilt.currency, original.currency);
      expect(rebuilt.status, original.status);
      expect(rebuilt.cocktails, original.cocktails);
      expect(rebuilt.shots, original.shots);
      expect(rebuilt.shotSelections.map((s) => (s.name, s.quantity)),
          original.shotSelections.map((s) => (s.name, s.quantity)));
      expect(rebuilt.bar, original.bar);
      expect(rebuilt.distanceKm, original.distanceKm);
      expect(rebuilt.thekeCost, original.thekeCost);
      expect(rebuilt.offerClientName, original.offerClientName);
      expect(rebuilt.offerEventTime, original.offerEventTime);
      expect(rebuilt.offerEventTypes, original.offerEventTypes);
      expect(rebuilt.offerDiscount, original.offerDiscount);
      expect(rebuilt.offerExtraPositions, original.offerExtraPositions);
      expect(rebuilt.offerPositions, original.offerPositions);
      expect(rebuilt.offerShotsCount, original.offerShotsCount);
      expect(rebuilt.offerShotsPricePerPiece, original.offerShotsPricePerPiece);
      expect(rebuilt.offerExtraHours, original.offerExtraHours);
      expect(rebuilt.offerExtraHourRate, original.offerExtraHourRate);
      expect(rebuilt.assignedEmployees, original.assignedEmployees);
      expect(rebuilt.location, original.location);
      expect(rebuilt.serviceType, original.serviceType);
      expect(rebuilt.barDrinks, original.barDrinks);
      expect(rebuilt.alcoholPurchase, original.alcoholPurchase);
      expect(rebuilt.additionalServices, original.additionalServices);
      expect(rebuilt.remarks, original.remarks);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_model_test.dart`
Expected: FAIL with "The method 'toJson' isn't defined for the type 'SavedOrder'"

- [ ] **Step 3: Write the implementation**

Add to `lib/models/order.dart`, directly after the `factory SavedOrder.fromFirestore(...)` block (after its closing `}`, i.e. after line 328, before the class's final closing `}`):

```dart

  /// Serializes back to the same shape [fromFirestore] reads. `id` is
  /// intentionally excluded (fromFirestore takes it as a separate
  /// parameter) — used by [ShareLinkRepository] to snapshot an order for
  /// a public share link; callers that need a PII-free snapshot must strip
  /// `userId`, `userEmail`, `createdBy` and `phone` from the result
  /// themselves (see ShareLinkRepository.createInvoiceShareLink).
  Map<String, dynamic> toJson() => {
    'name': name,
    'date': date.toIso8601String(),
    'items': items,
    'total': total,
    'personCount': personCount,
    'drinkerType': drinkerType,
    'currency': currency,
    'status': status.value,
    'createdBy': createdBy,
    'createdAt': createdAt?.toIso8601String(),
    'cocktails': cocktails,
    'shots': shots,
    'shotQuantities': shotSelections
        .map((s) => {'name': s.name, 'quantity': s.quantity})
        .toList(),
    'bar': bar,
    'distanceKm': distanceKm,
    'thekeCost': thekeCost,
    'offerTravelCostPerKm': offerTravelCostPerKm,
    'offerBarCost': offerBarCost,
    'offerClientName': offerClientName,
    'offerClientContact': offerClientContact,
    'offerEventTime': offerEventTime,
    'offerEventTypes': offerEventTypes,
    'offerDiscount': offerDiscount,
    'offerDiscountRemark': offerDiscountRemark,
    'offerLanguage': offerLanguage,
    'offerFirstPositionText': offerFirstPositionText,
    'offerFirstPositionRemark': offerFirstPositionRemark,
    'offerExtraPositions': offerExtraPositions,
    'offerPositions': offerPositions,
    'offerShotsCount': offerShotsCount,
    'offerShotsPricePerPiece': offerShotsPricePerPiece,
    'offerShotsRemark': offerShotsRemark,
    'offerExtraHours': offerExtraHours,
    'offerExtraHourRate': offerExtraHourRate,
    'assignedEmployees': assignedEmployees,
    'source': source.value,
    'hasShoppingList': hasShoppingList,
    'formSubmissionId': formSubmissionId,
    'formCreatedAt': formCreatedAt?.toIso8601String(),
    'userId': userId,
    'userEmail': userEmail,
    'phone': phone,
    'location': location,
    'eventTime': eventTime,
    'guestCountRange': guestCountRange,
    'mobileBar': mobileBar,
    'eventType': eventType,
    'serviceType': serviceType,
    'requestedCocktails': requestedCocktails,
    'isPendingDismissed': isPendingDismissed,
    'cocktailPopularity': cocktailPopularity,
    'barDrinks': barDrinks,
    'alcoholPurchase': alcoholPurchase,
    'additionalServices': additionalServices,
    'remarks': remarks,
  };
```

Check `OrderStatus` and `OrderSource` each have a `.value` getter already (they do — used throughout this file, e.g. `OrderStatus.fromString(data['status'] as String?)` reads a string produced by `.value`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/order_model_test.dart`
Expected: PASS (all tests including the new group)

- [ ] **Step 5: Commit**

```bash
git add lib/models/order.dart test/order_model_test.dart
git commit -m "feat: add SavedOrder.toJson for share-link snapshots"
```

---

### Task 4: `OfferData.toJson()` / `OfferData.fromJson()`

**Files:**
- Modify: `lib/models/offer.dart`
- Test: `test/offer_model_test.dart` (new file)

**Interfaces:**
- Consumes: `OfferData` (`lib/models/offer.dart:61-189`), `ExtraPosition.toJson()`/`.fromJson()` (already exist, same file, lines 24-53), `EventType` enum (`lib/models/offer.dart:2`).
- Produces: `Map<String, dynamic> OfferData.toJson()` and `factory OfferData.fromJson(Map<String, dynamic>)` — used by Task 5's `createOfferShareLink` and Task 7's `SharedDocumentScreen`.

- [ ] **Step 1: Write the failing test**

Create `test/offer_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/models/offer.dart';

void main() {
  group('OfferData.toJson / fromJson round-trip', () {
    test('fromJson(offer.toJson()) reproduces every field', () {
      final original = OfferData(
        orderName: 'Test Event',
        eventDate: DateTime(2026, 10, 31),
        eventTime: '18:00',
        currency: 'CHF',
        guestCount: 100,
        editorName: 'Inthusan',
        clientName: 'Jane Doe',
        clientContact: '+41 79 000 00 00',
        eventTypes: {EventType.wedding},
        cocktails: const ['Mojito'],
        shots: const ['Tequila'],
        barDescription: 'Whiskey Bar',
        orderTotal: 1500.0,
        distanceKm: 260,
        travelCostPerKm: 0.7,
        barCost: 100.0,
        discount: 50.0,
        additionalInfo: 'Some info',
        language: 'de',
        serviceType: 'cocktail_barservice',
        servicePositionText: 'Cocktail- & Barservice',
        servicePositionRemark: 'Inkl. 3x Barkeeper',
        eventLocation: 'Dortmund',
        extraPositions: const [
          ExtraPosition(name: 'Reisekosten', price: 0.7, quantity: 260),
        ],
        offerPositions: const [
          ExtraPosition(name: 'Barservice', price: 1500.0, quantity: 1, remark: 'Inkl. 3x Barkeeper', date: '21.08.2026'),
        ],
        assignedEmployees: const ['Mario'],
        supervisorItems: const [
          {'name': 'Barkeeper (5h)', 'category': 'supervisor', 'price': 250, 'quantity': 3, 'total': 750},
        ],
        barDrinks: const ['Bier'],
        alcoholPurchase: const ['Wodka'],
        additionalServices: const ['photobooth'],
        remarks: 'Welcomedrinks',
      );

      final rebuilt = OfferData.fromJson(original.toJson());

      expect(rebuilt.orderName, original.orderName);
      expect(rebuilt.eventDate, original.eventDate);
      expect(rebuilt.eventTime, original.eventTime);
      expect(rebuilt.currency, original.currency);
      expect(rebuilt.guestCount, original.guestCount);
      expect(rebuilt.editorName, original.editorName);
      expect(rebuilt.clientName, original.clientName);
      expect(rebuilt.clientContact, original.clientContact);
      expect(rebuilt.eventTypes, original.eventTypes);
      expect(rebuilt.cocktails, original.cocktails);
      expect(rebuilt.shots, original.shots);
      expect(rebuilt.barDescription, original.barDescription);
      expect(rebuilt.orderTotal, original.orderTotal);
      expect(rebuilt.distanceKm, original.distanceKm);
      expect(rebuilt.travelCostPerKm, original.travelCostPerKm);
      expect(rebuilt.barCost, original.barCost);
      expect(rebuilt.discount, original.discount);
      expect(rebuilt.additionalInfo, original.additionalInfo);
      expect(rebuilt.language, original.language);
      expect(rebuilt.serviceType, original.serviceType);
      expect(rebuilt.servicePositionText, original.servicePositionText);
      expect(rebuilt.servicePositionRemark, original.servicePositionRemark);
      expect(rebuilt.eventLocation, original.eventLocation);
      expect(rebuilt.extraPositions.map((p) => p.toJson()),
          original.extraPositions.map((p) => p.toJson()));
      expect(rebuilt.offerPositions.map((p) => p.toJson()),
          original.offerPositions.map((p) => p.toJson()));
      expect(rebuilt.assignedEmployees, original.assignedEmployees);
      expect(rebuilt.supervisorItems, original.supervisorItems);
      expect(rebuilt.barDrinks, original.barDrinks);
      expect(rebuilt.alcoholPurchase, original.alcoholPurchase);
      expect(rebuilt.additionalServices, original.additionalServices);
      expect(rebuilt.remarks, original.remarks);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/offer_model_test.dart`
Expected: FAIL with "The method 'toJson' isn't defined for the type 'OfferData'"

- [ ] **Step 3: Write the implementation**

Add to `lib/models/offer.dart`, directly after the `OfferData` constructor's field declarations end and before the `travelCostTotal` getter (i.e. right after the `final String remarks;` line):

```dart

  Map<String, dynamic> toJson() => {
    'orderName': orderName,
    'serviceType': serviceType,
    'servicePositionText': servicePositionText,
    'servicePositionRemark': servicePositionRemark,
    'eventDate': eventDate.toIso8601String(),
    'eventTime': eventTime,
    'currency': currency,
    'guestCount': guestCount,
    'editorName': editorName,
    'clientName': clientName,
    'clientContact': clientContact,
    'eventLocation': eventLocation,
    'eventTypes': eventTypes.map((e) => e.name).toList(),
    'cocktails': cocktails,
    'shots': shots,
    'barDescription': barDescription,
    'orderTotal': orderTotal,
    'distanceKm': distanceKm,
    'travelCostPerKm': travelCostPerKm,
    'barCost': barCost,
    'discount': discount,
    'discountRemark': discountRemark,
    'additionalInfo': additionalInfo,
    'language': language,
    'extraPositions': extraPositions.map((p) => p.toJson()).toList(),
    'assignedEmployees': assignedEmployees,
    'supervisorItems': supervisorItems,
    'barDrinks': barDrinks,
    'alcoholPurchase': alcoholPurchase,
    'additionalServices': additionalServices,
    'remarks': remarks,
    'offerPositions': offerPositions.map((p) => p.toJson()).toList(),
  };

  factory OfferData.fromJson(Map<String, dynamic> json) {
    return OfferData(
      orderName: json['orderName'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? 'cocktail_barservice',
      servicePositionText: json['servicePositionText'] as String? ?? '',
      servicePositionRemark: json['servicePositionRemark'] as String? ?? '',
      eventDate: DateTime.parse(json['eventDate'] as String),
      eventTime: json['eventTime'] as String? ?? '',
      currency: json['currency'] as String? ?? 'CHF',
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
      editorName: json['editorName'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      clientContact: json['clientContact'] as String? ?? '',
      eventLocation: json['eventLocation'] as String? ?? '',
      eventTypes: (json['eventTypes'] as List<dynamic>? ?? [])
          .map((s) => EventType.values.where((e) => e.name == s).firstOrNull)
          .whereType<EventType>()
          .toSet(),
      cocktails: (json['cocktails'] as List<dynamic>?)?.cast<String>() ?? [],
      shots: (json['shots'] as List<dynamic>?)?.cast<String>() ?? [],
      barDescription: json['barDescription'] as String? ?? '',
      orderTotal: (json['orderTotal'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toInt() ?? 0,
      travelCostPerKm: (json['travelCostPerKm'] as num?)?.toDouble() ?? 0.70,
      barCost: (json['barCost'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      discountRemark: json['discountRemark'] as String? ?? '',
      additionalInfo: json['additionalInfo'] as String? ?? '',
      language: json['language'] as String? ?? 'de',
      extraPositions: (json['extraPositions'] as List<dynamic>? ?? [])
          .map((e) => ExtraPosition.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      assignedEmployees:
          (json['assignedEmployees'] as List<dynamic>?)?.cast<String>() ?? [],
      supervisorItems:
          (json['supervisorItems'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      barDrinks: (json['barDrinks'] as List<dynamic>?)?.cast<String>() ?? [],
      alcoholPurchase:
          (json['alcoholPurchase'] as List<dynamic>?)?.cast<String>() ?? [],
      additionalServices:
          (json['additionalServices'] as List<dynamic>?)?.cast<String>() ?? [],
      remarks: json['remarks'] as String? ?? '',
      offerPositions: (json['offerPositions'] as List<dynamic>? ?? [])
          .map((e) => ExtraPosition.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
```

`firstOrNull` requires `package:collection`'s extension on `Iterable` — check whether `lib/models/offer.dart` or `create_offer_screen.dart` already imports it (`create_offer_screen.dart` already uses `.firstOrNull` per the existing pattern at line 182, so the package is already a dependency); add `import 'package:collection/collection.dart';` at the top of `lib/models/offer.dart` if it isn't already there.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/offer_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/offer.dart test/offer_model_test.dart
git commit -m "feat: add OfferData.toJson/fromJson for share-link snapshots"
```

---

### Task 5: `ShareLinkRepository`

**Files:**
- Create: `lib/data/share_link_repository.dart`
- Test: `test/share_link_repository_test.dart`

**Interfaces:**
- Consumes: `firestoreService.shareLinksCollection` (Task 1), `generateShortCode()` (Task 2), `SavedOrder.toJson()` (Task 3), `OfferData.toJson()`/`.fromJson()` (Task 4).
- Produces:
  - `Future<String> ShareLinkRepository.createOfferShareLink(OfferData offer, {required String orderId})` → returns the short code.
  - `Future<String> ShareLinkRepository.createInvoiceShareLink(SavedOrder order)` → returns the short code.
  - `Future<ShareLinkResult> ShareLinkRepository.fetchShareLink(String code)`.
  - `class ShareLinkResult { final bool found; final String? type; final Map<String, dynamic>? snapshot; }` (a plain data class — `found: false` covers both "never existed" and "expired", matching the spec's "don't leak whether a code ever existed").
  - Singleton: `final shareLinkRepository = ShareLinkRepository();` at the bottom of the file, matching the `orderRepository` pattern in `lib/data/order_repository.dart:881`.

This repository is standalone — it does not depend on `OrderRepository`.

- [ ] **Step 1: Write the failing test**

Create `test/share_link_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/data/share_link_repository.dart';
import 'package:cocktail_planer/models/order.dart';

void main() {
  group('ShareLinkRepository PII stripping', () {
    test('stripInvoicePii removes userId, userEmail, createdBy, phone', () {
      final order = SavedOrder(
        id: 'x',
        name: 'Test',
        date: DateTime(2026, 1, 1),
        items: const [],
        total: 0,
        personCount: 1,
        drinkerType: 'normal',
        currency: 'CHF',
        status: OrderStatus.quote,
        userId: 'uid-123',
        userEmail: 'customer@example.com',
        createdBy: 'staff@example.com',
        phone: '+41 79 000 00 00',
      );

      final snapshot = ShareLinkRepository.stripInvoicePii(order.toJson());

      expect(snapshot.containsKey('userId'), isFalse);
      expect(snapshot.containsKey('userEmail'), isFalse);
      expect(snapshot.containsKey('createdBy'), isFalse);
      expect(snapshot.containsKey('phone'), isFalse);
      expect(snapshot['name'], 'Test');
    });
  });

  group('ShareLinkResult', () {
    test('not-found result exposes found=false with no data', () {
      const result = ShareLinkResult.notFound();
      expect(result.found, isFalse);
      expect(result.type, isNull);
      expect(result.snapshot, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/share_link_repository_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:cocktail_planer/data/share_link_repository.dart'"

- [ ] **Step 3: Write the implementation**

Create `lib/data/share_link_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/offer.dart';
import '../models/order.dart';
import '../utils/short_code.dart';
import 'firestore_service.dart';

/// Result of looking up a share link. `found: false` covers both "the code
/// never existed" and "it existed but expired" — the public viewer must not
/// be able to distinguish the two.
class ShareLinkResult {
  const ShareLinkResult.notFound() : found = false, type = null, snapshot = null;

  const ShareLinkResult.found({required this.type, required this.snapshot})
      : found = true;

  final bool found;
  final String? type; // 'offer' | 'invoice'
  final Map<String, dynamic>? snapshot;
}

/// Creates and resolves short-lived, publicly-readable share links for
/// offers and invoices. See docs/superpowers/specs/2026-09-16-share-links-design.md.
class ShareLinkRepository {
  static const _linkLifetime = Duration(days: 14);

  /// Fields that must never appear in a public share-link snapshot.
  static const _invoicePiiKeys = {'userId', 'userEmail', 'createdBy', 'phone'};

  /// Strips PII-bearing keys from a [SavedOrder.toJson] map before it is
  /// written to the public `shareLinks` collection.
  static Map<String, dynamic> stripInvoicePii(Map<String, dynamic> json) {
    return {
      for (final entry in json.entries)
        if (!_invoicePiiKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<String> _writeWithRetry(Map<String, dynamic> data) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = generateShortCode();
      final ref = firestoreService.shareLinksCollection.doc(code);
      final existing = await ref.get();
      if (existing.exists) continue; // negligible odds, but retry is cheap
      await ref.set(data);
      return code;
    }
    throw StateError('Could not allocate a unique share link code after 3 attempts');
  }

  /// Creates a share link for an offer. [orderId] is stored for staff
  /// traceability only — the public viewer never reads it.
  Future<String> createOfferShareLink(OfferData offer, {required String orderId}) async {
    final now = DateTime.now();
    return _writeWithRetry({
      'type': 'offer',
      'orderId': orderId,
      'snapshot': offer.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(_linkLifetime)),
    });
  }

  /// Creates a share link for an invoice (Auftragsbestätigung).
  Future<String> createInvoiceShareLink(SavedOrder order) async {
    final now = DateTime.now();
    return _writeWithRetry({
      'type': 'invoice',
      'orderId': order.id,
      'snapshot': stripInvoicePii(order.toJson()),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(_linkLifetime)),
    });
  }

  /// Resolves a share link. Returns [ShareLinkResult.notFound] for a
  /// missing OR expired code (Firestore denies the read once expired, which
  /// surfaces here as a permission-denied exception — treated the same as
  /// "not found").
  Future<ShareLinkResult> fetchShareLink(String code) async {
    try {
      final doc = await firestoreService.shareLinksCollection.doc(code).get();
      if (!doc.exists) return const ShareLinkResult.notFound();
      final data = doc.data()!;
      final type = data['type'] as String?;
      final snapshot = data['snapshot'] as Map<String, dynamic>?;
      if (type == null || snapshot == null) return const ShareLinkResult.notFound();
      return ShareLinkResult.found(type: type, snapshot: snapshot);
    } on FirebaseException catch (e) {
      debugPrint('Share link $code unavailable: ${e.code}');
      return const ShareLinkResult.notFound();
    }
  }
}

final shareLinkRepository = ShareLinkRepository();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/share_link_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/share_link_repository.dart test/share_link_repository_test.dart
git commit -m "feat: add ShareLinkRepository for offer/invoice share links"
```

---

### Task 6: Router — `/s/:code` route + redirect exemption

**Files:**
- Modify: `lib/router/app_router.dart`
- Create: `lib/screens/share/shared_document_screen.dart` (placeholder body only — Task 7 fills it in; this task must produce a compiling app with the route wired up)

**Interfaces:**
- Consumes: nothing new yet.
- Produces: route `/s/:code`; `SharedDocumentScreen({required String code})` widget (empty scaffold for now, replaced in Task 7).

- [ ] **Step 1: Create the placeholder screen**

Create `lib/screens/share/shared_document_screen.dart`:

```dart
import 'package:flutter/material.dart';

/// Public, signed-out-accessible screen that resolves a `/s/:code` share
/// link. Filled in by Task 7.
class SharedDocumentScreen extends StatelessWidget {
  const SharedDocumentScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('code: $code')));
  }
}
```

- [ ] **Step 2: Add the route**

In `lib/router/app_router.dart`, add the import near the other screen imports:

```dart
import '../screens/share/shared_document_screen.dart';
```

Add the route inside the `routes: [` list (anywhere among the other top-level `GoRoute` entries, e.g. right after the `/login` route):

```dart
    GoRoute(
      path: '/s/:code',
      builder: (context, state) =>
          SharedDocumentScreen(code: state.pathParameters['code']!),
    ),
```

- [ ] **Step 3: Exempt the route from the auth redirect**

In the same file's `redirect:` callback, change:

```dart
    final isLoginRoute = state.matchedLocation == '/login';

    // Not logged in and not on login page -> redirect to login
    if (!isLoggedIn && !isLoginRoute) {
      return '/login';
    }
```

to:

```dart
    final isLoginRoute = state.matchedLocation == '/login';
    final isPublicShareRoute = state.matchedLocation.startsWith('/s/');

    // Not logged in and not on login page or a public share link -> redirect to login
    if (!isLoggedIn && !isLoginRoute && !isPublicShareRoute) {
      return '/login';
    }
```

- [ ] **Step 4: Verify it compiles and the route is reachable**

Run: `flutter analyze lib/router/app_router.dart lib/screens/share/shared_document_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/router/app_router.dart lib/screens/share/shared_document_screen.dart
git commit -m "feat: add public /s/:code route, exempt from login redirect"
```

---

### Task 7: `SharedDocumentScreen` — full implementation

**Files:**
- Modify: `lib/screens/share/shared_document_screen.dart`
- Test: `test/shared_document_screen_test.dart` (new file)
- Modify: `assets/translations/de.json`, `assets/translations/en.json`

**Interfaces:**
- Consumes: `shareLinkRepository.fetchShareLink(String)` (Task 5), `ShareLinkResult` (Task 5), `OfferData.fromJson()` (Task 4), `SavedOrder.fromFirestore()` (existing), `OfferPdfGenerator.generatePdfBytes(OfferData)` (existing, `lib/services/offer_pdf_generator.dart:20`), `InvoicePdfGenerator.generateBytes(SavedOrder, {String? language})` (existing, `lib/services/invoice_pdf_generator.dart:23`), `PdfPreview` widget (from the `printing` package, already a dependency).
- Produces: the finished `SharedDocumentScreen` widget.

- [ ] **Step 1: Add translation keys**

In `assets/translations/de.json`, add a new top-level `"share"` object (place it alphabetically, e.g. right before the `"settings"` key if one exists, otherwise anywhere at the top level next to `"orders"`):

```json
  "share": {
    "loading": "Dokument wird geladen...",
    "expired_title": "Link nicht mehr gültig",
    "expired_body": "Dieser Link ist abgelaufen oder ungültig. Bitte fordere einen neuen Link an."
  },
```

In `assets/translations/en.json`, the matching block:

```json
  "share": {
    "loading": "Loading document...",
    "expired_title": "Link no longer valid",
    "expired_body": "This link has expired or is invalid. Please request a new link."
  },
```

- [ ] **Step 2: Write the failing test**

Create `test/shared_document_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cocktail_planer/screens/share/shared_document_screen.dart';

void main() {
  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('de'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      child: Builder(builder: (context) => MaterialApp(home: child, locale: const Locale('de'))),
    );
  }

  testWidgets('shows a loading indicator before the fetch resolves', (tester) async {
    await tester.pumpWidget(wrap(const SharedDocumentScreen(code: 'doesNotMatter')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the expired message for an unknown code', (tester) async {
    await tester.pumpWidget(wrap(const SharedDocumentScreen(code: 'unknown1')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('abgelaufen'), findsOneWidget);
  });
}
```

Note: the second test relies on `shareLinkRepository.fetchShareLink` hitting Firestore and failing/returning not-found in the test environment (no Firebase test app is configured in `test/`), which naturally exercises the "not found" branch — consistent with how other Firestore-touching widgets are tested in this repo (see the `AuthService` skip note pattern in `test/click_interactions_test.dart` if this call needs the same treatment; if the fetch throws instead of resolving to `notFound()`, catch that in `fetchShareLink` — Task 5's `on FirebaseException catch` already covers the expected exception type. If a different exception surfaces in the test environment, broaden that catch to `catch (e)` and keep the `debugPrint`).

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/shared_document_screen_test.dart`
Expected: FAIL (loading indicator test may pass already since the placeholder shows plain text with no `CircularProgressIndicator`; the expired-message test fails since there's no such text yet).

- [ ] **Step 4: Write the implementation**

Replace `lib/screens/share/shared_document_screen.dart` entirely:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/share_link_repository.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/offer_pdf_generator.dart';

/// Public, signed-out-accessible screen that resolves a `/s/:code` share
/// link created by [ShareLinkRepository], regenerates the PDF from the
/// stored snapshot, and displays it inline. No Firebase Auth session is
/// required or assumed — see app_router.dart's redirect exemption for '/s/'.
class SharedDocumentScreen extends StatefulWidget {
  const SharedDocumentScreen({super.key, required this.code});

  final String code;

  @override
  State<SharedDocumentScreen> createState() => _SharedDocumentScreenState();
}

class _SharedDocumentScreenState extends State<SharedDocumentScreen> {
  late final Future<Uint8List?> _pdfBytesFuture;

  @override
  void initState() {
    super.initState();
    _pdfBytesFuture = _resolveAndRender();
  }

  Future<Uint8List?> _resolveAndRender() async {
    final result = await shareLinkRepository.fetchShareLink(widget.code);
    if (!result.found) return null;

    switch (result.type) {
      case 'offer':
        final offer = OfferData.fromJson(result.snapshot!);
        return OfferPdfGenerator.generatePdfBytes(offer);
      case 'invoice':
        final order = SavedOrder.fromFirestore('shared', result.snapshot!);
        return InvoicePdfGenerator.generateBytes(order, language: order.offerLanguage);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Uint8List?>(
        future: _pdfBytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('share.loading'.tr()),
                ],
              ),
            );
          }

          final bytes = snapshot.data;
          if (bytes == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_off, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'share.expired_title'.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'share.expired_body'.tr(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return PdfPreview(
            build: (format) async => bytes,
            allowSharing: true,
            allowPrinting: true,
            canDebug: false,
          );
        },
      ),
    );
  }
}
```

`Uint8List` comes from `dart:typed_data`, re-exported by `package:printing/printing.dart` (already imported) — if `flutter analyze` flags it as undefined, add `import 'dart:typed_data';` explicitly.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/shared_document_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/screens/share/shared_document_screen.dart test/shared_document_screen_test.dart assets/translations/de.json assets/translations/en.json
git commit -m "feat: implement SharedDocumentScreen to view offer/invoice share links"
```

---

### Task 8: Wire up offer sharing

**Files:**
- Modify: `lib/screens/offer/create_offer_screen.dart`
- Modify: `lib/screens/offer/widgets/offer_share_dialog.dart`

**Interfaces:**
- Consumes: `shareLinkRepository.createOfferShareLink(OfferData, {required String orderId})` (Task 5).
- Produces: `OfferShareDialog` gains a required `shareUrl` builder; the "PDF teilen" button now creates a link instead of attaching bytes.

- [ ] **Step 1: Pass the data `OfferShareDialog` needs**

In `lib/screens/offer/create_offer_screen.dart`, in `_shareOffer()` (starts line 875), replace the `OfferShareDialog(...)` construction (lines 897-904):

```dart
      builder: (_) => OfferShareDialog(
        clientName: _clientNameCtrl.text.trim(),
        editorName: _editorNameCtrl.text.trim(),
        selectedCocktails: cocktails,
        generatePdfBytes: () =>
            OfferPdfGenerator.generatePdfBytes(offerSnapshot),
        pdfFilename: pdfFilename,
      ),
```

with:

```dart
      builder: (_) => OfferShareDialog(
        clientName: _clientNameCtrl.text.trim(),
        editorName: _editorNameCtrl.text.trim(),
        selectedCocktails: cocktails,
        generatePdfBytes: () =>
            OfferPdfGenerator.generatePdfBytes(offerSnapshot),
        pdfFilename: pdfFilename,
        createShareLink: () => shareLinkRepository.createOfferShareLink(
          offerSnapshot,
          orderId: widget.order.id,
        ),
      ),
```

Add the import near the other imports in this file: `import '../../data/share_link_repository.dart';`

- [ ] **Step 2: Accept the new callback and build the link URL**

In `lib/screens/offer/widgets/offer_share_dialog.dart`, add a new required field to the widget:

```dart
  const OfferShareDialog({
    super.key,
    required this.clientName,
    required this.editorName,
    required this.selectedCocktails,
    required this.generatePdfBytes,
    required this.pdfFilename,
    required this.createShareLink,
  });
```

and its declaration alongside the others:

```dart
  /// Creates a 14-day share link for the current offer snapshot and
  /// returns its short code (see ShareLinkRepository).
  final Future<String> Function() createShareLink;
```

- [ ] **Step 3: Replace `_sharePdf` with a link-based share**

Replace the entire `_sharePdf` method (lines 226-251) with:

```dart
  /// Creates a 14-day share link, appends it to the message, copies the
  /// full text to the clipboard, and opens WhatsApp with it — replacing
  /// the previous raw-PDF-bytes share, which produced an unusable
  /// `blob:` URL for the recipient on Flutter web.
  Future<void> _sharePdf() async {
    setState(() => _pdfSharing = true);
    try {
      final code = await widget.createShareLink();
      final shareUrl = '${Uri.base.origin}/s/$code';
      final fullMessage = '${_messageCtrl.text}\n\n$shareUrl';

      await Clipboard.setData(ClipboardData(text: fullMessage));

      final encoded = Uri.encodeComponent(fullMessage);
      final webUrl = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offer.share_pdf_hint'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offer.share_pdf_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfSharing = false);
    }
  }
```

Remove the now-unused `generatePdfBytes` invocation inside this method (it no longer calls `widget.generatePdfBytes()` or `Printing.sharePdf`) — `widget.generatePdfBytes` itself stays on the widget (it's still used to build `pdfFilename`'s bytes nowhere else in this file — check: if `generatePdfBytes` has no remaining caller in this file after this change, remove the field and its constructor parameter too, and remove the now-unused `package:printing/printing.dart` import; otherwise leave it in place). Update the info tip text `'offer.share_pdf_tip'` in `assets/translations/de.json`/`en.json` if it still says "PDF" where it should say "Link" (check the current string first — if it explains the old attach-a-PDF flow, change it to explain that a link is copied to the clipboard).

- [ ] **Step 4: Run analyze and fix any fallout**

Run: `flutter analyze lib/screens/offer/create_offer_screen.dart lib/screens/offer/widgets/offer_share_dialog.dart`
Expected: No issues. If `generatePdfBytes`/`pdfFilename` become genuinely unused after Step 3, remove them from both the widget's fields and its constructor call in Step 1 rather than leaving dead code.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/offer/create_offer_screen.dart lib/screens/offer/widgets/offer_share_dialog.dart assets/translations/de.json assets/translations/en.json
git commit -m "feat: share offers via a 14-day link instead of raw PDF bytes"
```

---

### Task 9: Wire up invoice sharing

**Files:**
- Modify: `lib/screens/invoice/create_invoice_screen.dart`
- Modify: `assets/translations/de.json`, `assets/translations/en.json`

**Interfaces:**
- Consumes: `shareLinkRepository.createInvoiceShareLink(SavedOrder)` (Task 5).

- [ ] **Step 1: Add translation keys**

In `assets/translations/de.json`, inside the existing `"invoice"` object, add:

```json
    "share_link_copied": "Link in Zwischenablage kopiert (14 Tage gültig)",
```

In `assets/translations/en.json`, inside the existing `"invoice"` object, add:

```json
    "share_link_copied": "Link copied to clipboard (valid 14 days)",
```

- [ ] **Step 2: Replace the raw-bytes share in `_generatePdf()`**

In `lib/screens/invoice/create_invoice_screen.dart`, inside `_generatePdf()` (the method containing the OneDrive upload block, ending in `await Printing.sharePdf(bytes: pdfBytes, filename: fileName);`), replace that line:

```dart
      // Share/download the PDF
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('invoice.pdf_created'.tr())));
      }
```

with:

```dart
      // Create a 14-day share link instead of attaching raw PDF bytes
      // (which produced an unusable blob: URL for the recipient on web).
      final code = await shareLinkRepository.createInvoiceShareLink(updatedOrder);
      final shareUrl = '${Uri.base.origin}/s/$code';
      await Clipboard.setData(ClipboardData(text: shareUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invoice.share_link_copied'.tr())),
        );
      }
```

Add the imports this file needs, if not already present: `import 'package:flutter/services.dart';` (for `Clipboard`/`ClipboardData`) and `import '../../data/share_link_repository.dart';`. Check whether `Printing` (from `package:printing/printing.dart`) is still used elsewhere in this file (e.g. by `_downloadPdf`'s `Printing.layoutPdf`, seen earlier in this file) — if so keep that import; do not remove it just because this one call site no longer needs it.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/screens/invoice/create_invoice_screen.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/invoice/create_invoice_screen.dart assets/translations/de.json assets/translations/en.json
git commit -m "feat: share invoices via a 14-day link instead of raw PDF bytes"
```

---

### Task 10: Whole-feature verification

**Files:** none (verification only)

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: No new issues beyond the two pre-existing info-level notices already present on `main` before this plan started (`recipe_edit_dialog.dart:57` and `order_detail_sheet.dart:561`).

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All tests pass, including every new test file added in Tasks 2-7.

- [ ] **Step 3: Manual smoke check (requires a deployed dev environment)**

After this plan's commits are pushed to `main` (dev auto-deploys) — per this repo's `deploy_mechanics` convention, also run `firebase deploy --only firestore:rules --project development` (and `--project production` once ready to ship, noting the production `deploy.yml` workflow already deploys rules on a version tag per this session's earlier finding) since the new `shareLinks` rule in `firestore.rules` is not deployed by the dev GH Actions workflow automatically:
  1. Open an offer in the admin UI, click "Teilen", click "PDF teilen" (now link-based), confirm a `/s/...` link is copied/opened.
  2. Open that link in a fresh incognito/private browser window (no session).
  3. Confirm the PDF renders without any login redirect.
  4. Repeat for an invoice via "Angebot annehmen" → invoice generation flow.

- [ ] **Step 4: Commit** (only if Steps 1-2 required fixes)

```bash
git add -u
git commit -m "fix: address whole-feature review findings for share links"
```
