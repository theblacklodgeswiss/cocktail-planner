import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/offer.dart' show EventType;
import '../../../utils/currency.dart';
import '../order_form_state.dart';

/// Step 3: guests, distance, currency, drinker type and event type.
class PreferencesStep extends StatelessWidget {
  const PreferencesStep({
    super.key,
    required this.form,
    required this.desktopActions,
    required this.isEmployeeOrHigher,
  });

  /// The shared wizard state (read for display, mutated via `update`).
  final OrderFormState form;

  /// Builds the desktop back/next row (only shown at width >= 600).
  final Widget Function() desktopActions;

  /// Staff get the distance slider, guests the read-only computed value.
  final bool isEmployeeOrHigher;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.preferences_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.preferences_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          if (form.prefillOrder != null &&
              (form.prefillOrder!.location.isNotEmpty ||
                  form.prefillOrder!.guestCountRange.isNotEmpty)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (form.prefillOrder!.location.isNotEmpty) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final origin = Uri.encodeComponent('Allschwil, 4123');
                        final dest = Uri.encodeComponent(
                          form.prefillOrder!.location,
                        );
                        launchUrl(
                          Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=driving',
                          ),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              form.prefillOrder!.location,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (form.prefillOrder!.location.isNotEmpty &&
                      form.prefillOrder!.guestCountRange.isNotEmpty)
                    const SizedBox(height: 8),
                  if (form.prefillOrder!.guestCountRange.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Formular: ${form.prefillOrder!.guestCountRange} Personen → Mittelwert: ${form.personCount}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          _buildPersonCountSlider(context),
          const SizedBox(height: 32),
          isEmployeeOrHigher
              ? _buildDistanceSlider(context)
              : _buildDistanceDisplay(context),
          const SizedBox(height: 32),
          _buildCurrencySelector(context),
          const SizedBox(height: 32),
          _buildDrinkerTypeSelector(context),
          const SizedBox(height: 32),
          _buildEventTypeSelector(context),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            desktopActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonCountSlider(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'order_setup.person_count_label'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${form.personCount}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
            Text('50', style: Theme.of(context).textTheme.bodySmall),
            Text('1000', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildDistanceSlider(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'order_setup.distance_label'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${form.distanceKm} km',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
            Text('0 km', style: Theme.of(context).textTheme.bodySmall),
            Text('1000 km', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  /// Read-only distance row shown to guest customers in place of the
  /// staff-only slider. The value is computed automatically from the
  /// address they entered earlier in the form (see the debounced listener
  /// on `form.addressController` in `initState`).
  Widget _buildDistanceDisplay(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'order_setup.distance_label'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              iconSize: 20,
              onPressed: () => _showDistanceInfo(context),
              tooltip: 'order_setup.distance_info'.tr(),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            form.distanceLookupPending
                ? 'order_setup.distance_calculating'.tr()
                : '${form.distanceKm} km',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencySelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.currency_label'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: Currency.values
              .map(
                (currency) => ButtonSegment<String>(
                  value: currency.code,
                  label: Text(currency.code),
                ),
              )
              .toList(growable: false),
          selected: {form.currency},
          onSelectionChanged: (values) {
            HapticFeedback.selectionClick();
            form.update(() => form.currency = values.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventTypeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'offer.event_type'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildEventTypeChip(
              context,
              EventType.birthday,
              Icons.cake_outlined,
              'offer.event_birthday'.tr(),
            ),
            _buildEventTypeChip(
              context,
              EventType.wedding,
              Icons.favorite_border,
              'offer.event_wedding'.tr(),
            ),
            _buildEventTypeChip(
              context,
              EventType.company,
              Icons.business_center_outlined,
              'offer.event_company'.tr(),
            ),
            _buildEventTypeChip(
              context,
              EventType.babyshower,
              Icons.child_friendly_outlined,
              'offer.event_babyshower'.tr(),
            ),
            _buildEventTypeChip(
              context,
              EventType.other,
              Icons.celebration_outlined,
              'offer.event_other'.tr(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventTypeChip(
    BuildContext context,
    EventType type,
    IconData icon,
    String label,
  ) {
    final isSelected = form.selectedEventType == type;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
      ),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        form.update(() {
          // Single-select: tapping the already-selected chip deselects it,
          // tapping another one replaces the selection - an event has one
          // occasion, unlike the admin offer screen's multi-select.
          form.selectedEventType = isSelected ? null : type;
        });
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildDrinkerTypeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.drinker_type_label'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildDrinkerChip(
              context,
              'light',
              Icons.local_drink,
              'order_setup.drinker_light'.tr(),
            ),
            _buildDrinkerChip(
              context,
              'normal',
              Icons.local_bar,
              'order_setup.drinker_normal'.tr(),
            ),
            _buildDrinkerChip(
              context,
              'heavy',
              Icons.sports_bar,
              'order_setup.drinker_heavy'.tr(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDrinkerChip(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) {
    final isSelected = form.drinkerType == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
      ),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        form.update(() => form.drinkerType = value);
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  void _showDistanceInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('order_setup.distance_info_title'.tr()),
        content: Text('order_setup.distance_info_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }
}
