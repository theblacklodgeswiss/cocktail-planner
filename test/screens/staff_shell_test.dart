import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/floating_fab.dart';
import 'package:cocktail_planer/ui/widgets/glass_surface.dart';
import 'package:cocktail_planer/ui/widgets/staff_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Root page of a tab: a long list and a search field at the top.
class _TabPage extends StatelessWidget {
  const _TabPage(this.tab);

  final StaffTab tab;

  @override
  Widget build(BuildContext context) => StaffScaffold(
    tab: tab,
    title: 'Seite ${tab.name}',
    slivers: [
      SliverToBoxAdapter(child: TextField(key: Key('tf ${tab.name}'))),
      SliverToBoxAdapter(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('snack ${tab.name}'))),
            child: Text('show snack ${tab.name}'),
          ),
        ),
      ),
      SliverList.builder(
        itemCount: 40,
        itemBuilder: (_, i) => SizedBox(
          key: ValueKey('${tab.name} row $i'),
          height: 60,
          child: Text('${tab.name} row $i'),
        ),
      ),
    ],
  );
}

/// Same shape as the app router: an indexed-stack shell with the branches
/// orders (`/`, `/orders`), inventory and more, and a pushed page outside.
GoRouter shellRouter({String initial = '/', bool staff = true}) => GoRouter(
  initialLocation: initial,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => StaffShell(
        showChrome: staff,
        current: StaffTab.values[shell.currentIndex],
        onSwitch: (t) => shell.goBranch(t.index),
        onNewOrder: () => context.push(staffNewOrderRoute),
        child: shell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const _TabPage(StaffTab.orders),
            ),
            GoRoute(
              path: '/orders',
              builder: (_, _) => const _TabPage(StaffTab.orders),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              builder: (_, _) => const _TabPage(StaffTab.inventory),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (_, _) => const _TabPage(StaffTab.more),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () => context.go('/orders?status=accepted'),
          child: const Text('to orders'),
        ),
      ),
    ),
    GoRoute(
      path: staffNewOrderRoute,
      builder: (_, _) => const Scaffold(body: Text('order form')),
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

Finder _tab(String label) => find.descendant(
  of: find.byType(StaffTabBar),
  matching: find.bySemanticsLabel(label),
);

Rect _bar(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(StaffTabBar),
    matching: find.byType(GlassSurface),
  ),
);

