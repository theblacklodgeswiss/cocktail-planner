import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../utils/order_option_labels.dart';
import '../order_form_state.dart';
import 'wizard_widgets.dart';

/// Bar drink categories that can be poured (stored values, display order).
const List<String> kBarDrinkValues = [
  'whiskey_mix',
  'vodka_mix',
  'gin_mix',
  'shots',
  'other',
];

/// Bottles that can be bought from us (stored values, display order).
const List<String> kAlcoholValues = [
  'whiskey_chivas',
  'whiskey_black_label',
  'vodka_absolut',
  'vodka_three_sixty',
  'vodka_ciroc',
  'vodka_belvedere',
  'vodka_grey_goose',
  'gin_bombay',
  'gin_bulldog',
];

/// Whether [serviceType] includes the bar (and so the bar drinks section).
bool serviceIncludesBar(String serviceType) =>
    serviceType == 'cocktail_barservice' || serviceType == 'bar_service';

/// Bar drinks and alcohol purchase (multi-select); only shown for service
/// types that include the bar.
class BarDrinksSection extends StatelessWidget {
  const BarDrinksSection({super.key, required this.form});

  final OrderFormState form;

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.locale.languageCode == 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardSection(
          caption: 'order_wizard.bar_drinks_caption'.tr(),
          child: _group(
            context,
            subtitle: 'order_setup.bar_drinks_subtitle'.tr(),
            values: kBarDrinkValues,
            selected: form.selectedBarDrinks,
            label: (v) => formatOrderBarDrinkLabel(v, isEnglish: isEnglish),
          ),
        ),
        WizardSection(
          caption: 'order_wizard.alcohol_caption'.tr(),
          child: _group(
            context,
            subtitle: 'order_setup.alcohol_purchase_subtitle'.tr(),
            values: kAlcoholValues,
            selected: form.selectedAlcoholItems,
            label: (v) => formatOrderAlcoholLabel(v, isEnglish: isEnglish),
          ),
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context, {
    required String subtitle,
    required List<String> values,
    required Set<String> selected,
    required String Function(String) label,
  }) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(subtitle, style: AppText.body.copyWith(color: p.textSecondary)),
        const SizedBox(height: AppSpace.s8),
        PillGroup(
          children: [
            for (final value in values)
              SelectPill(
                label: label(value),
                selected: selected.contains(value),
                onTap: () => form.update(() {
                  if (!selected.remove(value)) selected.add(value);
                }),
              ),
          ],
        ),
      ],
    );
  }
}
