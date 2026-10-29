import 'dart:async';

import 'package:cocktail_planer/screens/dashboard/home_switch.dart';
import 'package:cocktail_planer/screens/more/more_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/staff_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pages = [
  '/orders',
  '/inventory',
  '/more',
  '/order-form',
  '/dashboard',
  '/pending-orders',
  '/admin',
  '/settings',
  '/settings/users',
  '/settings/employees',
  '/settings/services',
  '/login',
];

/// Real German translations behind a GoRouter, wired like lib/app.dart.
/// Every staff destination is a stand-in page that shows its path.
///
/// The home sits in a [StaffShell] (the bar and the "+" navigate like the
/// app's shell); [chrome] false shows it without the bar, like for customers.
GoRouter router(
  Widget home, {
  StaffTab tab = StaffTab.more,
  bool chrome = true,
}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => StaffShell(
        current: tab,
        showChrome: chrome,
        onSwitch: (t) => context.go(staffTabRoutes[t]!),
        onNewOrder: () => context.push(staffNewOrderRoute),
        child: home,
      ),
    ),
    for (final path in _pages)
      GoRoute(
        path: path,
        builder: (_, state) => Scaffold(body: Text('page $path')),
      ),
  ],
);

Widget app(GoRouter r, {ThemeData? theme, double textScale = 1}) {
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: const Locale('de'),
    child: Builder(
      builder: (context) => MaterialApp.router(
        theme: theme ?? AppTheme.light(),
        routerConfig: r,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
}

Future<void> pumpApp(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

void phone(WidgetTester tester, {double w = 360, double h = 640}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _user = MoreUser(name: 'Mia Muster', email: 'mia@example.com');

MoreView more({
  bool isAdmin = false,
  bool canManageUsers = false,
  bool isAnonymous = false,
  bool showFormSync = false,
  Future<void> Function()? onLogout,
  VoidCallback? onLinkGoogle,
  VoidCallback? onFormSync,
}) => MoreView(
  user: isAnonymous
      ? const MoreUser(name: null, email: null, isAnonymous: true)
      : _user,
  flags: MoreFlags(
    isAdmin: isAdmin,
    canManageUsers: canManageUsers,
    isAnonymous: isAnonymous,
    web: showFormSync,
  ),
  version: '1.2.3',
  onLinkGoogle: onLinkGoogle ?? () {},
  onFormSync: onFormSync ?? () {},
  onLogout: onLogout ?? () async {},
);

/// Text of a home that stands in for the customer start.
const _customer = Text('customer start');

Widget _staffHome() => const Scaffold(body: Text('orders list'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  // The bar on `/` belongs to the shell (see staff_shell_test.dart).
  group('HomeSwitch on /', () {
    testWidgets('customer sees the customer start', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          router(
            HomeSwitch(
              initialStaff: false,
              staffChanges: const Stream.empty(),
              staff: (_) => _staffHome(),
              customer: (_) => const Scaffold(body: _customer),
            ),
            chrome: false,
          ),
        ),
      );
      expect(find.text('customer start'), findsOneWidget);
      expect(find.text('orders list'), findsNothing);
    });

    testWidgets('staff sees the orders home', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          router(
            HomeSwitch(
              initialStaff: true,
              staffChanges: const Stream.empty(),
              staff: (_) => _staffHome(),
              customer: (_) => const Scaffold(body: _customer),
            ),
            chrome: false,
          ),
        ),
      );
      expect(find.text('orders list'), findsOneWidget);
      expect(find.text('customer start'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unresolved role -> staff switches without error', (
      tester,
    ) async {
      phone(tester);
      final changes = StreamController<bool>.broadcast();
      addTearDown(changes.close);
      var customerBuilds = 0;
      await pumpApp(
        tester,
        app(
          router(
            HomeSwitch(
              initialStaff: false,
              staffChanges: changes.stream,
              staff: (_) => _staffHome(),
              customer: (_) {
                customerBuilds++;
                return const Scaffold(body: _customer);
              },
            ),
            chrome: false,
          ),
        ),
      );
      expect(find.text('customer start'), findsOneWidget);

      changes.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('orders list'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Repeated resolves of the same role do not flip back.
      final before = customerBuilds;
      changes.add(true);
      await tester.pump();
      expect(find.text('orders list'), findsOneWidget);
      expect(customerBuilds, before);

      // Losing the role (e.g. sign-out) returns to the customer start.
      changes.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('customer start'), findsOneWidget);
    });
  });

  group('MoreView', () {
    Future<GoRouter> pumpMore(
      WidgetTester tester,
      MoreView view, {
      ThemeData? theme,
      double textScale = 1,
      double h = 640,
    }) async {
      phone(tester, h: h);
      final r = router(view);
      await pumpApp(tester, app(r, theme: theme, textScale: textScale));
      return r;
    }

    testWidgets('employee: no admin, no user management', (tester) async {
      await pumpMore(tester, more(), h: 1400);
      expect(find.text('Dashboard-Kennzahlen'), findsNothing);
      expect(find.text('Aufträge mit Pendenzen'), findsOneWidget);
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Abmelden'), findsOneWidget);
      expect(find.text('Admin-Bereich'), findsNothing);
      expect(find.text('Benutzer verwalten'), findsNothing);
      expect(find.byKey(const Key('more-employees')), findsNothing);
      expect(find.byKey(const Key('more-services')), findsNothing);
      expect(find.text('Mit Google verknüpfen'), findsNothing);
      expect(find.text('Admin'), findsNothing, reason: 'no admin badge');
      expect(find.text('Mia Muster'), findsOneWidget);
      expect(find.text('mia@example.com'), findsOneWidget);
    });

    testWidgets('admin without canManageUsers: admin, no users', (
      tester,
    ) async {
      await pumpMore(tester, more(isAdmin: true), h: 1400);
      expect(find.text('Admin-Bereich'), findsOneWidget);
      expect(find.text('Dashboard-Kennzahlen'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget, reason: 'badge');
      expect(find.text('Benutzer verwalten'), findsNothing);
    });

    testWidgets('canManageUsers shows users, employees and services', (
      tester,
    ) async {
      await pumpMore(
        tester,
        more(isAdmin: true, canManageUsers: true),
        h: 1600,
      );
      expect(find.text('Benutzer verwalten'), findsOneWidget);
      expect(find.byKey(const Key('more-employees')), findsOneWidget);
      expect(find.text('Zusatzleistungen'), findsOneWidget);
    });

    testWidgets('link Google only for anonymous', (tester) async {
      var linked = 0;
      await pumpMore(
        tester,
        more(isAnonymous: true, onLinkGoogle: () => linked++),
        h: 1400,
      );
      expect(find.text('Mit Google verknüpfen'), findsOneWidget);
      await tester.tap(find.text('Mit Google verknüpfen'));
      expect(linked, 1);
    });

    testWidgets('OneDrive sync for every employee on web', (tester) async {
      var synced = 0;
      await pumpMore(
        tester,
        more(showFormSync: true, onFormSync: () => synced++),
        h: 1400,
      );
      await tester.tap(find.text('OneDrive-Sync'));
      expect(synced, 1);
    });

    for (final admin in [false, true]) {
      testWidgets('no OneDrive sync off the web (admin: $admin)', (
        tester,
      ) async {
        await pumpMore(tester, more(isAdmin: admin), h: 1400);
        expect(find.text('OneDrive-Sync'), findsNothing);
      });
    }

    testWidgets('rows push their routes', (tester) async {
      final r = await pumpMore(
        tester,
        more(isAdmin: true, canManageUsers: true),
        h: 1600,
      );
      await tester.tap(find.text('Benutzer verwalten'));
      await tester.pumpAndSettle();
      expect(find.text('page /settings/users'), findsOneWidget);
      expect(r.canPop(), isTrue);
    });

    testWidgets('logout asks for confirmation', (tester) async {
      var loggedOut = 0;
      await pumpMore(tester, more(onLogout: () async => loggedOut++), h: 1400);
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Abmelden?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(loggedOut, 0);

      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abmelden').last);
      await tester.pumpAndSettle();
      expect(loggedOut, 1);
    });

    testWidgets('no access-denied flash while signing out', (tester) async {
      phone(tester);
      final role = ValueNotifier(true);
      addTearDown(role.dispose);
      final signedOut = Completer<void>();
      var done = 0;
      late Future<void> Function() logout;
      final r = router(
        LogoutTransition(
          signOut: () async {
            // Like authService.signOut: the role drops before it returns.
            role.value = false;
            await signedOut.future;
          },
          onSignedOut: () => done++,
          builder: (context, l) {
            logout = l;
            return ValueListenableBuilder<bool>(
              valueListenable: role,
              builder: (_, staff, _) =>
                  Scaffold(body: Text(staff ? 'more page' : 'access denied')),
            );
          },
        ),
      );
      await pumpApp(tester, app(r));
      expect(find.text('more page'), findsOneWidget);

      final pending = logout();
      await tester.pump();
      expect(find.text('access denied'), findsNothing);
      expect(find.byType(LoadingState), findsOneWidget);

      signedOut.complete();
      await pending;
      await tester.pump();
      expect(done, 1);
      expect(find.text('access denied'), findsNothing);
    });

    for (final dark in [false, true]) {
      testWidgets('fits 360x640 at text scale 1.3 (dark: $dark)', (
        tester,
      ) async {
        await pumpMore(
          tester,
          more(isAdmin: true, canManageUsers: true, showFormSync: true),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final bar = tester.getRect(find.byType(StaffTabBar));
        expect(bar.bottom, lessThanOrEqualTo(640));
        expect(bar.top, greaterThan(400));
        expect(bar.right, lessThanOrEqualTo(360));
      });
    }
  });

  group('lost functions', () {
    // Hand-written from the old user menu (user_menu_sheet.dart), the old
    // orders app bar and the old dashboard: destination, the role that could
    // see it, and the label it now has in the staff frame (a Mehr row, a
    // tab, or the "+" button). Not derived from moreGroups.
    final old = <(String, bool Function(MoreFlags), String)>[
      // user menu
      ('/admin', (f) => f.isAdmin, 'Admin-Bereich'),
      ('/orders', (f) => true, 'Aufträge'),
      ('/inventory', (f) => true, 'Inventur'),
      ('/settings', (f) => true, 'Einstellungen'),
      ('link-google', (f) => f.isAnonymous, 'Mit Google verknüpfen'),
      ('logout', (f) => true, 'Abmelden'),
      // orders app bar (dashboard icon: admin only; sync popup: web)
      ('/dashboard', (f) => f.isAdmin, 'Dashboard-Kennzahlen'),
      ('form-sync', (f) => f.web, 'OneDrive-Sync'),
      // dashboard
      ('/pending-orders', (f) => true, 'Aufträge mit Pendenzen'),
      ('/order-form', (f) => true, 'Neuer Auftrag'),
      // settings admin section
      ('/settings/users', (f) => f.canManageUsers, 'Benutzer verwalten'),
      ('/settings/employees', (f) => f.canManageUsers, 'Mitarbeiter'),
      ('/settings/services', (f) => f.canManageUsers, 'Zusatzleistungen'),
    ];

    final combos = [
      for (final admin in [false, true])
        for (final manage in [false, true])
          for (final anon in [false, true])
            for (final web in [false, true])
              if (!manage || admin)
                MoreFlags(
                  isAdmin: admin,
                  canManageUsers: manage,
                  isAnonymous: anon,
                  web: web,
                ),
    ];

    for (final f in combos) {
      testWidgets('every old entry is reachable for $f', (tester) async {
        for (final (dest, visible, label) in old) {
          if (!visible(f)) continue;
          var action = '';
          phone(tester, h: 1800);
          final r = router(
            MoreView(
              user: f.isAnonymous
                  ? const MoreUser(name: null, email: null, isAnonymous: true)
                  : _user,
              flags: f,
              version: '1.2.3',
              onLinkGoogle: () => action = 'link-google',
              onFormSync: () => action = 'form-sync',
              onLogout: () async => action = 'logout',
            ),
          );
          await pumpApp(tester, app(r));
          final target = find.bySemanticsLabel(label).evaluate().isNotEmpty
              ? find.bySemanticsLabel(label).last
              : find.text(label).last;
          await tester.tap(target);
          await tester.pumpAndSettle();
          if (dest == 'logout') {
            await tester.tap(find.text('Abmelden').last);
            await tester.pumpAndSettle();
          }
          if (dest.startsWith('/')) {
            expect(
              find.text('page $dest'),
              findsOneWidget,
              reason: '$dest via "$label"',
            );
          } else {
            expect(action, dest, reason: '$dest via "$label"');
          }
          // Fresh tree for the next entry.
          await tester.pumpWidget(const SizedBox());
        }
      });
    }

    test('role-only items stay role-only', () {
      for (final f in combos) {
        final dests = {
          for (final group in moreGroups(f))
            for (final item in group.items) item.destination,
        };
        expect(dests.contains('/admin'), f.isAdmin, reason: '$f');
        expect(dests.contains('/dashboard'), f.isAdmin, reason: '$f');
        for (final d in [
          '/settings/users',
          '/settings/employees',
          '/settings/services',
        ]) {
          expect(dests.contains(d), f.canManageUsers, reason: '$d $f');
        }
        expect(dests.contains('link-google'), f.isAnonymous, reason: '$f');
        expect(dests.contains('form-sync'), f.web, reason: '$f');
      }
    });
  });
}
