import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/floating_fab.dart';
import 'package:cocktail_planer/ui/widgets/glass_cta_bar.dart';
import 'package:cocktail_planer/ui/widgets/staff_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bare MaterialApp home without a Scaffold/Material, like the router's
/// shell builder: the shell's chrome sits above the pages' Scaffolds, so the
/// only DefaultTextStyle above it is MaterialApp's debug error style (yellow
/// double underline).
Widget bare(Widget home, {ThemeData? theme}) => EasyLocalization(
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
      home: home,
    ),
  ),
);

/// Every painted text below [of] resolves to no decoration.
void expectNoDecoration(WidgetTester tester, Finder of) {
  final texts = tester.widgetList<RichText>(
    find.descendant(of: of, matching: find.byType(RichText)),
  );
  expect(texts, isNotEmpty);
  for (final t in texts) {
    final deco = t.text.style?.decoration;
    expect(
      deco == null || deco == TextDecoration.none,
      isTrue,
      reason: '"${t.text.toPlainText()}" is decorated with $deco',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(WidgetTester tester, Widget w) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(w);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final dark in [false, true]) {
    testWidgets('shell tab labels are not underlined (dark: $dark)', (
      tester,
    ) async {
      await pump(
        tester,
        bare(
          StaffShell(
            current: StaffTab.inventory,
            onSwitch: (_) {},
            onNewOrder: () {},
            child: const SizedBox.expand(),
          ),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
        ),
      );
      expect(find.text('Inventur'), findsOneWidget);
      expectNoDecoration(tester, find.byType(StaffTabBar));
    });
  }

  testWidgets('FAB and glass CTA bar text is not underlined without Material', (
    tester,
  ) async {
    await pump(
      tester,
      bare(
        Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: FloatingFab(onPressed: () {}, icon: Icons.add),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassCtaBar(label: 'Weiter', onPressed: () {}),
            ),
          ],
        ),
      ),
    );
    expectNoDecoration(tester, find.byType(GlassCtaBar));
    // The icon glyph is a RichText too.
    expectNoDecoration(tester, find.byType(FloatingFab));
  });
}
