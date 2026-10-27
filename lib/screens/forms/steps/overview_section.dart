import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../utils/order_option_labels.dart';
import '../order_form_state.dart';
import 'occasion_step.dart' show kDrinkerTypes, kEventTypes, kServiceTypes;
import 'wizard_widgets.dart';

/// Read-only summary of everything entered, grouped like the steps; each
/// group can jump back to its step. The submit button lives in the bottom
/// bar (exactly once).
class OverviewSection extends StatelessWidget {
  const OverviewSection({
    super.key,
    required this.form,
    required this.isEmployeeOrHigher,
    required this.onEditStep,
  });

  final OrderFormState form;

  /// Staff see the order wording instead of the request wording.
  final bool isEmployeeOrHigher;

  /// Jumps to the given step.
  final ValueChanged<int> onEditStep;

  String _orDash(String value) => value.trim().isEmpty ? '–' : value.trim();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isEnglish = context.locale.languageCode == 'en';

    String labelOf<T>(List<(T, IconData, String)> options, T? value) {
      for (final (v, _, key) in options) {
        if (v == value) return key.tr();
      }
      return '–';
    }

    final barDrinks = formatOrderBarDrinkLabels(
      form.selectedBarDrinks,
      isEnglish: isEnglish,
    );
    final alcohol = formatOrderAlcoholLabels(
      form.selectedAlcoholItems,
      isEnglish: isEnglish,
    );
    final services = form.additionalServicesList
        .map(
          (value) => resolveAdditionalServiceLabel(
            value,
            catalog: form.serviceCatalog,
            isEnglish: isEnglish,
            currencyCode: form.currency,
          ),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s8),
        Semantics(
          header: true,
          child: Text(
            isEmployeeOrHigher
                ? 'order_wizard.review_staff'.tr()
                : 'order_wizard.review_guest'.tr(),
            style: AppText.section.copyWith(color: p.text),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          isEmployeeOrHigher
              ? 'order_wizard.review_hint_staff'.tr()
              : 'order_wizard.review_hint_guest'.tr(),
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s12),
        _group(context, 'order_wizard.summary_occasion'.tr(), 0, [
          SummaryRow(
            label: 'order_wizard.summary_service'.tr(),
            value: labelOf(kServiceTypes, form.serviceType),
          ),
          SummaryRow(
            label: 'order_wizard.summary_event_type'.tr(),
            value: labelOf(kEventTypes, form.selectedEventType),
          ),
          SummaryRow(
            label: 'order_wizard.drinker_caption'.tr(),
            value: labelOf(kDrinkerTypes, form.drinkerType),
          ),
        ]),
        _group(context, 'order_wizard.summary_schedule'.tr(), 1, [
          SummaryRow(
            label: 'order_wizard.summary_date'.tr(),
            value: form.eventDate != null
                ? DateFormat('EEEE, dd. MMMM yyyy').format(form.eventDate!)
                : '–',
          ),
          SummaryRow(
            label: 'order_wizard.summary_time'.tr(),
            value: form.eventTime?.format(context) ?? '–',
          ),
          SummaryRow(
            label: 'order_wizard.summary_place'.tr(),
            value: _orDash(form.addressController.text),
          ),
          SummaryRow(
            label: 'order_wizard.summary_distance'.tr(),
            value: '${form.distanceKm} km',
          ),
          SummaryRow(
            label: 'order_wizard.summary_guests'.tr(),
            value: '${form.personCount}',
          ),
          SummaryRow(
            label: 'order_wizard.currency_caption'.tr(),
            value: form.currency,
          ),
        ]),
        _group(context, 'order_wizard.contact_caption'.tr(), 2, [
          SummaryRow(
            label: 'common.name'.tr(),
            value: _orDash(form.nameController.text),
          ),
          SummaryRow(
            label: 'order_setup.phone_label'.tr(),
            value: _orDash(form.phoneController.text),
          ),
          if (form.remarksController.text.trim().isNotEmpty)
            SummaryRow(
              label: 'order_wizard.remarks_caption'.tr(),
              value: form.remarksController.text.trim(),
            ),
        ]),
        _group(
          context,
          'order_wizard.summary_drinks'.tr(
            args: ['${form.selectedRecipes.length}'],
          ),
          3,
          [
            for (final recipe in form.selectedRecipes)
              SummaryRow(
                label: recipe.isShot
                    ? '${recipe.name} (${form.shotQuantities[recipe.name] ?? 1}×)'
                    : recipe.name,
                value: 'order_wizard.summary_popularity'.tr(
                  args: [
                    '${(form.cocktailPopularity[recipe.name] ?? 50).round()}',
                  ],
                ),
              ),
            if (form.selectedRecipes.isEmpty)
              SummaryRow(
                label: 'order_wizard.filter_cocktails'.tr(),
                value: '–',
              ),
            if (barDrinks.isNotEmpty)
              SummaryRow(
                label: 'order_wizard.bar_drinks_caption'.tr(),
                value: barDrinks.join(', '),
              ),
            for (final label in alcohol)
              SummaryRow(
                label: 'order_wizard.alcohol_caption'.tr(),
                value: label,
              ),
          ],
        ),
        if (services.isNotEmpty)
          _group(context, 'order_wizard.services_caption'.tr(), null, [
            for (final label in services)
              SummaryRow(
                label: 'order_wizard.summary_service'.tr(),
                value: label,
              ),
          ]),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    int? step,
    List<Widget> rows,
  ) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: FloatingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppText.section.copyWith(color: p.text),
                  ),
                ),
                if (step != null)
                  TextAction(
                    label: 'order_wizard.edit'.tr(),
                    onPressed: () => onEditStep(step),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            ...rows,
          ],
        ),
      ),
    );
  }
}
