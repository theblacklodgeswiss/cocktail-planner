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
