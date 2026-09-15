# Order Access Roles, Own-Request Visibility, and Per-Flavor Shot Quantities

Date: 2026-09-15
Status: Design approved, not yet planned

## Problem

The app has exactly one access tier above "signed in": admin. Everything
order-related is gated on `AuthService.isAdmin`, and everything not gated is
visible to everyone. Three consequences the business owner wants fixed:

1. Bar staff need full order access without being handed admin powers over
   users, pricing configuration, and settings.
2. A customer who submits a request (Anfrage) can never see it again. There is
   no "my requests" concept anywhere in the app.
3. A customer who wants shots can only tick flavor names. There is no way to say
   "20 Aarewasser, 10 Tequila", so staff have to phone back for quantities.

There is also a security gap behind (2): `firestore.rules:63` allows
`read: if isAuthenticated()` on the whole `orders` collection. Every signed-in
user — including anonymous ones — can already read every customer's order,
contact phone number, and address. Only the client UI hides them. Closing this
is a requirement of this work, not a nice-to-have.

## Goals

- A named "employee" tier between "customer" and "admin" that can view and edit
  all orders.
- Customers see only their own requests, enforced server-side.
- A customer-facing list of their own past requests.
- Per-flavor shot quantities captured on the request form and carried through to
  the offer.

## Non-goals

See "Related issues noticed, not fixed here" at the end.

## 1. Role model

### Where the tier lives

Add a `role` string field to `allowedUsers/{email-lowercase}`, alongside the
existing `isAdmin` boolean. Values: `"employee"`, `"admin"`. A signed-in user
with no `allowedUsers` document is a customer.

`isAdmin` stays as the authoritative admin signal and is not migrated away.
Resolution order:

1. Email matches `superAdminEmail` -> `AppRole.superAdmin`
2. `isAdmin == true` -> `AppRole.admin` (regardless of `role`)
3. `role == "admin"` -> `AppRole.admin`
4. `role == "employee"` -> `AppRole.employee`
5. Otherwise -> `AppRole.customer`

Keeping `isAdmin` as a first-class input means every existing admin keeps
working with zero data migration, and `addAllowedUser` / `updateAdminStatus`
(`auth_service.dart:255, 281`) keep their current semantics. Setting `role`
becomes an additive write.

### Why not reuse the `employees` collection

`lib/models/employee.dart` defines `EmployeeRole { leadingSupervisor,
supervisor, staff }` and the `employees` collection is a *staffing* record: who
physically works an event, referenced from `SavedOrder.assignedEmployees` for
offer and invoice PDFs. It has an optional `email` field, but nothing joins it
to Firebase Auth, and it intentionally contains people who have no app account
at all.

Matching `employees.email` against the signed-in email would silently merge two
independent concepts — "who works the bar on Saturday" and "who may read
customer data". Adding a temporary helper to an event would grant them the
entire order history. These stay separate. `EmployeeRole` is not touched by this
work.

### AuthService changes

Add:

```dart
enum AppRole { customer, employee, admin, superAdmin }
```

with an ordering helper (`bool atLeast(AppRole other)`) based on `index`, so
gates read as `role.atLeast(AppRole.employee)`.

Add to `AuthService`:

- `AppRole? _cachedRole` replacing `bool? _cachedIsAdmin` as the single cached
  value.
- `AppRole get role` — returns `_cachedRole ?? AppRole.customer`.
- `bool get roleResolved` — `_cachedRole != null`. See the gate race below.
- `bool get isEmployeeOrHigher` — `role.atLeast(AppRole.employee)`.
- `Future<AppRole> checkRole()` — replaces the body of `checkIsAdmin()`, reads
  the `allowedUsers` doc once and applies the resolution order above.

Keep `isAdmin`, `canManageUsers`, and `isSuperAdmin` as getters derived from
`role`. `checkIsAdmin()` stays as a thin wrapper over `checkRole()` so nothing
outside `auth_service.dart` needs to change to keep compiling. This is what
keeps the thirteen files that reference role getters from all needing edits;
only the ones whose *policy* changes get touched.

Extend `AllowedUser` (`auth_service.dart:328`) with `final AppRole role`, parsed
with the same resolution order minus the super-admin check, and add it to
`copyWith` and `addAllowedUser`.

### Fixing the gate race

`isAdmin` currently returns `false` while `checkIsAdmin()` is still in flight,
so `AdminProtectedScreen` renders "access denied" during first paint after a
hard refresh. With more gated screens this becomes routinely visible.

