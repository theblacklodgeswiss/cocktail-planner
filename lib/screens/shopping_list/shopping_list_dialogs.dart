import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/currency.dart';

/// Result from the initial setup dialog (master data).
typedef InitialSetupResult = ({
  String name,
  int personCount,
  String drinkerType,
  Currency currency,
  int distanceKm,
});

/// Shows the initial setup dialog for all master data.
/// This is shown at the beginning of the shopping list wizard.
Future<InitialSetupResult?> showInitialSetupDialog(
  BuildContext context, {
  String? prefilledName,
  int? prefilledPersonCount,
}) async {
  final nameController = TextEditingController(text: prefilledName ?? '');
  final personCountController = TextEditingController(
    text: prefilledPersonCount != null && prefilledPersonCount > 0
        ? prefilledPersonCount.toString()
        : '',
  );
  final distanceController = TextEditingController();
  String drinkerType = 'normal';
  Currency selectedCurrency = defaultCurrency;
  String? nameError;
  String? personCountError;
  String? distanceError;

  return showDialog<InitialSetupResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('shopping.setup_title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'shopping.setup_description'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'shopping.order_name_label'.tr(),
                  hintText: 'shopping.order_name_hint'.tr(),
                  errorText: nameError,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                autofocus: true,
                onChanged: (_) {
                  if (nameError != null) {
                    setDialogState(() => nameError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: personCountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'shopping.person_count_label'.tr(),
                  hintText: 'shopping.person_count_hint'.tr(),
                  errorText: personCountError,
                  prefixIcon: const Icon(Icons.people_outlined),
                ),
                onChanged: (_) {
                  if (personCountError != null) {
                    setDialogState(() => personCountError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: distanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'shopping.distance_label'.tr(),
                  hintText: 'shopping.distance_hint'.tr(),
                  errorText: distanceError,
                  prefixIcon: const Icon(Icons.directions_car_outlined),
                  suffixText: 'km',
                ),
                onChanged: (_) {
                  if (distanceError != null) {
                    setDialogState(() => distanceError = null);
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                'shopping.currency'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<Currency>(
                segments: Currency.values
                    .map((c) => ButtonSegment(
                          value: c,
                          label: Text(c.code),
                        ))
                    .toList(),
                selected: {selectedCurrency},
                onSelectionChanged: (v) =>
                    setDialogState(() => selectedCurrency = v.first),
              ),
              const SizedBox(height: 16),
              Text(
                'shopping.drinker_type'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'light',
                    label: Text('orders.drinker_light'.tr()),
                    icon: const Icon(Icons.local_drink),
                  ),
                  ButtonSegment(
                    value: 'normal',
                    label: Text('orders.drinker_normal'.tr()),
                    icon: const Icon(Icons.local_bar),
                  ),
                  ButtonSegment(
                    value: 'heavy',
                    label: Text('orders.drinker_heavy'.tr()),
                    icon: const Icon(Icons.sports_bar),
                  ),
                ],
                selected: {drinkerType},
                onSelectionChanged: (v) =>
                    setDialogState(() => drinkerType = v.first),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final personCount =
                  int.tryParse(personCountController.text.trim()) ?? 0;
              final distanceKm =
                  int.tryParse(distanceController.text.trim()) ?? -1;

              String? nameErr;
              String? personErr;
              String? distErr;
              if (name.isEmpty) nameErr = 'shopping.name_required'.tr();
              if (personCount <= 0) {
                personErr = 'shopping.person_count_error'.tr();
              }
              if (distanceKm < 0) {
                distErr = 'shopping.distance_error'.tr();
              }
              if (nameErr != null || personErr != null || distErr != null) {
                setDialogState(() {
                  nameError = nameErr;
                  personCountError = personErr;
                  distanceError = distErr;
                });
                return;
              }
              Navigator.pop(
                context,
                (
                  name: name,
                  personCount: personCount,
                  drinkerType: drinkerType,
                  currency: selectedCurrency,
                  distanceKm: distanceKm,
                ),
              );
            },
            child: Text('common.next'.tr()),
          ),
        ],
      ),
    ),
  );
}

