import 'dart:async';

import 'package:cocktail_planer/models/app_role.dart';
import 'package:cocktail_planer/models/employee.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

AuthService build({
  String? email = 'a@b.de',
  Future<bool> Function(String)? allowed,
  Future<({bool exists, EmployeeRole? role})> Function(String)? access,
}) => AuthService.forTesting(
  emailProvider: () => email,
  lookupAllowedUserIsAdmin: allowed ?? (_) async => false,
  lookupEmployeeAccess: access ?? (_) async => (exists: false, role: null),
);

void main() {
  test('no email -> customer, no lookups', () async {
    var calls = 0;
    final s = build(
      email: null,
      allowed: (_) async {
        calls++;
        return true;
      },
    );
    expect(await s.checkRole(), AppRole.customer);
    expect(calls, 0);
    expect(s.roleResolved, isTrue);
  });

  test('super admin shortcut does not touch lookups', () async {
    var calls = 0;
    final s = build(
      email: superAdminEmail.toUpperCase(),
      allowed: (_) async {
        calls++;
        return false;
      },
      access: (_) async {
        calls++;
        return (exists: false, role: null);
      },
    );
    expect(await s.checkRole(), AppRole.superAdmin);
    expect(calls, 0);
  });

  test('allowedUsers admin wins over employee mirror', () async {
    final s = build(
      allowed: (_) async => true,
      access: (_) async => (exists: true, role: EmployeeRole.supervisor),
    );
    expect(await s.checkRole(), AppRole.admin);
    expect(s.employeeRole, isNull);
  });

  test('employee only', () async {
    final s = build(
      access: (_) async => (exists: true, role: EmployeeRole.supervisor),
    );
    expect(await s.checkRole(), AppRole.employee);
    expect(s.employeeRole, EmployeeRole.supervisor);
  });

  test('neither -> customer', () async {
    final s = build();
    expect(await s.checkRole(), AppRole.customer);
    expect(s.employeeRole, isNull);
  });

  test('allowedUsers throws -> falls back to employee mirror', () async {
    final s = build(
      allowed: (_) async => throw Exception('x'),
      access: (_) async => (exists: true, role: EmployeeRole.supervisor),
    );
    expect(await s.checkRole(), AppRole.employee);
  });

  test('employeeAccess throws -> customer', () async {
    final s = build(access: (_) async => throw Exception('x'));
    expect(await s.checkRole(), AppRole.customer);
  });

  test('employeeAccess throws but admin -> admin', () async {
    final s = build(
      allowed: (_) async => true,
      access: (_) async => throw Exception('x'),
    );
    expect(await s.checkRole(), AppRole.admin);
  });

  test('lookups run concurrently and email is lowercased', () async {
    final started = <String>[];
    final gate = Completer<void>();
    final s = build(
      email: 'A@B.de',
      allowed: (e) async {
        started.add('allowed:$e');
        await gate.future;
        return false;
      },
      access: (e) async {
        started.add('access:$e');
        await gate.future;
        return (exists: false, role: null);
      },
    );
    final f = s.checkRole();
    await Future<void>.delayed(Duration.zero);
    expect(started, ['allowed:a@b.de', 'access:a@b.de']);
    gate.complete();
    expect(await f, AppRole.customer);
  });

  test('employeeAccess doc exists with unparseable role still counts', () async {
    final s = build(access: (_) async => (exists: true, role: null));
    expect(await s.checkRole(), AppRole.employee);
  });

  test('synchronous throw from lookups is handled', () async {
    final s = build(
      allowed: (_) => throw Exception('sync'),
      access: (_) => throw Exception('sync'),
    );
    expect(await s.checkRole(), AppRole.customer);
  });

  test('emits on roleChanges', () async {
    final s = build(allowed: (_) async => true);
    final next = s.roleChanges.first;
    await s.checkRole();
    expect(await next, AppRole.admin);
  });
}
