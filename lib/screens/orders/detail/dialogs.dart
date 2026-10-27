import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../inventory/inventory_rows.dart' show formatQuantity;
import '../../shopping_list/completion_deduction.dart';

/// "Auftrag abschliessen?" - true when confirmed.
Future<bool?> showCompleteConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('orders.complete_confirm_title'.tr()),
      content: Text('orders.complete_confirm_msg'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('orders.complete'.tr()),
        ),
      ],
    ),
  );
}

/// Confirmation before accepting an offer - true when confirmed.
Future<bool?> showAcceptConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('invoice.confirm_save_title'.tr()),
      content: Text('invoice.confirm_save_msg'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('common.save'.tr()),
        ),
      ],
    ),
  );
}

/// Shows a dialog to enter why the order is declined, prefilled with
/// [initial]. Returns the trimmed reason (possibly empty), or null if the
/// dialog was cancelled.
Future<String?> showDeclineReasonDialog(
  BuildContext context, {
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('orders.decline_reason_title'.tr()),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'orders.decline_reason'.tr(),
          hintText: 'orders.decline_reason_hint'.tr(),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text('common.save'.tr()),
        ),
      ],
    ),
  );
  controller.dispose();
  return reason;
}

/// Shortfalls / unresolved items of a stock deduction. Shown right after
/// booking and awaited: it is the only record of a shortfall.
Future<void> showStockSummaryDialog(
  BuildContext context,
  OrderDeductionPlan plan,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('orders.stock_summary_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in plan.shortfalls)
              Text(
                'orders.stock_shortfall_line'.tr(
                  namedArgs: {
                    'name': s.name,
                    'qty': formatQuantity(s.quantity),
                  },
                ),
              ),
            for (final name in plan.unresolved)
              Text(
                'orders.stock_unresolved_line'.tr(namedArgs: {'name': name}),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('common.ok'.tr()),
        ),
      ],
    ),
  );
}

/// "Bestehende Einkaufsliste ersetzen?" before regenerating with Claude.
Future<bool?> showClaudeResetConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('orders.claude_reset_confirm_title'.tr()),
      content: Text('orders.claude_reset_confirm_message'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('orders.claude_reset_confirm'.tr()),
        ),
      ],
    ),
  );
}

/// Non-dismissible loading dialog with a seconds counter while Claude
/// generates. Not awaited; the caller pops it.
void showClaudeGeneratingDialog(
  BuildContext context,
  ValueNotifier<int> secondsNotifier,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('orders.claude_generating'.tr()),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: secondsNotifier,
            builder: (_, s, _) => Text(
              '${s}s',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Delete confirmation. Keeps the dialog open with a spinner on the delete
/// button until [delete] resolves, instead of popping immediately and
/// performing the Firestore write invisibly behind a closed dialog. Returns
/// true once deleted.
Future<bool?> showDeleteOrderDialog(
  BuildContext context, {
  required String orderName,
  required Future<bool> Function() delete,
}) {
  bool saving = false;
  String? error;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('orders.delete_confirm_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'orders.delete_confirm_message'.tr(
                namedArgs: {'name': orderName},
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setDialogState(() {
                      saving = true;
                      error = null;
                    });
                    final success = await delete();
                    if (success) {
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } else {
                      setDialogState(() {
                        saving = false;
                        error = 'orders.delete_failed'.tr();
                      });
                    }
                  },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('common.delete'.tr()),
          ),
        ],
      ),
    ),
  );
}
