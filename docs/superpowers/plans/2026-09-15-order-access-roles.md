# Order Access Roles, Own-Request Visibility, and Per-Flavor Shot Quantities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give employees (from the existing Mitarbeiter roster) full order access without admin rights, scope customer order visibility to their own requests (client + Firestore rules), add a "my requests" dashboard for customers, and let customers specify a quantity per shot flavor.

**Architecture:** A new `employeeAccess/{email}` Firestore collection mirrors the `employees` roster by email so security rules — which cannot run queries — can grant order access with a single `exists()` check. `AuthService` gains an `AppRole` enum (customer/employee/admin/superAdmin) resolved from `allowedUsers` then `employeeAccess`. `SavedOrder` gains typed `userId`/`userEmail` and `shotSelections` (per-flavor quantities), with new owner-scoped repository queries backing a new customer-facing "my requests" view. Firestore rules are rewritten last, after every reader/writer that depends on the new shape is deployed.

**Tech Stack:** Flutter/Dart, Firebase Auth, Cloud Firestore, `flutter_test`, Firestore Security Rules.

**Spec:** `docs/superpowers/specs/2026-09-15-order-access-roles-design.md`

## Global Constraints

- Do not add a `role` field to `allowedUsers`. The `employees` roster (via the `employeeAccess` mirror) is the sole source of the employee tier; `allowedUsers.isAdmin` is the sole source of the admin tier.
- All three `EmployeeRole` values (`staff`, `supervisor`, `leadingSupervisor`) grant identical order access. Do not differentiate between them for gating.
- Employees can create offers and invoices (`/create-offer`, `/create-invoice`, `/shopping-list` stay employee-or-higher). Configuration/user-management screens stay admin-only. Order deletion stays super-admin-only.
- Keep `shots: List<String>` writing exactly as it does today — `shotQuantities` is additive, never a replacement.
- Deploy order matters and must not be reordered: (1) `employeeAccess` mirror + its rule, run the rebuild; (2) owner-scoped client queries; (3) the `orders` rules rewrite. Reversing (2) and (3) breaks every customer session; shipping (3) before (1) locks out every employee.
- Follow the repo's existing test posture: Firebase-touching code paths (repository methods that hit real Firestore, `AuthService.checkRole()`) are not unit-tested directly (see the pre-existing `Skip: Requires dependency injection for AuthService` pattern in `test/click_interactions_test.dart`) — instead extract and unit-test the pure decision logic (role resolution, parsing, totals), and verify the Firebase-touching glue manually against the dev deploy.

---

## File Structure

New files:
- `lib/models/app_role.dart` — `AppRole` enum + pure `resolveAppRole(...)` function.
- `lib/widgets/role_protected_screen.dart` — generalized gate, replaces `admin_protected_screen.dart`'s body.
- `lib/screens/dashboard/my_requests_screen.dart` — full "my requests" route.
- `lib/screens/dashboard/widgets/my_requests_list.dart` — customer-facing card list.
- `lib/screens/dashboard/widgets/my_request_detail_sheet.dart` — read-only detail sheet.
- `test/app_role_test.dart`, `test/order_model_test.dart` additions, `test/employee_model_test.dart` (normalization helper), `test/shot_selection_test.dart`, widget test additions to `test/click_interactions_test.dart`.

Modified files (by task): `lib/services/auth_service.dart`, `lib/models/employee.dart`, `lib/data/employee_repository.dart`, `lib/screens/admin/employees_tab.dart`, `firestore.rules`, `lib/widgets/admin_protected_screen.dart`, `lib/screens/orders/pending_orders_screen.dart`, `lib/screens/orders/orders_overview_screen.dart`, `lib/screens/dashboard/simple_dashboard_screen.dart`, `lib/screens/dashboard/user_menu_sheet.dart`, `lib/screens/forms/modern_order_form_screen.dart`, `lib/models/order.dart`, `lib/data/order_repository.dart`, `lib/router/app_router.dart`, `lib/screens/dashboard/customer_landing_screen.dart`, `lib/screens/offer/create_offer_screen.dart`, `firestore.indexes.json` (created if absent), `firebase.json`.

---

### Task 1: `AppRole` enum with pure, testable resolution logic

**Files:**
- Create: `lib/models/app_role.dart`
- Test: `test/app_role_test.dart`

**Interfaces:**
- Produces: `enum AppRole { customer, employee, admin, superAdmin }` with `bool atLeast(AppRole other)`; `AppRole resolveAppRole({required bool isSuperAdminEmail, required bool allowedUserIsAdmin, required bool hasEmployeeAccessDoc})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/app_role_test.dart
import 'package:cocktail_planer/models/app_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRole.atLeast', () {
    test('customer does not meet employee bar', () {
      expect(AppRole.customer.atLeast(AppRole.employee), isFalse);
    });

    test('admin meets employee bar', () {
      expect(AppRole.admin.atLeast(AppRole.employee), isTrue);
    });

    test('employee meets its own bar', () {
      expect(AppRole.employee.atLeast(AppRole.employee), isTrue);
    });
  });

  group('resolveAppRole', () {
    test('super admin email wins regardless of other flags', () {
      expect(
        resolveAppRole(
          isSuperAdminEmail: true,
          allowedUserIsAdmin: false,
          hasEmployeeAccessDoc: false,
        ),
        AppRole.superAdmin,
      );
    });

    test('allowedUsers.isAdmin wins over employeeAccess', () {
      expect(
        resolveAppRole(
          isSuperAdminEmail: false,
          allowedUserIsAdmin: true,
          hasEmployeeAccessDoc: true,
        ),
        AppRole.admin,
      );
    });

    test('employeeAccess grants employee when not admin', () {
      expect(
        resolveAppRole(
          isSuperAdminEmail: false,
          allowedUserIsAdmin: false,
          hasEmployeeAccessDoc: true,
        ),
        AppRole.employee,
      );
    });

    test('neither flag set resolves to customer', () {
      expect(
        resolveAppRole(
          isSuperAdminEmail: false,
          allowedUserIsAdmin: false,
          hasEmployeeAccessDoc: false,
        ),
        AppRole.customer,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_role_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:cocktail_planer/models/app_role.dart'`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/app_role.dart

/// Application-level access tier, independent from [EmployeeRole] (which is
/// a staffing/scheduling detail, not a login access tier).
enum AppRole {
  customer,
  employee,
  admin,
  superAdmin;

  /// True if this role's access is at least as broad as [other]'s.
  bool atLeast(AppRole other) => index >= other.index;
}

