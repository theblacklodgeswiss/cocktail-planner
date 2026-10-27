import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/pressable.dart';
import '../../../utils/currency.dart';
import '../order_form_state.dart';
import 'wizard_widgets.dart';

/// Step 1 "Wann und wo?": date, time, address (+ distance), guest count
/// and currency.
class ScheduleStep extends StatelessWidget {
  const ScheduleStep({
    super.key,
    required this.form,
    required this.isEmployeeOrHigher,
  });

  final OrderFormState form;

  /// Staff get the distance slider, guests the read-only computed value.
  final bool isEmployeeOrHigher;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasPrefillInfo) _PrefillInfo(form: form),
        WizardSection(
          caption: 'order_wizard.when_caption'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: form.fieldKeys[FormFieldId.eventDate],
                child: PickerRow(
                  icon: Icons.calendar_today,
                  label: '${'order_setup.event_date_label'.tr()} *',
                  value: form.eventDate == null
                      ? null
                      : DateFormat(
                          'EEEE, dd. MMMM yyyy',
                        ).format(form.eventDate!),
                  placeholder: 'order_setup.event_date_hint'.tr(),
                  onTap: () => _pickDate(context),
                ),
              ),
              FieldHint(form.visibleHint(FormFieldId.eventDate)),
              Divider(height: AppSpace.s16, color: p.border),
              KeyedSubtree(
                key: form.fieldKeys[FormFieldId.eventTime],
                child: PickerRow(
                  icon: Icons.access_time,
                  label: '${'order_setup.event_time_label'.tr()} *',
                  value: form.eventTime?.format(context),
                  placeholder: 'order_setup.event_time_hint'.tr(),
                  onTap: () => _pickTime(context),
                ),
              ),
              FieldHint(form.visibleHint(FormFieldId.eventTime)),
            ],
          ),
        ),
        WizardSection(
          caption: 'order_wizard.where_caption'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: form.fieldKeys[FormFieldId.address],
                child: WizardTextField(
                  controller: form.addressController,
                  focusNode: form.addressFocus,
                  label: '${'order_setup.address_label'.tr()} *',
                  hintText: 'order_setup.address_hint'.tr(),
                  errorKey: form.visibleHint(FormFieldId.address),
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.fullStreetAddress],
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              isEmployeeOrHigher
                  ? _distanceSlider(context)
                  : _distanceDisplay(context),
            ],
          ),
        ),
        WizardSection(
          caption: 'order_wizard.guests_caption'.tr(),
          child: _personCountSlider(context),
        ),
        WizardSection(
          caption: 'order_wizard.currency_caption'.tr(),
          child: PillGroup(
            children: [
              for (final currency in Currency.values)
                SelectPill(
                  label: currency.code,
                  selected: form.currency == currency.code,
                  onTap: () => form.update(() => form.currency = currency.code),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasPrefillInfo {
    final order = form.prefillOrder;
    return order != null &&
        (order.location.isNotEmpty || order.guestCountRange.isNotEmpty);
  }

  Widget _valueRow(
    BuildContext context,
    String label,
    String value, {
    Widget? trailing,
  }) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
        ),
        ?trailing,
        const SizedBox(width: AppSpace.s8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.number.copyWith(color: p.text),
          ),
        ),
      ],
    );
  }

  Widget _personCountSlider(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _valueRow(
          context,
          'order_setup.person_count_label'.tr(),
          '${form.personCount}',
        ),
        Slider(
          value: form.personCount.toDouble(),
          min: 50,
          max: 1000,
          divisions: 19,
          label: '${form.personCount}',
          onChanged: (value) {
            HapticFeedback.selectionClick();
            form.update(() => form.personCount = value.round());
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('50', style: AppText.caption.copyWith(color: p.textSecondary)),
            Text(
              '1000',
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _distanceSlider(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _valueRow(
          context,
          'order_setup.distance_label'.tr(),
          '${form.distanceKm} km',
        ),
        Slider(
          value: form.distanceKm.toDouble(),
          min: 0,
          max: 1000,
          divisions: 50,
          label: '${form.distanceKm} km',
          onChanged: (value) {
            HapticFeedback.selectionClick();
            form.update(() => form.distanceKm = value.round());
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0 km',
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
            Text(
              '1000 km',
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  /// Read-only distance for guests, computed from the address (see the
  /// debounced address listener in the screen's `initState`).
  Widget _distanceDisplay(BuildContext context) {
    return _valueRow(
      context,
      'order_setup.distance_label'.tr(),
      form.distanceLookupPending
          ? 'order_setup.distance_calculating'.tr()
          : '${form.distanceKm} km',
      trailing: InfoButton(
        tooltip: 'order_setup.distance_info'.tr(),
        title: 'order_setup.distance_info_title'.tr(),
        message: 'order_setup.distance_info_message'.tr(),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    var initial = form.eventDate ?? now;
    // A prefilled date may lie outside the bookable window; widen the
    // window instead of tripping the picker's range assertion.
    final minDate = initial.isBefore(now) ? initial : now;
    final maxCandidate = now.add(const Duration(days: 730));
    final maxDate = initial.isAfter(maxCandidate) ? initial : maxCandidate;
    final picked = await _showPickerSheet<DateTime>(
      context,
      title: 'order_setup.event_date_label'.tr(),
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: initial,
        minimumDate: minDate,
        maximumDate: maxDate,
        onDateTimeChanged: (value) => initial = value,
      ),
      result: () => initial,
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      form.update(() => form.eventDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    HapticFeedback.lightImpact();
    final start = form.eventTime ?? const TimeOfDay(hour: 18, minute: 0);
    var selected = DateTime(2000, 1, 1, start.hour, start.minute);
    final picked = await _showPickerSheet<TimeOfDay>(
      context,
      title: 'order_setup.event_time_label'.tr(),
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: selected,
        use24hFormat: true,
        onDateTimeChanged: (value) => selected = value,
      ),
      result: () => TimeOfDay(hour: selected.hour, minute: selected.minute),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      form.update(() => form.eventTime = picked);
    }
  }

  /// A sheet with [picker], OK and cancel; resolves to [result] on OK.
  Future<T?> _showPickerSheet<T>(
    BuildContext context, {
    required String title,
    required Widget picker,
    required T Function() result,
  }) {
    return showAppSheet<T>(
      context,
      builder: (sheet) {
        final p = AppPalette.of(sheet);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.heroTitle.copyWith(color: p.text)),
            SizedBox(height: AppSize.pickerHeight, child: picker),
            const SizedBox(height: AppSpace.s16),
            PrimaryButton(
              label: 'common.ok'.tr(),
              onPressed: () => Navigator.of(sheet).pop(result()),
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
  }
}

/// Staff prefill: the form order's location (opens a route in Google Maps)
/// and its guest-count range with the derived mean.
class _PrefillInfo extends StatelessWidget {
  const _PrefillInfo({required this.form});

  final OrderFormState form;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final order = form.prefillOrder!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: FloatingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (order.location.isNotEmpty)
              Pressable(
                minSize: AppSize.minTap,
                onTap: () {
                  final origin = Uri.encodeComponent('Allschwil, 4123');
                  final dest = Uri.encodeComponent(order.location);
                  launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=driving',
                    ),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: AppSize.rowIcon,
                      color: p.text,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        order.location,
                        style: AppText.body.copyWith(
                          color: p.text,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new,
                      size: AppSpace.s16,
                      color: p.textSecondary,
                    ),
                  ],
                ),
              ),
            if (order.guestCountRange.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: AppSize.rowIcon,
                      color: p.textSecondary,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        'order_wizard.prefill_guest_range'.tr(
                          args: [order.guestCountRange, '${form.personCount}'],
                        ),
                        style: AppText.body.copyWith(color: p.textSecondary),
                      ),
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
