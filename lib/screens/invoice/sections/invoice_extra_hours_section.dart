import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/employee.dart';
import '../../../utils/currency.dart';
import '../../shared/document_sections/common_sections.dart';
import '../../shared/document_sections/document_field.dart';
import '../invoice_form_state.dart';

/// Extra hours (fields mode): employee chips, hours and rate, the
/// "n x h x rate" line and the missing-employees error. Moved verbatim.
class InvoiceExtraHoursSection extends StatelessWidget {
  const InvoiceExtraHoursSection({
    super.key,
    required this.form,
    required this.update,
    required this.field,
    required this.employees,
  });

  final InvoiceFormState form;
  final void Function(VoidCallback) update;
  final DocumentFieldFactory field;
  final Stream<List<Employee>> employees;

  @override
  Widget build(BuildContext context) {
    final currencyCode = form.order.currency;
    final curr = Currency.fromCode(currencyCode);
    return StreamBuilder<List<Employee>>(
      stream: employees,
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'invoice.extra_hours_section'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'invoice.select_employees'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            EmployeeChips(
              employees: snapshot.data ?? [],
              selected: form.selectedEmployees,
              onToggle: (name, selected) =>
                  update(() => form.toggleEmployee(name, selected)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 500;
                final fields = [
                  field(
                    controller: form.extraHoursCtrl,
                    label: 'invoice.extra_hours'.tr(),
                    hint: '0',
                    keyboard: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  field(
                    controller: form.extraHourRateCtrl,
                    label:
                        '${'invoice.extra_hour_rate'.tr()} ($currencyCode)',
                    hint: '50.00',
                    keyboard: TextInputType.number,
                  ),
                ];
                return responsivePair(fields, wide: wide);
              },
            ),
            if (form.selectedEmployees.isNotEmpty && form.extraHours > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${form.selectedEmployees.length} ${'invoice.employees'.tr()} × ${form.extraHours}h × ${curr.format(form.extraHourRate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '= ${curr.format(form.extraHoursTotal)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (form.employeeValidationErrorKey != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    form.employeeValidationErrorKey!.tr(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Two fields side by side (wide) or stacked (narrow), as in the old
/// screen's repeated LayoutBuilders.
Widget responsivePair(List<Widget> fields, {required bool wide}) {
  return wide
      ? Row(
          children: fields
              .map(
                (f) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: f,
                  ),
                ),
              )
              .toList(),
        )
      : Column(
          children: fields
              .map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: f,
                ),
              )
              .toList(),
        );
}
