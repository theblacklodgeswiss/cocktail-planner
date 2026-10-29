import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/tokens.dart';
import '../../../utils/currency.dart';
import '../../forms/steps/wizard_widgets.dart' show WizardSection;
import '../../shared/document_sections/document_field.dart';
import '../invoice_form_state.dart';

/// Extra hours (fields mode): hours and rate per employee and the
/// "n x h x rate = total" line. The employees themselves are picked on the
/// services step.
class InvoiceExtraHoursSection extends StatelessWidget {
  const InvoiceExtraHoursSection({super.key, required this.form});

  final InvoiceFormState form;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final code = form.order.currency;
    final curr = Currency.fromCode(code);
    return WizardSection(
      caption: 'invoice.extra_hours_section'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocTextField(
            controller: form.extraHoursCtrl,
            label: 'invoice.extra_hours'.tr(),
            hintText: '0',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: form.extraHourRateCtrl,
            label: '${'invoice.extra_hour_rate'.tr()} ($code)',
            hintText: '50.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
          ),
          if (form.selectedEmployees.isNotEmpty && form.extraHours > 0) ...[
            const SizedBox(height: AppSpace.s12),
            DocAmountRow(
              label:
                  '${form.selectedEmployees.length} ${'invoice.employees'.tr()} × ${form.extraHours}h × ${curr.format(form.extraHourRate)}',
              value: '= ${curr.format(form.extraHoursTotal)}',
              bold: true,
            ),
          ] else if (form.selectedEmployees.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Text(
                'invoice.select_employees'.tr(),
                style: AppText.caption.copyWith(color: p.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
