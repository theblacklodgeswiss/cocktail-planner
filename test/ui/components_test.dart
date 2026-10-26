import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/date_tile.dart';
import 'package:cocktail_planer/ui/widgets/floating_card.dart';
import 'package:cocktail_planer/ui/widgets/glass_surface.dart';
import 'package:cocktail_planer/ui/widgets/hero_card.dart';
import 'package:cocktail_planer/ui/widgets/pill_filter.dart';
import 'package:cocktail_planer/ui/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Widget child, {
  ThemeData? theme,
  MediaQueryData? media,
  double width = 800,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: (media ?? MediaQuery.of(context)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Every widget below must survive 280 px and 1.3x text without overflow.
final narrow = <String, Widget Function()>{
  'FloatingCard': () => FloatingCard(
    onTap: () {},
    child: const Text('Hochzeit Mueller mit sehr langem Namen und mehr'),
  ),
  'HeroCard': () => HeroCard(
    kicker: 'NAECHSTER TERMIN',
    title: 'Hochzeit Mueller mit sehr langem Namen',
    meta: '80 Gaeste - Koeln - Samstag Abend',
    trailing: const Text('12'),
    onTap: () {},
  ),
  'DateTile': () => DateTile(DateTime(2026, 6, 14)),
  'StatusDot': () => const StatusDot(StatusKind.accepted),
  'PillFilter': () => PillFilter<int>(
    options: const [
      PillOption(0, 'Alle', count: 12),
      PillOption(1, 'Offen', count: 3),
      PillOption(2, 'Angenommen', count: 7),
    ],
    value: 0,
    onChanged: (_) {},
  ),
  'GlassSurface': () => const GlassSurface(
    child: Padding(
      padding: EdgeInsets.all(8),
      child: Text('Ein ziemlich langer Text in Glas'),
    ),
  ),
  'PrimaryButton': () => PrimaryButton(
    label: 'Einkaufsliste generieren und teilen',
    onPressed: () {},
  ),
  'SecondaryButton': () => SecondaryButton(
    label: 'Einkaufsliste generieren und teilen',
    onPressed: () {},
  ),
  'TextAction': () => TextAction(
    label: 'Einkaufsliste generieren und teilen',
    onPressed: () {},
  ),
};

void main() {
  testWidgets('StatusDot: accepted is gold, offer is grey', (tester) async {
    Color dotColor() {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(StatusDot),
          matching: find.byKey(const ValueKey('status-dot')),
        ),
      );
      return (box.decoration as BoxDecoration).color!;
    }

    await tester.pumpWidget(
      host(const StatusDot(StatusKind.accepted, showLabel: false)),
    );
    expect(dotColor(), AppColors.goldDotOnWhite);
    await tester.pumpWidget(
      host(const StatusDot(StatusKind.offer, showLabel: false)),
    );
    expect(dotColor(), AppColors.statusOffer);
  });

  testWidgets('StatusDot shows its status key as label', (tester) async {
    await tester.pumpWidget(host(const StatusDot(StatusKind.completed)));
    expect(find.text('status.completed'), findsOneWidget);
  });

  testWidgets('PillFilter calls onChanged with tapped value', (tester) async {
    int? got;
    await tester.pumpWidget(
      host(
        PillFilter<int>(
          options: const [
            PillOption(0, 'Alle'),
            PillOption(1, 'Offen', count: 3),
          ],
          value: 0,
          onChanged: (v) => got = v,
        ),
      ),
    );
    await tester.tap(find.text('Offen 3'));
    expect(got, 1);
  });

  testWidgets('PrimaryButton(loading) does not call onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(PrimaryButton(label: 'Los', loading: true, onPressed: () => taps++)),
    );
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);

    await tester.pumpWidget(
      host(PrimaryButton(label: 'Los', onPressed: () => taps++)),
    );
    await tester.tap(find.text('Los'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
  });

  testWidgets('buttons are at least 44 px tall', (tester) async {
    await tester.pumpWidget(
      host(PrimaryButton(label: 'Los', onPressed: () {})),
    );
    expect(
      tester.getSize(find.byType(PrimaryButton)).height,
      greaterThanOrEqualTo(44),
    );
    await tester.pumpWidget(host(TextAction(label: 'Los', onPressed: () {})));
    expect(
      tester.getSize(find.byType(TextAction)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets(
    'GlassSurface blurs normally, drops BackdropFilter on highContrast',
    (tester) async {
      await tester.pumpWidget(host(const GlassSurface(child: Text('x'))));
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.pumpWidget(
        host(
          const GlassSurface(child: Text('x')),
          media: const MediaQueryData(highContrast: true),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets('DateTile shows day and month (en default: JUN)', (tester) async {
    await tester.pumpWidget(host(DateTile(DateTime(2026, 6, 14))));
    expect(find.text('14'), findsOneWidget);
    expect(find.text('JUN'), findsOneWidget);
  });

  testWidgets('DateTile uses German month names for de locale', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('de'),
            child: DateTile(DateTime(2026, 3, 5)),
          ),
        ),
      ),
    );
    expect(find.text('05'), findsOneWidget);
    expect(find.text('MÄR'), findsOneWidget);
  });

  testWidgets('HeroCard shows kicker, title, meta and trailing', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const HeroCard(
          kicker: 'K',
          title: 'T',
          meta: 'M',
          trailing: Text('12'),
        ),
      ),
    );
    for (final t in ['K', 'T', 'M', '12']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  for (final dark in [false, true]) {
    for (final e in narrow.entries) {
      testWidgets('${e.key} no overflow at 280px, text 1.3, dark=$dark', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            e.value(),
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            media: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            width: 280,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
