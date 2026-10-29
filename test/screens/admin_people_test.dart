import 'package:cocktail_planer/models/additional_service.dart';
import 'package:cocktail_planer/models/employee.dart';
import 'package:cocktail_planer/screens/admin/employees_view.dart';
import 'package:cocktail_planer/screens/admin/services_view.dart';
import 'package:cocktail_planer/screens/settings/user_management_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_harness.dart';

const _anna = Employee(id: 'a', name: 'Anna', role: EmployeeRole.supervisor);

EmployeesView employeesView({
  List<Employee> employees = const [_anna],
  Future<bool> Function(String, String?, EmployeeRole)? onAdd,
  Future<bool> Function(Employee)? onDelete,
}) => EmployeesView(
  employees: employees,
  loading: false,
  errorMessage: null,
  onRetry: () {},
  onAdd: onAdd ?? (_, _, _) async => true,
  onUpdate: (_, _, _, _) async => true,
  onDelete: onDelete ?? (_) async => true,
  onReorder: (_, _) async {},
  onRebuildAccess: () async => 3,
);

ServicesView servicesView({
  List<AdditionalService> services = const [],
  Future<bool> Function(ServiceFormResult)? onAdd,
}) => ServicesView(
  services: services,
  loading: false,
  errorMessage: null,
  onRetry: () {},
  onAdd: onAdd ?? (_) async => true,
  onUpdate: (_, _) async => true,
  onDelete: (_) async => true,
  onReorder: (_, _) async {},
  onPickImage: () async => null,
  showImportLegacy: true,
  onImportLegacy: () async => 2,
);

UserManagementView usersView({
  List<UserRow>? users,
  bool viewerIsAdmin = true,
  Future<void> Function(UserRow, bool)? onToggle,
  Future<bool> Function(String, String, bool)? onAdd,
}) => UserManagementView(
  users:
      users ??
      const [
        UserRow(email: 'me@x.ch', name: 'Me', isAdmin: true),
        UserRow(email: 'boss@x.ch', name: '', isAdmin: false),
        UserRow(email: 'root@x.ch', name: 'Root', isAdmin: true),
      ],
  loading: false,
  errorMessage: null,
  onRetry: () {},
  currentEmail: 'me@x.ch',
  superAdminEmail: 'root@x.ch',
  viewerIsAdmin: viewerIsAdmin,
  onToggleAdmin: onToggle ?? (_, _) async {},
  onRemove: (_) async => true,
  onAdd: onAdd ?? (_, _, _) async => true,
);

