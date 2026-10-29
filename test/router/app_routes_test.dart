import 'dart:async';

import 'package:cocktail_planer/router/app_routes.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/staff_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's real route table with stand-in pages that show their name and
/// `extra`, and injected role flags.
GoRouter _router({
  String initial = '/',
  bool staff = true,
  Stream<bool>? staffChanges,
}) => GoRouter(
  initialLocation: initial,
  routes: buildAppRoutes(
    page: (context, state, page) =>
        Scaffold(body: Text('page ${page.name} ${state.extra ?? ''}'.trim())),
    isStaff: () => staff,
    staffChanges: staffChanges ?? const Stream.empty(),
  ),
);

Widget _app(GoRouter r) => EasyLocalization(
  supportedLocales: const [Locale('de'), Locale('en')],
  path: 'assets/translations',
  fallbackLocale: const Locale('de'),
  startLocale: const Locale('de'),
  child: Builder(
    builder: (context) => MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: r,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  // Path, page, tab of the shell (null: a pushed page outside the shell).
  const table = <(String, AppPage, StaffTab?)>[
    ('/', AppPage.home, StaffTab.orders),
    ('/orders', AppPage.orders, StaffTab.orders),
    ('/orders?status=accepted', AppPage.orders, StaffTab.orders),
    ('/inventory', AppPage.inventory, StaffTab.inventory),
    ('/more', AppPage.more, StaffTab.more),
    ('/orders/pending', AppPage.pendingOrders, null),
    ('/orders/years', AppPage.ordersYears, null),
    ('/pending-orders', AppPage.pendingOrders, null),
    ('/dashboard', AppPage.dashboard, null),
    ('/my-requests', AppPage.myRequests, null),
    ('/order-form', AppPage.orderForm, null),
    ('/order-success', AppPage.orderSuccess, null),
    ('/shopping-list', AppPage.shoppingList, null),
    ('/admin', AppPage.admin, null),
    ('/settings', AppPage.settings, null),
    ('/settings/legal/imprint', AppPage.legalImprint, null),
    ('/settings/legal/terms', AppPage.legalTerms, null),
    ('/settings/legal/privacy', AppPage.legalPrivacy, null),
    ('/settings/admin', AppPage.adminSettings, null),
    ('/settings/users', AppPage.userManagement, null),
    ('/settings/employees', AppPage.employees, null),
    ('/settings/services', AppPage.services, null),
    ('/create-offer', AppPage.createOffer, null),
    ('/create-invoice', AppPage.createInvoice, null),
    ('/login', AppPage.login, null),
    ('/s/abc', AppPage.sharedDocument, null),
  ];

  for (final (path, page, tab) in table) {
    testWidgets(
      '$path -> ${page.name} ${tab == null ? 'outside the shell' : 'in tab ${tab.name}'}',
      (tester) async {
        _phone(tester);
        final r = _router(initial: path);
        await _pump(tester, _app(r));
        expect(find.text('page ${page.name}'), findsOneWidget);
        if (tab == null) {
          expect(find.byType(StaffShell), findsNothing);
          expect(find.byType(StaffTabBar), findsNothing);
        } else {
          expect(
            tester.widget<StaffShell>(find.byType(StaffShell)).current,
            tab,
          );
          expect(find.byType(StaffTabBar), findsOneWidget);
        }
      },
    );
  }

  test('every page is reachable and the tab roots match staffTabRoutes', () {
    expect({for (final (_, page, _) in table) page}, AppPage.values.toSet());
    for (final MapEntry(key: tab, value: path) in staffTabRoutes.entries) {
      expect(
        table.where((e) => e.$1 == path && e.$3 == tab),
        hasLength(1),
        reason: '$tab at $path',
      );
    }
  });

  group('role-dependent chrome (StaffShellHost)', () {
    testWidgets('unresolved -> staff shows the bar; losing it hides it', (
      tester,
    ) async {
      _phone(tester);
      final changes = StreamController<bool>.broadcast();
      addTearDown(changes.close);
      await _pump(
        tester,
        _app(_router(staff: false, staffChanges: changes.stream)),
      );
      expect(find.text('page home'), findsOneWidget);
      expect(find.byType(StaffTabBar), findsNothing);

      changes.add(true);
      await tester.pump();
      expect(find.byType(StaffTabBar), findsOneWidget);
      final shell = tester.state(find.byType(StaffShell));

      // A repeated equal resolve changes nothing.
      changes.add(true);
      await tester.pump();
      expect(tester.state(find.byType(StaffShell)), same(shell));

      changes.add(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(StaffTabBar), findsNothing);
      expect(find.text('page home'), findsOneWidget, reason: 'content kept');
    });

    for (final path in ['/', '/inventory', '/more']) {
      testWidgets('customer never sees the bar on $path', (tester) async {
        _phone(tester);
        final changes = StreamController<bool>.broadcast();
        addTearDown(changes.close);
        await _pump(
          tester,
          _app(
            _router(initial: path, staff: false, staffChanges: changes.stream),
          ),
        );
        changes.add(false);
        await tester.pump();
        expect(find.byType(StaffTabBar), findsNothing);
        expect(find.byType(StaffShell), findsOneWidget);
      });
    }
  });

  testWidgets('a repeated orders link with a new extra rebuilds the page', (
    tester,
  ) async {
    _phone(tester);
    final r = _router(initial: '/inventory');
    await _pump(tester, _app(r));
    r.go('/orders?status=accepted', extra: 1);
    await tester.pumpAndSettle();
    expect(find.text('page orders 1'), findsOneWidget);
    r.go('/orders?status=accepted', extra: 2);
    await tester.pumpAndSettle();
    expect(find.text('page orders 2'), findsOneWidget);
  });
}
