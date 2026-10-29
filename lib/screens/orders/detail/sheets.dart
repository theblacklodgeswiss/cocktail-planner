import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../inventory/inventory_rows.dart' show formatQuantity;
import '../../shopping_list/completion_deduction.dart';

/// "Auftrag abschliessen?" - true when confirmed.
Future<bool> showCompleteConfirmSheet(BuildContext context) {
  return showConfirmSheet(
    context,
    title: 'orders.complete_confirm_title'.tr(),
    body: 'orders.complete_confirm_msg'.tr(),
    confirmLabel: 'orders.complete'.tr(),
  );
}

/// Confirmation before accepting an offer - true when confirmed.
Future<bool> showAcceptConfirmSheet(BuildContext context) {
  return showConfirmSheet(
    context,
    title: 'invoice.confirm_save_title'.tr(),
    body: 'invoice.confirm_save_msg'.tr(),
    confirmLabel: 'common.save'.tr(),
  );
}

/// "Bestehende Einkaufsliste ersetzen?" before regenerating with Claude.
Future<bool> showClaudeResetConfirmSheet(BuildContext context) {
  return showConfirmSheet(
    context,
    title: 'orders.claude_reset_confirm_title'.tr(),
    body: 'orders.claude_reset_confirm_message'.tr(),
    confirmLabel: 'orders.claude_reset_confirm'.tr(),
  );
}

/// Sheet to enter why the order is declined, prefilled with [initial].
/// Returns the trimmed reason (possibly empty), or null if cancelled or
/// dismissed. The form owns and disposes its text controller.
Future<String?> showDeclineReasonSheet(
  BuildContext context, {
  required String initial,
}) {
  return showAppSheet<String>(
    context,
    builder: (sheet) => _DeclineReasonForm(initial: initial),
  );
}

class _DeclineReasonForm extends StatefulWidget {
  const _DeclineReasonForm({required this.initial});

  final String initial;

  @override
  State<_DeclineReasonForm> createState() => _DeclineReasonFormState();
}

class _DeclineReasonFormState extends State<_DeclineReasonForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'orders.decline_reason_title'.tr(),
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s12),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'orders.decline_reason'.tr(),
            hintText: 'orders.decline_reason_hint'.tr(),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        PrimaryButton(
          label: 'common.save'.tr(),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
        const SizedBox(height: AppSpace.s8),
        TextAction(
          label: 'ui.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Date picker sheet (2020 - 2035); the result is a date without time, like
/// the former `showDatePicker`. Null when cancelled.
Future<DateTime?> showOrderDateSheet(
  BuildContext context, {
  required DateTime initial,
}) {
  final min = DateTime(2020);
  final max = DateTime(2035);
  var selected = DateTime(initial.year, initial.month, initial.day);
  if (selected.isBefore(min)) selected = min;
  if (selected.isAfter(max)) selected = max;
  final start = selected;
  return showAppSheet<DateTime>(
    context,
    builder: (sheet) {
      final p = AppPalette.of(sheet);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'order_detail.change_date'.tr(),
            style: AppText.heroTitle.copyWith(color: p.text),
          ),
          SizedBox(
            height: AppSize.pickerHeight,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: start,
              minimumDate: min,
              maximumDate: max,
              onDateTimeChanged: (v) => selected = v,
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          PrimaryButton(
            label: 'common.ok'.tr(),
            onPressed: () => Navigator.of(
              sheet,
            ).pop(DateTime(selected.year, selected.month, selected.day)),
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

/// Shortfalls / unresolved items of a stock deduction. Shown right after
/// booking and awaited: it is the only record of a shortfall.
Future<void> showStockSummarySheet(
  BuildContext context,
  OrderDeductionPlan plan,
) {
  return showAppSheet<void>(
    context,
    builder: (sheet) {
      final p = AppPalette.of(sheet);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'orders.stock_summary_title'.tr(),
            style: AppText.heroTitle.copyWith(color: p.text),
          ),
          const SizedBox(height: AppSpace.s12),
          for (final s in plan.shortfalls)
            Text(
              'orders.stock_shortfall_line'.tr(
                namedArgs: {'name': s.name, 'qty': formatQuantity(s.quantity)},
              ),
              style: AppText.body.copyWith(color: p.text),
            ),
          for (final name in plan.unresolved)
            Text(
              'orders.stock_unresolved_line'.tr(namedArgs: {'name': name}),
              style: AppText.body.copyWith(color: p.text),
            ),
          const SizedBox(height: AppSpace.s24),
          PrimaryButton(
            label: 'common.ok'.tr(),
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
      );
    },
  );
}

/// Non-dismissible loading dialog with a seconds counter while Claude
/// generates. Not awaited; the caller pops it. (A dialog, not a sheet: the
/// app sheet is always dismissible.)
void showClaudeGeneratingDialog(
  BuildContext context,
  ValueNotifier<int> secondsNotifier,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpace.s16),
              Text('orders.claude_generating'.tr()),
              const SizedBox(height: AppSpace.s8),
              ValueListenableBuilder<int>(
                valueListenable: secondsNotifier,
                builder: (_, s, _) => Text(
                  '${s}s',
                  style: AppText.body.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Delete confirmation. Keeps the sheet open with a spinner on the delete
/// button until [delete] resolves, instead of popping immediately and
/// performing the Firestore write invisibly behind a closed sheet. Returns
/// true once deleted.
Future<bool?> showDeleteOrderSheet(
  BuildContext context, {
  required String orderName,
  required Future<bool> Function() delete,
}) {
  return showAppSheet<bool>(
    context,
    builder: (sheet) => _DeleteOrderForm(orderName: orderName, delete: delete),
  );
}

class _DeleteOrderForm extends StatefulWidget {
  const _DeleteOrderForm({required this.orderName, required this.delete});

  final String orderName;
  final Future<bool> Function() delete;

  @override
  State<_DeleteOrderForm> createState() => _DeleteOrderFormState();
}

class _DeleteOrderFormState extends State<_DeleteOrderForm> {
  bool _saving = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await widget.delete();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = 'orders.delete_failed'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'orders.delete_confirm_title'.tr(),
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'orders.delete_confirm_message'.tr(
            namedArgs: {'name': widget.orderName},
          ),
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.s12),
          Text(_error!, style: AppText.body.copyWith(color: p.error)),
        ],
        const SizedBox(height: AppSpace.s24),
        PrimaryButton(
          label: 'common.delete'.tr(),
          destructive: true,
          loading: _saving,
          onPressed: _saving ? null : _delete,
        ),
        const SizedBox(height: AppSpace.s8),
        TextAction(
          label: 'ui.cancel'.tr(),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
