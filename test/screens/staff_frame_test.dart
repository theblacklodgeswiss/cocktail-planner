import 'dart:async';

import 'package:cocktail_planer/screens/dashboard/home_switch.dart';
import 'package:cocktail_planer/screens/more/more_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/staff_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
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
GoRouter router(Widget home) => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => home),
    for (final path in _pages)
      GoRoute(
        path: path,
        builder: (_, _) => Scaffold(body: Text('page $path')),
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

Widget _staffHome() => const StaffFrame(
  tab: StaffTab.orders,
  child: Scaffold(body: Text('orders list')),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('HomeSwitch on /', () {
    testWidgets('customer sees the customer start and no bar', (tester) async {
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
          ),
        ),
      );
      expect(find.text('customer start'), findsOneWidget);
      expect(find.byType(StaffTabBar), findsNothing);
      expect(find.text('orders list'), findsNothing);
    });

    testWidgets('staff sees the orders home and the bar', (tester) async {
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
          ),
        ),
      );
      expect(find.text('orders list'), findsOneWidget);
      expect(find.byType(StaffTabBar), findsOneWidget);
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
          ),
        ),
      );
      expect(find.text('customer start'), findsOneWidget);

      changes.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('orders list'), findsOneWidget);
      expect(find.byType(StaffTabBar), findsOneWidget);
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
      expect(find.byType(StaffTabBar), findsNothing);
    });
  });

  group('StaffScaffold', () {
    Widget page({ScrollController? controller}) => StaffScaffold(
      tab: StaffTab.orders,
      title: 'Aufträge',
      controller: controller,
      slivers: [
        SliverList.list(
          children: [
            for (var i = 0; i < 60; i++)
              SizedBox(height: 40, child: Text('row $i')),
          ],
        ),
      ],
    );

    testWidgets('+ FAB pushes /order-form', (tester) async {
      phone(tester);
      final r = router(page());
      await pumpApp(tester, app(r));
      await tester.tap(find.bySemanticsLabel('Neuer Auftrag'));
      await tester.pumpAndSettle();
      expect(find.text('page /order-form'), findsOneWidget);
      expect(r.canPop(), isTrue, reason: 'the form is pushed');
    });

    testWidgets('tapping the active tab scrolls to top, no navigation', (
      tester,
    ) async {
      phone(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final r = router(page(controller: controller));
      await pumpApp(tester, app(r));
      controller.jumpTo(800);
      await tester.pump();
      expect(controller.offset, 800);

      await tester.tap(find.bySemanticsLabel('Aufträge').last);
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(r.state.matchedLocation, '/');
    });

    testWidgets('another tab navigates with go (no back stack)', (
      tester,
    ) async {
      phone(tester);
      final r = router(page());
      await pumpApp(tester, app(r));
      await tester.tap(find.bySemanticsLabel('Inventur'));
      await tester.pumpAndSettle();
      expect(find.text('page /inventory'), findsOneWidget);
      expect(r.canPop(), isFalse);
    });

    testWidgets('Mehr tab goes to /more', (tester) async {
      phone(tester);
      final r = router(page());
      await pumpApp(tester, app(r));
      await tester.tap(find.bySemanticsLabel('Mehr'));
      await tester.pumpAndSettle();
      expect(find.text('page /more'), findsOneWidget);
    });

    test('tab routes keep the existing paths', () {
      expect(staffTabRoutes, {
        StaffTab.orders: '/orders',
        StaffTab.inventory: '/inventory',
        StaffTab.more: '/more',
      });
    });
  });

  group('StaffFrame (legacy screens)', () {
    testWidgets('shows the bar and the + FAB around a Material page', (
      tester,
    ) async {
      phone(tester);
      final r = router(
        const StaffFrame(
          tab: StaffTab.inventory,
          child: Scaffold(body: Text('inventory table')),
        ),
      );
      await pumpApp(tester, app(r));
      expect(find.text('inventory table'), findsOneWidget);
      expect(find.byType(StaffTabBar), findsOneWidget);
      final bar = tester.getRect(find.byType(StaffTabBar));
      expect(bar.bottom, lessThanOrEqualTo(640));

      await tester.tap(find.bySemanticsLabel('Neuer Auftrag'));
      await tester.pumpAndSettle();
      expect(find.text('page /order-form'), findsOneWidget);
    });

    testWidgets('active tab scrolls the page to top', (tester) async {
      phone(tester);
      final r = router(
        StaffFrame(
          tab: StaffTab.orders,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 40, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await pumpApp(tester, app(r));
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(600);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Aufträge').last);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);
      expect(r.state.matchedLocation, '/');
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
      expect(find.text('Dashboard-Kennzahlen'), findsOneWidget);
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

    testWidgets('OneDrive sync only when enabled', (tester) async {
      var synced = 0;
      await pumpMore(
        tester,
        more(isAdmin: true, showFormSync: true, onFormSync: () => synced++),
        h: 1400,
      );
      await tester.tap(find.text('OneDrive-Sync'));
      expect(synced, 1);
    });

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
    // Every entry of the old user menu (user_menu_sheet.dart) with the role
    // that could see it. 'logout' and 'link-google' are actions.
    final oldMenu = <(String, bool Function(MoreFlags))>[
      ('/admin', (f) => f.isAdmin),
      ('/orders', (f) => true),
      ('/inventory', (f) => true),
      ('/settings', (f) => true),
      ('link-google', (f) => f.isAnonymous),
      ('logout', (f) => true),
    ];
    // Old app-bar / dashboard entries for staff.
    final oldBars = <(String, bool Function(MoreFlags))>[
      ('/dashboard', (f) => f.isAdmin),
      ('/pending-orders', (f) => true),
      ('/order-form', (f) => true),
      ('form-sync', (f) => f.isAdmin && f.web),
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

    test('every old entry has a destination for the same role', () {
      for (final f in combos) {
        final reachable = {
          for (final group in moreGroups(f))
            for (final item in group.items) item.destination,
          ...staffTabRoutes.values,
          staffNewOrderRoute,
        };
        for (final (dest, visible) in [...oldMenu, ...oldBars]) {
          if (!visible(f)) continue;
          expect(reachable, contains(dest), reason: '$dest for $f');
        }
      }
    });

    test('role-only items stay role-only', () {
      for (final f in combos) {
        final dests = {
          for (final group in moreGroups(f))
            for (final item in group.items) item.destination,
        };
        expect(dests.contains('/admin'), f.isAdmin, reason: '$f');
        for (final d in [
          '/settings/users',
          '/settings/employees',
          '/settings/services',
        ]) {
          expect(dests.contains(d), f.canManageUsers, reason: '$d $f');
        }
        expect(dests.contains('link-google'), f.isAnonymous, reason: '$f');
        expect(dests.contains('form-sync'), f.isAdmin && f.web, reason: '$f');
      }
    });
  });
}
