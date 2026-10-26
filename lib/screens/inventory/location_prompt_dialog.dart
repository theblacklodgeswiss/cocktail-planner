import 'package:cocktail_planer/data/stock_repository.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'package:cocktail_planer/utils/shared_future.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

final _ensureOwnLocation = SharedFuture<StorageLocation?>();

/// Returns the current user's storage location. If none exists yet, asks for
/// a name once and creates it. Returns null if the dialog was cancelled.
/// Concurrent calls share one dialog.
Future<StorageLocation?> ensureOwnLocation(BuildContext context) {
  return _ensureOwnLocation.run(() => _ensure(context));
}

Future<StorageLocation?> _ensure(BuildContext context) async {
  final existing = await stockRepository.ownLocation();
  if (existing != null) return existing;
  if (!context.mounted) return null;
  final name = await showDialog<String>(
    context: context,
    builder: (_) =>
        _LocationNameDialog(suggestion: authService.displayName ?? ''),
  );
  if (name == null) return null;
  // A location may have been created while the dialog was open.
  final meanwhile = await stockRepository.ownLocation();
  if (meanwhile != null) return meanwhile;
  return stockRepository.createLocation(name, ownerEmail: authService.email);
}

class _LocationNameDialog extends StatefulWidget {
  const _LocationNameDialog({required this.suggestion});

  final String suggestion;

  @override
  State<_LocationNameDialog> createState() => _LocationNameDialogState();
}

class _LocationNameDialogState extends State<_LocationNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.suggestion,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'stock.location_name_required'.tr());
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('stock.location_prompt_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('stock.location_prompt_hint'.tr()),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'stock.location_name'.tr(),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(onPressed: _submit, child: Text('common.save'.tr())),
      ],
    );
  }
}