/// Pure resolution of the effective [AppRole] from the three independent
/// signals `AuthService.checkRole()` reads. Kept side-effect free so it can
/// be unit-tested without touching Firebase.
AppRole resolveAppRole({
  required bool isSuperAdminEmail,
  required bool allowedUserIsAdmin,
  required bool hasEmployeeAccessDoc,
}) {
  if (isSuperAdminEmail) return AppRole.superAdmin;
  if (allowedUserIsAdmin) return AppRole.admin;
  if (hasEmployeeAccessDoc) return AppRole.employee;
  return AppRole.customer;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app_role_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/app_role.dart test/app_role_test.dart
git commit -m "feat: add AppRole enum with pure role resolution logic"
```

---

### Task 2: Wire `AppRole` into `AuthService`

**Files:**
- Modify: `lib/services/auth_service.dart`

**Interfaces:**
- Consumes: `AppRole`, `resolveAppRole` from Task 1 (`lib/models/app_role.dart`).
- Produces: `AuthService.role` (`AppRole`), `AuthService.roleResolved` (`bool`), `AuthService.isEmployeeOrHigher` (`bool`), `AuthService.roleChanges` (`Stream<AppRole>`), `AuthService.checkRole()` (`Future<AppRole>`). `isAdmin`, `canManageUsers`, `isSuperAdmin`, `checkIsAdmin()` keep their exact current signatures and semantics, now derived from `role`.

This task has no isolated unit test of its own — `checkRole()` hits real Firestore and the repo's existing convention (see `test/click_interactions_test.dart`'s `Skip: Requires dependency injection for AuthService`) is to not fake that. Its correctness is covered by Task 1's `resolveAppRole` test (the decision logic) plus the manual verification in Step 4 below (the wiring).

- [ ] **Step 1: Read the current file to confirm nothing has drifted**

Run: `sed -n '1,30p' lib/services/auth_service.dart` and confirm the constructor still clears `_cachedIsAdmin` in the `authStateChanges` listener (lines 12-19 as of this plan) and that `checkIsAdmin()` still spans roughly lines 92-125. If line numbers drifted, adjust the edits below by content match, not line number.

- [ ] **Step 2: Replace the cached-admin field and constructor with role-based state**

Replace:

```dart
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  bool? _cachedIsAdmin;
```

with:

```dart
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  AppRole? _cachedRole;
  EmployeeRole? _cachedEmployeeRole;
  final StreamController<AppRole> _roleChangesController =
      StreamController<AppRole>.broadcast();
```

Replace the constructor body:

```dart
  AuthService._internal() {
    _firebaseAuth.authStateChanges().listen((user) {
      _cachedIsAdmin = null; // Clear cache on user change
      if (user != null && !user.isAnonymous) {
        checkIsAdmin();
      }
    });
  }
```

with:

```dart
  AuthService._internal() {
    _firebaseAuth.authStateChanges().listen((user) {
      _cachedRole = null; // Clear cache on user change
      _cachedEmployeeRole = null;
      if (user != null && !user.isAnonymous) {
        checkRole();
      }
    });
  }
```

Add the import at the top of the file: `import 'dart:async';` and `import '../models/app_role.dart';` and `import '../models/employee.dart';`.

- [ ] **Step 3: Replace the role getters and `checkIsAdmin()` with role-based versions**

Replace this whole block:

```dart
  /// Check if current user is admin (sync - uses cache)
  bool get isAdmin {
    final userEmail = email;
    if (userEmail == null) return false;
    // Super admin is always an admin
    if (userEmail.toLowerCase() == superAdminEmail.toLowerCase()) return true;
    return _cachedIsAdmin ?? false;
  }

  /// Check if current user can manage users (admin or super admin)
  bool get canManageUsers {
    final userEmail = email;
    if (userEmail == null) return false;
    if (userEmail.toLowerCase() == superAdminEmail.toLowerCase()) return true;
    return _cachedIsAdmin ?? false;
  }

  /// Check if current user is super admin
  bool get isSuperAdmin {
    final userEmail = email;
    if (userEmail == null) return false;
    return userEmail.toLowerCase() == superAdminEmail.toLowerCase();
  }

  /// Check admin status from Firestore (async - call on login)
  Future<bool> checkIsAdmin() async {
    final userEmail = email;
    if (userEmail == null) {
      _cachedIsAdmin = false;
      return false;
    }

    // Super admin is always an admin
    if (userEmail.toLowerCase() == superAdminEmail.toLowerCase()) {
      _cachedIsAdmin = true;
      return true;
    }

    // Check Firestore allowedUsers collection
    try {
      final doc = await FirebaseFirestore.instance
          .collection('allowedUsers')
          .doc(userEmail.toLowerCase())
          .get();

      if (doc.exists) {
        final data = doc.data();
        _cachedIsAdmin = data?['isAdmin'] == true;
      } else {
        _cachedIsAdmin = false;
      }
    } catch (e) {
      debugPrint('Failed to check admin status: $e');
      _cachedIsAdmin = false;
    }

    return _cachedIsAdmin ?? false;
  }
```

with:

```dart
  /// Current resolved role (sync - uses cache; defaults to customer until
  /// [checkRole] has completed at least once for this session).
  AppRole get role => _cachedRole ?? AppRole.customer;

  /// True once [checkRole] has resolved for the current auth state. Use this
  /// to distinguish "definitely a customer" from "still checking" in UI
  /// gates - see [role_protected_screen.dart].
  bool get roleResolved => _cachedRole != null;

  /// True if [role] is employee, admin, or super admin.
  bool get isEmployeeOrHigher => role.atLeast(AppRole.employee);

  /// Emits every time [checkRole] resolves a (possibly unchanged) role.
  Stream<AppRole> get roleChanges => _roleChangesController.stream;

  /// The employee roster role backing an employee-tier grant, for display
  /// only (e.g. "Angemeldet als Supervisor"). Never used for gating - gating
  /// always goes through [role] / [isEmployeeOrHigher].
  EmployeeRole? get employeeRole => _cachedEmployeeRole;

  /// Check if current user is admin (sync - uses cache)
  bool get isAdmin => role.atLeast(AppRole.admin);

  /// Check if current user can manage users (admin or super admin)
  bool get canManageUsers => role.atLeast(AppRole.admin);

  /// Check if current user is super admin
  bool get isSuperAdmin {
    final userEmail = email;
    if (userEmail == null) return false;
    return userEmail.toLowerCase() == superAdminEmail.toLowerCase();
  }

  /// Resolve the current user's [AppRole] from Firestore (async - call on
  /// login). Reads `allowedUsers/{email}` first; if that does not resolve to
  /// admin, reads `employeeAccess/{email}` - a single document get by known
  /// path, not a query.
  Future<AppRole> checkRole() async {
    final userEmail = email;
    if (userEmail == null) {
      _cachedRole = AppRole.customer;
      _cachedEmployeeRole = null;
      _roleChangesController.add(_cachedRole!);
      return _cachedRole!;
    }

    final normalizedEmail = userEmail.toLowerCase();
    final isSuperAdminEmail = normalizedEmail == superAdminEmail.toLowerCase();

    bool allowedUserIsAdmin = false;
    bool hasEmployeeAccessDoc = false;
    EmployeeRole? employeeRoleFromMirror;

    if (!isSuperAdminEmail) {
      try {
        final allowedDoc = await FirebaseFirestore.instance
            .collection('allowedUsers')
            .doc(normalizedEmail)
            .get();
        allowedUserIsAdmin = allowedDoc.data()?['isAdmin'] == true;
      } catch (e) {
        debugPrint('Failed to check admin status: $e');
      }

      if (!allowedUserIsAdmin) {
        try {
          final mirrorDoc = await FirebaseFirestore.instance
              .collection('employeeAccess')
              .doc(normalizedEmail)
              .get();
          hasEmployeeAccessDoc = mirrorDoc.exists;
          if (hasEmployeeAccessDoc) {
            employeeRoleFromMirror =
                EmployeeRole.fromFirestore(mirrorDoc.data()?['role'] as String?);
          }
        } catch (e) {
          debugPrint('Failed to check employee access: $e');
        }
      }
    }

    _cachedRole = resolveAppRole(
      isSuperAdminEmail: isSuperAdminEmail,
      allowedUserIsAdmin: allowedUserIsAdmin,
      hasEmployeeAccessDoc: hasEmployeeAccessDoc,
    );
    _cachedEmployeeRole = employeeRoleFromMirror;
    _roleChangesController.add(_cachedRole!);
    return _cachedRole!;
  }

  /// Kept for source compatibility with existing call sites; delegates to
  /// [checkRole].
  Future<bool> checkIsAdmin() async {
    final resolved = await checkRole();
    return resolved.atLeast(AppRole.admin);
  }
```

- [ ] **Step 4: Manually verify against the dev deploy**

This step replaces an automated test for this task, per the Global Constraints note on Firebase-touching code. Run the app locally against the dev Firebase project (`flutter run -d chrome --dart-define=FLAVOR=dev`), sign in as:
- The super-admin email → confirm `authService.isSuperAdmin` and `authService.isAdmin` are both true and the admin dashboard still loads (nothing else changed yet, this just confirms the refactor didn't break the existing admin path).
- An existing `allowedUsers` admin → confirm the admin dashboard still loads.
- A plain Google account with no `allowedUsers` or `employeeAccess` doc → confirm `authService.role == AppRole.customer` (add a temporary `debugPrint('role: ${authService.role}')` right after `checkRole()` resolves in `initState` of any screen while testing, then remove it before committing).

- [ ] **Step 5: Run the full analyzer and existing test suite to confirm no regressions**

Run: `flutter analyze && flutter test`
Expected: no new analyzer errors; all previously-passing tests still pass (the pre-existing `AuthService` DI-related skips are unaffected).

- [ ] **Step 6: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat: resolve AppRole in AuthService from allowedUsers and employeeAccess"
```

---

### Task 3: `employeeAccess` mirror sync in `EmployeeRepository`

**Files:**
- Modify: `lib/data/employee_repository.dart`
- Modify: `lib/screens/admin/employees_tab.dart` (callers of the changed signatures)
- Test: `test/employee_model_test.dart`

**Interfaces:**
- Consumes: `Employee`, `EmployeeRole` from `lib/models/employee.dart` (unchanged).
- Produces: `String? normalizeAccessEmail(String? email)` (pure, exported from `employee_repository.dart`); `EmployeeRepository.updateEmployee({required Employee previous, required String name, String? email, EmployeeRole? role})` (signature change: takes the previous `Employee`, not a bare `id`); `EmployeeRepository.deleteEmployee(Employee employee)` (signature change: takes `Employee`, not `String id`); `EmployeeRepository.rebuildEmployeeAccessIndex()` (`Future<int>`, returns count of mirror docs written).

- [ ] **Step 1: Write the failing test for the pure normalization helper**

```dart
// test/employee_model_test.dart
import 'package:cocktail_planer/data/employee_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAccessEmail', () {
    test('lowercases and trims', () {
      expect(normalizeAccessEmail('  Foo@Example.COM  '), 'foo@example.com');
    });

    test('returns null for null input', () {
      expect(normalizeAccessEmail(null), isNull);
    });

    test('returns null for empty/whitespace-only input', () {
      expect(normalizeAccessEmail(''), isNull);
      expect(normalizeAccessEmail('   '), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/employee_model_test.dart`
Expected: FAIL — `normalizeAccessEmail` is not defined.

- [ ] **Step 3: Implement the helper and the batched sync methods**

Add near the top of `lib/data/employee_repository.dart` (module-level, exported):

```dart
/// Normalizes an email for use as an `employeeAccess` document ID: trims
/// whitespace and lowercases. Returns null for null/empty/whitespace-only
/// input, matching how `allowedUsers` doc IDs are already normalized in
/// `auth_service.dart`.
String? normalizeAccessEmail(String? email) {
  if (email == null) return null;
  final trimmed = email.trim();
  return trimmed.isEmpty ? null : trimmed.toLowerCase();
}
```

Replace the whole `EmployeeRepository` class body's `addEmployee`, `updateEmployee`, `deleteEmployee` with:

```dart
  Future<bool> addEmployee({
    required String name,
    String? email,
    EmployeeRole role = EmployeeRole.staff,
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final sortOrder = await _getNextSortOrder();
      final normalizedEmail = normalizeAccessEmail(email);
      final data = <String, dynamic>{
        'name': name,
        'role': role.firestoreValue,
        'sortOrder': sortOrder,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      if (normalizedEmail != null) {
        data['email'] = normalizedEmail;
      }

      final batch = firestoreService.firestore.batch();
      final employeeRef = firestoreService.employeesCollection.doc();
      batch.set(employeeRef, data);
      if (normalizedEmail != null) {
        batch.set(
          firestoreService.firestore
              .collection('employeeAccess')
              .doc(normalizedEmail),
          {
            'employeeId': employeeRef.id,
            'role': role.firestoreValue,
            'name': name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to add employee: $e');
      return false;
    }
  }

  Future<bool> updateEmployee({
    required Employee previous,
    required String name,
    String? email,
    EmployeeRole? role,
  }) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final normalizedNewEmail = normalizeAccessEmail(email);
      final normalizedOldEmail = normalizeAccessEmail(previous.email);
      final resolvedRole = role ?? previous.role;

      final data = <String, dynamic>{
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser?.email ?? currentUser?.uid ?? 'unknown',
      };
      if (normalizedNewEmail != null) {
        data['email'] = normalizedNewEmail;
      } else {
        data['email'] = FieldValue.delete();
      }
      if (role != null) {
        data['role'] = role.firestoreValue;
      }

      final batch = firestoreService.firestore.batch();
      batch.update(
        firestoreService.employeesCollection.doc(previous.id),
        data,
      );

      final accessCollection =
          firestoreService.firestore.collection('employeeAccess');
      if (normalizedOldEmail != null &&
          normalizedOldEmail != normalizedNewEmail) {
        batch.delete(accessCollection.doc(normalizedOldEmail));
      }
      if (normalizedNewEmail != null) {
        batch.set(accessCollection.doc(normalizedNewEmail), {
          'employeeId': previous.id,
          'role': resolvedRole.firestoreValue,
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to update employee: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(Employee employee) async {
    if (!firestoreService.isAvailable) return false;
    try {
      final batch = firestoreService.firestore.batch();
      batch.delete(firestoreService.employeesCollection.doc(employee.id));
      final normalizedEmail = normalizeAccessEmail(employee.email);
      if (normalizedEmail != null) {
        batch.delete(
          firestoreService.firestore
              .collection('employeeAccess')
              .doc(normalizedEmail),
        );
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Failed to delete employee: $e');
      return false;
    }
  }

  /// Rebuilds the `employeeAccess` mirror from the current `employees`
  /// roster: writes one mirror doc per roster entry that has an email, and
  /// deletes mirror docs with no matching roster entry. Idempotent - safe to
  /// run repeatedly (initial rollout, or as a repair action from the
  /// Employees screen).
  Future<int> rebuildEmployeeAccessIndex() async {
    if (!firestoreService.isAvailable) return 0;
    try {
      final employeesSnapshot = await firestoreService.employeesCollection.get();
      final employees = employeesSnapshot.docs
          .map((d) => Employee.fromFirestore(d.id, d.data()))
          .toList();

      final accessCollection =
          firestoreService.firestore.collection('employeeAccess');
      final existingMirrorDocs = await accessCollection.get();

      final expectedEmails = <String>{};
      final batch = firestoreService.firestore.batch();
      var written = 0;

      for (final employee in employees) {
        final normalizedEmail = normalizeAccessEmail(employee.email);
        if (normalizedEmail == null) continue;
        expectedEmails.add(normalizedEmail);
        batch.set(accessCollection.doc(normalizedEmail), {
          'employeeId': employee.id,
          'role': employee.role.firestoreValue,
          'name': employee.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        written++;
      }

      for (final doc in existingMirrorDocs.docs) {
        if (!expectedEmails.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
      return written;
    } catch (e) {
      debugPrint('Failed to rebuild employeeAccess index: $e');
      return 0;
    }
  }
```

Note the ID-generation change in `addEmployee`: it now uses `firestoreService.employeesCollection.doc()` (a pre-allocated auto-ID reference) instead of `.add(data)`, so the same ID is available for the mirror doc's `employeeId` field inside the same batch. This is the standard Firestore pattern for "create with a known ID inside a batch."

- [ ] **Step 4: Update the one caller file for the changed signatures**

In `lib/screens/admin/employees_tab.dart`, update `_deleteEmployee`:

```dart
    final success = await employeeRepository.deleteEmployee(employee);
```

(was `employeeRepository.deleteEmployee(employee.id)`).

Update `_editEmployee`'s call, inside the `if (result != true) return;` block:

```dart
    final emailText = emailController.text.trim();
    final success = await employeeRepository.updateEmployee(
      previous: employee,
      name: nameController.text.trim(),
      email: emailText.isEmpty ? null : emailText,
      role: selectedRole,
    );
```

(was `id: employee.id,` instead of `previous: employee,`).

- [ ] **Step 5: Run test to verify it passes, then analyze the whole project**

Run: `flutter test test/employee_model_test.dart && flutter analyze`
Expected: 3 tests pass; no analyzer errors (this confirms every call site of the changed signatures compiles — there is exactly one caller file, `employees_tab.dart`, already updated in Step 4).

- [ ] **Step 6: Commit**

```bash
git add lib/data/employee_repository.dart lib/screens/admin/employees_tab.dart test/employee_model_test.dart
git commit -m "feat: sync employeeAccess mirror from employees roster on write"
```

---

### Task 4: `employeeAccess` Firestore rule and the `allowedUsers` email-case fix

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: nothing from Dart.
- Produces: `employeeAccess/{email}` collection readable by its own owner and by admins, writable only by admins; `.lower()` fix so `isAdminFromCollection()` matches the lowercased doc IDs `auth_service.dart` writes.

- [ ] **Step 1: Edit `firestore.rules`**

Replace:

```
    // Check if user is admin via allowedUsers collection
    function isAdminFromCollection() {
      return request.auth != null && 
             exists(/databases/$(database)/documents/allowedUsers/$(request.auth.token.email)) &&
             get(/databases/$(database)/documents/allowedUsers/$(request.auth.token.email)).data.isAdmin == true;
    }
```

with:

```
    function authEmail() {
      return request.auth.token.email.lower();
    }

    function hasEmail() {
      return request.auth != null && request.auth.token.email != null;
    }

    // Check if user is admin via allowedUsers collection
    function isAdminFromCollection() {
      return hasEmail() &&
             exists(/databases/$(database)/documents/allowedUsers/$(authEmail())) &&
             get(/databases/$(database)/documents/allowedUsers/$(authEmail())).data.isAdmin == true;
    }

    // Check if user is on the employees roster via the employeeAccess mirror
    function isRosteredEmployee() {
      return hasEmail() &&
             exists(/databases/$(database)/documents/employeeAccess/$(authEmail()));
    }

    // Admin, super admin, or a rostered employee: full order access
    function hasFullOrderAccess() {
      return isSuperAdmin() || isAdminFromCollection() || isRosteredEmployee();
    }
```

Add the new collection's rules directly after the existing `employees` block:

```
    // Employees collection - users who can manage users can read/write
    match /employees/{document=**} {
      allow read: if isAuthenticated();
      allow write: if canManageUsers();
    }

    // employeeAccess mirror - existence grants order access. Write is
    // admin-only so the tier cannot be self-granted; read is limited to the
    // owner's own doc plus admins, so it is not a staff directory readable
    // by every customer.
    match /employeeAccess/{email} {
      allow read: if canManageUsers() || (hasEmail() && email == authEmail());
      allow write: if canManageUsers();
    }
```

Do **not** change the `orders` block yet — that is Task 8, deployed only after the owner-scoped client queries (Task 6-7) are live, per the Global Constraints deploy order.

- [ ] **Step 2: Deploy the rules to the dev Firebase project and smoke-test**

Run: `firebase use dev && firebase deploy --only firestore:rules`
(If a `dev` alias is not configured, use `firebase deploy --only firestore:rules --project <dev-project-id>` with the dev project ID from `.github/workflows/deploy-dev.yml`'s `DEV_FIREBASE_PROJECT_ID` secret — ask the human operator for the project id string if it is not visible in a non-secret config file.)

Manually verify in the Firebase console (Firestore → Rules playground, or via the app):
- An admin can still read/write `orders`, `employees`, `allowedUsers`.
- A plain signed-in user can read their own `allowedUsers`/`employeeAccess` doc path (even though neither exists for them) without a permission error, and cannot read another user's `employeeAccess/{other-email}` document.

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat: add employeeAccess rule and fix allowedUsers email-case lookup"
```

---

### Task 5: Run the initial `employeeAccess` rebuild and add the roster's rebuild/hint UI

**Files:**
- Modify: `lib/screens/admin/employees_tab.dart`

**Interfaces:**
- Consumes: `EmployeeRepository.rebuildEmployeeAccessIndex()` from Task 3.

- [ ] **Step 1: Add a "kein App-Zugang" hint for roster rows with no email**

Find the widget that renders each employee row (search `_localEmployees.map` or the `ListView`/`ReorderableListView` item builder in `employees_tab.dart`, in the `build` method after line ~220). Wherever the row currently shows `employee.name` and role, add — directly below the role label, only when `employee.email == null || employee.email!.isEmpty` — a small secondary line:

```dart
if (employee.email == null || employee.email!.trim().isEmpty)
  Text(
    'admin.employee_no_app_access'.tr(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
  ),
```

Add the translation key to both `assets/translations/de.json` and `assets/translations/en.json` under the `admin` section:
- `de.json`: `"employee_no_app_access": "Kein App-Zugang (keine E-Mail hinterlegt)"`
- `en.json`: `"employee_no_app_access": "No app access (no email on file)"`

- [ ] **Step 2: Add a "Zugänge neu aufbauen" admin action**

In the same file, add a state field `bool _isRebuildingAccess = false;` next to the other `bool` state fields, and a handler:

```dart
  Future<void> _rebuildEmployeeAccess() async {
    setState(() => _isRebuildingAccess = true);
    final count = await employeeRepository.rebuildEmployeeAccessIndex();
    setState(() => _isRebuildingAccess = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('admin.employee_access_rebuilt'.tr(args: ['$count'])),
      ),
    );
  }
```

Add a button that calls it — place it near the existing add-employee form, e.g. as a `TextButton.icon` below the "Hinzufügen" button:

```dart
TextButton.icon(
  onPressed: _isRebuildingAccess ? null : _rebuildEmployeeAccess,
  icon: _isRebuildingAccess
      ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.sync),
  label: Text('admin.rebuild_employee_access'.tr()),
),
```

Add translation keys:
- `de.json`: `"rebuild_employee_access": "Zugänge neu aufbauen"`, `"employee_access_rebuilt": "{} Zugänge synchronisiert"`
- `en.json`: `"rebuild_employee_access": "Rebuild access"`, `"employee_access_rebuilt": "{} access entries synced"`

- [ ] **Step 2: Run the translations consistency test**

Run: `flutter test test/translations_test.dart`
Expected: PASS — this test (seen passing in the existing suite) checks `de.json` and `en.json` have matching top-level keys, so it will catch a typo'd or missing key in either file.

- [ ] **Step 3: Manually run the rebuild against dev and verify**

Deploy dev (see Task 4 Step 2's deploy command applies to hosting too, via the normal `git push` to `main` once this task is committed — or run locally against dev with `flutter run -d chrome --dart-define=FLAVOR=dev`). Open the Employees screen as an admin, click "Zugänge neu aufbauen", and confirm in the Firebase console that an `employeeAccess/{email}` document now exists for every roster entry that has an email, and that the snackbar reports the correct count.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/admin/employees_tab.dart assets/translations/de.json assets/translations/en.json
git commit -m "feat: add employee access rebuild action and no-access hint to roster"
```

---

### Task 6: `RoleProtectedScreen` and flipping the employee-tier gates

**Files:**
- Create: `lib/widgets/role_protected_screen.dart`
- Modify: `lib/widgets/admin_protected_screen.dart`
- Modify: `lib/screens/orders/pending_orders_screen.dart`
- Modify: `lib/screens/orders/orders_overview_screen.dart`
- Modify: `lib/screens/dashboard/simple_dashboard_screen.dart`
- Modify: `lib/screens/dashboard/user_menu_sheet.dart`
- Modify: `lib/screens/forms/modern_order_form_screen.dart`

**Interfaces:**
- Consumes: `AppRole`, `AuthService.role`/`roleResolved`/`roleChanges`/`isEmployeeOrHigher` from Task 2.
- Produces: `RoleProtectedScreen({required AppRole minimumRole, required Widget child})`.

- [ ] **Step 1: Create `RoleProtectedScreen`**

```dart
// lib/widgets/role_protected_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';

/// Gates [child] behind [minimumRole]. Shows a loading spinner while the
/// role is still resolving (see [AuthService.roleResolved]) rather than
/// flashing an access-denied screen during that window, then an
/// access-denied screen if the resolved role does not meet [minimumRole].
class RoleProtectedScreen extends StatefulWidget {
  const RoleProtectedScreen({
    super.key,
    required this.minimumRole,
    required this.child,
  });

  final AppRole minimumRole;
  final Widget child;

  @override
  State<RoleProtectedScreen> createState() => _RoleProtectedScreenState();
}

class _RoleProtectedScreenState extends State<RoleProtectedScreen> {
  late final Stream<AppRole> _roleChanges = authService.roleChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppRole>(
      stream: _roleChanges,
      initialData: authService.roleResolved ? authService.role : null,
      builder: (context, snapshot) {
        if (!authService.roleResolved && !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentRole = snapshot.data ?? authService.role;
        if (!currentRole.atLeast(widget.minimumRole)) {
          return Scaffold(
            appBar: AppBar(
              title: Text('admin.access_denied'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'admin.access_denied'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'admin.access_denied_message'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home),
                      label: Text('common.back'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return widget.child;
      },
    );
  }
}
```

- [ ] **Step 2: Turn `AdminProtectedScreen` into a one-line wrapper**

Replace the entire body of `lib/widgets/admin_protected_screen.dart` with:

```dart
import 'package:flutter/material.dart';

import '../models/app_role.dart';
import 'role_protected_screen.dart';

/// Gates [child] behind admin access. Thin wrapper over
/// [RoleProtectedScreen] kept for source compatibility with existing call
/// sites.
class AdminProtectedScreen extends StatelessWidget {
  final Widget child;

  const AdminProtectedScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(minimumRole: AppRole.admin, child: child);
  }
}
```

- [ ] **Step 3: Flip the employee-tier gates**

In `lib/screens/orders/pending_orders_screen.dart`, find `return AdminProtectedScreen(` (around line 73) and replace with:

```dart
    return RoleProtectedScreen(
      minimumRole: AppRole.employee,
```

(keep its existing `child:` argument as-is; the closing paren's construct name changes from `AdminProtectedScreen(` to `RoleProtectedScreen(minimumRole: AppRole.employee, ...)`). Add the two imports:
```dart
import 'package:cocktail_planer/models/app_role.dart';
import 'package:cocktail_planer/widgets/role_protected_screen.dart';
```
(remove the now-unused `admin_protected_screen.dart` import if nothing else in the file references `AdminProtectedScreen`).

In `lib/screens/orders/orders_overview_screen.dart`, apply the identical change to `return AdminProtectedScreen(child: _buildContent(context));` (around line 255) → `return RoleProtectedScreen(minimumRole: AppRole.employee, child: _buildContent(context));`, with the same import swap. Leave the `if (authService.isAdmin)` check around line 276 (the admin-only sync/dashboard action inside the app bar) untouched — that one stays admin-only per the design.

In `lib/screens/dashboard/simple_dashboard_screen.dart`, replace `if (!authService.isAdmin) {` (around line 48) with `if (!authService.isEmployeeOrHigher) {`, and `final bool isAdmin = authService.isAdmin;` (around line 442) with `final bool isAdmin = authService.isEmployeeOrHigher;` (keep the local variable name `isAdmin` to avoid a larger rename — it now means "employee or higher" at its one remaining use site around line 461, which is fine since that conditional gates staff-only dashboard sections, not truly admin-only ones).

In `lib/screens/dashboard/user_menu_sheet.dart`, replace `if (authService.isAdmin) _buildAdminTile(context),` (line 32) — **leave this one as `isAdmin`**, it is the admin settings tile and stays admin-only. Replace only the orders-tile line `if (authService.isAdmin || authService.isSuperAdmin)` (line 33) with `if (authService.isEmployeeOrHigher)`. Leave line 56 (`if (authService.isAdmin) ...[`) untouched.

In `lib/screens/forms/modern_order_form_screen.dart`, replace:

```dart
    // Check if user is admin
    final isAdmin = authService.isAdmin;

    if (!isAdmin) {
```

with:

```dart
    // Employees and admins get the staff flow (pricing, shopping list);
    // everyone else gets the customer request flow.
    final isEmployeeOrHigher = authService.isEmployeeOrHigher;

    if (!isEmployeeOrHigher) {
```

and update the following `else if` branches in the same block to reference `isEmployeeOrHigher` wherever they previously referenced `isAdmin` (there is exactly one `if (!isAdmin)`/implicit-else pair here; grep the file for `isAdmin` after this edit to confirm none remain in this function).

Add the `import 'package:cocktail_planer/models/app_role.dart';` import to any of the above files only if you introduce a direct `AppRole` reference in it (`pending_orders_screen.dart` and `orders_overview_screen.dart` need it for `AppRole.employee`; the other three files only use `authService.isEmployeeOrHigher`, a `bool`, and do not need the import).

- [ ] **Step 4: Run analyzer and existing tests**

Run: `flutter analyze && flutter test`
Expected: no analyzer errors (this catches any missed `AdminProtectedScreen`/`isAdmin` reference and any unused import); existing tests still pass.

- [ ] **Step 5: Manually verify against dev**

Sign in as: an admin (staff screens still load); a user whose email is in `employeeAccess` (pending orders, orders overview, and the order-form staff flow now load, where they previously would have shown access-denied); a plain customer (still gets the customer request flow and is still denied the staff screens).

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/role_protected_screen.dart lib/widgets/admin_protected_screen.dart lib/screens/orders/pending_orders_screen.dart lib/screens/orders/orders_overview_screen.dart lib/screens/dashboard/simple_dashboard_screen.dart lib/screens/dashboard/user_menu_sheet.dart lib/screens/forms/modern_order_form_screen.dart
git commit -m "feat: gate staff order screens on employee-or-higher, not admin-only"
```

---

### Task 7: Order ownership fields and owner-scoped queries

**Files:**
- Modify: `lib/models/order.dart`
- Modify: `lib/data/order_repository.dart`
- Create/modify: `firestore.indexes.json`
- Modify: `firebase.json`
- Test: `test/order_model_test.dart` (add to existing file)

**Interfaces:**
- Produces: `SavedOrder.userId` (`String?`), `SavedOrder.userEmail` (`String?`); `OrderRepository.watchOrdersForOwner(String userId)` (`Stream<List<SavedOrder>>`), `OrderRepository.getOrdersForOwner(String userId)` (`Future<List<SavedOrder>>`).

- [ ] **Step 1: Write the failing model test**

Add to `test/order_model_test.dart` (inside the existing `group('SavedOrder Model', ...)` or a new group if that one doesn't exist by that exact name — match whatever grouping the file already uses):

```dart
  group('SavedOrder ownership fields', () {
    test('fromFirestore reads userId and userEmail when present', () {
      final order = SavedOrder.fromFirestore('order1', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
        'userId': 'uid-123',
        'userEmail': 'someone@example.com',
      });

      expect(order.userId, 'uid-123');
      expect(order.userEmail, 'someone@example.com');
    });

    test('fromFirestore leaves userId/userEmail null when absent', () {
      final order = SavedOrder.fromFirestore('order2', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
      });

      expect(order.userId, isNull);
      expect(order.userEmail, isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_model_test.dart`
Expected: FAIL — `The named parameter 'userId' isn't defined` (or the getter simply returns nothing matching, depending on how the constructor call resolves — either way, a compile or assertion failure).

- [ ] **Step 3: Add the fields to `SavedOrder`**

In `lib/models/order.dart`, add to the constructor's parameter list (after `this.formCreatedAt,` or any convenient spot among the optional named params):

```dart
    this.userId,
    this.userEmail,
```

Add the field declarations near `final String? createdBy;`:

```dart
  final String? userId;
  final String? userEmail;
```

In `fromFirestore`, add alongside the other `data['...']` reads (e.g. near `createdBy: data['createdBy'] as String?,`):

```dart
      userId: data['userId'] as String?,
      userEmail: data['userEmail'] as String?,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/order_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the owner-scoped repository methods**

In `lib/data/order_repository.dart`, add new methods near `watchOrders`/`getOrders` (do not modify those existing methods):

```dart
  /// Watch orders owned by [userId], sorted by createdAt descending. Unlike
  /// [watchOrders], this does not filter out pending orders (total == 0) -
  /// a customer's own request IS the total == 0 case - and does not filter
  /// by year.
  Stream<List<SavedOrder>> watchOrdersForOwner(String userId) {
    if (!firestoreService.isAvailable) {
      return Stream.value([]);
    }

    return firestoreService.ordersCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
            .toList())
        .handleError((e) {
      debugPrint('Failed to watch orders for owner: $e');
      return <SavedOrder>[];
    });
  }

  /// One-shot fetch variant of [watchOrdersForOwner].
  Future<List<SavedOrder>> getOrdersForOwner(String userId) async {
    if (!await _ensureFirestoreAvailable()) return [];
    try {
      final snapshot = await firestoreService.ordersCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => SavedOrder.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Failed to get orders for owner: ${_formatError(e)}');
      return [];
    }
  }
```

- [ ] **Step 6: Add the composite index**

If `firestore.indexes.json` does not exist, create it:

```json
{
  "indexes": [
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

If it already exists, add this object to its `"indexes"` array instead of overwriting the file.

In `firebase.json`, add an `"indexes"` key inside the existing `"firestore"` block:

```json
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
```

- [ ] **Step 7: Deploy the index to dev and verify**

Run: `firebase deploy --only firestore:indexes --project <dev-project-id>`
Expected: the CLI reports the index is building or already exists; check the Firebase console's Firestore → Indexes tab for `orders (userId ASC, createdAt DESC)` reaching "Enabled" status before Task 9 ships the rules that make customers depend on it.

- [ ] **Step 8: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, no new analyzer errors.

- [ ] **Step 9: Commit**

```bash
git add lib/models/order.dart lib/data/order_repository.dart firestore.indexes.json firebase.json test/order_model_test.dart
git commit -m "feat: add SavedOrder ownership fields and owner-scoped order queries"
```

---

### Task 8: "My requests" dashboard for customers

**Files:**
- Create: `lib/screens/dashboard/widgets/my_requests_list.dart`
- Create: `lib/screens/dashboard/widgets/my_request_detail_sheet.dart`
- Create: `lib/screens/dashboard/my_requests_screen.dart`
- Modify: `lib/screens/dashboard/customer_landing_screen.dart`
- Modify: `lib/router/app_router.dart`

**Interfaces:**
- Consumes: `OrderRepository.watchOrdersForOwner` from Task 7; `order_info_chip.dart`'s `OrderInfoChip`, `order_status_helpers.dart`'s `statusLabel`/`statusColor`/`statusIcon`/`formatDate` (all pre-existing, used unmodified).
- Produces: `MyRequestsList({required List<SavedOrder> requests, required void Function(SavedOrder) onTap})`; `MyRequestDetailSheet` (shown via a new `showMyRequestDetails(BuildContext, SavedOrder)` top-level function, mirroring the existing `showOrderDetails` pattern in `order_detail_sheet.dart`); `MyRequestsScreen` (no constructor args, reads `authService.currentUser` itself); route `/my-requests`.

- [ ] **Step 1: Build the card list widget**

```dart
// lib/screens/dashboard/widgets/my_requests_list.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../orders/order_status_helpers.dart';
import '../../orders/widgets/order_info_chip.dart';

/// Customer-facing list of the signed-in user's own submitted requests.
/// Deliberately does not show total price or article count (see design
/// spec section 4) - only what a customer should see before an offer is
/// formally sent.
class MyRequestsList extends StatelessWidget {
  const MyRequestsList({
    super.key,
    required this.requests,
    required this.onTap,
  });

  final List<SavedOrder> requests;
  final void Function(SavedOrder request) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'dashboard.no_requests_yet'.tr(),
            style: TextStyle(color: colorScheme.outline),
          ),
        ),
      );
    }

    return Column(
      children: requests.map((request) => _buildCard(context, request)).toList(),
    );
  }

  Widget _buildCard(BuildContext context, SavedOrder request) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(request),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(request.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon(request.status),
                            size: 14, color: statusColor(request.status)),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel(request.status),
                          style: TextStyle(
                            color: statusColor(request.status),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatDate(request.date),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              OrderInfoChip(
                icon: Icons.people,
                label: '${request.personCount}',
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Build the read-only detail sheet**

```dart
// lib/screens/dashboard/widgets/my_request_detail_sheet.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../orders/order_status_helpers.dart';

/// Shows a read-only summary of a customer's own submitted request. Unlike
/// `order_detail_sheet.dart`'s `showOrderDetails` (staff tooling: offer
/// generation, status transitions, employee assignment, deletion), this
/// exposes nothing actionable - a customer cannot edit or delete a request
/// from here.
Future<void> showMyRequestDetails(BuildContext context, SavedOrder request) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => MyRequestDetailSheet(request: request),
  );
}

class MyRequestDetailSheet extends StatelessWidget {
  const MyRequestDetailSheet({super.key, required this.request});

  final SavedOrder request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon(request.status),
                    size: 16, color: statusColor(request.status)),
                const SizedBox(width: 4),
                Text(statusLabel(request.status),
                    style: TextStyle(color: statusColor(request.status))),
              ],
            ),
            const Divider(height: 32),
            _row(context, 'dashboard.request_date'.tr(), formatDate(request.date)),
            if (request.effectiveEventTime.isNotEmpty)
              _row(context, 'dashboard.request_time'.tr(), request.effectiveEventTime),
            if (request.location.isNotEmpty)
              _row(context, 'dashboard.request_location'.tr(), request.location),
            _row(context, 'dashboard.request_guests'.tr(), '${request.personCount}'),
            if (request.serviceType.isNotEmpty)
              _row(context, 'dashboard.request_service_type'.tr(), request.serviceType),
            if (request.cocktails.isNotEmpty)
              _row(context, 'dashboard.request_cocktails'.tr(),
                  request.cocktails.join(', ')),
            if (request.shotSelections.isNotEmpty)
              _row(
                context,
                'dashboard.request_shots'.tr(),
                request.shotSelections
                    .map((s) => '${s.name} (${s.quantity})')
                    .join(', '),
              )
            else if (request.shots.isNotEmpty)
              _row(context, 'dashboard.request_shots'.tr(), request.shots.join(', ')),
            if (request.remarks.isNotEmpty)
              _row(context, 'dashboard.request_remarks'.tr(), request.remarks),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
```

This references `request.shotSelections` (Task 10) — this task can be implemented before or after Task 10 without breaking compilation either way, since Task 10 adds `shotSelections` as a new field defaulting to `const []`; if Task 8 lands first, `shotSelections` will not exist yet, so **land this file's `if (request.shotSelections.isNotEmpty)` branch only after Task 10 is merged**, or implement Task 10 first. This plan's task order (7, 8, then 10 later per the milestone list) means: when doing Task 8, either reorder to do Task 10 first, or temporarily omit the `shotSelections` branch and add it back as part of Task 10's own steps. Prefer reordering: do Task 10 immediately before Task 8 if executing out of the written order, or do Task 8's Step 2 with only the `else if (request.shots.isNotEmpty)` branch and add the `shotSelections` branch as an extra step in Task 10.

- [ ] **Step 3: Build the full "my requests" screen**

```dart
// lib/screens/dashboard/my_requests_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import 'widgets/my_request_detail_sheet.dart';
import 'widgets/my_requests_list.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('dashboard.my_requests_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: userId == null
          ? Center(child: Text('dashboard.sign_in_to_see_requests'.tr()))
          : StreamBuilder<List<SavedOrder>>(
              stream: orderRepository.watchOrdersForOwner(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = snapshot.data ?? [];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: MyRequestsList(
                        requests: requests,
                        onTap: (request) => showMyRequestDetails(context, request),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 4: Add the route**

In `lib/router/app_router.dart`, add the import `import '../screens/dashboard/my_requests_screen.dart';` and a new `GoRoute` alongside the other dashboard-area routes:

```dart
    GoRoute(
      path: '/my-requests',
      builder: (context, state) => const MyRequestsScreen(),
    ),
```

- [ ] **Step 5: Add the "Meine Anfragen" section to `CustomerLandingScreen`**

Read `lib/screens/dashboard/customer_landing_screen.dart` in full first to find where the existing "new order" call-to-action button is, and add directly below it (inside the same scrollable column) a new section using `StreamBuilder<List<SavedOrder>>` bound to `orderRepository.watchOrdersForOwner(authService.currentUser!.uid)`, guarded by `if (authService.isSignedIn)` (anonymous users get a short sign-in prompt instead, per the design spec's section 4 "Anonymous users are excluded"):

```dart
if (authService.isSignedIn) ...[
  const SizedBox(height: 24),
  Text(
    'dashboard.my_requests_title'.tr(),
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  ),
  const SizedBox(height: 12),
  StreamBuilder<List<SavedOrder>>(
    stream: orderRepository.watchOrdersForOwner(authService.currentUser!.uid),
    builder: (context, snapshot) {
      final requests = (snapshot.data ?? []).take(3).toList();
      final hasMore = (snapshot.data ?? []).length > 3;
      return Column(
        children: [
          MyRequestsList(
            requests: requests,
            onTap: (request) => showMyRequestDetails(context, request),
          ),
          if (hasMore)
            TextButton(
              onPressed: () => context.push('/my-requests'),
              child: Text('dashboard.show_all_requests'.tr()),
            ),
        ],
      );
    },
  ),
] else ...[
  const SizedBox(height: 24),
  Text(
    'dashboard.sign_in_to_see_requests'.tr(),
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
  ),
],
```

Add the required imports for `orderRepository`, `authService`, `SavedOrder`, `MyRequestsList`, and `showMyRequestDetails` to the top of the file, matching whatever import style the file already uses for its other dependencies.

Add all new translation keys used above to both `assets/translations/de.json` and `assets/translations/en.json` under a `dashboard` section (create the section if it does not already exist — check first with `grep -n '"dashboard"' assets/translations/de.json`):

- `de.json`: `"my_requests_title": "Meine Anfragen"`, `"no_requests_yet": "Noch keine Anfragen gestellt"`, `"show_all_requests": "Alle anzeigen"`, `"sign_in_to_see_requests": "Melde dich an, um deine Anfragen zu sehen"`, `"request_date": "Datum"`, `"request_time": "Uhrzeit"`, `"request_location": "Ort"`, `"request_guests": "Gäste"`, `"request_service_type": "Service"`, `"request_cocktails": "Cocktails"`, `"request_shots": "Shots"`, `"request_remarks": "Bemerkungen"`
- `en.json`: matching English strings.

- [ ] **Step 6: Run the translations test and full analyzer**

Run: `flutter test test/translations_test.dart && flutter analyze`
Expected: PASS, no new analyzer errors.

- [ ] **Step 7: Manually verify against dev**

Sign in as a plain customer with at least one prior submitted request (or submit one via the order form first) → confirm the landing screen shows "Meine Anfragen" with that request, tapping it opens the read-only detail sheet, and `/my-requests` shows the full list. Sign in as a different customer → confirm they see zero requests (not the first customer's). Sign in anonymously → confirm the sign-in prompt shows instead of a request list.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/dashboard/widgets/my_requests_list.dart lib/screens/dashboard/widgets/my_request_detail_sheet.dart lib/screens/dashboard/my_requests_screen.dart lib/screens/dashboard/customer_landing_screen.dart lib/router/app_router.dart assets/translations/de.json assets/translations/en.json
git commit -m "feat: add my-requests dashboard view for customers"
```

---

### Task 9: Rewrite the `orders` Firestore rule to scope reads to owner-or-employee

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: `isOrderOwner()`, `hasFullOrderAccess()` (from Task 4), both already/now defined in `firestore.rules`.

This is the last piece of the access-control change and must not ship before Tasks 6, 7, and 8 are live in production for at least one deploy cycle (Global Constraints deploy order) — every customer-visible order query must already be using `watchOrdersForOwner` before this lands, or customers get `permission-denied` instead of a filtered list.

- [ ] **Step 1: Edit the `orders` block in `firestore.rules`**

Replace:

```
    // Orders collection - all authenticated users can read/write their own
    match /orders/{orderId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isAdmin() || isSuperAdmin() || isOrderOwner();
    }
```

with:

```
    // Orders collection - owner or employee-or-higher can read/write; create
    // requires the caller to be the resource's own userId.
    match /orders/{orderId} {
      allow read: if isOrderOwner() || hasFullOrderAccess();
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOrderOwner() || hasFullOrderAccess();
    }
```

Also tighten the `allowedUsers` read rule while touching this file (recommended in the same pass per the design spec section 3, since it is currently `allow read: if isAuthenticated()` — every signed-in user can read every user's email and admin status):

```
    // Allowed users collection - super admin can create; full admins can create/update/delete
    match /allowedUsers/{email} {
      allow read: if canManageUsers() || (hasEmail() && email == authEmail());
      allow create, update, delete: if canManageUsers();
    }
```

- [ ] **Step 2: Deploy to dev**

Run: `firebase deploy --only firestore:rules --project <dev-project-id>`

- [ ] **Step 3: Manually verify every case from the design spec's Testing section against dev**

Using two real Google accounts (or one account plus the Firebase console's Rules Playground with simulated auth), confirm:
- A customer reading their own order: allowed.
- A customer reading another customer's order by ID: denied.
- A customer's app screen (customer landing / my-requests) still loads with no `permission-denied` — this confirms `watchOrdersForOwner`'s query shape (`where('userId', ...)` + `orderBy('createdAt', ...)`) is accepted by the new rule; an unscoped `watchOrders()` call from a customer session would be denied, which is expected and must not happen anywhere in the customer-facing UI (grep the codebase for any remaining customer-reachable call to `orderRepository.watchOrders(` or `.getOrders(` without an owner filter as a final check).
- An employee (via `employeeAccess`) reading/writing any order: allowed.
- An admin reading/writing any order: allowed (unchanged).
- Creating an order with a `userId` that does not match the caller's own uid: denied.

- [ ] **Step 4: Commit**

```bash
git add firestore.rules
git commit -m "feat: scope orders Firestore rule to owner or employee-or-higher"
```

---

### Task 10: Per-flavor shot quantities — data model

**Files:**
- Modify: `lib/models/order.dart`
- Modify: `lib/data/order_repository.dart`
- Modify: `lib/screens/dashboard/widgets/my_request_detail_sheet.dart` (finish the `shotSelections` branch deferred in Task 8 Step 2, if not already done)
- Test: `test/order_model_test.dart` (add), `test/shot_selection_test.dart` (new)

**Interfaces:**
- Produces: `class ShotSelection { final String name; final int quantity; }`; `SavedOrder.shotSelections` (`List<ShotSelection>`), `SavedOrder.requestedShotsTotal` (`int` getter); `OrderRepository.saveOrder(..., List<Map<String, dynamic>> shotQuantities = const [])` and the raw `updateOrder(orderId, data)` path continues to accept a `'shotQuantities'` key in its `data` map with no signature change needed (it already takes an arbitrary `Map<String, dynamic>`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/shot_selection_test.dart
import 'package:cocktail_planer/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShotSelection', () {
    test('holds a name and quantity', () {
      const selection = ShotSelection(name: 'Aarewasser', quantity: 20);
      expect(selection.name, 'Aarewasser');
      expect(selection.quantity, 20);
    });
  });

  group('SavedOrder.requestedShotsTotal', () {
    test('sums quantities across selections', () {
      final order = SavedOrder.fromFirestore('o1', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
        'shotQuantities': [
          {'name': 'Aarewasser', 'quantity': 20},
          {'name': 'Tequila', 'quantity': 10},
        ],
      });

      expect(order.requestedShotsTotal, 30);
      expect(order.shotSelections.map((s) => s.name), ['Aarewasser', 'Tequila']);
    });

    test('is zero when shotQuantities is missing', () {
      final order = SavedOrder.fromFirestore('o2', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
      });

      expect(order.requestedShotsTotal, 0);
      expect(order.shotSelections, isEmpty);
    });

    test('skips malformed entries (empty name or non-positive quantity)', () {
      final order = SavedOrder.fromFirestore('o3', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
        'shotQuantities': [
          {'name': '', 'quantity': 5},
          {'name': 'Valid', 'quantity': 0},
          {'name': 'Valid', 'quantity': -1},
          {'name': 'Tequila', 'quantity': 10},
        ],
      });

      expect(order.shotSelections, [const ShotSelection(name: 'Tequila', quantity: 10)]);
      expect(order.requestedShotsTotal, 10);
    });
  });
}
```

`ShotSelection` will need a value-equality `==`/`hashCode` (or `const` constructor with `@immutable` and manual equality) for the `expect(..., [const ShotSelection(...)])` list-equality check above to pass — include that in Step 2's implementation.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shot_selection_test.dart`
Expected: FAIL — `ShotSelection` is not defined.

- [ ] **Step 3: Implement `ShotSelection`, `shotSelections`, and `requestedShotsTotal`**

In `lib/models/order.dart`, add near the top-level enums (before `class SavedOrder`):

```dart
/// A single flavor + quantity a customer selected when requesting shots.
class ShotSelection {
  const ShotSelection({required this.name, required this.quantity});

  final String name;
  final int quantity;

  @override
  bool operator ==(Object other) =>
      other is ShotSelection && other.name == name && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(name, quantity);

  @override
  String toString() => 'ShotSelection(name: $name, quantity: $quantity)';
}
```

Add to `SavedOrder`'s constructor parameter list: `this.shotSelections = const [],` and the field: `final List<ShotSelection> shotSelections;`.

Add the `requestedShotsTotal` getter near the existing `effectiveEventTime` getter:

```dart
  int get requestedShotsTotal =>
      shotSelections.fold(0, (sum, s) => sum + s.quantity);
```

In `fromFirestore`, add a parsing block. Place it near where `shots` is parsed:

```dart
      shotSelections: (data['shotQuantities'] as List<dynamic>? ?? [])
          .map((entry) {
            if (entry is! Map) return null;
            final name = entry['name'] as String? ?? '';
            final quantity = (entry['quantity'] as num?)?.toInt() ?? 0;
            if (name.trim().isEmpty || quantity <= 0) return null;
            return ShotSelection(name: name, quantity: quantity);
          })
          .whereType<ShotSelection>()
          .toList(),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shot_selection_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Add the `shotQuantities` write parameter to `saveOrder`**

In `lib/data/order_repository.dart`'s `saveOrder`, add the parameter `List<Map<String, dynamic>> shotQuantities = const [],` to the signature (alongside the existing `List<String> shots = const [],`) and add `'shotQuantities': shotQuantities,` to the `firestoreService.ordersCollection.add({...})` map, alongside the existing `'shots': shots,` line.

The generic `updateOrder(String orderId, Map<String, dynamic> data)` needs no signature change — callers simply include a `'shotQuantities': [...]` key in the `data` map they already build, which Task 11 does.

- [ ] **Step 6: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all pass, no new errors.

- [ ] **Step 7: Un-defer the `shotSelections` branch in `MyRequestDetailSheet` if Task 8 was done first**

If Task 8 was implemented before this task and its Step 2 used only the `else if (request.shots.isNotEmpty)` fallback branch (per that task's note), now add back the primary branch:

```dart
            if (request.shotSelections.isNotEmpty)
              _row(
                context,
                'dashboard.request_shots'.tr(),
                request.shotSelections
                    .map((s) => '${s.name} (${s.quantity})')
                    .join(', '),
              )
            else if (request.shots.isNotEmpty)
              _row(context, 'dashboard.request_shots'.tr(), request.shots.join(', ')),
```

- [ ] **Step 8: Commit**

```bash
git add lib/models/order.dart lib/data/order_repository.dart lib/screens/dashboard/widgets/my_request_detail_sheet.dart test/shot_selection_test.dart test/order_model_test.dart
git commit -m "feat: add ShotSelection model and requestedShotsTotal to SavedOrder"
```

---

### Task 11: Per-flavor shot quantity stepper on the request form

**Files:**
- Modify: `lib/screens/forms/modern_order_form_screen.dart`
- Test: widget test added to `test/click_interactions_test.dart`

**Interfaces:**
- Consumes: `ShotSelection` (Task 10) only at the point where the map is converted for saving; the stepper itself works purely on a `Map<String, int>` keyed by recipe name.
- Produces: `_ModernOrderFormScreenState._shotQuantities` (`Map<String, int>`), a private `_toggleRecipeSelection(Recipe recipe)` helper replacing the duplicated inline toggle logic, and a stepper widget rendered inside `_buildCocktailCard`.

- [ ] **Step 1: Add the `_shotQuantities` state and a shared toggle helper**

Add a state field near `_selectedRecipes`: `final Map<String, int> _shotQuantities = {};`

Add a private method (place it near `_buildCocktailCard`):

```dart
  void _toggleRecipeSelection(Recipe recipe) {
    setState(() {
      final isSelected = _selectedRecipes.any((r) => r.id == recipe.id);
      if (isSelected) {
        _selectedRecipes.removeWhere((r) => r.id == recipe.id);
        if (recipe.isShot) _shotQuantities.remove(recipe.name);
      } else {
        _selectedRecipes.add(recipe);
        if (recipe.isShot) _shotQuantities[recipe.name] = 1;
      }
    });
  }

  void _setShotQuantity(Recipe recipe, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _selectedRecipes.removeWhere((r) => r.id == recipe.id);
        _shotQuantities.remove(recipe.name);
      } else {
        _shotQuantities[recipe.name] = quantity;
      }
    });
  }
```

Replace the two duplicated `onTap` bodies inside `_buildCocktailCard` (desktop card around line 2211-2219, mobile card around line 2311-2319):

```dart
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (isSelected) {
              _selectedRecipes.removeWhere((r) => r.id == recipe.id);
            } else {
              _selectedRecipes.add(recipe);
            }
          });
        },
```

with, in both places:

```dart
        onTap: () {
          HapticFeedback.selectionClick();
          _toggleRecipeSelection(recipe);
        },
```

Also update the `mocktail_service` branch (around line 1177) so it clears quantities too:

```dart
            if (value == 'mocktail_service') {
              _selectedRecipes.removeWhere((recipe) => recipe.isShot);
              _shotQuantities.clear();
              _cocktailPopularity.removeWhere(
```

- [ ] **Step 2: Add the stepper widget to the mobile card layout**

In the mobile-list branch of `_buildCocktailCard` (the second `return Card(...)`, around line 2298), inside the `Row` that currently ends with the trailing check-icon `Icon(isSelected ? Icons.check_circle : ...)`, add the stepper immediately before that icon, only when the recipe is a shot and currently selected:

```dart
              if (recipe.isShot && isSelected) ...[
                _buildShotQuantityStepper(recipe),
                const SizedBox(width: 12),
              ],
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
```

Add the stepper builder method near `_buildCocktailCard`:

```dart
  Widget _buildShotQuantityStepper(Recipe recipe) {
    final quantity = _shotQuantities[recipe.name] ?? 1;
    return Semantics(
      label: '${recipe.name}: $quantity',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            iconSize: 20,
            onPressed: () => _setShotQuantity(recipe, quantity - 1),
            tooltip: 'order_setup.shot_quantity_decrease'.tr(),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 20,
            onPressed: () => _setShotQuantity(recipe, quantity + 1),
            tooltip: 'order_setup.shot_quantity_increase'.tr(),
          ),
        ],
      ),
    );
  }
```

Note: the desktop card layout (the compact square tile, first `return Card(...)` in `_buildCocktailCard`) does not get the stepper — there is no room in that tile's fixed layout for it without a redesign out of scope here. Desktop users select shots the same way as before; the mobile list layout (used below 600px width, and reachable on desktop by resizing) is the one place the stepper is required to exist at all, satisfying the requirement. If the business later wants it on the desktop tile too, that is a follow-up, not a blocker for this task.

Add translation keys: `de.json` under `order_setup`: `"shot_quantity_decrease": "Weniger"`, `"shot_quantity_increase": "Mehr"`; matching `en.json`.

- [ ] **Step 3: Write a widget test for the stepper behavior**

Add to `test/click_interactions_test.dart`, following the file's existing pattern of skipping when `AuthService` DI is required (check the top of the file for how existing tests there handle the `AuthService` singleton — reuse that same skip guard if the screen under test needs auth, or construct `ModernOrderFormScreen` directly if it doesn't require a signed-in user to render the cocktail-selection step in isolation; match whichever existing test in this file already renders a step of `ModernOrderFormScreen` and copy its setup):

```dart
  group('Shot quantity stepper', () {
    testWidgets('selecting a shot defaults its quantity to 1, then increments',
        (tester) async {
      // Arrange: pump the order form to the cocktail-selection step and
      // locate one Recipe with isShot == true, following the same pump/setup
      // pattern as the nearest existing test in this group above.
      // Act: tap the shot's card once to select it.
      // Assert: a Text widget showing '1' appears within the same card.
      // Act: tap the '+' IconButton once.
      // Assert: the Text widget now shows '2'.
      // Act: tap '-' twice.
      // Assert: the shot is deselected (quantity Text and stepper icons gone)
      // and the underlying recipe is removed from the selected set.
    }, skip: true); // Skip: needs the same AuthService DI the adjacent tests
                     // in this file skip for; unskip once that harness exists.
  });
```

Follow the exact skip convention already used elsewhere in this file (copy its skip reason string verbatim in style) rather than inventing a new one — the goal is consistency with the existing suite, not a new testing pattern. If, on inspection, the cocktail-selection step of `ModernOrderFormScreen` turns out **not** to require `AuthService` (unlike the dashboard/shopping-list steps the existing skipped tests cover), remove `skip: true` and write out the real `tester.tap`/`tester.pump`/`expect` calls following this test file's existing widget-finder idioms (e.g. `find.text`, `find.byIcon`) instead of leaving the comment-only body — the comment-only body above is acceptable only if the skip guard turns out to be genuinely necessary.

- [ ] **Step 4: Run the test and the full suite**

Run: `flutter test test/click_interactions_test.dart && flutter test`
Expected: PASS (or a documented skip, per Step 3's guidance); no regressions elsewhere.

- [ ] **Step 5: Manually verify on a narrow (mobile-width) viewport against dev**

Resize the browser below 600px width (or use a mobile device), open the order form's cocktail step, filter to "Shots", select a flavor → confirm quantity 1 appears with +/- controls, increment/decrement, and decrementing to 0 deselects it.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/forms/modern_order_form_screen.dart test/click_interactions_test.dart assets/translations/de.json assets/translations/en.json
git commit -m "feat: add per-flavor quantity stepper for shot selection"
```

---

### Task 12: Persist shot quantities from both submit paths, fix the cocktails/shots split

**Files:**
- Modify: `lib/screens/forms/modern_order_form_screen.dart`

**Interfaces:**
- Consumes: `_shotQuantities` (Task 11), `OrderRepository.saveOrder(..., shotQuantities:)` (Task 10).

- [ ] **Step 1: Fix `_savePendingOrderAndShowThanks`'s cocktails/shots split and add `shotQuantities`**

Replace:

```dart
      final orderId = await orderRepository.saveOrder(
        name: setupData.orderName,
        date: setupData.eventDate ?? DateTime.now(),
        items: [], // Empty items for pending order
        total: 0, // Pending order
        currency: setupData.currency,
        personCount: setupData.personCount,
        drinkerType: setupData.drinkerType,
        status: 'quote',
        cocktails: _selectedRecipes.map((r) => r.name).toList(),
        bar: setupData.serviceType,
```

with:

```dart
      final orderId = await orderRepository.saveOrder(
        name: setupData.orderName,
        date: setupData.eventDate ?? DateTime.now(),
        items: [], // Empty items for pending order
        total: 0, // Pending order
        currency: setupData.currency,
        personCount: setupData.personCount,
        drinkerType: setupData.drinkerType,
        status: 'quote',
        cocktails: _selectedRecipes
            .where((r) => !r.isShot)
            .map((r) => r.name)
            .toList(),
        shots: _selectedRecipes
            .where((r) => r.isShot)
            .map((r) => r.name)
            .toList(),
        shotQuantities: _shotQuantities.entries
            .map((e) => {'name': e.key, 'quantity': e.value})
            .toList(),
        bar: setupData.serviceType,
```

(Leave `bar: setupData.serviceType` exactly as-is — that mismatch is the separately-tracked, out-of-scope "related issue" noted in the design spec; do not fix it here.)

- [ ] **Step 2: Add `shotQuantities` to the staff update path**

In `_updateFormOrderAndNavigate`, find the `await orderRepository.updateOrder(order.id, {...})` call (built from `cocktailNames`/`shotNames`, which already correctly splits on `isShot`) and add one more entry to the map literal:

```dart
      'shots': shotNames,
      'shotQuantities': _shotQuantities.entries
          .map((e) => {'name': e.key, 'quantity': e.value})
          .toList(),
```

(insert the new line directly after the existing `'shots': shotNames,` line).

- [ ] **Step 3: Manually verify against dev**

Submit a customer request with two shot flavors at different quantities via the mobile-width form → open the order in the staff Orders overview (as an employee or admin) → open its detail sheet → confirm both `cocktails` and `shots` are correctly split (no shot flavor appears under cocktails) and that the Firestore document has a `shotQuantities` array matching what was entered.

- [ ] **Step 4: Run the full test suite and analyzer one more time**

Run: `flutter test && flutter analyze`
Expected: all pass, no new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/forms/modern_order_form_screen.dart
git commit -m "fix: split cocktails/shots correctly and persist shot quantities on submit"
```

---

### Task 13: Seed the offer's "Shots" position from `requestedShotsTotal` and per-flavor breakdown

**Files:**
- Modify: `lib/screens/offer/create_offer_screen.dart`

**Interfaces:**
- Consumes: `SavedOrder.requestedShotsTotal`, `SavedOrder.shotSelections` (Task 10); the existing `_buildRequestDerivedOfferPositions` method and the "Shots" `ExtraPosition` it already generates (added in this repo's most recent prior change — see `git log -1 --grep=shots -p -- lib/screens/offer/create_offer_screen.dart` if you need to confirm the current exact block before editing).

- [ ] **Step 1: Read the current shots block in `_buildRequestDerivedOfferPositions`**

It currently reads (added in the immediately preceding piece of work on this codebase):

```dart
    if (widget.order.shots.isNotEmpty) {
      rows.add(
        ExtraPosition(
          date: dateStr,
          name: isEn ? 'Shots' : 'Shots',
          quantity: widget.order.offerShotsCount,
          price: widget.order.offerShotsPricePerPiece > 0
              ? widget.order.offerShotsPricePerPiece
              : 1.50,
          remark: widget.order.offerShotsRemark.isNotEmpty
              ? widget.order.offerShotsRemark
              : widget.order.shots.join(', '),
        ),
      );
    }
```

- [ ] **Step 2: Update the quantity and remark to prefer the new per-flavor data**

Replace it with:

```dart
    if (widget.order.shots.isNotEmpty) {
      final perFlavorRemark = widget.order.shotSelections.isNotEmpty
          ? widget.order.shotSelections
              .map((s) => '${s.name} ${s.quantity}')
              .join(', ')
          : widget.order.shots.join(', ');

      rows.add(
        ExtraPosition(
          date: dateStr,
          name: isEn ? 'Shots' : 'Shots',
          quantity: widget.order.offerShotsCount > 0
              ? widget.order.offerShotsCount
              : widget.order.requestedShotsTotal,
          price: widget.order.offerShotsPricePerPiece > 0
              ? widget.order.offerShotsPricePerPiece
              : 1.50,
          remark: widget.order.offerShotsRemark.isNotEmpty
              ? widget.order.offerShotsRemark
              : perFlavorRemark,
        ),
      );
    }
```

This preserves both admin overrides exactly as before (`offerShotsCount > 0` and `offerShotsRemark.isNotEmpty` still win when set) and only changes the *un-overridden* defaults: quantity now defaults to what the customer actually asked for instead of always `0`, and the remark now shows the per-flavor breakdown when available instead of just the bare flavor names.

- [ ] **Step 3: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all pass, no new errors.

- [ ] **Step 4: Manually verify against dev**

Open a customer request that has `shotQuantities` set (from Task 12's manual test) in the offer screen as staff → confirm the "Shots" position now pre-fills with quantity = the sum the customer requested and a remark listing each flavor with its quantity, and that manually overriding quantity/remark in the offer screen still sticks (i.e., re-opening the offer after saving does not reset it back to the request's defaults).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/offer/create_offer_screen.dart
git commit -m "feat: seed offer Shots position from customer's requested per-flavor quantities"
```

---

## Self-Review Notes (for whoever executes this plan)

- **Spec coverage:** §1 (role model) → Tasks 2, 3, 4, 5, 6. §2 (ownership) → Task 7. §3 (rules) → Tasks 4, 9. §4 (my requests) → Task 8. §5 (shot quantities) → Tasks 10, 11, 12, 13. §6 (rollout order) → encoded directly into the task ordering and the Global Constraints note; Task 4/5 (mirror) intentionally precede Task 9 (orders rule), and Task 7 (owner queries) intentionally precedes Task 9 too.
- **Type consistency check performed:** `AppRole`, `resolveAppRole`, `ShotSelection`, `shotSelections`, `requestedShotsTotal`, `watchOrdersForOwner`, `updateEmployee(previous:)`, `deleteEmployee(Employee)` are named and typed identically everywhere they are produced (Tasks 1, 3, 7, 10) and consumed (Tasks 2, 6, 8, 9, 11, 12, 13).
- **Known deferred item:** Task 8 Step 2 and Task 10 Step 7 explicitly call out the one place a field (`shotSelections`) is consumed by a task (8) before it's produced by a later task (10) in this plan's written order, with an explicit instruction to reorder or defer — flagged rather than silently glossed over.
- **Explicitly not covered by this plan** (per the design spec's "Related issues noticed, not fixed here"): the `_savePendingOrderAndShowThanks` → `bar: setupData.serviceType` mismatch, the duplicate `/orders` route in `app_router.dart`, the two `DashboardScreen` classes, and `total == 0` as an implicit pending status. Do not fix these as part of this plan; they are separate tickets.
