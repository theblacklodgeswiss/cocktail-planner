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

- Staff listed on the existing Mitarbeiter (Employees) screen get full view and
  edit access to all orders.
- Customers see only their own requests, enforced server-side.
- A customer-facing list of their own past requests.
- Per-flavor shot quantities captured on the request form and carried through to
  the offer.

## Non-goals

See "Related issues noticed, not fixed here" at the end.

## 1. Role model

### Source of truth: the existing Employees screen

The app already has a Mitarbeiter screen (`screens/admin/employees_tab.dart`,
`screens/settings/employees_screen.dart`) backed by the `employees` collection,
where an admin maintains a roster with a name, an optional email, and a Rolle
dropdown — `EmployeeRole { leadingSupervisor, supervisor, staff }`
(`lib/models/employee.dart`).

That roster is the source of truth for the new tier. No second role field is
added to `allowedUsers`, and `user_management_screen.dart` keeps its current
admin toggle unchanged. Admins grant order access by putting someone on the
Employees screen with their login email filled in — one roster, one place.

The access predicate is:

```
hasFullOrderAccess := isAdmin || isSuperAdmin || isRosteredEmployee(login email)
```

Admin remains a superset: `superAdmin ⊇ admin ⊇ employee ⊇ customer`. An admin
does not need an `employees` record.

### All three EmployeeRole tiers qualify equally

`staff`, `supervisor`, and `leadingSupervisor` all grant the same full order
view and edit access. The distinction stays what it is today: a staffing detail
about who is in charge at an event, surfaced on offer and invoice PDFs. It is
not a second access ladder.

The one differentiation worth naming and rejecting: restricting destructive or
financial actions (order deletion, invoice creation) to `leadingSupervisor`.
Rejected for now because deletion is already super-admin-only
(`order_detail_sheet.dart:904`, `order_repository.dart:487`), so the remaining
delta is invoicing — and a supervisor who can quote but not invoice cannot close
out an event. If the owner later wants this, it is an additive change to the
gate calls, not a change to the model. Recorded as an option, not adopted.

### Why a derived mirror collection is required

Firestore security rules cannot run queries. They expose exactly two document
operations — `get(path)` and `exists(path)` — and both need a fully known
document path. There is no `where`, no collection iteration, no way to ask "is
there a document in `employees` whose `email` field equals X".

`employees` documents use auto-generated IDs (`employeesCollection.add(data)`,
`employee_repository.dart:62`), so the path cannot be derived from an email
either. The lookup the owner is asking for is expressible on the client and
inexpressible on the server.

Doing it client-side only is not an option. The whole point of this work is that
`orders` is currently server-readable by every signed-in user; a client-side
employee check would leave that untouched.

So: `employees` stays authoritative and admin-facing, and every employee record
that has an email is mirrored into an email-keyed index that rules *can*
address.

### The `employeeAccess` mirror

New collection, document ID = the employee's email, lowercased and trimmed —
the same normalization `allowedUsers` already uses (`auth_service.dart:111`):

```
employeeAccess/{email-lowercase}
  employeeId: "<employees doc id>"
  role:       "staff" | "supervisor" | "leading_supervisor"
  name:       "<display name>"
  updatedAt:  <server timestamp>
```

