import 'package:flutter/material.dart';

import '../tokens.dart';

const _monthsDe = [
  'JAN',
  'FEB',
  'MÄR',
  'APR',
  'MAI',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OKT',
  'NOV',
  'DEZ',
];
const _monthsEn = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// Small square date tile: day over abbreviated month. intl is only a
/// transitive dependency, so month names come from a small local table keyed
/// on the active locale (German, otherwise English).
class DateTile extends StatelessWidget {
  const DateTile(this.date, {super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final lang = Localizations.maybeLocaleOf(context)?.languageCode;
    final months = lang == 'de' ? _monthsDe : _monthsEn;
    final day = date.day.toString().padLeft(2, '0');

    return Semantics(
      container: true,
      child: Container(
        width: AppSize.dateTile,
        height: AppSize.dateTile,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        // Clamp instead of shrinking so the label never renders below 10 px.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: AppSize.maxTileTextScale,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(day, style: AppText.tileDay.copyWith(color: p.text)),
                const SizedBox(height: AppSize.tileGap),
                Text(
                  months[date.month - 1],
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: AppText.tileLabel.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
