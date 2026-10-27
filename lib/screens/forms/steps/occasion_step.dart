import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/offer.dart' show EventType;
import '../../../ui/tokens.dart';
import '../order_form_state.dart';
import 'wizard_widgets.dart';

/// Service type values with their icon and label/description keys.
const List<(String, IconData, String)> kServiceTypes = [
  (
    'cocktail_barservice',
    Icons.celebration,
    'order_setup.service_cocktail_barservice',
  ),
  ('cocktail_service', Icons.local_bar, 'order_setup.service_cocktailservice'),
  ('mocktail_service', Icons.no_drinks, 'order_setup.service_mocktailservice'),
  ('bar_service', Icons.liquor, 'order_setup.service_barservice'),
];

/// Event types with icon and label key, in display order.
const List<(EventType, IconData, String)> kEventTypes = [
  (EventType.birthday, Icons.cake_outlined, 'offer.event_birthday'),
  (EventType.wedding, Icons.favorite_border, 'offer.event_wedding'),
  (EventType.company, Icons.business_center_outlined, 'offer.event_company'),
  (
    EventType.babyshower,
    Icons.child_friendly_outlined,
    'offer.event_babyshower',
  ),
  (EventType.other, Icons.celebration_outlined, 'offer.event_other'),
];

/// Drinker types with icon and label key.
const List<(String, IconData, String)> kDrinkerTypes = [
  ('light', Icons.local_drink, 'order_setup.drinker_light'),
  ('normal', Icons.local_bar, 'order_setup.drinker_normal'),
  ('heavy', Icons.sports_bar, 'order_setup.drinker_heavy'),
];

/// Step 0 "Was feiern wir?": service type, event type (required) and
/// drinker type.
class OccasionStep extends StatelessWidget {
  const OccasionStep({super.key, required this.form});

  final OrderFormState form;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            0,
            AppSpace.s4,
            AppSpace.s8,
          ),
          child: Text(
            'order_wizard.service_caption'.tr(),
            style: AppText.caption.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final (value, icon, key) in kServiceTypes)
          SelectCard(
            icon: icon,
            title: key.tr(),
            subtitle: '${key}_desc'.tr(),
            selected: form.serviceType == value,
            onTap: () => form.update(() => form.selectServiceType(value)),
          ),
        const SizedBox(height: AppSpace.s8),
        KeyedSubtree(
          key: form.fieldKeys[FormFieldId.eventType],
          child: WizardSection(
            caption: '${'offer.event_type'.tr()} *',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PillGroup(
                  children: [
                    for (final (type, icon, key) in kEventTypes)
                      SelectPill(
                        icon: icon,
                        label: key.tr(),
                        selected: form.selectedEventType == type,
                        // Single-select: tapping the selected pill clears it,
                        // tapping another one replaces it.
                        onTap: () => form.update(
                          () => form.selectedEventType =
                              form.selectedEventType == type ? null : type,
                        ),
                      ),
                  ],
                ),
                FieldHint(form.visibleHint(FormFieldId.eventType)),
              ],
            ),
          ),
        ),
        WizardSection(
          caption: 'order_wizard.drinker_caption'.tr(),
          child: PillGroup(
            children: [
              for (final (value, icon, key) in kDrinkerTypes)
                SelectPill(
                  icon: icon,
                  label: key.tr(),
                  selected: form.drinkerType == value,
                  onTap: () => form.update(() => form.drinkerType = value),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