`RoleProtectedScreen` must therefore render a centered progress indicator while
`!authService.roleResolved`, and only decide once the role is known. To make
that reactive, `AuthService` exposes `Stream<AppRole> get roleChanges` backed by
a broadcast controller written to by `checkRole()` and by the `authStateChanges`
listener (which resets `_cachedRole` to `null` first). The gate widget listens.

### Generalizing the gate

Replace `lib/widgets/admin_protected_screen.dart` with:

```dart
class RoleProtectedScreen extends StatelessWidget {
  const RoleProtectedScreen({required this.minimumRole, required this.child});
  final AppRole minimumRole;
  final Widget child;
}
```

Keep `AdminProtectedScreen` in the same file as a one-line wrapper delegating
with `minimumRole: AppRole.admin`, so the three existing call sites keep
compiling and are converted individually and deliberately.

### Which checks change, which stay

Change to **employee-or-higher** (order operations):

| Location | Note |
|---|---|
| `screens/orders/orders_overview_screen.dart` (wrapper) | full order list |
| `screens/orders/pending_orders_screen.dart:73` | triaging new requests is the core staff job |
| `screens/orders/orders_overview_screen.dart:276` | admin-only action in the overview |
| `screens/dashboard/simple_dashboard_screen.dart:48, 442, 461` | staff dashboard vs customer landing |
| `screens/dashboard/user_menu_sheet.dart:33` | orders tile |
| `screens/forms/modern_order_form_screen.dart:529` | staff take the pricing/shopping-list branch, customers the request branch |

Staying **admin-only** (configuration and user management):

- `screens/settings/user_management_screen.dart:42` — granting roles must not be
  self-serve; an employee who could promote themselves makes the tier
  meaningless.
- `screens/settings/admin_settings_screen.dart:92`
- `screens/settings/settings_screen.dart:75, 83, 465`
- `screens/settings/employees_screen.dart:14` — staffing roster
- `screens/admin/admin_screen.dart:35` and `user_menu_sheet.dart:32, 56`

Staying **super-admin-only**: `screens/orders/order_detail_sheet.dart:904`
(delete) and `data/order_repository.dart:487`.

Decided explicitly: employees **can** create offers and invoices. `/create-offer`,
`/create-invoice`, and `/shopping-list` are order operations, and an employee who
can edit an order but cannot quote it cannot do the job. The line is
configuration and user management, not money.

`app_router.dart` keeps its current logged-in/logged-out redirect. Role
enforcement stays in the screen wrappers rather than moving into the router,
because the router redirect is synchronous and cannot await role resolution —
pushing the decision there would reintroduce the race the gate widget just
fixed.

## 2. Order ownership

`_ownerMetadata()` (`data/order_repository.dart:17-30`) already writes `userId`
(uid) and `userEmail` on every create, and `saveOrder` also writes `createdBy`.
`SavedOrder` reads only `createdBy` (`models/order.dart:105, 217`).

Changes:

- Add `final String? userId` and `final String? userEmail` to `SavedOrder`, read
  in `fromFirestore` as `data['userId'] as String?` / `data['userEmail'] as
  String?`.
- `userId` is the canonical ownership key. It is stable, always present for
  authenticated users, never null for Google sign-in, and is the one field the
  existing `isOrderOwner()` rule already checks first. `createdBy` is not usable
  as a key: it is `email ?? uid`, so its type varies per document.
- Add owner-scoped repository reads:

