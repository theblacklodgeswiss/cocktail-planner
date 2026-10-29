import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/offer.dart';
import '../../../utils/currency.dart';
import '../../forms/steps/wizard_widgets.dart' show WizardSection;
import '../../shared/document_sections/document_field.dart';
import '../invoice_form_state.dart';

/// One line of a price breakdown; [divider] lines draw a rule instead.
class PreviewLine {
  const PreviewLine(this.label, this.value, {this.bold = false})
    : divider = false;

  const PreviewLine.divider() : label = '', value = '', bold = false, divider = true;

  final String label;
  final String value;
  final bool bold;
  final bool divider;
}

/// The invoice breakdown lines (same content as the old price preview).
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
  ),
];

/// The breakdown card of the invoice's last step.
class InvoiceBreakdown extends StatelessWidget {
  const InvoiceBreakdown({super.key, required this.form});

  final InvoiceFormState form;

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(form.order.currency);
    return WizardSection(
      caption: 'invoice.price_preview'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in invoicePreviewRows(form, curr))
            row.divider
                ? const DocDivider()
                : DocAmountRow(
                    label: row.label,
                    value: row.value,
                    bold: row.bold,
                  ),
        ],
      ),
    );
  }
}
