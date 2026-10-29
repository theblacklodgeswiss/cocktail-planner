import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/offer.dart';
import '../../../utils/currency.dart';
import '../invoice_form_state.dart';

/// Price preview card of the invoice (moved verbatim).
class InvoicePricePreview extends StatelessWidget {
  const InvoicePricePreview({super.key, required this.form});

  final InvoiceFormState form;

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(form.order.currency);
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'invoice.price_preview'.tr(),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final row in invoicePreviewRows(form, curr))
              _PreviewRow(row: row),
            if (form.totalValidationErrorKey != null) ...[
              const SizedBox(height: 8),
              Text(
                form.totalValidationErrorKey!.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line of a price preview; [divider] lines draw a rule instead.
class PreviewLine {
  const PreviewLine(
    this.label,
    this.value, {
    this.bold = false,
    this.highlight = false,
  }) : divider = false;

  const PreviewLine.divider()
    : label = '',
      value = '',
      bold = false,
      highlight = false,
      divider = true;

  final String label;
  final String value;
  final bool bold;
  final bool highlight;
  final bool divider;
}

/// The invoice preview lines (labels already translated).
List<PreviewLine> invoicePreviewRows(InvoiceFormState form, Currency curr) => [
  if (form.usePositionsMode) ...[
    for (final pos in form.offerPositions)
      PreviewLine(
        pos.quantity > 1 ? '${pos.quantity}× ${pos.name}' : pos.name,
        pos.quantity == 0 ? 'tbd' : curr.format(pos.total),
      ),
    const PreviewLine.divider(),
    PreviewLine(
      'invoice.positions_sum'.tr(),
      curr.format(form.offerPositionsSum),
      bold: true,
    ),
  ] else ...[
    PreviewLine(
      'invoice.bar_service_cost'.tr(),
      curr.format(form.barServiceCost),
    ),
    if (form.distanceKm > 0)
      PreviewLine(
        'invoice.travel_cost'.tr(),
        '${form.distanceKm * 2} km × ${curr.format(form.travelCostPerKm)} = ${curr.format(form.travelCostTotal)}',
      ),
    if (form.thekeCost > 0)
      PreviewLine('invoice.theke_cost'.tr(), curr.format(form.thekeCost)),
    if (form.shotsCount > 0)
      PreviewLine(
        'Shots',
        '${form.shotsCount} × ${curr.format(form.shotsPricePerPiece)} = ${curr.format(form.shotsCostTotal)}',
      ),
    if (form.extraHoursTotal > 0)
      PreviewLine(
        'invoice.extra_hours_label'.tr(),
        '${form.selectedEmployees.length} × ${form.extraHours}h × ${curr.format(form.extraHourRate)} = ${curr.format(form.extraHoursTotal)}',
      ),
    if (form.extraPositionsTotal > 0)
      PreviewLine(
        'invoice.extra_positions'.tr(),
        curr.format(form.extraPositionsTotal),
      ),
    const PreviewLine.divider(),
    PreviewLine(
      'invoice.positions_sum'.tr(),
      curr.format(form.positionsSum),
      bold: true,
    ),
  ],
  if (form.discount > 0)
    PreviewLine(
      form.storedDiscountPercent > 0
          ? '${'invoice.discount'.tr()} (${formatDiscountPercent(form.storedDiscountPercent)}%)'
          : 'invoice.discount'.tr(),
      '-${curr.format(form.discount)}',
    ),
  const PreviewLine.divider(),
  PreviewLine(
    'invoice.grand_total'.tr(),
    curr.format(form.grandTotal),
    bold: true,
    highlight: true,
  ),
];

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row});

  final PreviewLine row;

  @override
  Widget build(BuildContext context) {
    if (row.divider) return const Divider();
    final style = TextStyle(
      fontWeight: row.bold ? FontWeight.bold : FontWeight.normal,
      color: row.highlight ? Theme.of(context).colorScheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(row.label, style: style)),
          const SizedBox(width: 12),
          Text(row.value, textAlign: TextAlign.right, style: style),
        ],
      ),
    );
  }
}

