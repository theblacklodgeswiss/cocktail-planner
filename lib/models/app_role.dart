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
