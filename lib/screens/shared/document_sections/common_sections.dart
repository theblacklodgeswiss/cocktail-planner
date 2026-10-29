import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/employee.dart';
import '../../../models/offer.dart';
import '../../../models/order.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/hero_card.dart';
import '../../../utils/currency.dart';
import '../../forms/steps/wizard_widgets.dart';
import '../../offer/offer_form_state.dart' show formatDocumentDate;
import '../../offer/widgets/cocktail_chips_field.dart';
import 'document_field.dart';

/// Sections shared by the offer and invoice flows. [prefix] is the
/// translation group of the screen, 'offer' or 'invoice'.

/// Order name, date and request total (former info banner).
class DocumentOrderSummary extends StatelessWidget {
  const DocumentOrderSummary({
    super.key,
    required this.order,
    required this.currency,
  });

  final SavedOrder order;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: FloatingCard(
        child: Row(
          children: [
            Icon(Icons.receipt_long, size: AppSize.rowIcon, color: p.text),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.name, style: AppText.section.copyWith(color: p.text)),
                  Text(
                    '${formatDocumentDate(order.date)} • ${currency.format(order.total)}',
                    style: AppText.body.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Language (DE/EN), the offer's currency and the editor name.
class DocumentSettingsSection extends StatelessWidget {
  const DocumentSettingsSection({
    super.key,
    required this.prefix,
    required this.language,
    required this.onLanguage,
    required this.editorCtrl,
    required this.hints,
    this.currency,
    this.onCurrency,
  });

  final String prefix;
  final String language;
  final ValueChanged<String> onLanguage;
  final TextEditingController editorCtrl;
  final DocHints hints;
  final Currency? currency;
  final ValueChanged<Currency>? onCurrency;

  @override
  Widget build(BuildContext context) {
    return WizardSection(
      caption: 'docflow.document'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('docflow.language'.tr()),
          PillGroup(
            children: [
              for (final lang in const ['de', 'en'])
                SelectPill(
                  label: lang.toUpperCase(),
                  selected: language == lang,
                  onTap: () => onLanguage(lang),
                ),
            ],
          ),
          if (currency != null) ...[
            const SizedBox(height: AppSpace.s12),
            FieldLabel('docflow.currency'.tr()),
            PillGroup(
              children: [
                for (final c in Currency.values)
                  SelectPill(
                    label: c.code,
                    selected: currency == c,
                    onTap: () => onCurrency?.call(c),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: editorCtrl,
            label: '$prefix.editor_name'.tr(),
            hints: hints,
            field: 'editor',
          ),
        ],
      ),
    );
  }
}

/// Client name, contact and location (offer: all required; invoice: name).
class DocumentClientSection extends StatelessWidget {
  const DocumentClientSection({
    super.key,
    required this.prefix,
    required this.nameCtrl,
    required this.contactCtrl,
    required this.locationCtrl,
    required this.hints,
  });

  final String prefix;
  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController locationCtrl;
  final DocHints hints;

  @override
  Widget build(BuildContext context) {
    return WizardSection(
      caption: '$prefix.client'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocTextField(
            controller: nameCtrl,
            label: '$prefix.client_name'.tr(),
            hints: hints,
            field: 'client_name',
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: contactCtrl,
            label: '$prefix.client_contact'.tr(),
            hintText: '$prefix.client_contact_hint'.tr(),
            hints: hints,
            field: 'client_contact',
          ),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: locationCtrl,
            label: 'orders.location'.tr(),
            hintText: 'z.B. Musterstrasse 123, 3000 Bern',
            hints: hints,
            field: 'location',
            keyboardType: TextInputType.streetAddress,
          ),
        ],
      ),
    );
  }
}

/// Guest count, event time and date (date picked in a sheet).
class DocumentScheduleSection extends StatelessWidget {
  const DocumentScheduleSection({
    super.key,
    required this.prefix,
    required this.guestCountCtrl,
    required this.eventTimeCtrl,
    required this.eventDate,
    required this.onDateChanged,
    required this.hints,
  });

  final String prefix;
  final TextEditingController guestCountCtrl;
  final TextEditingController eventTimeCtrl;
  final DateTime eventDate;
  final ValueChanged<DateTime> onDateChanged;
  final DocHints hints;

  @override
  Widget build(BuildContext context) {
    return WizardSection(
      caption: 'docflow.schedule'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocTextField(
            controller: guestCountCtrl,
            label: '$prefix.guest_count'.tr(),
            hints: hints,
            field: 'guests',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: eventTimeCtrl,
            label: '$prefix.event_time'.tr(),
            hintText: '17:30',
            hints: hints,
            field: 'event_time',
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpace.s8),
          PickerRow(
            icon: Icons.calendar_today,
            label: '$prefix.event_date'.tr(),
            value: formatDocumentDate(eventDate),
            placeholder: 'docflow.pick_date'.tr(),
            onTap: () => _pickDate(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    var picked = eventDate;
    final first = DateTime(2020);
    final last = DateTime.now().add(const Duration(days: 1825));
    final result = await showAppSheet<DateTime>(
      context,
      builder: (sheet) {
        final p = AppPalette.of(sheet);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$prefix.event_date'.tr(),
              style: AppText.heroTitle.copyWith(color: p.text),
            ),
            SizedBox(
              height: AppSize.pickerHeight,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: eventDate,
                minimumDate: eventDate.isBefore(first) ? eventDate : first,
                maximumDate: eventDate.isAfter(last) ? eventDate : last,
                onDateTimeChanged: (v) => picked = v,
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            PrimaryButton(
              label: 'common.ok'.tr(),
              onPressed: () => Navigator.of(sheet).pop(picked),
            ),
            const SizedBox(height: AppSpace.s8),
            TextAction(
              label: 'ui.cancel'.tr(),
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        );
      },
    );
    if (result != null) onDateChanged(result);
  }
}

/// Event type pills with the "required" hint (offer).
class DocumentEventTypeSection extends StatelessWidget {
  const DocumentEventTypeSection({
    super.key,
    required this.prefix,
    required this.selected,
    required this.onChanged,
    required this.hints,
  });

  final String prefix;
  final Set<EventType> selected;
  final ValueChanged<Set<EventType>> onChanged;
  final DocHints hints;

  static const _types = [
    (EventType.birthday, 'offer.event_birthday'),
    (EventType.wedding, 'offer.event_wedding'),
    (EventType.company, 'offer.event_company'),
    (EventType.babyshower, 'offer.event_babyshower'),
    (EventType.other, 'offer.event_other'),
  ];

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: hints.anchorOf('event_type'),
      child: WizardSection(
        caption: '$prefix.event_type'.tr(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PillGroup(
              children: [
                for (final (type, key) in _types)
                  SelectPill(
                    label: key.tr(),
                    selected: selected.contains(type),
                    onTap: () {
                      final next = Set<EventType>.from(selected);
                      if (!next.remove(type)) next.add(type);
                      onChanged(next);
                    },
                  ),
              ],
            ),
            FieldHint(hints.hintOf('event_type')),
          ],
        ),
      ),
    );
  }
}

/// The four service types.
const serviceTypeOptions = [
  ('cocktail_barservice', 'orders.service_cocktail_bar'),
  ('cocktail_service', 'orders.service_cocktail_only'),
  ('mocktail_service', 'orders.service_mocktail_only'),
  ('bar_service', 'orders.service_bar_only'),
];

/// Service type pills; the offer adds the "positions follow" hint.
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
    final p = AppPalette.of(context);
    return WizardSection(
      caption: 'orders.service_type'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillGroup(
            children: [
              for (final (v, key) in serviceTypeOptions)
                SelectPill(
                  label: key.tr(),
                  selected: value == v,
                  onTap: () => onChanged(v),
                ),
            ],
          ),
          if (showHint) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              'offer.positions_manage_hint'.tr(),
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cocktails (chips + catalog search), bar description and shots.
class DocumentServicesSection extends StatelessWidget {
  const DocumentServicesSection({
    super.key,
    required this.prefix,
    required this.cocktailsCtrl,
    required this.barDescCtrl,
    required this.shotsCtrl,
    required this.hints,
    this.loadCatalog,
  });

  final String prefix;
  final TextEditingController cocktailsCtrl;
  final TextEditingController barDescCtrl;
  final TextEditingController shotsCtrl;
  final DocHints hints;
  final Future<List<String>> Function()? loadCatalog;

  @override
  Widget build(BuildContext context) {
    return WizardSection(
      caption: '$prefix.services'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: hints.anchorOf('cocktails'),
            child: CocktailChipsField(
              controller: cocktailsCtrl,
              label: '$prefix.cocktails'.tr(),
              loadCatalog: loadCatalog,
            ),
          ),
          FieldHint(hints.hintOf('cocktails')),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: barDescCtrl,
            label: '$prefix.bar_description'.tr(),
            hintText: '$prefix.bar_description_hint'.tr(),
          ),
          const SizedBox(height: AppSpace.s12),
          DocTextField(
            controller: shotsCtrl,
            label: '$prefix.shots'.tr(),
            hintText: '$prefix.shots_hint'.tr(),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

/// Employee selection as pills, with the "required" hint (invoice).
class DocumentEmployeesSection extends StatelessWidget {
  const DocumentEmployeesSection({
    super.key,
    required this.employees,
    required this.selected,
    required this.onToggle,
    required this.hints,
  });

  final List<Employee> employees;
  final Set<String> selected;
  final void Function(String name, bool selected) onToggle;
  final DocHints hints;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return KeyedSubtree(
      key: hints.anchorOf('employees'),
      child: WizardSection(
        caption: 'docflow.staff'.tr(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'invoice.select_employees'.tr(),
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpace.s8),
            if (employees.isEmpty)
              Text(
                'orders.no_employees_available'.tr(),
                style: AppText.body.copyWith(color: p.textSecondary),
              )
            else
              PillGroup(
                children: [
                  for (final e in employees)
                    SelectPill(
                      label: e.name,
                      selected: selected.contains(e.name),
                      onTap: () =>
                          onToggle(e.name, !selected.contains(e.name)),
                    ),
                ],
              ),
            FieldHint(hints.hintOf('employees')),
          ],
        ),
      ),
    );
  }
}

/// One position as a floating card: name, number, total, meta, remark and
/// 44 px edit/delete actions.
class DocPositionCard extends StatelessWidget {
  const DocPositionCard({
    super.key,
    required this.index,
    required this.position,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final ExtraPosition position;
  final Currency currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pos = position;
    final tbd = pos.quantity == 0;
    final meta = [
      if (pos.date.isNotEmpty) pos.date,
      '${'offer.position_quantity'.tr()}: ${tbdOr(tbd, '${pos.quantity}')}',
      '${'offer.position_price'.tr()}: ${tbdOr(tbd, currency.format(pos.price))}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: FloatingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${index + 1}',
                        style: AppText.caption.copyWith(color: p.textSecondary),
                      ),
                      Text(
                        pos.name,
                        style: AppText.section.copyWith(color: p.text),
                      ),
                    ],
                  ),
                ),
                DocIconAction(
                  icon: Icons.edit_outlined,
                  label: 'common.edit'.tr(),
                  onTap: onEdit,
                ),
                const SizedBox(width: AppSpace.s4),
                DocIconAction(
                  icon: Icons.delete_outline,
                  label: 'common.delete'.tr(),
                  destructive: true,
                  onTap: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              tbdOr(tbd, currency.format(pos.total)),
              style: AppText.number.copyWith(
                color: tbd ? p.textSecondary : p.text,
              ),
            ),
            Text(meta, style: AppText.caption.copyWith(color: p.textSecondary)),
            if (pos.remark.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s4),
              Text(pos.remark, style: AppText.body.copyWith(color: p.text)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one black card of the flow: the grand total on the last step.
class DocTotalHero extends StatelessWidget {
  const DocTotalHero({
    super.key,
    required this.label,
    required this.total,
    this.meta,
  });

  final String label;
  final String total;
  final String? meta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s16),
    child: HeroCard(
      kicker: label.toUpperCase(),
      title: total,
      titleStyle: AppText.display,
      meta: meta,
    ),
  );
}
