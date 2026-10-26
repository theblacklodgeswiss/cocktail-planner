import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/app_sheet.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/floating_fab.dart';
import 'package:cocktail_planer/ui/widgets/glass_cta_bar.dart';
import 'package:cocktail_planer/ui/widgets/large_title_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:cocktail_planer/ui/widgets/step_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  testWidgets('GlassCtaBar sits above the keyboard', (tester) async {
    phone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await pumpApp(
      tester,
      app(
        Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: GlassCtaBar(
                  label: 'Weiter',
                  badge: '3',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byType(GlassCtaBar)).bottom,
      lessThanOrEqualTo(500),
    );
    expect(find.text('3'), findsOneWidget);
  });

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
      tester.getSemantics(find.bySemanticsLabel('Bestand')),
      matchesSemantics(
        label: 'Bestand',
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
          bottomBar: StaffTabBar(current: StaffTab.orders, onSelect: (_) {}),
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

  testWidgets('reduced-motion page transition is a fade', (tester) async {
    phone(tester);
    for (final reduced in [false, true]) {
      await pumpApp(
        tester,
        app(
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
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(CupertinoPageTransition),
        reduced ? findsNothing : findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
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
