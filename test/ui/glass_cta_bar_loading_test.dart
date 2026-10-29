import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/glass_cta_bar.dart';
import 'package:cocktail_planer/ui/widgets/glass_surface.dart';
import 'package:cocktail_planer/ui/widgets/large_title_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({required bool loading, required VoidCallback onTap}) =>
    MaterialApp(
      theme: AppTheme.light(),
      home: LargeTitleScaffold(
        title: 'Titel',
        bottomBar: GlassCtaBar(
          label: 'Weiter',
          loading: loading,
          onPressed: onTap,
        ),
        slivers: const [SliverToBoxAdapter(child: SizedBox(height: 50))],
      ),
    );

void main() {
  testWidgets('loading shows a spinner, blocks taps and keeps the width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    await tester.pumpWidget(host(loading: false, onTap: () => taps++));
    final before = tester.getSize(find.byType(GlassCtaBar));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Weiter'));
    expect(taps, 1);

    await tester.pumpWidget(host(loading: true, onTap: () => taps++));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(GlassCtaBar)), before);
    await tester.tap(find.text('Weiter'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  Widget sized(
    Size size, {
    bool dark = false,
    String? badge,
    double scale = 1,
  }) => MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: LargeTitleScaffold(
        title: 'Titel',
        bottomBar: GlassCtaBar(
          label: 'Anfrage starten',
          badge: badge,
          onPressed: () {},
        ),
        slivers: const [SliverToBoxAdapter(child: SizedBox(height: 50))],
      ),
    ),
  );

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('primary button fills the glass capsule at 390 px', (
    tester,
  ) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(sized(const Size(390, 844)));
    final bar = tester.getRect(find.byType(GlassCtaBar));
    final btn = tester.getRect(find.byType(PrimaryButton));
    expect(btn.width, greaterThanOrEqualTo(bar.width - 16 - 2 * 14));
    expect(btn.height, inInclusiveRange(44, 56));
    expect(tester.getCenter(find.text('Anfrage starten')).dx, closeTo(195, 1));
  });

  testWidgets('bar is capped and centered at 1200 px, button fills it', (
    tester,
  ) async {
    await setSize(tester, const Size(1200, 800));
    await tester.pumpWidget(sized(const Size(1200, 800)));
    final glass = tester.getRect(find.byType(GlassSurface));
    final btn = tester.getRect(find.byType(PrimaryButton));
    expect(glass.width, AppSize.maxBarWidth);
    expect(glass.center.dx, closeTo(600, 1));
    expect(btn.width, greaterThanOrEqualTo(glass.width - 16));
  });

  testWidgets('badge sits inside the button', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(sized(const Size(390, 844), badge: '12'));
    final btn = tester.getRect(find.byType(PrimaryButton));
    expect(btn.contains(tester.getCenter(find.text('12'))), isTrue);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360x640, 1.3x, dark=$dark', (tester) async {
      await setSize(tester, const Size(360, 640));
      await tester.pumpWidget(
        sized(
          const Size(360, 640),
          dark: dark,
          badge: '12 Positionen',
          scale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(GlassCtaBar));
      final btn = tester.getRect(find.byType(PrimaryButton));
      expect(btn.width, greaterThanOrEqualTo(bar.width - 16 - 2 * 14));
    });
  }
}