It stores no access decision of its own — existence *is* the grant. `role` and
`name` are carried so the client can label the session ("Angemeldet als
Mitarbeiter") without a second lookup, and so a repair job can verify the mirror
against the roster.

Rejected alternatives:

- **Re-key `employees` by lowercased email.** Would let rules address it
  directly, but breaks every existing document, breaks `assignedEmployees`
  references, and has no valid ID for the roster entries that legitimately have
  no email.
- **A synced `isEmployee` boolean on `allowedUsers`.** Fewer collections, but it
  re-centers app access on `allowedUsers` — the exact thing the owner asked us
  to move away from — and would require creating `allowedUsers` documents for
  staff who are not admins, blurring what that collection means.

### Keeping the mirror correct

`EmployeeRepository` owns the sync, writing both documents in a single
`WriteBatch` so the roster and the mirror cannot diverge on a partial failure:

- `addEmployee` — if an email is given, batch the `employees` create with an
  `employeeAccess/{email}` set.
- `updateEmployee` — needs the *previous* email to clean up. Change the
  signature to take the existing `Employee` (the two callers in
  `employees_tab.dart:182` and the settings screen already hold it) rather than
  a bare `id`. Batch: update the roster doc; delete the old mirror doc if the
  email changed or was cleared; set the new mirror doc if an email is present.
- `deleteEmployee` — same signature change, from `String id` to `Employee`, so
  the mirror doc can be deleted in the same batch. Deleting by id alone cannot
  know which mirror doc to remove.
- `reorderEmployees` — untouched; `sortOrder` has no bearing on access.
- `rebuildEmployeeAccessIndex()` — new: reads the whole roster, writes every
  mirror document, and deletes mirror documents with no matching roster entry.
  Needed for the initial rollout and as a repair action. See §6.

Normalize on write in one place — a single `String? normalizeAccessEmail(String?)`
helper doing trim + lowercase, returning null for empty — and use it for both
the mirror doc ID and the `employees.email` field itself, so the roster stops
storing mixed-case addresses going forward.

**Revoking access is immediate and obvious**: removing someone from the
Employees screen, or clearing their email, deletes the mirror document in the
same batch. There is no separate "deactivate" step to forget.

### AuthService changes

Add:

```dart
enum AppRole { customer, employee, admin, superAdmin }
```

with an ordering helper (`bool atLeast(AppRole other)`) based on `index`, so
gates read as `role.atLeast(AppRole.employee)`.

On `AuthService`:

- `AppRole? _cachedRole` replaces `bool? _cachedIsAdmin` as the single cached
  value, still cleared by the `authStateChanges` listener (l.13-18).
- `Future<AppRole> checkRole()` replaces the body of `checkIsAdmin()`. It reads
  `allowedUsers/{email-lowercase}` as today; if that yields admin it returns
  immediately. Otherwise it reads `employeeAccess/{email-lowercase}` — a single
  document get by known path, the same cheap shape as the existing admin check,
  no query — and returns `AppRole.employee` if it exists, `AppRole.customer`
  otherwise.
- `AppRole get role`, `bool get isEmployeeOrHigher`, `bool get roleResolved`,
  and `Stream<AppRole> get roleChanges`.
- `EmployeeRole? get employeeRole` — read from the mirror document, for display
  only. Never used in a gate.

Keep `isAdmin`, `canManageUsers`, and `isSuperAdmin` as getters derived from
`role`, and keep `checkIsAdmin()` as a thin wrapper over `checkRole()`. That is
what stops the thirteen files referencing role getters from all needing edits —
only the ones whose *policy* changes get touched.

The client deliberately reads the same mirror the rules read, rather than
querying `employees` by email directly. A client that queried the authoritative
roster while rules consulted the mirror would, on any drift, show a user the
staff UI and then have every request denied — the worst possible failure shape.
One predicate, one document, both sides.

`AllowedUser` is unchanged. No `role` field is added to it.

### Fixing the gate race

`isAdmin` currently returns `false` while `checkIsAdmin()` is still in flight, so
`AdminProtectedScreen` renders "access denied" on first paint after a hard
refresh. With more gated screens this becomes routinely visible, and the
employee path is now two sequential document reads rather than one, widening the
window.

`RoleProtectedScreen` must render a centered progress indicator while
`!authService.roleResolved` and only decide once the role is known, listening to
`roleChanges` for reactivity.

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

- `screens/settings/employees_screen.dart:14` and the employees tab — **now the
  access-granting surface**, so this one matters more than before. An employee
  who could edit the roster could promote anyone, including themselves.
- `screens/settings/user_management_screen.dart:42`
- `screens/settings/admin_settings_screen.dart:92`
- `screens/settings/settings_screen.dart:75, 83, 465`
- `screens/admin/admin_screen.dart:35` and `user_menu_sheet.dart:32, 56`

Staying **super-admin-only**: `screens/orders/order_detail_sheet.dart:904`
(delete) and `data/order_repository.dart:487`.

Decided explicitly: employees **can** create offers and invoices.
`/create-offer`, `/create-invoice`, and `/shopping-list` are order operations,
and an employee who can edit an order but cannot quote it cannot do the job. The
line is configuration and user management, not money.

`app_router.dart` keeps its current logged-in/logged-out redirect. Role
enforcement stays in the screen wrappers rather than moving into the router,
because the router redirect is synchronous and cannot await role resolution.

## 2. Order ownership

`_ownerMetadata()` (`data/order_repository.dart:17-30`) already writes `userId`
(uid) and `userEmail` on every create, and `saveOrder` also writes `createdBy`.
`SavedOrder` reads only `createdBy` (`models/order.dart:105, 217`).

Changes:

- Add `final String? userId` and `final String? userEmail` to `SavedOrder`, read
  in `fromFirestore` as `data['userId'] as String?` / `data['userEmail'] as
  String?`.
- `userId` is the canonical ownership key. It is stable, always present for
  authenticated users, and is the one field the existing `isOrderOwner()` rule
  already checks first. `createdBy` is not usable as a key: it is `email ?? uid`,
  so its type varies per document.
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
rather than a silent leak — but a confusing one to debug.

## 3. Firestore rules

Helper block:

```
function authEmail() {
  return request.auth.token.email.lower();
}

function hasEmail() {
  return request.auth != null && request.auth.token.email != null;
}

function isAdminFromCollection() {
  return hasEmail()
      && exists(/databases/$(database)/documents/allowedUsers/$(authEmail()))
      && get(/databases/$(database)/documents/allowedUsers/$(authEmail())).data.isAdmin == true;
}

function isRosteredEmployee() {
  return hasEmail()
      && exists(/databases/$(database)/documents/employeeAccess/$(authEmail()));
}

function hasFullOrderAccess() {
  return isSuperAdmin() || isAdminFromCollection() || isRosteredEmployee();
}
```

Note `.lower()` — the current `isAdminFromCollection()` (`firestore.rules:13`)
looks the document up under the raw token email while Dart writes it lowercased
(`auth_service.dart:111`), so any mixed-case address fails the server-side admin
check today. Fixing it is part of this rewrite, and the same normalization is
what makes the `employeeAccess` lookup work.

`isRosteredEmployee()` is an `exists()`, not a `get()` — existence is the grant,
so the mirror's field contents are never trusted for authorization. That also
makes it the cheaper of the two checks.

The `orders` block becomes:

```
match /orders/{orderId} {
  allow read:   if isOrderOwner() || hasFullOrderAccess();
  allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
  allow update, delete: if isOrderOwner() || hasFullOrderAccess();
}
```

`isOrderOwner()` comes first deliberately. Rules short-circuit on `||`, and
`isOrderOwner()` reads no additional documents — so the common customer case
costs zero extra document reads, and only staff pay for the one or two `get`/
`exists` lookups. Those lookups count against the rules access limit (10
documents for a single-document request, 20 for a query); at a worst case of two
per evaluation this is comfortably inside it, but it is the reason not to add
further `get()`-based conditions to this rule casually.

New collection:

```
match /employeeAccess/{email} {
  allow read: if canManageUsers()
              || (hasEmail() && email == authEmail());
  allow write: if canManageUsers();
}
```

Write is admin-only, matching `employees` (`firestore.rules:97`). This is
load-bearing: if an employee could write `employeeAccess`, the tier would be
self-granting. Read is limited to one's own document plus admins, so the mirror
does not become a staff directory readable by every customer.

`employees` itself keeps `read: if isAuthenticated()` (order detail needs the
roster to render assignment chips) and `write: if canManageUsers()`.

**Critical implementation constraint:** Firestore evaluates `read` rules against
a query, not against results. A collection query that is not provably scoped to
documents the caller can read is rejected wholesale. So the moment this rule
ships, any customer-visible screen must use `watchOrdersForOwner` — the existing
`watchOrders` will throw `permission-denied` for customers instead of returning
a filtered list. The rule change and section 2's scoped queries must land
together, in the order given in §6.

Also recommended in the same pass, since it is one line and currently leaks every
user's email and admin status to every signed-in account:

```
match /allowedUsers/{email} {
  allow read: if canManageUsers() || (hasEmail() && email == authEmail());
  allow create, update, delete: if canManageUsers();
}
```

Compatible with the Dart code as written: `checkRole()` reads only the caller's
own document, and `getAllowedUsers()` (`auth_service.dart:238`) is already
guarded by `canManageUsers`.

## 4. The "my requests" view

Route `/my-requests` -> `MyRequestsScreen`, in
`lib/screens/dashboard/my_requests_screen.dart`.

`CustomerLandingScreen` (`lib/screens/dashboard/customer_landing_screen.dart`)
gains a section below the existing "new order" call to action: the heading
"Meine Anfragen", the three most recent requests, and an "alle anzeigen" link to
`/my-requests` when there are more. Putting it on the landing screen directly
satisfies the requirement without asking the customer to discover a menu item;
the full route exists for when the list grows.

Data source: `orderRepository.watchOrdersForOwner(authService.currentUser!.uid)`.

`order_success_screen.dart` keeps returning to `/`, which now lands the customer
on a page showing the request they just submitted — a better confirmation than
the current dead end. No change needed there.

**Anonymous users are excluded.** A Firebase anonymous uid is per-device and is
destroyed on sign-out, so a request list keyed on it would silently empty itself
and could resurface someone else's requests on a shared device. Anonymous users
keep the submit-only flow; the section renders a short prompt to sign in with
Google to keep track of requests. Anonymous users also have no email, so they
can never match the employee mirror — `hasEmail()` guards every role lookup.

### Widget reuse

Do not reuse `OrdersTable` (`lib/screens/orders/widgets/orders_table.dart`). Its
columns are status, date, name, persons, articles, **total**, created-at. Total
and article count are internal figures — 0 on a fresh request, then the quoted
price — which is not what a customer should read out of a list before the offer
is formally sent. Parameterizing it with `showTotal`/`showArticles`/`compact`
flags would mean three booleans threaded through both the desktop `DataTable`
and mobile card branches to serve one caller.

Instead add `lib/screens/dashboard/widgets/my_requests_list.dart`: a card list
showing event date, request name, person count, and a status chip, reusing the
existing `order_info_chip.dart` and `order_status_helpers.dart` so the visual
language matches the staff views without coupling to their column set.

Tapping a row opens `MyRequestDetailSheet` — a read-only summary of what was
submitted (date, time, location, persons, service type, selected cocktails,
shots with quantities, extras, remarks). A new widget rather than a mode on
`order_detail_sheet.dart`, which is ~900 lines of staff tooling including offer
generation, status transitions, employee assignment, and a delete section.

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
`recipe.isShot && isSelected`, render a compact quantity stepper — minus, the
number, plus — inside the card below the name. It reads and writes
`Map<String, int> _shotQuantities` keyed by recipe name, held in
`_ModernOrderFormScreenState`.

Rules:

- Selecting a shot inserts `name -> 1`. Default 1, not a larger batch size: a
  predictable starting point the customer must raise deliberately beats a guessed
  default they might not notice and submit unchanged.
- Minimum is 1; pressing minus at 1 deselects the shot and removes the entry.
- Deselecting via the card tap removes the entry.
- The `_cocktailFilter` reset at line 1177, which clears shots when switching
  away from the shots filter, must also clear the corresponding map entries, or
  stale quantities will be submitted for shots no longer selected.
- The stepper is shown for staff too. The quantity is useful data regardless of
  who enters it, and a role-conditional form widget is a needless branch.

The steppers need a semantics label using the flavor name — a bare number plus
two icon buttons is not self-describing to a screen reader.

### Persisting from both submit paths

The customer path, `_savePendingOrderAndShowThanks` (line 596), currently sends
`cocktails: _selectedRecipes.map((r) => r.name).toList()` — every selected
recipe, shots included — and never passes `shots:` at all. Shot flavors are
being filed as cocktails today.

That has to be corrected here. It is not optional cleanup: the point of this
section is that a customer's shot choice reaches staff, and `shotQuantities`
entries whose names appear under `cocktails` and nowhere under `shots` would be
incoherent. The fix is the split already written correctly in
`_updateFormOrderAndNavigate` (lines 553-558) — partition `_selectedRecipes` on
`isShot` — plus passing `shotQuantities` built from `_shotQuantities`.

Apply the same `shotQuantities` write to `_updateFormOrderAndNavigate`'s
`updateOrder` call so the staff path stays in step.

Scope note: only the cocktails/shots split and the new field are in scope here.
Other data that path drops is listed under related issues.

### Keeping the offer in step

`offerShotsCount` and `offerShotsPricePerPiece` stay as they are: the
admin-editable, billable aggregate. `requestedShotsTotal` is what the customer
asked for. These are two different numbers and are allowed to diverge — staff
routinely adjust quantities when quoting.

The link is seeding, in `_buildRequestDerivedOfferPositions`
(`screens/offer/create_offer_screen.dart:1703`):

- Quantity becomes `order.offerShotsCount > 0 ? order.offerShotsCount :
  order.requestedShotsTotal`. An untouched order quotes what the customer asked
  for; once an admin has set a count, theirs wins and is never overwritten.
- The remark, when `offerShotsRemark` is empty, becomes the per-flavor breakdown
  — `"Aarewasser 20, Tequila 10"` — built from `shotSelections`, falling back to
  the current `order.shots.join(', ')` when `shotSelections` is empty (legacy
  orders). The breakdown is what staff actually need to buy against.

`invoice_pdf_generator.dart` and `create_invoice_screen.dart` are unchanged:
they read `offerShotsCount`, which now has a better default.

## 6. Migration and rollout

No data migration for orders. Two one-time setup steps for the roster.

**Employees need emails on file.** `Employee.email` is optional today and many
roster entries will have none — they exist to be assigned to events, not to log
in. A record without an email cannot grant anyone app access, and there is no way
to infer one. Before the tier does anything, an admin must open the Mitarbeiter
screen and fill in the login email for each person who should have order access.
This is expected manual work, not a defect, and it is the right default: access
is granted by a deliberate act, never inferred from a name.

To make it visible rather than mysterious, the Employees list shows a small
"kein App-Zugang" hint on rows with no email, so an admin can see at a glance who
is rostered but cannot sign in.

**Initial mirror build.** Existing `employees` documents predate
`employeeAccess`. Run `rebuildEmployeeAccessIndex()` once after deploy, exposed
as an admin action on the Employees screen ("Zugänge neu aufbauen") rather than
a script, so it can also be used later if anyone suspects drift. It is
idempotent: it writes a mirror document for every roster entry with an email and
deletes mirror documents with no matching entry.

**Orders without `userId`.** Every order created through the app already carries
`userId` (`_ownerMetadata`, in place before this work). Orders imported from
Microsoft Forms and genuinely old documents do not. Those are invisible to
customers under the new read rule and visible to employees and admins — the
correct outcome: a customer cannot be shown a historical order we cannot prove is
theirs. `MyRequestsList` renders its empty state for a customer with no
attributable orders. This is the intended, permanent behavior, not a temporary
state awaiting a backfill.

**Orders without `shotQuantities`.** `shotSelections` parses to an empty list,
`requestedShotsTotal` is 0, `shots` is still populated, and the offer falls back
to `offerShotsCount` and the joined-names remark — byte-identical output to
today.

**Existing admins.** Untouched. `allowedUsers.isAdmin` keeps working exactly as
it does now, with no `employees` record required.

**Deploy order.** This matters:

1. Ship `employeeAccess` writes in `EmployeeRepository` plus the
   `match /employeeAccess/...` rule, and run the rebuild. The mirror now exists
   and is maintained, but nothing reads it for authorization yet.
2. Ship the scoped client queries (§2). They work fine under the current
   permissive rules.
3. Ship the `orders` rules change (§3) last.

Reversing 2 and 3 breaks every customer session in between. Shipping 3 before 1
locks every employee out of orders until the rebuild runs.

## Testing

- `AppRole` resolution: admin via `allowedUsers`, super admin by email, employee
  via mirror, customer with neither, and the overlap case (admin who is also on
  the roster resolves to admin, not employee). Mixed-case and whitespace-padded
  emails resolve correctly on both paths.
- Mirror sync: add with email, add without email, update changing the email
  (old mirror doc deleted, new one created), update clearing the email (mirror
  deleted), delete employee (mirror deleted), reorder (mirror untouched).
  `rebuildEmployeeAccessIndex` is idempotent and removes orphans.
- `SavedOrder.fromFirestore`: `userId`/`userEmail` present, absent, wrong type;
  `shotQuantities` well-formed, empty, missing, and containing a malformed entry.
- `requestedShotsTotal` over empty and populated selections.
- Firestore rules, via the emulator: customer reading own order (allow), another's
  (deny), unscoped collection query (deny), owner-scoped query (allow); rostered
  employee reading any order (allow); employee writing `employeeAccess` (deny) —
  this is the self-promotion guard and must be an explicit test; employee writing
  `employees` (deny); customer reading another user's `employeeAccess` doc (deny);
  create with mismatched `userId` (deny); mixed-case admin email resolving
  correctly.
- Widget test for the shot stepper: select inserts 1, minus at 1 deselects,
  switching the filter away from shots clears the map.
- Widget test for `RoleProtectedScreen`: spinner while unresolved, not the
  access-denied screen.

## Suggested implementation order

1. `AppRole` + `AuthService` role resolution reading `allowedUsers` then
   `employeeAccess`, with `isAdmin`/`canManageUsers`/`isSuperAdmin` derived and
   a `roleChanges` stream. No behavior change yet.
2. `employeeAccess` mirror: normalization helper, batched writes in
   `EmployeeRepository` (including the `updateEmployee`/`deleteEmployee`
   signature changes to take an `Employee`), and
   `rebuildEmployeeAccessIndex()`.
3. `match /employeeAccess/...` rule + the `.lower()` fix in
   `isAdminFromCollection()`. Deploy and run the rebuild.
4. Employees screen: the rebuild action and the "kein App-Zugang" hint.
5. `RoleProtectedScreen` with the unresolved-state spinner;
   `AdminProtectedScreen` becomes a wrapper. Still no policy change.
6. Flip the six employee-tier call sites listed in §1.
7. `userId`/`userEmail` on `SavedOrder`; `watchOrdersForOwner` /
   `getOrdersForOwner`; composite index.
8. `MyRequestsList`, `MyRequestsScreen`, `MyRequestDetailSheet`, and the
   `CustomerLandingScreen` section.
9. `orders` rules rewrite and emulator tests. Deploy after 7 and 8 are live.
10. `ShotSelection` model, repository parameters, the form stepper, and the
    cocktails/shots split in `_savePendingOrderAndShowThanks`.
11. Offer seeding from `requestedShotsTotal` and the per-flavor remark.

## Related issues noticed, not fixed here

Found while researching. Each deserves its own ticket.

- **Pending orders drop form data.** `_savePendingOrderAndShowThanks`
  (`modern_order_form_screen.dart:596`) never passes `serviceType` — it passes the
  service type as `bar:` instead — so a customer request loses the field the rest
  of the app branches on. Only the cocktails/shots split is corrected by this
  work, because §5 depends on it. The rest of the path's data loss is a separate
  fix.
- **`/orders` is registered twice** in `lib/router/app_router.dart` (lines 70 and
  131), pointing at different screens. The first registration wins; the second is
  dead configuration.
- **Two classes named `DashboardScreen`**, in
  `screens/dashboard/dashboard_screen.dart` and
  `screens/dashboard/simple_dashboard_screen.dart`. The router imports the
  `simple_` file, so the other is only reachable via direct import and its admin
  check at line 71 is effectively dead. Renaming is mechanical but touches enough
  imports to deserve its own change.
- **Pending status is inferred from `total == 0`** across the repository
  (`watchOrders`, `watchPendingOrders`) rather than from an explicit status. A
  legitimately free order would be permanently pending. `OrderStatus` has no
  `pending` member; adding one is a data migration.
- **Employee roster emails are unnormalized today.** This design normalizes on
  write going forward, but existing `employees.email` values keep whatever casing
  they were typed with. The mirror lowercases the key regardless, so access works
  either way; tidying the stored roster values is cosmetic.