void main() {
  setUpAll(initAdminTest);

  group('employees', () {
    testWidgets('lists employees and the empty state', (tester) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(employeesView()));
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Supervisor'), findsOneWidget);
      expect(find.text('Kein App-Zugang (keine E-Mail hinterlegt)'), findsOneWidget);
    });

    testWidgets('empty list shows the empty state', (tester) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(employeesView(employees: const [])));
      expect(find.text('Keine Mitarbeiter vorhanden'), findsOneWidget);
    });

    testWidgets('add via FAB validates and calls onAdd', (tester) async {
      phone(tester);
      String? gotName;
      String? gotEmail = 'unset';
      EmployeeRole? gotRole;
      await pumpAdmin(
        tester,
        adminApp(
          employeesView(
            onAdd: (n, e, r) async {
              gotName = n;
              gotEmail = e;
              gotRole = r;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Mitarbeiter hinzufügen'));
      await settleAdmin(tester);
      // Empty name: validation message, no write.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Hinzufügen'));
      await settleAdmin(tester);
      expect(gotName, isNull);
      expect(find.text('Pflichtfeld'), findsOneWidget);
      // Bad email.
      await tester.enterText(find.byKey(const Key('employee-name')), 'Bob');
      await tester.enterText(find.byKey(const Key('employee-email')), 'nope');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Hinzufügen'));
      await settleAdmin(tester);
      expect(gotName, isNull);
      await tester.enterText(find.byKey(const Key('employee-email')), '');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Hinzufügen'));
      await settleAdmin(tester);
      expect(gotName, 'Bob');
      expect(gotEmail, isNull);
      expect(gotRole, EmployeeRole.staff);
      expect(find.text('Mitarbeiter hinzugefügt!'), findsOneWidget);
    });

    testWidgets('delete goes through the confirm sheet', (tester) async {
      phone(tester);
      final deleted = <String>[];
      await pumpAdmin(
        tester,
        adminApp(
          employeesView(
            onDelete: (e) async {
              deleted.add(e.id);
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Löschen'));
      await settleAdmin(tester);
      expect(deleted, isEmpty);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Löschen'));
      await settleAdmin(tester);
      expect(deleted, ['a']);
    });

    testWidgets('rebuild access reports the count', (tester) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(employeesView()));
      await tester.tap(find.text('Zugänge neu aufbauen'));
      await settleAdmin(tester);
      expect(find.text('3 Zugänge synchronisiert'), findsOneWidget);
    });
  });

  group('services', () {
    testWidgets('add via FAB passes name and variants', (tester) async {
      phone(tester);
      ServiceFormResult? got;
      await pumpAdmin(
        tester,
        adminApp(
          servicesView(
            onAdd: (r) async {
              got = r;
              return true;
            },
          ),
        ),
      );
      expect(find.text('Keine Zusatzleistungen vorhanden'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Zusatzleistung hinzufügen'));
      await settleAdmin(tester);
      await tester.enterText(find.byKey(const Key('service-name')), 'Photobox');
      await tester.tap(find.text('Variante hinzufügen'));
      await settleAdmin(tester);
      await tester.enterText(find.byType(TextField).at(1), 'Digital');
      await tester.enterText(find.byType(TextField).at(2), '300,5');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Hinzufügen'));
      await settleAdmin(tester);
      expect(got!.name, 'Photobox');
      expect(got!.imageUrl, isNull);
      expect(got!.variants.single.name, 'Digital');
      expect(got!.variants.single.price, 300.5);
    });

    testWidgets('legacy import button reports the count', (tester) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(servicesView()));
      await tester.tap(find.text('Alte Zusatzleistungen importieren'));
      await settleAdmin(tester);
      expect(find.text('2 Zusatzleistung(en) importiert'), findsOneWidget);
    });
  });

  group('users', () {
    testWidgets('self cannot be changed or removed, super admin has no switch', (
      tester,
    ) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(usersView()));
      expect(find.byType(Switch), findsNWidgets(2)); // me + boss, not root
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].onChanged, isNull); // me
      expect(switches[1].onChanged, isNotNull); // boss
      expect(find.text('Du'), findsOneWidget);
      // Delete only for boss.
      expect(find.bySemanticsLabel('Löschen'), findsOneWidget);
    });

    testWidgets('non-admin manager sees no delete buttons', (tester) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(usersView(viewerIsAdmin: false)));
      expect(find.bySemanticsLabel('Löschen'), findsNothing);
    });

    testWidgets('toggle calls onToggle', (tester) async {
      phone(tester);
      String? who;
      bool? to;
      await pumpAdmin(
        tester,
        adminApp(
          usersView(
            onToggle: (u, v) async {
              who = u.email;
              to = v;
            },
          ),
        ),
      );
      await tester.tap(find.byType(Switch).at(1));
      await tester.pump();
      expect(who, 'boss@x.ch');
      expect(to, true);
    });

    testWidgets('add via FAB calls onAdd', (tester) async {
      phone(tester);
      String? email;
      String? name;
      bool? admin;
      await pumpAdmin(
        tester,
        adminApp(
          usersView(
            onAdd: (e, n, a) async {
              email = e;
              name = n;
              admin = a;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Neuen Benutzer hinzufügen'));
      await settleAdmin(tester);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Hinzufügen'));
      await settleAdmin(tester);
      expect(email, isNull); // empty email is not submitted
      await tester.enterText(find.byKey(const Key('user-email')), ' a@b.ch ');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Hinzufügen'));
      await settleAdmin(tester);
      expect(email, 'a@b.ch');
      expect(name, '');
      expect(admin, false);
    });
  });

  group('no overflow at 360x640, text 1.3, keyboard 300', () {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      ThemeData theme() => dark ? AppTheme.dark() : AppTheme.light();

      testWidgets('employee sheet ($mode)', (tester) async {
        phone(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await pumpAdmin(
          tester,
          adminApp(employeesView(), theme: theme(), textScale: 1.3),
        );
        await tester.tap(find.text('Anna'));
        await settleAdmin(tester);
        await tester.tap(find.byKey(const Key('employee-name')));
        await settleAdmin(tester);
        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(PrimaryButton, 'Speichern'), findsOneWidget);
      });

      testWidgets('users and services lists ($mode)', (tester) async {
        phone(tester);
        await pumpAdmin(
          tester,
          adminApp(usersView(), theme: theme(), textScale: 1.3),
        );
        expect(tester.takeException(), isNull);
        await pumpAdmin(
          tester,
          adminApp(
            servicesView(
              services: const [
                AdditionalService(
                  id: 's',
                  name: 'BlackLodge - Bubble Waffles Deluxe',
                  variants: [ServiceVariant(id: 'v', name: 'Std')],
                ),
              ],
            ),
            theme: theme(),
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
