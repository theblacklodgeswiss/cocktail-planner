import 'package:cocktail_planer/data/stock_repository.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Returns the current user's storage location. If none exists yet, asks for
/// a name once and creates it. Returns null if the dialog was cancelled.
Future<StorageLocation?> ensureOwnLocation(BuildContext context) async {
  final existing = await stockRepository.ownLocation();
  if (existing != null) return existing;
  if (!context.mounted) return null;
  final name = await _askLocationName(context, authService.displayName ?? '');
  if (name == null) return null;
  return stockRepository.createLocation(name, ownerEmail: authService.email);
}

/// Returns the trimmed, non-empty name or null if the dialog was cancelled.
Future<String?> _askLocationName(
  BuildContext context,
  String suggestion,
) async {
  final controller = TextEditingController(text: suggestion);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('stock.location_prompt_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('stock.location_prompt_hint'.tr()),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'stock.location_name'.tr(),
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setState(() => error = 'stock.location_name_required'.tr());
                  return;
                }
                Navigator.of(ctx).pop(value);
              },
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  return name;
}
