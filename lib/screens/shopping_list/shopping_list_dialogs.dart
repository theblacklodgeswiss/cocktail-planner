import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/currency.dart';

/// Shows the distance input dialog.
/// Returns the entered distance in kilometers, or null if cancelled.
Future<int?> showDistanceDialog(BuildContext context) async {
  final distanceController = TextEditingController();
  String? errorText;

  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('shopping.distance_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('shopping.distance_description'.tr()),
            const SizedBox(height: 16),
            TextField(
              controller: distanceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'shopping.distance_label'.tr(),
                hintText: 'shopping.distance_hint'.tr(),
                border: const OutlineInputBorder(),
                errorText: errorText,
                suffixText: 'km',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final km = int.tryParse(distanceController.text.trim());
              if (km == null) {
                setDialogState(
                  () => errorText = 'shopping.distance_error'.tr(),
                );
                return;
              }
              Navigator.pop(context, km);
            },
            child: Text('common.next'.tr()),
          ),
        ],
      ),
    ),
  );
}

/// Result from the export dialog.
typedef ExportDialogResult = ({
  String name,
  int personCount,
  String drinkerType,
  Currency currency,
});

/// Shows the export dialog for saving an order.
/// Returns the dialog result, or null if cancelled.
Future<ExportDialogResult?> showExportDialog(
  BuildContext context, {
  required int selectedItemCount,
  required double total,
}) async {
  final nameController = TextEditingController();
  final personCountController = TextEditingController();
  String drinkerType = 'normal';
  Currency selectedCurrency = defaultCurrency;
  String? nameError;
  String? personCountError;

  return showDialog<ExportDialogResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('shopping.save_order'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '$selectedItemCount ${'orders.articles'.tr()} • ${selectedCurrency.format(total)}'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'shopping.order_name_label'.tr(),
                  hintText: 'shopping.order_name_hint'.tr(),
                  border: const OutlineInputBorder(),
                  errorText: nameError,
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
                decoration: InputDecoration(
                  labelText: 'shopping.person_count_label'.tr(),
                  hintText: 'shopping.person_count_hint'.tr(),
                  border: const OutlineInputBorder(),
                  errorText: personCountError,
                ),
                onChanged: (_) {
                  if (personCountError != null) {
                    setDialogState(() => personCountError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('shopping.currency'.tr()),
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
              Text('shopping.drinker_type'.tr()),
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
              String? nameErr;
              String? personErr;
              if (name.isEmpty) nameErr = 'shopping.name_required'.tr();
              if (personCount <= 0) {
                personErr = 'shopping.person_count_error'.tr();
              }
              if (nameErr != null || personErr != null) {
                setDialogState(() {
                  nameError = nameErr;
                  personCountError = personErr;
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
                ),
              );
            },
            child: Text('shopping.generate_pdf'.tr()),
          ),
        ],
      ),
    ),
  );
}