ScrollPosition _position(WidgetTester tester, StaffTab tab) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is _TabPage && w.tab == tab,
              skipOffstage: false,
            ),
            matching: find.byType(Scrollable, skipOffstage: false),
          )
          .first,
    )
    .position;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('bar persists (same state) across tab switches', (tester) async {
    phone(tester);
    final r = shellRouter();
    await pumpApp(tester, app(r));
    final shell = tester.state(find.byType(StaffShell));
    final lens = tester.state(find.byKey(const ValueKey('tab-lens')));

    await tester.tap(_tab('Inventur'));
    await tester.pumpAndSettle();
    expect(r.state.matchedLocation, '/inventory');
    expect(find.byType(StaffShell), findsOneWidget);
    expect(tester.state(find.byType(StaffShell)), same(shell));
    expect(tester.state(find.byKey(const ValueKey('tab-lens'))), same(lens));

    await tester.tap(_tab('Mehr'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(StaffShell)), same(shell));
  });

  testWidgets('content swaps instantly, without a route transition', (
    tester,
  ) async {
    phone(tester);
    final r = shellRouter();
    await pumpApp(tester, app(r));
    await tester.tap(_tab('Inventur'));
    // One frame: no slide, the new tab is already in place and on top.
    await tester.pump();
    expect(find.text('Seite inventory').hitTestable(), findsWidgets);
    expect(tester.getTopLeft(find.byType(CustomScrollView)), Offset.zero);
    expect(find.text('Seite orders'), findsNothing, reason: 'offstage');
    expect(r.canPop(), isFalse, reason: 'tabs do not stack');
  });

  testWidgets('each tab keeps its scroll position', (tester) async {
    phone(tester);
    await pumpApp(tester, app(shellRouter()));
    _position(tester, StaffTab.orders).jumpTo(700);
    await tester.pump();

    await tester.tap(_tab('Inventur'));
    await tester.pumpAndSettle();
    expect(_position(tester, StaffTab.inventory).pixels, 0);
    _position(tester, StaffTab.inventory).jumpTo(300);
    await tester.pump();

    await tester.tap(_tab('Aufträge'));
    await tester.pumpAndSettle();
    expect(_position(tester, StaffTab.orders).pixels, 700);
    await tester.tap(_tab('Inventur'));
    await tester.pumpAndSettle();
    expect(_position(tester, StaffTab.inventory).pixels, 300);
  });

  testWidgets('tapping the active tab scrolls it to the top', (tester) async {
    phone(tester);
    final r = shellRouter();
    await pumpApp(tester, app(r));
    _position(tester, StaffTab.orders).jumpTo(900);
    await tester.pump();
    await tester.tap(_tab('Aufträge'));
    await tester.pumpAndSettle();
    expect(_position(tester, StaffTab.orders).pixels, 0);
    expect(r.state.matchedLocation, '/');
  });

  testWidgets('customer sees the content without bar and +', (tester) async {
    phone(tester);
    await pumpApp(tester, app(shellRouter(staff: false)));
    expect(find.text('Seite orders'), findsWidgets);
    expect(find.byType(StaffTabBar), findsNothing);
    expect(find.byType(FloatingFab), findsNothing);
    // No clearance is added for a bar that is not there.
    expect(
      MediaQuery.paddingOf(
        tester.element(find.byKey(const ValueKey('orders row 0'))),
      ).bottom,
      0,
    );
  });

  testWidgets('deep link /inventory opens the inventory branch', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, app(shellRouter(initial: '/inventory')));
    expect(find.text('Seite inventory'), findsWidgets);
    expect(
      tester.widget<StaffShell>(find.byType(StaffShell)).current,
      StaffTab.inventory,
    );
    // Lens on "Inventur".
    final lens = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('tab-lens')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(lens.center.dx, closeTo(tester.getCenter(_tab('Inventur')).dx, 1));
  });

  testWidgets('/orders deep link is the orders tab', (tester) async {
    phone(tester);
    await pumpApp(tester, app(shellRouter(initial: '/orders')));
    expect(
      tester.widget<StaffShell>(find.byType(StaffShell)).current,
      StaffTab.orders,
    );
  });

  testWidgets('+ pushes the form full-screen, outside the shell', (
    tester,
  ) async {
    phone(tester);
    final r = shellRouter();
    await pumpApp(tester, app(r));
    await tester.tap(find.bySemanticsLabel('Neuer Auftrag'));
    await tester.pumpAndSettle();
    expect(find.text('order form'), findsOneWidget);
    expect(find.byType(StaffTabBar).hitTestable(), findsNothing);
    expect(r.canPop(), isTrue);
    r.pop();
    await tester.pumpAndSettle();
    expect(find.byType(StaffTabBar).hitTestable(), findsOneWidget);
  });

  testWidgets('keyboard hides bar and +, drops the clearance', (tester) async {
    phone(tester);
    await pumpApp(tester, app(shellRouter()));
    await tester.tap(find.byKey(const Key('tf orders')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(_tab('Inventur').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Neuer Auftrag').hitTestable(), findsNothing);
    expect(
      MediaQuery.paddingOf(
        tester.element(find.byKey(const ValueKey('orders row 0'))),
      ).bottom,
      0,
    );
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(_tab('Inventur').hitTestable(), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('bar sits clear of the edge; + above it (dark: $dark)', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          shellRouter(),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = _bar(tester);
      // Flutter web reports no safe area: the floor keeps the bar off the
      // home indicator.
      expect(640 - bar.bottom, greaterThanOrEqualTo(AppSize.tabBarBottom));
      expect(bar.left, greaterThanOrEqualTo(16));
      expect(360 - bar.right, greaterThanOrEqualTo(16));
      final fab = tester.getRect(find.byType(FloatingFab));
      expect(bar.top - fab.bottom, greaterThanOrEqualTo(12));

      // The last row scrolls fully above the bar and the "+".
      _position(
        tester,
        StaffTab.orders,
      ).jumpTo(_position(tester, StaffTab.orders).maxScrollExtent);
      await tester.pump();
      final last = tester.getRect(find.byKey(const ValueKey('orders row 39')));
      expect(last.bottom, lessThanOrEqualTo(fab.top));
    });
  }

  testWidgets('safe area adds to the bar margin', (tester) async {
    phone(tester);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await pumpApp(tester, app(shellRouter()));
    expect(640 - _bar(tester).bottom, greaterThanOrEqualTo(34 + 8));
  });

  testWidgets('a tab link from a pushed page (go) lands in the shell', (
    tester,
  ) async {
    phone(tester);
    final r = shellRouter();
    await pumpApp(tester, app(r));
    r.push('/dashboard');
    await tester.pumpAndSettle();
    await tester.tap(find.text('to orders'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Seite orders').hitTestable(), findsWidgets);
    expect(find.byType(StaffTabBar).hitTestable(), findsOneWidget);
    expect(r.state.uri.toString(), '/orders?status=accepted');
    expect(r.canPop(), isFalse);
  });

  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    testWidgets('snackbar on a tab floats above bar and + ($size)', (
      tester,
    ) async {
      phone(tester, w: size.width, h: size.height);
      await pumpApp(tester, app(shellRouter()));
      await tester.tap(find.text('show snack orders'));
      await tester.pumpAndSettle();
      // The visible snackbar (its Material), without the floating margin.
      final snack = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      final bar = _bar(tester);
      final fab = tester.getRect(find.byType(FloatingFab));
      expect(snack.bottom, lessThanOrEqualTo(bar.top));
      expect(snack.bottom, lessThanOrEqualTo(fab.top));
      expect(snack.height, lessThan(100), reason: 'no padded block');
      expect(find.text('snack orders').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('snackbar on a pushed page keeps the default look', (
    tester,
  ) async {
    phone(tester);
    final r = shellRouter();
    await pumpApp(tester, app(r));
    r.push('/dashboard');
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.text('to orders')),
    ).showSnackBar(const SnackBar(content: Text('pushed snack')));
    await tester.pumpAndSettle();
    final snack = tester.widget<SnackBar>(find.byType(SnackBar).last);
    expect(snack.behavior, isNull);
    final rect = tester.getRect(find.byType(SnackBar).last);
    expect(rect.bottom, 640, reason: 'fixed at the bottom edge');
  });
}
