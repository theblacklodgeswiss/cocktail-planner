import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/floating_fab.dart';
import 'package:cocktail_planer/ui/widgets/glass_cta_bar.dart';
import 'package:cocktail_planer/ui/widgets/glass_surface.dart';
import 'package:cocktail_planer/ui/widgets/large_title_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/pressable.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(
  Widget home, {
  ThemeData? theme,
  bool reduceMotion = false,
  bool highContrast = false,
  double textScale = 1,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: const Locale('de'),
    child: Builder(
      builder: (context) => MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            highContrast: highContrast,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: home,
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
}

void phone(WidgetTester tester, {double w = 360, double h = 640}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder barGlass() => find.descendant(
  of: find.byType(StaffTabBar),
  matching: find.byType(GlassSurface),
);

Finder lens() => find.byKey(const ValueKey('tab-lens'));

/// Center of the lens' painted box.
double lensCenter(WidgetTester tester) => tester
    .getRect(
      find.descendant(of: lens(), matching: find.byType(DecoratedBox)).first,
    )
    .center
    .dx;

Widget page({int rows = 30, bool field = false}) => LargeTitleScaffold(
  title: 'Aufträge',
  fab: FloatingFab(onPressed: () {}),
  tabBar: StaffTabBar(current: StaffTab.orders, onSelect: (_) {}),
  slivers: [
    SliverList.builder(
      itemCount: rows,
      itemBuilder: (_, i) =>
          SizedBox(key: ValueKey('row $i'), height: 60, child: Text('row $i')),
    ),
    if (field) const SliverToBoxAdapter(child: TextField(key: Key('tf'))),
    if (field)
      SliverList.builder(
        itemCount: 10,
        itemBuilder: (_, i) => SizedBox(height: 60, child: Text('s$i')),
      ),
  ],
);

/// Holds the selected tab, like a router would.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var tab = StaffTab.orders;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: StaffTabBar(
        current: tab,
        onSelect: (t) => setState(() => tab = t),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('bar floats: content scrolls under it, last row clears it', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, app(page()));
    final bar = tester.getRect(barGlass());
    final fab = tester.getRect(find.byType(FloatingFab));
    expect(bar.bottom, lessThanOrEqualTo(640 - AppSize.tabBarBottom));
    expect(fab.bottom, lessThanOrEqualTo(bar.top), reason: 'FAB above bar');

    // Some row is painted under the glass (the bar does not take space).
    final under = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('row '),
    );
    final overlaps = under
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .where((r) => r.overlaps(bar));
    expect(overlaps, isNotEmpty);

    // Scrolled to the end, the last row sits above bar and FAB.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final last = tester.getRect(find.byKey(const ValueKey('row 29')));
    expect(last.bottom, lessThanOrEqualTo(bar.top));
    expect(last.bottom, lessThanOrEqualTo(fab.top));
  });

  testWidgets('keyboard hides bar and FAB; focused field stays visible', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, app(page(rows: 6, field: true)));
    expect(find.text('Mehr').hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('tf')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.text('Mehr').hitTestable(), findsNothing);
    expect(find.byType(FloatingFab).hitTestable(), findsNothing);
    final opacities = tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(StaffTabBar),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .map((o) => o.opacity);
    expect(opacities, contains(0));

    final field = tester.getRect(find.byKey(const Key('tf')));
    expect(field.bottom, lessThanOrEqualTo(640 - 300));
    expect(field.top, greaterThan(0));

    // Keyboard closed again: bar is back.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.text('Mehr').hitTestable(), findsOneWidget);
  });

  testWidgets('hiding is instant under reduced motion', (tester) async {
    phone(tester);
    await pumpApp(tester, app(page(), reduceMotion: true));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump();
    expect(find.text('Mehr').hitTestable(), findsNothing);
    final slide = tester.widget<AnimatedSlide>(
      find.ancestor(
        of: find.byType(StaffTabBar),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(slide.duration, Duration.zero);
  });

  testWidgets('GlassCtaBar as bottomBar still rides above the keyboard', (
    tester,
  ) async {
    phone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await pumpApp(
      tester,
      app(
        LargeTitleScaffold(
          title: 'Titel',
          bottomBar: GlassCtaBar(label: 'Weiter', onPressed: () {}),
          slivers: const [SliverToBoxAdapter(child: Text('x'))],
        ),
      ),
    );
    final bar = tester.getRect(find.byType(GlassCtaBar));
    expect(bar.bottom, lessThanOrEqualTo(640 - 300));
    expect(find.text('Weiter').hitTestable(), findsOneWidget);
  });

  testWidgets('active lens slides to the selected tab', (tester) async {
    phone(tester);
    await pumpApp(tester, app(const _Host()));
    final start = lensCenter(tester);
    final more = tester.getCenter(find.text('Mehr'));
    expect(start, lessThan(more.dx));

    await tester.tap(find.text('Mehr'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final mid = lensCenter(tester);
    expect(mid, greaterThan(start));
    expect(mid, lessThan(more.dx), reason: 'still moving');

    await tester.pump(const Duration(milliseconds: 300));
    expect(lensCenter(tester), closeTo(more.dx, 1));
  });

  testWidgets('lens jumps instantly under reduced motion', (tester) async {
    phone(tester);
    await pumpApp(tester, app(const _Host(), reduceMotion: true));
    await tester.tap(find.text('Inventur'));
    await tester.pump();
    await tester.pump();
    expect(
      lensCenter(tester),
      closeTo(tester.getCenter(find.text('Inventur')).dx, 1),
    );
  });

  testWidgets('active tab: white on a dark lens; inactive primary text', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, app(const _Host()));
    final active = tester.widget<Text>(find.text('Aufträge'));
    final inactive = tester.widget<Text>(find.text('Mehr'));
    expect(active.style?.fontWeight, FontWeight.w600);
    expect(active.style?.color, AppColors.textDark);
    expect(inactive.style?.color, AppColors.textLight);
    final lensBox = tester.widget<DecoratedBox>(
      find.descendant(of: lens(), matching: find.byType(DecoratedBox)).first,
    );
    expect((lensBox.decoration as BoxDecoration).color, AppColors.tabLensLight);
    // Lens fills the bar height minus the inset.
    final lensRect = tester.getRect(
      find.descendant(of: lens(), matching: find.byType(DecoratedBox)).first,
    );
    final barRect = tester.getRect(barGlass());
    expect(
      barRect.height - lensRect.height,
      closeTo(2 * AppSize.tabLensInset, 2.5),
    );
    expect(active.style!.fontSize, greaterThanOrEqualTo(10));
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('every tab is at least 44 px and tappable', (tester) async {
    phone(tester);
    await pumpApp(tester, app(const _Host()));
    final tabs = find.descendant(
      of: find.byType(StaffTabBar),
      matching: find.byType(Pressable),
    );
    expect(tabs, findsNWidgets(3));
    for (final e in tabs.evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    }
    await tester.tap(find.text('Inventur'));
    await tester.pump();
    final selected = tester
        .widgetList<Pressable>(tabs)
        .where((p) => p.selected ?? false)
        .map((p) => p.semanticLabel);
    expect(selected, ['Inventur']);
  });

  testWidgets('blur by default, none with reduced transparency', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, app(page()));
    expect(
      find.descendant(
        of: find.byType(StaffTabBar),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final filter = tester.widget<BackdropFilter>(
      find.descendant(
        of: find.byType(StaffTabBar),
        matching: find.byType(BackdropFilter),
      ),
    );
    expect(filter.filter.toString(), contains('${AppSize.liquidBlur}'));

    await pumpApp(tester, app(page(), highContrast: true));
    expect(
      find.descendant(
        of: find.byType(StaffTabBar),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FloatingFab),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360x640, text 1.3, dark=$dark', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          page(),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(barGlass());
      expect(bar.bottom, lessThanOrEqualTo(640));
      expect(bar.left, greaterThanOrEqualTo(AppSize.tabBarSide));
      expect(
        tester.getRect(find.byType(FloatingFab)).bottom,
        lessThanOrEqualTo(bar.top),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('row 29'))).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(FloatingFab)).top),
      );
    });
  }
}
