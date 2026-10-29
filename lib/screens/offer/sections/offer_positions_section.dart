import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/document_sections/common_sections.dart';
import '../offer_form_state.dart';

/// The offer positions card: rebuild/add buttons and one tile per position
/// with edit/delete (moved verbatim from the screen).
class OfferPositionsSection extends StatelessWidget {
  const OfferPositionsSection({
    super.key,
    required this.form,
    required this.update,
    required this.onEdit,
  });

  final OfferFormState form;
  final void Function(VoidCallback) update;

  /// Opens the position dialog; [index] null adds a new one.
  final void Function({int? index}) onEdit;

  @override
  Widget build(BuildContext context) {
    final errorKey = form.positionsErrorKey;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: errorKey != null
              ? Theme.of(context).colorScheme.error
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 620;
                final titleRow = Row(
                  children: [
                    Icon(
                      Icons.list_alt,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'offer.positions_list'.tr(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                );
                final actionButtons = [
                  OutlinedButton.icon(
                    onPressed: () => update(form.regeneratePositions),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text('offer.rebuild_positions'.tr()),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => onEdit(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('offer.add_position'.tr()),
                  ),
                ];

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: actionButtons),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    actionButtons.first,
                    const SizedBox(width: 8),
                    actionButtons.last,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'offer.positions_help'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            if (errorKey != null) DocumentSectionError(errorKey.tr()),
            if (form.offerPositions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'offer.positions_empty'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              for (final entry in form.offerPositions.asMap().entries)
                _PositionTile(
                  index: entry.key,
                  form: form,
                  onEdit: () => onEdit(index: entry.key),
                  onDelete: () => update(() => form.removePosition(entry.key)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({
    required this.index,
    required this.form,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final OfferFormState form;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final curr = form.currency;
    final pos = form.offerPositions[index];
    final isTbd = pos.quantity == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 460;
              final titleInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pos.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '#${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              );
              final totalInfo = Column(
                crossAxisAlignment: isCompact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    'offer.total'.tr(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    isTbd ? 'tbd' : curr.format(pos.total),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                    tooltip: 'common.edit'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: onDelete,
                    tooltip: 'common.delete'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleInfo),
                        const SizedBox(width: 6),
                        actionButtons,
                      ],
                    ),
                    const SizedBox(height: 6),
                    totalInfo,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleInfo),
                  const SizedBox(width: 8),
                  totalInfo,
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (pos.date.isNotEmpty)
                _MetaChip(icon: Icons.calendar_today, label: pos.date),
              _MetaChip(
                icon: Icons.numbers,
                label:
                    '${'offer.position_quantity'.tr()}: ${isTbd ? 'tbd' : pos.quantity}',
              ),
              _MetaChip(
                icon: Icons.attach_money,
                label:
                    '${'offer.position_price'.tr()}: ${isTbd ? 'tbd' : curr.format(pos.price)}',
              ),
            ],
          ),
          if (pos.remark.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(pos.remark, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
