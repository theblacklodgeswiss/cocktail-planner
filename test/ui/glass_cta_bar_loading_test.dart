import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/glass_cta_bar.dart';
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
}
