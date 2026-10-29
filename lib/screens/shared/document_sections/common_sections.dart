import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/employee.dart';
import '../../../models/offer.dart';
import '../../../models/order.dart';
import '../../../utils/currency.dart';
import '../../offer/offer_form_state.dart' show formatDocumentDate;
import '../../offer/widgets/cocktail_chips_field.dart';
import '../../offer/widgets/event_type_selector.dart';
import '../../offer/widgets/section_header.dart';
import 'document_field.dart';

/// Sections shared by the offer and invoice screens (moved verbatim; the
/// differences between the two screens are parameters). [prefix] is the
/// translation group, 'offer' or 'invoice'.

/// Order name, date and total on top.
class DocumentOrderBanner extends StatelessWidget {
  const DocumentOrderBanner({
    super.key,
    required this.order,
    required this.currency,
  });

  final SavedOrder order;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text(order.name),
        subtitle: Text(
          '${formatDocumentDate(order.date)} • ${currency.format(order.total)}',
        ),
      ),
    );
  }
}

class DocumentEditorSection extends StatelessWidget {
  const DocumentEditorSection({
    super.key,
    required this.prefix,
    required this.controller,
    required this.field,
  });

  final String prefix;
  final TextEditingController controller;
  final DocumentFieldFactory field;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: '$prefix.editor'.tr()),
        const SizedBox(height: 8),
        SizedBox(
          width: 400,
          child: field(
            controller: controller,
            label: '$prefix.editor_name'.tr(),
            required: true,
          ),
        ),
      ],
    );
  }
}

/// Client name, contact and location. The offer requires all three; the
/// invoice only the name.
class DocumentClientSection extends StatelessWidget {
  const DocumentClientSection({
    super.key,
    required this.prefix,
    required this.nameCtrl,
    required this.contactCtrl,
    required this.locationCtrl,
    required this.field,
    required this.allRequired,
  });

  final String prefix;
  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController locationCtrl;
  final DocumentFieldFactory field;
  final bool allRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: '$prefix.client'.tr()),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 500;
            final fields = [
              field(
                controller: nameCtrl,
                label: '$prefix.client_name'.tr(),
                required: true,
              ),
              field(
                controller: contactCtrl,
                label: '$prefix.client_contact'.tr(),
                hint: '$prefix.client_contact_hint'.tr(),
                required: allRequired,
              ),
            ];
            return Column(
              children: [
                wide
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
                    : allRequired
                    ? Column(
                        children: fields
                            .map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: f,
                              ),
                            )
                            .toList(),
                      )
                    : Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 8),
                          fields[1],
                        ],
                      ),
                const SizedBox(height: 8),
                field(
                  controller: locationCtrl,
                  label: 'orders.location'.tr(),
                  hint: 'z.B. Musterstrasse 123, 3000 Bern',
                  required: allRequired,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Event type chips; the offer frames them and shows [errorKey].
class DocumentEventTypeSection extends StatelessWidget {
  const DocumentEventTypeSection({
    super.key,
    required this.prefix,
    required this.selected,
    required this.onChanged,
    this.framed = false,
    this.errorKey,
  });

  final String prefix;
  final Set<EventType> selected;
  final ValueChanged<Set<EventType>> onChanged;
  final bool framed;
  final String? errorKey;

  @override
  Widget build(BuildContext context) {
    final selector = EventTypeSelector(
      selectedTypes: selected,
      onChanged: onChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: '$prefix.event_type'.tr()),
        const SizedBox(height: 8),
        if (!framed)
          selector
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: errorKey != null
                    ? Theme.of(context).colorScheme.error
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: selector,
          ),
        if (errorKey != null) DocumentSectionError(errorKey!.tr()),
      ],
    );
  }
}

/// Red explanation below a section (offer).
class DocumentSectionError extends StatelessWidget {
  const DocumentSectionError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Guest count, event time and date.
class DocumentEventDetailsSection extends StatelessWidget {
  const DocumentEventDetailsSection({
    super.key,
    required this.prefix,
    required this.guestCountCtrl,
    required this.eventTimeCtrl,
    required this.eventDate,
    required this.onDateChanged,
    required this.field,
    this.guestValidator,
    required this.timeRequired,
  });

