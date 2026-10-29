import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/employee.dart';
import '../../../utils/currency.dart';
import '../../shared/document_sections/common_sections.dart';
import '../offer_form_state.dart';
import '../widgets/section_header.dart';

/// Currency picker of the offer (moved verbatim).
class OfferCurrencySection extends StatelessWidget {
  const OfferCurrencySection({
    super.key,
    required this.form,
    required this.update,
  });

  final OfferFormState form;
  final void Function(VoidCallback) update;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'shopping.currency'.tr()),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<Currency>(
            segments: Currency.values
                .map(
                  (currency) => ButtonSegment<Currency>(
                    value: currency,
                    label: Text(currency.code),
                  ),
                )
                .toList(),
            selected: {form.currency},
            onSelectionChanged: (selection) =>
                update(() => form.currency = selection.first),
          ),
        ),
      ],
    );
  }
}

/// Barkeeper selection of the offer.
class OfferEmployeesSection extends StatelessWidget {
  const OfferEmployeesSection({
    super.key,
    required this.form,
    required this.update,
    required this.employees,
  });

  final OfferFormState form;
  final void Function(VoidCallback) update;
  final Stream<List<Employee>> employees;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: employees,
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(label: 'invoice.extra_hours_section'.tr()),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// "Zusatzinformation" text of the offer.
class OfferAdditionalInfoSection extends StatelessWidget {
  const OfferAdditionalInfoSection({super.key, required this.form});

  final OfferFormState form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.additional_info'.tr()),
        const SizedBox(height: 8),
        TextFormField(
          controller: form.additionalInfoCtrl,
          maxLines: 8,
          decoration: InputDecoration(hintText: 'offer.additional_info'.tr()),
        ),
      ],
    );
  }
}