```dart
Stream<List<SavedOrder>> watchOrdersForOwner(String userId)
Future<List<SavedOrder>> getOrdersForOwner(String userId)
```

  These issue `.where('userId', isEqualTo: userId).orderBy('createdAt',
  descending: true)`, keep pending orders (they do not apply the `total > 0`
  filter — a customer's request is exactly the `total == 0` case), and do not
  year-filter.

This requires a composite index on `orders(userId asc, createdAt desc)`. Add it
to `firestore.indexes.json`; the first run will otherwise fail with a console
link.

Do not add the owner scope as an optional parameter on the existing
`watchOrders`. Separate methods make it impossible to accidentally ship an
unscoped customer query, which under the new rules is a hard query failure
rather than a leak — but a confusing one to debug.

## 3. Firestore rules

Add to the helper block:

```
function allowedUserDoc() {
  return /databases/$(database)/documents/allowedUsers/$(request.auth.token.email.lower());
}

function allowedUserData() {
  return get(allowedUserDoc()).data;
}

function hasAllowedUserDoc() {
  return request.auth != null
      && request.auth.token.email != null
      && exists(allowedUserDoc());
}

function isAdminFromCollection() {
  return hasAllowedUserDoc()
      && (allowedUserData().isAdmin == true || allowedUserData().role == 'admin');
}

function isEmployeeOrHigher() {
  return isSuperAdmin()
      || (hasAllowedUserDoc() && (
            allowedUserData().isAdmin == true ||
            allowedUserData().role == 'admin' ||
            allowedUserData().role == 'employee'
          ));
}
```

Note `.lower()` — the current `isAdminFromCollection()` at `firestore.rules:13`
looks the document up under the raw token email while Dart writes it lowercased
(`auth_service.dart:111`), so any mixed-case address fails the server-side check
today. Fixing it is part of this rewrite.

The `orders` block becomes:

```
match /orders/{orderId} {
  allow read:   if isEmployeeOrHigher() || isOrderOwner();
  allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
  allow update, delete: if isEmployeeOrHigher() || isOrderOwner();
}
```

Two things this does not do, deliberately:

- It does not stop a customer from editing their own submitted request. They
  already could (`isOrderOwner()` is in the current update rule) and nothing in
  the customer UI exposes an edit path. Removing it is a behavior change with no
  requirement behind it.
- It does not restrict which *fields* a customer may write on update. Field-level
  write rules on orders are a separate hardening exercise.

`create` now pins `userId` to the caller's uid, which closes the ability to
create an order attributed to someone else.

**Critical implementation constraint:** Firestore evaluates `read` rules against
a query, not against results. A collection query that is not provably scoped to
documents the caller can read is rejected wholesale. So the moment this rule
ships, any customer-visible screen must use `watchOrdersForOwner` — the existing
`watchOrders` will throw `permission-denied` for customers instead of returning
a filtered list. The rule change and section 2's scoped queries must land
together.

Also recommended in the same pass, since it is one line and currently leaks every
user's email and role to every signed-in account:

```
match /allowedUsers/{email} {
  allow read: if canManageUsers() || (request.auth != null && email == request.auth.token.email.lower());
  allow create, update, delete: if canManageUsers();
}
```

This is compatible with the Dart code as written: `checkRole()` reads only the
caller's own document, and `getAllowedUsers()` (`auth_service.dart:238`) is
already guarded by `canManageUsers`.

## 4. The "my requests" view

Route `/my-requests` -> `MyRequestsScreen`, in
`lib/screens/dashboard/my_requests_screen.dart`.

`CustomerLandingScreen` (`lib/screens/dashboard/customer_landing_screen.dart`)
gains a section below the existing "new order" call to action: the heading
"Meine Anfragen", the three most recent requests, and a "alle anzeigen" link to
`/my-requests` when there are more. Putting it on the landing screen directly
satisfies the requirement ("sees their past requests on their dashboard")
without asking the customer to discover a menu item; the full route exists for
when the list grows.

Data source: `orderRepository.watchOrdersForOwner(authService.currentUser!.uid)`.

`order_success_screen.dart` keeps returning to `/`, which now lands the customer
on a page that shows the request they just submitted — a better confirmation
than the current dead end. No change needed there.

**Anonymous users are excluded.** A Firebase anonymous uid is per-device and is
destroyed on sign-out, so a request list keyed on it would silently empty
itself and would resurface someone else's requests on a shared device. Anonymous
users keep the submit-only flow; the section renders a short prompt to sign in
with Google to keep track of requests. This is a deliberate scope boundary, not
an oversight.

### Widget reuse

Do not reuse `OrdersTable` (`lib/screens/orders/widgets/orders_table.dart`). Its
columns are status, date, name, persons, articles, **total**, created-at. Total
and article count are internal figures — they are 0 on a fresh request and
become the quoted price afterwards, which is not what a customer should read
out of a list before the offer is formally sent. Parameterizing it with
`showTotal`/`showArticles`/`compact` flags would mean three booleans threaded
through both the desktop `DataTable` and mobile card branches to serve one
caller.

Instead add `lib/screens/dashboard/widgets/my_requests_list.dart`: a card list
showing event date, request name, person count, and a status chip. It reuses the
existing `order_info_chip.dart` and `order_status_helpers.dart`, so the visual
language matches the staff views without coupling to their column set.

Tapping a row opens `MyRequestDetailSheet` — a read-only summary of what was
submitted (date, time, location, persons, service type, selected cocktails,
shots with quantities, extras, remarks). It is a new widget rather than a mode
on `order_detail_sheet.dart`, which is ~900 lines of staff tooling including
offer generation, status transitions, employee assignment, and a delete section.

## 5. Per-flavor shot quantities

### Data shape

New Firestore field on `orders`:

```
shotQuantities: [ { name: "Aarewasser", quantity: 20 },
                  { name: "Tequila",    quantity: 10 } ]
```

The existing `shots: List<String>` field keeps being written in parallel, as the
list of names. That is what makes this change safe: every current reader —
`invoice_pdf_generator.dart:695`, `create_offer_screen.dart:1703`, the form
prefill at `modern_order_form_screen.dart:129`, and
`_buildRequestDerivedOfferPositions`' fallback remark — continues to work
untouched, and `shots` remains the field that answers "were shots requested at
all". `shotQuantities` is strictly additive detail.

Rejected: replacing `shots` with a list of maps. It would require finding and
editing every reader of `order.shots` in the same change, including two PDF
generators, for no gain — the names list is genuinely useful on its own.

Model additions in `lib/models/order.dart`:

```dart
class ShotSelection {
  const ShotSelection({required this.name, required this.quantity});
  final String name;
  final int quantity;
}
```

on `SavedOrder`: `final List<ShotSelection> shotSelections`, parsed in
`fromFirestore` from `data['shotQuantities']` with a per-entry guard (skip
entries with an empty name or a non-positive quantity), plus

```dart
int get requestedShotsTotal =>
    shotSelections.fold(0, (sum, s) => sum + s.quantity);
```

`OrderRepository.saveOrder` and `updateOrder` gain a
`List<Map<String, dynamic>> shotQuantities` parameter written straight through.

### Form UI

In `_buildCocktailCard` (`modern_order_form_screen.dart:2191`), when
`recipe.isShot && isSelected`, render a compact quantity stepper — a minus
button, the number, a plus button — inside the card, below the name. It reads
and writes `Map<String, int> _shotQuantities` keyed by recipe name, held in
`_ModernOrderFormScreenState`.

Rules:

- Selecting a shot inserts `name -> 1`. Default 1, not a larger batch size: a
  predictable starting point that the customer has to raise deliberately beats a
  guessed default they might not notice and submit unchanged.
- Minimum is 1; pressing minus at 1 deselects the shot and removes the map entry.
- Deselecting via the card tap removes the map entry.
- The `_cocktailFilter` reset at line 1177, which clears shots when switching
  away from the shots filter, must also clear the corresponding map entries, or
  stale quantities will be submitted for shots that are no longer selected.
- The stepper is shown for staff too. The quantity is useful data regardless of
  who enters it, and a role-conditional form widget is a needless branch.

The steppers need a text label for screen readers — the bare number plus two
icon buttons is not self-describing. Use the flavor name in the stepper's
semantics label.

### Persisting from both submit paths

The customer path, `_savePendingOrderAndShowThanks` (line 596), currently sends
`cocktails: _selectedRecipes.map((r) => r.name).toList()` — every selected
recipe, shots included — and never passes `shots:` at all. Shot flavors are
being filed as cocktails today.

That has to be corrected here. It is not optional cleanup: the whole point of
this section is that a customer's shot choice reaches staff, and
`shotQuantities` entries whose names appear under `cocktails` and nowhere under
`shots` would be incoherent. The fix is the split already written correctly in
`_updateFormOrderAndNavigate` (lines 553-558) — partition `_selectedRecipes` on
`isShot` — plus passing `shotQuantities` built from `_shotQuantities`.

Apply the same `shotQuantities` write to `_updateFormOrderAndNavigate`'s
`updateOrder` call so the staff path stays in step.

Scope note: only the cocktails/shots split and the new field are in scope here.
Other data the pending path drops is listed under related issues.

### Keeping the offer in step

`offerShotsCount` and `offerShotsPricePerPiece` stay exactly as they are: the
admin-editable, billable aggregate. `requestedShotsTotal` is what the customer
asked for. These are two different numbers and are allowed to diverge — staff
routinely adjust quantities when quoting.

The link between them is seeding, in `_buildRequestDerivedOfferPositions`
(`screens/offer/create_offer_screen.dart:1703`):

- Quantity becomes `order.offerShotsCount > 0 ? order.offerShotsCount :
  order.requestedShotsTotal`. An untouched order quotes what the customer asked
  for; once an admin has set a count, theirs wins and is never overwritten.
- The remark, when `offerShotsRemark` is empty, becomes the per-flavor breakdown
  — `"Aarewasser 20, Tequila 10"` — built from `shotSelections`, falling back to
  the current `order.shots.join(', ')` when `shotSelections` is empty (legacy
  orders). The breakdown is what staff actually need to buy against.

`invoice_pdf_generator.dart` and `create_invoice_screen.dart` are unchanged:
they read `offerShotsCount`, which now simply has a better default.

## 6. Migration and rollout

No backfill, no migration script.

**Orders without `userId`.** Every order created through the app already carries
`userId` (`_ownerMetadata`, in place since before this work). Orders imported
from Microsoft Forms and any genuinely old documents do not. Those are invisible
to customers under the new read rule and visible to employees and admins, which
is the correct outcome: a customer cannot be shown a historical order we cannot
prove is theirs. `MyRequestsList` renders its empty state for a customer with no
attributable orders. This is the intended, permanent behavior, not a temporary
state awaiting a backfill.

**Orders without `shotQuantities`.** `shotSelections` parses to an empty list,
`requestedShotsTotal` is 0, `shots` is still populated, and the offer falls back
to `offerShotsCount` and the joined names remark — byte-identical output to
today.

**Existing admins.** Untouched. They have `isAdmin: true`, which resolves to
`AppRole.admin` without a `role` field ever being written.

**Rollout order.** Deploy the scoped client queries (section 2) *before* the
rules (section 3). The scoped queries work fine under the current permissive
rules; the reverse order breaks every customer session between the two deploys.

**Granting the first employee.** `user_management_screen.dart` needs a role
selector (customer / employee / admin) replacing the current admin toggle,
writing `role` and keeping `isAdmin` in sync for the admin case. Until that
ships, the tier can only be granted by editing Firestore directly — acceptable
for testing, not for handover, so the selector belongs in the same release.

## Testing

- `AppRole` resolution: a table test over the five inputs (super admin email,
  `isAdmin: true`, `role: 'admin'`, `role: 'employee'`, no document), including
  the precedence case `isAdmin: true` with `role: 'employee'`.
- `SavedOrder.fromFirestore`: `userId`/`userEmail` present, absent, and wrong
  type; `shotQuantities` well-formed, empty, missing, and containing a malformed
  entry.
- `requestedShotsTotal` over empty and populated selections.
- Firestore rules, via the emulator: customer reading own order (allow),
  customer reading another's (deny), customer running an unscoped collection
  query (deny), customer running the owner-scoped query (allow), employee
  reading any order (allow), employee writing `allowedUsers` (deny), create with
  a mismatched `userId` (deny), and a mixed-case admin email resolving correctly.
- Widget test for the shot stepper: select inserts 1, minus at 1 deselects,
  switching the filter away from shots clears the map.
- Widget test for `RoleProtectedScreen`: shows the spinner while the role is
  unresolved, not the access-denied screen.

## Suggested implementation order

1. `AppRole` + `AuthService` role resolution + `roleChanges` stream, with
   `isAdmin`/`canManageUsers`/`isSuperAdmin` derived. No behavior change yet.
2. `RoleProtectedScreen` with the unresolved-state spinner; `AdminProtectedScreen`
   becomes a wrapper. Still no policy change.
3. Flip the six employee-tier call sites listed in section 1.
4. Role selector in `user_management_screen.dart`.
5. `userId`/`userEmail` on `SavedOrder`; `watchOrdersForOwner` /
   `getOrdersForOwner`; composite index.
6. `MyRequestsList`, `MyRequestsScreen`, `MyRequestDetailSheet`, and the
   `CustomerLandingScreen` section.
7. Firestore rules rewrite and emulator tests. Deploy after 5 and 6 are live.
8. `ShotSelection` model, repository parameters, the form stepper, and the
   cocktails/shots split in `_savePendingOrderAndShowThanks`.
9. Offer seeding from `requestedShotsTotal` and the per-flavor remark.

## Related issues noticed, not fixed here

Found while researching. Each deserves its own ticket.

- **Pending orders drop form data.** `_savePendingOrderAndShowThanks`
  (`modern_order_form_screen.dart:596`) does not pass `serviceType` — it passes
  the service type as `bar:` instead — so a customer request loses the field the
  rest of the app branches on. Only the cocktails/shots split is corrected by
  this work, because section 5 depends on it. The rest of the path's data loss is
  a separate fix.
- **`/orders` is registered twice** in `lib/router/app_router.dart` (lines 70 and
  131), pointing at different screens. The first registration wins; the second is
  dead configuration.
- **Two classes named `DashboardScreen`**, in
  `screens/dashboard/dashboard_screen.dart` and
  `screens/dashboard/simple_dashboard_screen.dart`. The router imports the
  `simple_` file, so the other is only reachable via direct import and its
  admin check at line 71 is effectively dead. Renaming is mechanical but touches
  enough imports to deserve its own change.
- **Pending status is inferred from `total == 0`** across the repository
  (`watchOrders`, `watchPendingOrders`) rather than from an explicit status. A
  legitimately free order would be permanently pending. `OrderStatus` has no
  `pending` member; adding one is a data migration.