  final String prefix;
  final TextEditingController guestCountCtrl;
  final TextEditingController eventTimeCtrl;
  final DateTime eventDate;
  final ValueChanged<DateTime> onDateChanged;
  final DocumentFieldFactory field;

  /// Offer: the guest count validator; invoice: null (plain "required").
  final FormFieldValidator<String>? guestValidator;
  final bool timeRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: '$prefix.event_details'.tr()),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final fields = [
              SizedBox(
                width: 200,
                child: field(
                  controller: guestCountCtrl,
                  label: '$prefix.guest_count'.tr(),
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: guestValidator,
                  required: guestValidator == null,
                ),
              ),
              SizedBox(
                width: 200,
                child: field(
                  controller: eventTimeCtrl,
                  label: '$prefix.event_time'.tr(),
                  hint: '17:30',
                  required: timeRequired,
                ),
              ),
              SizedBox(
                width: 200,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: eventDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                    );
                    if (picked != null) onDateChanged(picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '$prefix.event_date'.tr(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(formatDocumentDate(eventDate)),
                  ),
                ),
              ),
            ];
            return wide
                ? Row(
                    children: fields
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: f,
                          ),
                        )
                        .toList(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: fields
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: f,
                          ),
                        )
                        .toList(),
                  );
          },
        ),
      ],
    );
  }
}

/// Service type dropdown; the offer adds a hint below it.
class DocumentServiceTypeSection extends StatelessWidget {
  const DocumentServiceTypeSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.showHint = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'orders.service_type'.tr()),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final (v, key) in serviceTypeOptions)
                DropdownMenuItem(value: v, child: Text(key.tr())),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
        if (showHint) ...[
          const SizedBox(height: 8),
          Text(
            'offer.positions_manage_hint'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}

/// The four service types and their labels.
const serviceTypeOptions = [
  ('cocktail_barservice', 'orders.service_cocktail_bar'),
  ('cocktail_service', 'orders.service_cocktail_only'),
  ('mocktail_service', 'orders.service_mocktail_only'),
  ('bar_service', 'orders.service_bar_only'),
];

/// Cocktails (chips), bar description and shots.
class DocumentServicesSection extends StatelessWidget {
  const DocumentServicesSection({
    super.key,
    required this.prefix,
    required this.cocktailsCtrl,
    required this.barDescCtrl,
    required this.shotsCtrl,
    required this.field,
    this.cocktailsValidator,
    this.loadCatalog,
  });

  final String prefix;
  final TextEditingController cocktailsCtrl;
  final TextEditingController barDescCtrl;
  final TextEditingController shotsCtrl;
  final DocumentFieldFactory field;
  final FormFieldValidator<String>? cocktailsValidator;
  final Future<List<String>> Function()? loadCatalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: '$prefix.services'.tr()),
        const SizedBox(height: 8),
        CocktailChipsField(
          controller: cocktailsCtrl,
          label: '$prefix.cocktails'.tr(),
          validator: cocktailsValidator,
          loadCatalog: loadCatalog,
        ),
        const SizedBox(height: 8),
        field(
          controller: barDescCtrl,
          label: '$prefix.bar_description'.tr(),
          hint: '$prefix.bar_description_hint'.tr(),
        ),
        const SizedBox(height: 8),
        field(
          controller: shotsCtrl,
          label: '$prefix.shots'.tr(),
          hint: '$prefix.shots_hint'.tr(),
        ),
      ],
    );
  }
}

/// Employee filter chips (offer: own section; invoice: inside extra hours).
class EmployeeChips extends StatelessWidget {
  const EmployeeChips({
    super.key,
    required this.employees,
    required this.selected,
    required this.onToggle,
  });

  final List<Employee> employees;
  final Set<String> selected;
  final void Function(String name, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Text(
        'orders.no_employees_available'.tr(),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: employees.map((employee) {
        final isSelected = selected.contains(employee.name);
        return FilterChip(
          selected: isSelected,
          label: Text(employee.name),
          avatar: CircleAvatar(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          onSelected: (value) => onToggle(employee.name, value),
        );
      }).toList(),
    );
  }
}
