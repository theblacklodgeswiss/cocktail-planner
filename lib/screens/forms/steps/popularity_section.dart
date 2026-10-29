import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/pressable.dart';
import '../order_form_state.dart';

/// Optional "Beliebtheit anpassen": expected popularity (0-100 %) per
/// selected drink. Collapsed by default and never required; the values
/// themselves are kept in sync with the selection by [OrderFormState]
/// whether or not this section was ever opened.
class PopularitySection extends StatelessWidget {
  const PopularitySection({super.key, required this.form});

  final OrderFormState form;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final expanded = form.popularityExpanded;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: FloatingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Pressable(
              minSize: AppSize.minTap,
              selected: expanded,
              onTap: () => form.update(
                () => form.popularityExpanded = !form.popularityExpanded,
              ),
              child: Row(
                children: [
                  Icon(Icons.bar_chart, size: AppSize.rowIcon, color: p.text),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'order_wizard.popularity_title'.tr(),
                          style: AppText.section.copyWith(color: p.text),
                        ),
                        Text(
                          'order_wizard.optional'.tr(),
                          style: AppText.caption.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: p.textSecondary,
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: AppSpace.s8),
              Text(
                'order_wizard.popularity_hint'.tr(),
                style: AppText.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: AppSpace.s8),
              for (final recipe in form.selectedRecipes)
                _slider(context, recipe.name),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slider(BuildContext context, String name) {
    final p = AppPalette.of(context);
    final popularity = form.cocktailPopularity[name] ?? 50.0;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppText.button.copyWith(color: p.text),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                '${popularity.round()}%',
                style: AppText.number.copyWith(color: p.goldText),
              ),
            ],
          ),
          Slider(
            value: popularity,
            min: 0,
            max: 100,
            divisions: 20,
            semanticFormatterCallback: (v) => '$name ${v.round()}%',
            onChanged: (value) {
              HapticFeedback.selectionClick();
              form.update(() => form.cocktailPopularity[name] = value);
            },
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'order_wizard.popularity_low'.tr(),
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  'order_wizard.popularity_high'.tr(),
                  textAlign: TextAlign.end,
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
