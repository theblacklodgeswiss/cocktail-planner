import 'dart:math' as math;

import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/motion.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final light = AppTheme.light();
  final dark = AppTheme.dark();

  test('light and dark themes build with M3 and compact density', () {
    for (final t in [light, dark]) {
      expect(t.useMaterial3, isTrue);
      expect(t.visualDensity, VisualDensity.compact);
      expect(t.materialTapTargetSize, MaterialTapTargetSize.padded);
    }
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
  });

  test('text on card has >= 4.5:1 in both modes', () {
    expect(contrast(AppColors.textLight, AppColors.cardLight),
        greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.textDark, AppColors.cardDark),
        greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.textSecondaryLight, AppColors.cardLight),
        greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.textSecondaryDark, AppColors.cardDark),
        greaterThanOrEqualTo(4.5));
  });

  test('gold accents are legible on their surface', () {
    expect(contrast(AppColors.goldOnWhite, Colors.white),
        greaterThanOrEqualTo(3.0));
    expect(contrast(AppColors.goldOnBlack, AppColors.ink),
        greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.goldLabelOnBlack, AppColors.ink),
        greaterThanOrEqualTo(4.5));
  });

  test('primary is black in light and white in dark', () {
    expect(light.colorScheme.primary, AppColors.ink);
    expect(dark.colorScheme.primary, Colors.white);
  });

  test('legacy roles stay legible (>= 4.5:1 text on container)', () {
    for (final cs in [light.colorScheme, dark.colorScheme]) {
      final pairs = <String, List<Color>>{
        'primary': [cs.onPrimary, cs.primary],
        'primaryContainer': [cs.onPrimaryContainer, cs.primaryContainer],
        'secondary': [cs.onSecondary, cs.secondary],
        'secondaryContainer': [cs.onSecondaryContainer, cs.secondaryContainer],
        'tertiary': [cs.onTertiary, cs.tertiary],
        'tertiaryContainer': [cs.onTertiaryContainer, cs.tertiaryContainer],
        'error': [cs.onError, cs.error],
        'errorContainer': [cs.onErrorContainer, cs.errorContainer],
        'surface': [cs.onSurface, cs.surface],
        'surfaceVariant': [cs.onSurfaceVariant, cs.surfaceContainerHighest],
      };
      pairs.forEach((name, p) {
        expect(contrast(p[0], p[1]), greaterThanOrEqualTo(4.5),
            reason: '$name in ${cs.brightness}');
      });
    }
  });

  test('page transitions are Cupertino on every platform', () {
    for (final t in [light, dark]) {
      final builders = t.pageTransitionsTheme.builders;
      for (final p in TargetPlatform.values) {
        expect(builders[p], isA<CupertinoPageTransitionsBuilder>(),
            reason: '$p');
      }
    }
  });

  test('tokens carry the spec values', () {
    expect(AppRadius.card, 20);
    expect(AppRadius.hero, 24);
    expect(AppRadius.heroXl, 30);
    expect(AppRadius.control, 12);
    expect(AppRadius.pill, 999);
    expect(
        [AppSpace.s4, AppSpace.s8, AppSpace.s12, AppSpace.s16, AppSpace.s24],
        [4, 8, 12, 16, 24]);
    expect(AppText.title.fontSize, 24);
    expect(AppText.section.fontSize, 15);
    expect(AppText.body.fontSize, 12);
    expect(AppText.caption.fontSize, 10.5);
    expect(AppText.number.fontSize, 17);
  });

  test('motion curve starts at 0 and ends at 1', () {
    expect(AppMotion.easeOut.transform(0), 0);
    expect(AppMotion.easeOut.transform(1), 1);
    expect(AppMotion.press < AppMotion.page, isTrue);
  });

  testWidgets('AppMotion.reduced follows disableAnimations', (tester) async {
    late bool reduced;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (c) {
        reduced = AppMotion.reduced(c);
        return const SizedBox();
      }),
    ));
    expect(reduced, isTrue);
  });

  testWidgets('AppMotion.reducedTransparency follows highContrast',
      (tester) async {
    Future<bool> read(MediaQueryData? data) async {
      late bool v;
      Widget child = Builder(builder: (c) {
        v = AppMotion.reducedTransparency(c);
        return const SizedBox();
      });
      if (data != null) child = MediaQuery(data: data, child: child);
      await tester.pumpWidget(child);
      return v;
    }

    expect(await read(const MediaQueryData(highContrast: true)), isTrue);
    expect(await read(const MediaQueryData()), isFalse);
    expect(await read(null), isFalse);
  });

  test('sheet duration stays within 200-300 ms', () {
    expect(AppMotion.sheet.inMilliseconds, inInclusiveRange(200, 300));
    expect(AppMotion.page.inMilliseconds, inInclusiveRange(200, 300));
  });
}
