import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../forms/steps/wizard_widgets.dart' show FieldHint;
import '../../shared/document_sections/common_sections.dart';
import '../../shared/document_sections/document_field.dart';
import '../offer_form_state.dart';

/// Step 3 of the offer: rebuild/add actions and the positions as floating
/// cards with 44 px edit/delete.
class OfferPositionsSection extends StatelessWidget {
  const OfferPositionsSection({
    super.key,
    required this.form,
    required this.update,
    required this.onEdit,
    required this.hints,
  });

  final OfferFormState form;
  final void Function(VoidCallback) update;

  /// Opens the position sheet; [index] null adds a new one.
  final void Function({int? index}) onEdit;
  final DocHints hints;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return KeyedSubtree(
      key: hints.anchorOf('positions'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'offer.positions_help'.tr(),
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              SecondaryButton(
                label: 'offer.rebuild_positions'.tr(),
                onPressed: () => update(form.regeneratePositions),
              ),
              SecondaryButton(
                label: 'offer.add_position'.tr(),
                onPressed: () => onEdit(),
              ),
            ],
          ),
          FieldHint(hints.hintOf('positions')),
          const SizedBox(height: AppSpace.s16),
          if (form.offerPositions.isEmpty)
            Text(
              'offer.positions_empty'.tr(),
              style: AppText.body.copyWith(color: p.textSecondary),
            )
          else
            for (final entry in form.offerPositions.asMap().entries)
              DocPositionCard(
                index: entry.key,
                position: entry.value,
                currency: form.currency,
                onEdit: () => onEdit(index: entry.key),
                onDelete: () => update(() => form.removePosition(entry.key)),
              ),
        ],
      ),
    );
  }
}