/// Sticky action bar of the invoice (moved verbatim).
class InvoiceActionButtons extends StatelessWidget {
  const InvoiceActionButtons({
    super.key,
    required this.isGenerating,
    required this.onSave,
    required this.onPreview,
    required this.onGeneratePdf,
    required this.onShare,
    required this.onCalendar,
  });

  final bool isGenerating;
  final VoidCallback onSave;
  final VoidCallback onPreview;
  final VoidCallback onGeneratePdf;
  final VoidCallback onShare;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final saveBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onSave,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: Text('invoice.save'.tr()),
    );
    final previewBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onPreview,
      icon: const Icon(Icons.visibility, size: 18),
      label: Text('invoice.preview'.tr()),
    );
    final pdfBtn = FilledButton.icon(
      onPressed: isGenerating ? null : onGeneratePdf,
      icon: isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.picture_as_pdf, size: 18),
      label: Text('invoice.generate_pdf'.tr()),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    );
    final shareBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onShare,
      icon: const Icon(Icons.share, size: 18),
      label: Text('invoice.share'.tr()),
    );
    final calendarBtn = OutlinedButton.icon(
      onPressed: isGenerating ? null : onCalendar,
      icon: const Icon(Icons.event, size: 18),
      label: Text('invoice.create_calendar'.tr()),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              saveBtn,
              const SizedBox(width: 8),
              previewBtn,
              const SizedBox(width: 8),
              shareBtn,
              const SizedBox(width: 8),
              calendarBtn,
              const Spacer(),
              pdfBtn,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: saveBtn),
                const SizedBox(width: 8),
                Expanded(child: previewBtn),
              ],
            ),
            const SizedBox(height: 8),
            pdfBtn,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: shareBtn),
                const SizedBox(width: 8),
                Expanded(child: calendarBtn),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Add/edit dialog of an extra position (fields mode; moved verbatim).
Future<ExtraPosition?> showExtraPositionDialog(
  BuildContext context, {
  required String currencyCode,
  ExtraPosition? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final quantityCtrl = TextEditingController(
    text: existing != null ? existing.quantity.toString() : '1',
  );
  final priceCtrl = TextEditingController(
    text: existing != null ? existing.price.toStringAsFixed(2) : '',
  );
  final remarkCtrl = TextEditingController(text: existing?.remark ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<ExtraPosition>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        existing == null
            ? 'invoice.add_position'.tr()
            : 'invoice.edit_position'.tr(),
      ),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'invoice.position_name'.tr(),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'invoice.field_required'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'invoice.position_quantity'.tr(),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => extraQuantityErrorKey(v)?.tr(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '${'invoice.position_price'.tr()} ($currencyCode)',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (v) => extraPriceErrorKey(v)?.tr(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: remarkCtrl,
                decoration: InputDecoration(
                  labelText: 'invoice.position_remark'.tr(),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(
                ctx,
                ExtraPosition(
                  name: nameCtrl.text.trim(),
                  quantity: int.parse(quantityCtrl.text.trim()),
                  price: double.parse(priceCtrl.text.trim()),
                  remark: remarkCtrl.text.trim(),
                ),
              );
            }
          },
          child: Text('common.save'.tr()),
        ),
      ],
    ),
  );
}

/// Extra position quantity: required, whole number >= 1.
String? extraQuantityErrorKey(String? v) {
  if (v == null || v.trim().isEmpty) return 'invoice.field_required';
  final n = int.tryParse(v.trim());
  if (n == null || n < 1) return 'invoice.invalid_number';
  return null;
}

/// Extra position price: required, plain decimal.
String? extraPriceErrorKey(String? v) {
  if (v == null || v.trim().isEmpty) return 'invoice.field_required';
  if (double.tryParse(v.trim()) == null) return 'invoice.invalid_number';
  return null;
}
