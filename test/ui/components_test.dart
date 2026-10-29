import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/date_tile.dart';
import 'package:cocktail_planer/ui/widgets/floating_card.dart';
import 'package:cocktail_planer/ui/widgets/glass_surface.dart';
import 'package:cocktail_planer/ui/widgets/hero_card.dart';
import 'package:cocktail_planer/ui/widgets/pill_filter.dart';
import 'package:cocktail_planer/ui/widgets/pressable.dart';
import 'package:cocktail_planer/ui/widgets/status_dot.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Widget child, {
  ThemeData? theme,
  MediaQueryData? media,
  double? textScale,
  double width = 800,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Builder(
      builder: (context) {
        var data = media ?? MediaQuery.of(context);
        if (textScale != null) {
          data = data.copyWith(textScaler: TextScaler.linear(textScale));
        }
        return MediaQuery(
          data: data,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        );
      },
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

  group('press feedback', () {
    Widget button(VoidCallback? onPressed) =>
        PrimaryButton(label: 'Los', onPressed: onPressed);

    testWidgets(
      'scale applies on pointer down without delay, cancel releases',
      (tester) async {
        await tester.pumpWidget(host(button(() {})));
        double scale() => tester
            .widget<AnimatedScale>(
              find.descendant(
                of: find.byType(PrimaryButton),
                matching: find.byType(AnimatedScale),
              ),
            )
            .scale;
        expect(scale(), 1);
        final g = await tester.startGesture(tester.getCenter(find.text('Los')));
        await tester.pump();
        expect(scale(), AppSize.pressScale);
        await g.cancel();
        await tester.pump();
        expect(scale(), 1);
      },
    );

    testWidgets('dragging away releases the pressed state', (tester) async {
      await tester.pumpWidget(host(button(() {})));
      double scale() => tester
          .widget<AnimatedScale>(
            find.descendant(
              of: find.byType(PrimaryButton),
              matching: find.byType(AnimatedScale),
            ),
          )
          .scale;
      final g = await tester.startGesture(tester.getCenter(find.text('Los')));
      await tester.pump();
      await g.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(scale(), 1);
      await g.up();
    });

    testWidgets('under disableAnimations it dims instead of scaling', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          button(() {}),
          media: const MediaQueryData(disableAnimations: true),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(AnimatedScale),
        ),
        findsNothing,
      );
      final g = await tester.startGesture(tester.getCenter(find.text('Los')));
      await tester.pump();
      final o = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(o.opacity, AppSize.pressedOpacity);
      await g.up();
    });
  });

  group('scroll drag', () {
    for (final c in <String, Widget Function()>{
      'PrimaryButton': () => PrimaryButton(label: 'Los', onPressed: () {}),
      'FloatingCard': () =>
          FloatingCard(onTap: () {}, child: const Text('Los')),
    }.entries) {
      testWidgets('${c.key} unpresses once a scroll moves past touch slop', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(ListView(children: [c.value(), const SizedBox(height: 2000)])),
        );
        double scale() => tester
            .widget<AnimatedScale>(
              find.descendant(
                of: find.byType(Pressable),
                matching: find.byType(AnimatedScale),
              ),
            )
            .scale;
        final g = await tester.startGesture(tester.getCenter(find.text('Los')));
        await tester.pump();
        expect(scale(), AppSize.pressScale);
        await g.moveBy(const Offset(0, 5));
        await tester.pump();
        expect(scale(), AppSize.pressScale);
        await g.moveBy(const Offset(0, 40));
        await tester.pump();
        expect(scale(), 1);
        await g.up();
      });
    }
  });

  testWidgets('focus ring wrapper keeps child state across focus changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(Pressable(onTap: () {}, child: const _Counter())),
    );
    await tester.tap(find.byType(_Counter));
    await tester.pump();
    final before = tester.state<_CounterState>(find.byType(_Counter));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.state<_CounterState>(find.byType(_Counter)), same(before));
  });

  testWidgets('DateTile label stays >= 10 px at text scale below 1', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(Align(child: DateTile(DateTime(2026, 6, 14))), textScale: 0.8),
    );
    final p = tester.renderObject<RenderParagraph>(find.text('JUN'));
    expect(p.textScaler.scale(10), greaterThanOrEqualTo(10));
  });

  group('keyboard', () {
    testWidgets('Enter on focused PrimaryButton calls onPressed once', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(PrimaryButton(label: 'Los', onPressed: () => taps++)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('loading and disabled buttons ignore Enter', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              PrimaryButton(label: 'A', loading: true, onPressed: () => taps++),
              const PrimaryButton(label: 'B', onPressed: null),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('focused button shows a focus ring', (tester) async {
      await tester.pumpWidget(
        host(PrimaryButton(label: 'Los', onPressed: () {})),
      );
      bool ring() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(PrimaryButton),
                          matching: find.byKey(const ValueKey('focus-ring')),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .border !=
          null;
      expect(ring(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring(), isTrue);
    });
  });

  group('dark edges', () {
    BoxDecoration deco(WidgetTester tester, Type t) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(t),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.borderRadius != null);

    for (final c in <String, (Type, Widget)>{
      'FloatingCard': (FloatingCard, const FloatingCard(child: Text('x'))),
      'HeroCard': (HeroCard, const HeroCard(title: 'x')),
    }.entries) {
      testWidgets('${c.key}: hairline border in dark only', (tester) async {
        await tester.pumpWidget(host(c.value.$2, theme: AppTheme.dark()));
        expect(deco(tester, c.value.$1).border, isNotNull);
        await tester.pumpWidget(host(c.value.$2));
        await tester.pumpAndSettle();
        expect(deco(tester, c.value.$1).border, isNull);
      });
    }

    testWidgets('StatusDot colors in dark mode', (tester) async {
      Color dot() =>
          (tester
                      .widget<DecoratedBox>(
                        find.byKey(const ValueKey('status-dot')),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      await tester.pumpWidget(
        host(
          const StatusDot(StatusKind.accepted, showLabel: false),
          theme: AppTheme.dark(),
        ),
      );
      expect(dot(), AppColors.goldOnBlack);
      await tester.pumpWidget(
        host(
          const StatusDot(StatusKind.offer, showLabel: false),
          theme: AppTheme.dark(),
        ),
      );
      expect(dot(), AppColors.disabledDark);
    });
  });

  testWidgets('DateTile label never renders below 10 px, tile stays 34x34', (
    tester,
  ) async {
    for (final scale in [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(
        host(Align(child: DateTile(DateTime(2026, 6, 14))), textScale: scale),
      );
      expect(tester.takeException(), isNull, reason: 'scale $scale');
      expect(find.byType(FittedBox), findsNothing);
      final p = tester.renderObject<RenderParagraph>(find.text('JUN'));
      expect(
        p.textScaler.scale(p.text.style!.fontSize!),
        greaterThanOrEqualTo(10),
      );
      expect(
        tester.getSize(find.byType(DateTile)),
        const Size(AppSize.dateTile, AppSize.dateTile),
      );
    }
  });

  test('minimum text size tokens are at least 10', () {
    expect(AppText.kicker.fontSize, greaterThanOrEqualTo(10));
    expect(AppText.tileLabel.fontSize, greaterThanOrEqualTo(10));
  });

  testWidgets('PillFilter pills with counts have a 44 px hit area', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PillFilter<int>(
          options: const [
            PillOption(0, 'Alle', count: 12),
            PillOption(1, 'Offen'),
          ],
          value: 0,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Alle 12'), findsOneWidget);
    for (final e in tester.elementList(find.byType(Pressable))) {
      expect(
        (e.renderObject! as RenderBox).size.height,
        greaterThanOrEqualTo(AppSize.minTap),
      );
    }
  });

  testWidgets('disabled and loading buttons expose disabled semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const PrimaryButton(label: 'Los', onPressed: null)),
    );
    expect(
      tester.getSemantics(find.byType(PrimaryButton)),
      matchesSemantics(
        label: 'Los',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.pumpWidget(
      host(PrimaryButton(label: 'Los', loading: true, onPressed: () {})),
    );
    expect(
      tester.getSemantics(find.byType(PrimaryButton)),
      matchesSemantics(
        label: 'Los',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  test('status.* keys exist in de and en', () {
    for (final lang in ['de', 'en']) {
      final m =
          jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
              as Map<String, dynamic>;
      final status = m['status'] as Map<String, dynamic>;
      for (final k in ['offer', 'accepted', 'completed', 'declined']) {
        expect(status[k], isA<String>(), reason: '$lang status.$k');
      }
    }
  });

  test('widgets contain no color, size or radius literals', () {
    final re = RegExp(
      r'Color\(0x|fontSize:|BorderRadius\.circular\([0-9]|SizedBox\((height|width): [0-9]|strokeWidth: [0-9]|opacity: [0-9]|Offset\([-0-9]|blurRadius: [0-9]|sigmaX: [0-9]',
    );
    for (final f in Directory('lib/ui/widgets').listSync().whereType<File>()) {
      final hits = f.readAsLinesSync().where(
        (l) => re.hasMatch(l) && !l.trimLeft().startsWith('//'),
      );
      expect(hits, isEmpty, reason: f.path);
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

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20);
}
