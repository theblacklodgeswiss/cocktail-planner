import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/offer.dart';

/// Selector widget for choosing event types.
class EventTypeSelector extends StatelessWidget {
  const EventTypeSelector({
    super.key,
    required this.selectedTypes,
    required this.onChanged,
  });

  final Set<EventType> selectedTypes;
  final void Function(Set<EventType>) onChanged;

  @override
  Widget build(BuildContext context) {
    final types = [
      (EventType.birthday, 'offer.event_birthday'.tr()),
      (EventType.wedding, 'offer.event_wedding'.tr()),
      (EventType.company, 'offer.event_company'.tr()),
      (EventType.babyshower, 'offer.event_babyshower'.tr()),
      (EventType.other, 'offer.event_other'.tr()),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: types.map((t) {
        final selected = selectedTypes.contains(t.$1);
        return FilterChip(
          label: Text(t.$2),
          selected: selected,
          onSelected: (val) {
            final newSet = Set<EventType>.from(selectedTypes);
            if (val) {
              newSet.add(t.$1);
            } else {
              newSet.remove(t.$1);
            }
            onChanged(newSet);
          },
        );
      }).toList(),
    );
  }
}
