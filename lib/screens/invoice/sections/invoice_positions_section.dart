import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../utils/currency.dart';
import '../../forms/steps/wizard_widgets.dart' show WizardSection;
import '../../shared/document_sections/common_sections.dart';
import '../../shared/document_sections/document_field.dart';
import '../invoice_form_state.dart';
import 'invoice_extra_hours_section.dart';

/// Step 3 of the invoice. Positions mode: the offer positions as floating
/// cards. Fields mode: bar service, travel and theke, the shots position
/// (when shots are booked), extra hours and extra positions.
class InvoicePositionsSection extends StatelessWidget {
  const InvoicePositionsSection({
    super.key,
    required this.form,
    required this.update,
    required this.hints,
    required this.onEditOfferPosition,
    required this.onEditExtraPosition,
  });

  final InvoiceFormState form;
  final void Function(VoidCallback) update;
  final DocHints hints;
  final void Function({int? index}) onEditOfferPosition;
  final void Function({int? index}) onEditExtraPosition;

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(form.order.currency);
    if (form.usePositionsMode) {
      return _PositionList(
        title: 'invoice.positions'.tr(),
        addLabel: 'invoice.add_position'.tr(),
        onAdd: () => onEditOfferPosition(),
        children: [
          for (final e in form.offerPositions.asMap().entries)
            DocPositionCard(
              index: e.key,
              position: e.value,
              currency: curr,
              onEdit: () => onEditOfferPosition(index: e.key),
              onDelete: () => update(() => form.offerPositions.removeAt(e.key)),
            ),
        ],
      );
    }
    final code = form.order.currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardSection(
          caption: 'docflow.fields_card'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DocTextField(
                controller: form.barServiceCostCtrl,
                label: '${'invoice.bar_service_cost'.tr()} ($code)',
                hints: hints,
                field: 'bar_service_cost',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              DocTextField(
                controller: form.distanceKmCtrl,
                label: 'invoice.distance_km'.tr(),
                hintText: '150',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: AppSpace.s12),
              DocTextField(
                controller: form.travelCostPerKmCtrl,
                label: '${'invoice.travel_cost_per_km'.tr()} ($code)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              DocTextField(
                controller: form.thekeCostCtrl,
                label: '${'invoice.theke_cost'.tr()} ($code)',
                hintText: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        if (form.shotsCtrl.text.trim().isNotEmpty)
          WizardSection(
            caption: 'invoice.shots_position'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DocTextField(
                  controller: form.shotsCountCtrl,
                  label: 'invoice.shots_count'.tr(),
                  hintText: '60',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpace.s12),
                DocTextField(
                  controller: form.shotsPricePerPieceCtrl,
                  label: '${'invoice.shots_price_per_piece'.tr()} ($code)',
                  hintText: '1.50',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: AppSpace.s12),
                DocTextField(
                  controller: form.shotsRemarkCtrl,
                  label: 'invoice.shots_remark'.tr(),
                  hintText:
                      'Shots – Aarewasser, Erdbeer Lime\nAusgeschenkt in 0.4 CL Shotbechern',
                  minLines: 2,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        InvoiceExtraHoursSection(form: form),
        _PositionList(
          title: 'invoice.extra_positions'.tr(),
          addLabel: 'invoice.add_position'.tr(),
          onAdd: () => onEditExtraPosition(),
          children: [
            for (final e in form.extraPositions.asMap().entries)
              DocPositionCard(
                index: e.key,
                position: e.value,
                currency: curr,
                onEdit: () => onEditExtraPosition(index: e.key),
                onDelete: () =>
                    update(() => form.extraPositions.removeAt(e.key)),
              ),
          ],
        ),
      ],
    );
  }
}

class _PositionList extends StatelessWidget {
  const _PositionList({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Text(
            title,
            style: AppText.caption.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        ...children,
        SecondaryButton(label: addLabel, onPressed: onAdd),
        const SizedBox(height: AppSpace.s16),
      ],
    );
  }
}
