import 'dart:async';

import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/motion.dart';
import 'package:cocktail_planer/ui/page_transitions.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/glass_surface.dart';
import 'package:cocktail_planer/ui/widgets/app_sheet.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/floating_fab.dart';
import 'package:cocktail_planer/ui/widgets/glass_cta_bar.dart';
import 'package:cocktail_planer/ui/widgets/large_title_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:cocktail_planer/ui/widgets/step_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real German translations, wired like lib/app.dart.
Widget app(
  Widget home, {
  ThemeData? theme,
  bool reduceMotion = false,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  void phone(WidgetTester tester, {double w = 360, double h = 800}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('StepScaffold shows "2 von 5" and the title', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      app(
        StepScaffold(
          step: 2,
          total: 5,
          title: 'Datum',
          onBack: () {},
          bottom: PrimaryButton(label: 'Weiter', onPressed: () {}),
          child: const Text('Inhalt'),
        ),
      ),
    );
    expect(find.text('2 von 5'), findsOneWidget);
    expect(find.text('Datum'), findsOneWidget);
    expect(find.text('Inhalt'), findsOneWidget);
  });

  testWidgets('StepScaffold bottom stays above the keyboard', (tester) async {
    phone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await pumpApp(
      tester,
      app(
        StepScaffold(
          step: 1,
          total: 3,
          title: 'Name',
          bottom: PrimaryButton(label: 'Weiter', onPressed: () {}),
          child: const TextField(),
        ),
      ),
    );
    final r = tester.getRect(find.byType(PrimaryButton));
    expect(r.bottom, lessThanOrEqualTo(800 - 300));
    expect(r.top, greaterThan(0));
  });

  testWidgets(
    'LargeTitleScaffold: CTA above the keyboard, field scrolls clear',
    (tester) async {
      phone(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await pumpApp(
        tester,
        app(
          LargeTitleScaffold(
            title: 'Titel',
            bottomBar: GlassCtaBar(label: 'Weiter', onPressed: () {}),
            slivers: [
              SliverList.builder(
                itemCount: 20,
                itemBuilder: (_, i) => SizedBox(height: 60, child: Text('r$i')),
              ),
              const SliverToBoxAdapter(child: TextField(key: Key('tf'))),
            ],
          ),
        ),
      );
      final bar = tester.getRect(find.byType(GlassCtaBar));
      expect(bar.bottom, lessThanOrEqualTo(500));
      await tester.scrollUntilVisible(
        find.byKey(const Key('tf')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('tf')));
      await tester.pump(const Duration(milliseconds: 400));
      final field = tester.getRect(find.byKey(const Key('tf')));
      expect(field.bottom, lessThanOrEqualTo(bar.top));
      expect(field.top, greaterThan(0));
    },
  );

  testWidgets('LargeTitleScaffold FAB sits bottom-right above the bar', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      app(
        LargeTitleScaffold(
          title: 'Titel',
          fab: FloatingFab(onPressed: () {}),
          tabBar: StaffTabBar(current: StaffTab.orders, onSelect: (_) {}),
          slivers: const [SliverToBoxAdapter(child: Text('x'))],
        ),
      ),
    );
    final fab = tester.getRect(find.byType(FloatingFab));
    final bar = tester.getRect(find.byType(StaffTabBar));
    expect(fab.center.dx, greaterThan(360 / 2));
    expect(fab.right, lessThanOrEqualTo(360 - 14));
    expect(fab.bottom, lessThanOrEqualTo(bar.top));
    expect(fab.center.dy, greaterThan(800 / 2));
  });

  testWidgets(
    'content is capped at 720 px and bars at 520 px on wide screens',
    (tester) async {
      phone(tester, w: 1200, h: 800);
      await pumpApp(
        tester,
        app(
          LargeTitleScaffold(
            title: 'Titel',
            tabBar: StaffTabBar(current: StaffTab.orders, onSelect: (_) {}),
            slivers: [
              SliverToBoxAdapter(
                child: Container(key: const Key('c'), height: 20),
              ),
            ],
          ),
        ),
      );
      final c = tester.getRect(find.byKey(const Key('c')));
      expect(c.width, lessThanOrEqualTo(720));
      expect(c.center.dx, closeTo(600, 1));
      final bar = tester.getRect(find.byType(GlassSurface));
      expect(bar.width, lessThanOrEqualTo(520));
      expect(bar.center.dx, closeTo(600, 1));

      await pumpApp(
        tester,
        app(
          StepScaffold(
            step: 1,
            total: 3,
            title: 'T',
            bottom: Container(key: const Key('b'), height: 44),
            child: Container(key: const Key('c'), height: 20),
          ),
        ),
      );
      expect(
        tester.getRect(find.byKey(const Key('c'))).width,
        lessThanOrEqualTo(720),
      );
      expect(
        tester.getRect(find.byKey(const Key('b'))).width,
        lessThanOrEqualTo(720),
      );
      expect(
        tester.getRect(find.byKey(const Key('b'))).center.dx,
        closeTo(600, 1),
      );

      await pumpApp(
        tester,
        app(
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: GlassCtaBar(label: 'Weiter', onPressed: () {}),
            ),
          ),
        ),
      );
      expect(
        tester.getRect(find.byType(GlassSurface)).width,
        lessThanOrEqualTo(520),
      );

      await pumpApp(
        tester,
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  full: true,
                  builder: (_) => const SizedBox.expand(key: Key('sb')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getRect(find.byKey(const Key('sb'))).width,
        lessThanOrEqualTo(720),
      );
    },
  );

  testWidgets('StepScaffold back calls onBack', (tester) async {
    phone(tester);
    var back = 0;
    await pumpApp(
      tester,
      app(
        StepScaffold(
          step: 2,
          total: 5,
          title: 'x',
          onBack: () => back++,
          bottom: const SizedBox(),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Zurück'));
    expect(back, 1);
  });

  testWidgets('PrimaryButton.dimmed: tappable, disabled look, hint', (
    tester,
  ) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpApp(
      tester,
      app(
        Scaffold(
          body: Center(
            child: PrimaryButton(
              label: 'Weiter',
              dimmed: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PrimaryButton));
    expect(taps, 1, reason: 'dimmed stays tappable');
    // Same fill and label color as a disabled button.
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(PrimaryButton),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    expect(
      (box.decoration as BoxDecoration).color,
      AppPalette.of(tester.element(find.byType(PrimaryButton))).surface,
    );
    final text = tester.widget<Text>(find.text('Weiter'));
    expect(text.style?.color, AppColors.disabledLight);
    expect(
      tester.getSemantics(find.byType(PrimaryButton)),
      matchesSemantics(
        label: 'Weiter',
        hint: 'Pflichtfelder fehlen',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('PrimaryButton without dimmed has no hint', (tester) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      app(
        Scaffold(
          body: Center(
            child: PrimaryButton(label: 'Weiter', onPressed: () {}),
          ),
        ),
      ),
    );
    expect(tester.getSemantics(find.byType(PrimaryButton)).hint, isEmpty);
    final text = tester.widget<Text>(find.text('Weiter'));
    expect(text.style?.color, isNot(AppColors.disabledLight));
    handle.dispose();
  });

  testWidgets('StepScaffold.controller drives the content scroll view', (
    tester,
  ) async {
    phone(tester, h: 640);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      app(
        StepScaffold(
          step: 1,
          total: 5,
          title: 'Titel',
          controller: controller,
          bottom: PrimaryButton(label: 'Weiter', onPressed: () {}),
          child: Column(
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 60, child: Text('Zeile $i')),
              const TextField(key: Key('far')),
            ],
          ),
        ),
      ),
    );
    expect(controller.hasClients, isTrue);
    expect(controller.offset, 0);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('Zeile 0').hitTestable(), findsNothing);
    controller.jumpTo(0);
    await tester.pump();
    expect(find.text('Zeile 0').hitTestable(), findsOneWidget);
    // Scrolling to a field through its context uses the same scroll view.
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('far'))),
    );
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    expect(
      tester.getRect(find.byKey(const Key('far'))).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(PrimaryButton)).top),
    );
  });

  testWidgets('showConfirmSheet confirmAction keeps the sheet open on '
      'failure and retries', (tester) async {
    phone(tester);
    bool? result;
    var calls = 0;
    await pumpApp(
      tester,
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showConfirmSheet(
                context,
                title: 'Loeschen?',
                confirmLabel: 'Ja',
                destructive: true,
                errorText: 'Hat nicht geklappt',
                confirmAction: () async {
                  calls++;
                  if (calls == 1) throw StateError('boom');
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Ja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Failed: still open, inline error, button now says retry.
    expect(result, isNull);
    expect(find.text('Loeschen?'), findsOneWidget);
    expect(find.text('Hat nicht geklappt'), findsOneWidget);
    expect(find.text('Ja'), findsNothing);
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 2);
    expect(result, isTrue);
    expect(find.text('Loeschen?'), findsNothing);
  });

  testWidgets('showConfirmSheet is not dismissible while its action runs', (
    tester,
  ) async {
    phone(tester);
    bool? result;
    var fail = false;
    var calls = 0;
    var gate = Completer<void>();
    await pumpApp(
      tester,
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showConfirmSheet(
                context,
                title: 'Loeschen?',
                confirmLabel: 'Ja',
                errorText: 'Hat nicht geklappt',
                confirmAction: () async {
                  calls++;
                  await gate.future;
                  if (fail) throw StateError('boom');
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('open'));
    await settle();
    await tester.tap(find.text('Ja'));
    await settle();
    expect(calls, 1);

    // Barrier tap.
    await tester.tapAt(const Offset(180, 40));
    await settle();
    expect(find.text('Loeschen?'), findsOneWidget);
    // Escape.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    expect(find.text('Loeschen?'), findsOneWidget);
    // Drag the handle far down.
    await tester.fling(
      find.byKey(const Key('sheet-handle')),
      const Offset(0, 400),
      2000,
    );
    await settle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Loeschen?'), findsOneWidget);
    expect(result, isNull);

    // Failure: dismissible again, inline error and retry.
    fail = true;
    gate.complete();
    await settle();
    expect(find.text('Hat nicht geklappt'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    expect(find.text('Loeschen?'), findsNothing);
    expect(result, isFalse);

    // Success closes and returns true.
    fail = false;
    gate = Completer<void>();
    await tester.tap(find.text('open'));
    await settle();
    await tester.tap(find.text('Ja'));
    await settle();
    expect(find.text('Loeschen?'), findsOneWidget);
    gate.complete();
    await settle();
    expect(find.text('Loeschen?'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('showConfirmSheet returns true and false', (tester) async {
    phone(tester);
    bool? result;
    await pumpApp(
      tester,
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showConfirmSheet(
                context,
                title: 'Loeschen?',
                body: 'Wirklich',
                confirmLabel: 'Ja',
                destructive: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Loeschen?'), findsOneWidget);
    await tester.tap(find.text('Ja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isTrue);
    expect(find.text('Loeschen?'), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Abbrechen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isFalse);

    // Dismissed by the barrier also means false.
    result = null;
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(180, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isFalse);
  });

  testWidgets('sheet moves in and out, or fades with reduced motion', (
    tester,
  ) async {
    phone(tester);
    for (final reduced in [false, true]) {
      await pumpApp(
        tester,
        app(
          reduceMotion: reduced,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => const SizedBox(height: 100, child: Text('S')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 100));
      final slides = find.descendant(
        of: find.byType(Overlay),
        matching: find.byType(SlideTransition),
      );
      final inFlight = tester.getTopLeft(find.text('S')).dy;
      await tester.pump(const Duration(milliseconds: 400));
      final settled = tester.getTopLeft(find.text('S')).dy;
      if (reduced) {
        expect(inFlight, settled, reason: 'fade does not move');
      } else {
        expect(inFlight, greaterThan(settled));
        expect(slides, findsWidgets);
      }
      await tester.tapAt(const Offset(180, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('S'), findsNothing);
    }
  });

  testWidgets('sheet with a field respects the keyboard', (tester) async {
    phone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await pumpApp(
      tester,
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context,
                builder: (_) => const TextField(key: Key('f')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getRect(find.byKey(const Key('f'))).bottom,
      lessThanOrEqualTo(500),
    );
  });

  testWidgets('StaffTabBar marks the active tab and selects', (tester) async {
    phone(tester);
    StaffTab? picked;
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      app(
        Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: StaffTabBar(
                  current: StaffTab.inventory,
                  onSelect: (t) => picked = t,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Inventur')),
      matchesSemantics(
        label: 'Inventur',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Aufträge')),
      matchesSemantics(
        label: 'Aufträge',
        isButton: true,
        isSelected: false,
        hasSelectedState: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text('Mehr'));
    expect(picked, StaffTab.more);
    final r = tester.getRect(find.byType(StaffTabBar));
    expect(r.height, greaterThanOrEqualTo(46));
    semantics.dispose();
  });

  testWidgets('ErrorState calls onRetry, EmptyState shows action', (
    tester,
  ) async {
    phone(tester);
    var n = 0;
    await pumpApp(
      tester,
      app(
        Scaffold(
          body: Column(
            children: [
              Expanded(
                child: ErrorState(message: 'Fehler', onRetry: () => n++),
              ),
              Expanded(
                child: EmptyState(
                  icon: Icons.inbox,
                  title: 'Leer',
                  body: 'Nichts da',
                  action: PrimaryButton(label: 'Neu', onPressed: () {}),
                ),
              ),
              const Expanded(child: LoadingState()),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Fehler'), findsOneWidget);
    await tester.tap(find.text('Erneut versuchen'));
    expect(n, 1);
    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Neu'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LargeTitleScaffold collapses the title into the top bar', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      app(
        LargeTitleScaffold(
          title: 'Übersicht',
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          ],
          fab: FloatingFab(onPressed: () {}),
          tabBar: StaffTabBar(current: StaffTab.orders, onSelect: (_) {}),
          slivers: [
            SliverList.builder(
              itemCount: 40,
              itemBuilder: (_, i) =>
                  SizedBox(height: 60, child: Text('row $i')),
            ),
          ],
        ),
      ),
    );
    double smallTitleOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Übersicht').last,
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(smallTitleOpacity(), 0);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(smallTitleOpacity(), 1);
    expect(tester.getTopLeft(find.text('Übersicht').last).dy, lessThan(60));
    expect(find.byType(FloatingFab), findsOneWidget);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets(
      'LargeTitleScaffold leading: expanded and collapsed, scale $scale',
      (tester) async {
        phone(tester);
        var taps = 0;
        await pumpApp(
          tester,
          app(
            textScale: scale,
            LargeTitleScaffold(
              title: 'Meine Anfragen',
              leading: SizedBox(
                key: const ValueKey('lead'),
                width: 44,
                height: 44,
                child: GestureDetector(onTap: () => taps++),
              ),
              actions: [
                SizedBox(
                  key: const ValueKey('act'),
                  width: 44,
                  height: 44,
                  child: GestureDetector(onTap: () {}),
                ),
              ],
              slivers: [
                SliverList.builder(
                  itemCount: 40,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 60, child: Text('row $i')),
                ),
              ],
            ),
          ),
        );
        Finder lead() => find.byKey(const ValueKey('lead'));
        expect(lead(), findsOneWidget);
        expect(tester.getSize(lead()).height, greaterThanOrEqualTo(44));
        final leadLeft = tester.getTopLeft(lead()).dx;
        expect(leadLeft, lessThan(40));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('act'))).dx,
          greaterThan(360 - 80),
        );
        await tester.tap(lead());
        expect(taps, 1);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(lead(), findsOneWidget);
        expect(tester.getTopLeft(lead()).dx, leadLeft);
        final title = tester.getRect(find.text('Meine Anfragen').last);
        expect(title.left, greaterThanOrEqualTo(tester.getRect(lead()).right));
        expect(
          title.right,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(const ValueKey('act'))).dx,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('FloatingFab is a 44 px tap target and fires', (tester) async {
    phone(tester);
    var n = 0;
    await pumpApp(
      tester,
      app(
        Scaffold(
          body: Center(child: FloatingFab(onPressed: () => n++)),
        ),
      ),
    );
    final r = tester.getRect(find.byType(FloatingFab));
    expect(r.width, greaterThanOrEqualTo(44));
    await tester.tap(find.byType(FloatingFab));
    expect(n, 1);
  });

  Widget pushApp({required bool reduced}) => app(
    reduceMotion: reduced,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('next')),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    ),
  );

  testWidgets('reduced-motion page transition fades instead of sliding', (
    tester,
  ) async {
    phone(tester);
    for (final reduced in [false, true]) {
      await pumpApp(tester, pushApp(reduced: reduced));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final dx = tester.getTopLeft(find.text('next')).dx;
      final fades = find.ancestor(
        of: find.text('next'),
        matching: find.byType(FadeTransition),
      );
      if (reduced) {
        expect(dx, 0, reason: 'no slide');
        final opacity = tester
            .widgetList<FadeTransition>(fades)
            .map((f) => f.opacity.value)
            .reduce((a, b) => a < b ? a : b);
        expect(opacity, lessThan(1), reason: 'still fading in');
      } else {
        expect(dx, greaterThan(0), reason: 'slides');
      }
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('swipe-back still works with reduced motion', (tester) async {
    phone(tester);
    await pumpApp(tester, pushApp(reduced: true));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(2, 300), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('next'), findsNothing);
  });

  test('page transition builder uses the app page duration', () {
    expect(
      const AppPageTransitionsBuilder().transitionDuration,
      AppMotion.page,
    );
  });

  // --- sheet contracts ---
  Widget sheetHost(
    Widget Function(BuildContext) builder, {
    bool full = false,
    bool? scrollable,
    bool reduced = false,
  }) => app(
    reduceMotion: reduced,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showAppSheet<void>(
            context,
            full: full,
            scrollable: scrollable,
            builder: builder,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('full sheet gives a ListView child bounded height', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      sheetHost(
        full: true,
        (_) =>
            ListView(children: [for (var i = 0; i < 50; i++) Text('item $i')]),
      ),
    );
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('item 0'), findsOneWidget);
    final list = tester.getRect(find.byType(ListView));
    expect(list.height, greaterThan(400));
    expect(list.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('full sheet lets an Expanded Column pin its button', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      sheetHost(
        full: true,
        (_) => Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            PrimaryButton(label: 'Fertig', onPressed: () {}),
          ],
        ),
      ),
    );
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byType(PrimaryButton)).bottom, greaterThan(700));
  });

  testWidgets('sheet strips the keyboard inset for its content', (
    tester,
  ) async {
    phone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    double? inner;
    await pumpApp(
      tester,
      sheetHost((c) {
        inner = MediaQuery.viewInsetsOf(c).bottom;
        return Column(
          children: [
            const TextField(key: Key('f')),
            PrimaryButton(label: 'Speichern', onPressed: () {}),
          ],
        );
      }),
    );
    await openSheet(tester);
    expect(inner, 0);
    expect(
      tester.getRect(find.byType(PrimaryButton)).bottom,
      lessThanOrEqualTo(500),
    );
    expect(
      tester.getRect(find.byKey(const Key('f'))).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(PrimaryButton)).top),
    );
  });

  testWidgets('Escape closes a sheet', (tester) async {
    phone(tester);
    await pumpApp(tester, sheetHost((_) => const Text('S')));
    await openSheet(tester);
    expect(find.text('S'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('S'), findsNothing);
  });

  testWidgets('Navigator.pop from outside closes a sheet', (tester) async {
    phone(tester);
    await pumpApp(tester, sheetHost((_) => const Text('S')));
    await openSheet(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('S'), findsNothing);
  });

  testWidgets('sheet announces itself as a route', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, sheetHost((_) => const Text('S')));
    await openSheet(tester);
    expect(find.bySemanticsLabel('Dialog'), findsWidgets);
    semantics.dispose();
  });

  testWidgets(
    'dragging the handle down past a third closes, less springs back',
    (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        sheetHost((_) => const SizedBox(height: 300, child: Text('S'))),
      );
      await openSheet(tester);
      final top = tester.getTopLeft(find.text('S')).dy;
      await tester.drag(
        find.byKey(const Key('sheet-handle')),
        const Offset(0, 20),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('S'), findsOneWidget);
      expect(tester.getTopLeft(find.text('S')).dy, closeTo(top, 0.5));

      await tester.drag(
        find.byKey(const Key('sheet-handle')),
        const Offset(0, 200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('S'), findsNothing);
    },
  );

  testWidgets('handle drag under reduced motion restores without spring', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      sheetHost(
        reduced: true,
        (_) => const SizedBox(height: 300, child: Text('S')),
      ),
    );
    await openSheet(tester);
    final top = tester.getTopLeft(find.text('S')).dy;
    await tester.drag(
      find.byKey(const Key('sheet-handle')),
      const Offset(0, 20),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.text('S')).dy, closeTo(top, 0.5));
  });

  testWidgets('tapped field stays above the CTA once the keyboard opens', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      app(
        LargeTitleScaffold(
          title: 'Titel',
          bottomBar: GlassCtaBar(label: 'Weiter', onPressed: () {}),
          slivers: [
            SliverList.builder(
              itemCount: 8,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('r$i')),
            ),
            const SliverToBoxAdapter(child: TextField(key: Key('tf'))),
            SliverList.builder(
              itemCount: 20,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('s$i')),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('tf')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(const Key('tf')));
    final bar = tester.getRect(find.byType(GlassCtaBar));
    expect(bar.bottom, lessThanOrEqualTo(500));
    expect(field.bottom, lessThanOrEqualTo(bar.top));
    expect(field.top, greaterThan(0));
  });

  testWidgets('a blocked pop springs the dragged sheet back', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      sheetHost(
        (_) => const PopScope(
          canPop: false,
          child: SizedBox(height: 300, child: Text('S')),
        ),
      ),
    );
    await openSheet(tester);
    final top = tester.getTopLeft(find.text('S')).dy;
    await tester.drag(
      find.byKey(const Key('sheet-handle')),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('S'), findsOneWidget);
    expect(tester.getTopLeft(find.text('S')).dy, closeTo(top, 0.5));
  });

  testWidgets('ending a drag after the sheet closed pops nothing else', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (c) => Scaffold(
                    body: TextButton(
                      onPressed: () => showAppSheet<void>(
                        c,
                        builder: (_) =>
                            const SizedBox(height: 300, child: Text('S')),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
              child: const Text('page'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('page'));
    await tester.pumpAndSettle();
    await openSheet(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sheet-handle'))),
    );
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(const Duration(milliseconds: 16));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('S'), findsNothing);
    expect(find.text('open'), findsOneWidget, reason: 'page below stays');
  });

  testWidgets('end spacer leaves room for the FAB above the bar', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(
      tester,
      app(
        LargeTitleScaffold(
          title: 'Titel',
          fab: FloatingFab(onPressed: () {}),
          tabBar: StaffTabBar(current: StaffTab.orders, onSelect: (_) {}),
          slivers: [
            SliverList.builder(
              itemCount: 30,
              itemBuilder: (_, i) => SizedBox(
                key: i == 29 ? const Key('last') : null,
                height: 60,
                child: Text('r$i'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final last = tester.getRect(find.byKey(const Key('last')));
    expect(
      last.bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(FloatingFab)).top),
    );
    expect(
      last.bottom,
      lessThanOrEqualTo(
        tester
            .getRect(
              find.descendant(
                of: find.byType(StaffTabBar),
                matching: find.byType(GlassSurface),
              ),
            )
            .top,
      ),
      reason: 'clear of the floating tab bar too',
    );
  });

  testWidgets('states work inside SliverFillRemaining', (tester) async {
    phone(tester);
    await pumpApp(
      tester,
      app(
        Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: Icons.inbox, title: 'Leer'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Leer'), findsOneWidget);
  });

  testWidgets('StepScaffold announces progress once', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      app(
        StepScaffold(
          step: 2,
          total: 5,
          title: 'T',
          bottom: const SizedBox(),
          child: const SizedBox(),
        ),
      ),
    );
    expect(find.bySemanticsLabel('2 von 5'), findsOneWidget);
    semantics.dispose();
  });

  test('large title token is 24 px', () {
    expect(AppText.largeTitle.fontSize, 24);
  });

  group('no overflow at 360 px, text 1.3', () {
    final cases = <String, Widget Function()>{
      'StepScaffold': () => StepScaffold(
        step: 2,
        total: 5,
        title: 'Ein sehr langer Titel fuer den Schritt mit mehr Text',
        onBack: () {},
        bottom: PrimaryButton(label: 'Weiter zur Uebersicht', onPressed: () {}),
        child: const Text('Inhalt'),
      ),
      'LargeTitleScaffold': () => LargeTitleScaffold(
        title: 'Ein sehr langer Titel fuer die Uebersicht',
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add))],
        bottomBar: GlassCtaBar(
          label: 'Angebot erstellen und senden',
          badge: '12 Positionen',
          onPressed: () {},
        ),
        fab: FloatingFab(onPressed: () {}),
        slivers: const [SliverToBoxAdapter(child: Text('x'))],
      ),
      'LargeTitleScaffold+tabBar': () => LargeTitleScaffold(
        title: 'Ein sehr langer Titel fuer die Uebersicht',
        tabBar: StaffTabBar(current: StaffTab.inventory, onSelect: (_) {}),
        fab: FloatingFab(onPressed: () {}),
        slivers: [
          SliverList.builder(
            itemCount: 30,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('r$i')),
          ),
        ],
      ),
      'StaffTabBar': () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: StaffTabBar(current: StaffTab.orders, onSelect: (_) {}),
        ),
      ),
      'States': () => Scaffold(
        body: Column(
          children: [
            Expanded(
              child: EmptyState(
                icon: Icons.inbox,
                title: 'Noch keine Auftraege vorhanden hier',
                body: 'Lege den ersten Auftrag an und starte los mit allem',
                action: PrimaryButton(
                  label: 'Auftrag anlegen',
                  onPressed: () {},
                ),
              ),
            ),
            Expanded(
              child: ErrorState(
                message: 'Daten konnten nicht geladen werden, bitte spaeter',
                onRetry: () {},
              ),
            ),
          ],
        ),
      ),
    };
    for (final dark in [false, true]) {
      for (final width in [360.0, 280.0]) {
        for (final e in cases.entries) {
          testWidgets('${e.key} w=$width dark=$dark', (tester) async {
            phone(tester, w: width, h: 640);
            await pumpApp(
              tester,
              app(
                e.value(),
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                textScale: 1.3,
              ),
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    for (final dark in [false, true]) {
      testWidgets('sheets w=280 dark=$dark', (tester) async {
        phone(tester, w: 280, h: 640);
        await pumpApp(
          tester,
          app(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            textScale: 1.3,
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showConfirmSheet(
                    context,
                    title: 'Auftrag wirklich endgueltig loeschen?',
                    body:
                        'Das kann nicht rueckgaengig gemacht werden. Alles geht verloren.',
                    confirmLabel: 'Endgueltig loeschen',
                    destructive: true,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
