import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/currency.dart';
import '../../../widgets/discount_editor.dart';
import '../../offer/widgets/section_header.dart';
import '../../shared/document_sections/document_field.dart';
import '../invoice_form_state.dart';
import 'invoice_extra_hours_section.dart';

/// "Positionen" of the invoice: the offer positions card (positions mode)
/// or the classic fields (bar service, travel, theke, shots), then the
/// discount, extra hours and extra positions. Moved verbatim.
class InvoicePositionsSection extends StatelessWidget {
  const InvoicePositionsSection({
    super.key,
    required this.form,
    required this.update,
    required this.field,
    required this.extraHours,
    required this.onEditOfferPosition,
    required this.onEditExtraPosition,
  });

  final InvoiceFormState form;
  final void Function(VoidCallback) update;
  final DocumentFieldFactory field;

  /// The extra hours section (built by the screen with its employee stream).
  final Widget extraHours;
  final void Function({int? index}) onEditOfferPosition;
  final void Function({int? index}) onEditExtraPosition;

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(form.order.currency);
    final code = form.order.currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'invoice.positions'.tr()),
        const SizedBox(height: 8),
        if (form.usePositionsMode) ...[
          InvoiceOfferPositionsCard(
            form: form,
            update: update,
            onEdit: onEditOfferPosition,
          ),
          const SizedBox(height: 12),
        ],
        if (!form.usePositionsMode) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field(
                    controller: form.barServiceCostCtrl,
                    label: '${'invoice.bar_service_cost'.tr()} ($code)',
                    keyboard: TextInputType.number,
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => responsivePair([
                      field(
                        controller: form.distanceKmCtrl,
                        label: 'invoice.distance_km'.tr(),
                        hint: '150',
                        keyboard: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      field(
                        controller: form.travelCostPerKmCtrl,
                        label: '${'invoice.travel_cost_per_km'.tr()} ($code)',
                        keyboard: TextInputType.number,
                      ),
                    ], wide: constraints.maxWidth >= 500),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 250,
                    child: field(
                      controller: form.thekeCostCtrl,
                      label: '${'invoice.theke_cost'.tr()} ($code)',
                      hint: '0',
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!form.usePositionsMode && form.shotsCtrl.text.trim().isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'invoice.shots_position'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => responsivePair([
                      field(
                        controller: form.shotsCountCtrl,
                        label: 'invoice.shots_count'.tr(),
                        hint: '60',
                        keyboard: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      field(
                        controller: form.shotsPricePerPieceCtrl,
                        label:
                            '${'invoice.shots_price_per_piece'.tr()} ($code)',
                        hint: '1.50',
                        keyboard: TextInputType.number,
                      ),
                    ], wide: constraints.maxWidth >= 500),
                  ),
                  const SizedBox(height: 12),
                  field(
                    controller: form.shotsRemarkCtrl,
                    label: 'invoice.shots_remark'.tr(),
                    hint:
                        'Shots – Aarewasser, Erdbeer Lime\nAusgeschenkt in 0.4 CL Shotbechern',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        DiscountEditor(
          currency: curr,
          subtotal: form.subtotal,
          isPercent: form.discountIsPercent,
          valueController: form.discountValueCtrl,
          remarkController: form.discountRemarkCtrl,
          onTypeChanged: (isPercent) =>
              update(() => form.setDiscountType(isPercent)),
          onChanged: () => update(() {}),
        ),
        const SizedBox(height: 12),
        if (!form.usePositionsMode) ...[
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: extraHours),
          ),
          const SizedBox(height: 12),
        ],
        if (!form.usePositionsMode)
          InvoiceExtraPositionsSection(
            form: form,
            update: update,
            onEdit: onEditExtraPosition,
          ),
      ],
    );
  }
}

/// Offer positions of the invoice (positions mode).
class InvoiceOfferPositionsCard extends StatelessWidget {
  const InvoiceOfferPositionsCard({
    super.key,
    required this.form,
    required this.update,
    required this.onEdit,
  });

  final InvoiceFormState form;
  final void Function(VoidCallback) update;
  final void Function({int? index}) onEdit;

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(form.order.currency);
    return Card(
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
                        'Angebotspositionen',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                );
                final addButton = FilledButton.tonalIcon(
                  onPressed: () => onEdit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('invoice.add_position'.tr()),
                );
                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titleRow, const SizedBox(height: 12), addButton],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    addButton,
                  ],
                );
              },
            ),
            if (form.offerPositions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final entry in form.offerPositions.asMap().entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final index = entry.key;
                      final pos = entry.value;
                      final isTbd = pos.quantity == 0;
                      final isCompact = constraints.maxWidth < 460;
                      final dateChip = pos.date.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pos.date,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            )
                          : null;
                      final titleColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dateChip != null) ...[
                            dateChip,
                            const SizedBox(height: 6),
                          ],
                          Text(
                            pos.quantity > 1
                                ? '${pos.quantity}× ${pos.name}'
                                : pos.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (pos.remark.isNotEmpty)
                            Text(
                              pos.remark.split('\n').first,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      );
                      final totalText = Text(
                        isTbd ? 'tbd' : curr.format(pos.total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isTbd
                              ? Theme.of(context).colorScheme.outline
                              : null,
                        ),
                      );
                      final actionButtons = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => onEdit(index: index),
                            tooltip: 'common.edit'.tr(),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => update(
                              () => form.offerPositions.removeAt(index),
                            ),
                            tooltip: 'common.delete'.tr(),
                            visualDensity: VisualDensity.compact,
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
                                Expanded(child: titleColumn),
                                const SizedBox(width: 8),
                                actionButtons,
                              ],
                            ),
                            const SizedBox(height: 8),
                            totalText,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 3, child: titleColumn),
                          const SizedBox(width: 8),
                          totalText,
                          const SizedBox(width: 4),
                          actionButtons,
                        ],
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Extra positions (fields mode).
class InvoiceExtraPositionsSection extends StatelessWidget {
  const InvoiceExtraPositionsSection({
    super.key,
    required this.form,
    required this.update,
    required this.onEdit,
  });

  final InvoiceFormState form;
  final void Function(VoidCallback) update;
  final void Function({int? index}) onEdit;

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(form.order.currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'invoice.extra_positions'.tr(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => onEdit(),
              icon: const Icon(Icons.add, size: 18),
              label: Text('invoice.add_position'.tr()),
            ),
          ],
        ),
        if (form.extraPositions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (final entry in form.extraPositions.asMap().entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value.quantity > 1
                              ? '${entry.value.quantity}x ${entry.value.name}'
                              : entry.value.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (entry.value.remark.isNotEmpty)
                          Text(
                            entry.value.remark,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    entry.value.quantity > 1
                        ? '${entry.value.quantity} × ${curr.format(entry.value.price)} = ${curr.format(entry.value.total)}'
                        : curr.format(entry.value.price),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => onEdit(index: entry.key),
                    tooltip: 'common.edit'.tr(),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () =>
                        update(() => form.extraPositions.removeAt(entry.key)),
                    tooltip: 'common.delete'.tr(),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
