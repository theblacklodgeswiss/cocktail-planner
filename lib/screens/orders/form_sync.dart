import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/order_repository.dart';
import '../../services/microsoft_graph_service.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../settings/sections/settings_widgets.dart';

/// OneDrive / Microsoft Forms sync, shared by the orders app bar and "Mehr".
/// Moved unchanged out of `OrdersOverviewScreen`; [isSyncing] replaces the
/// screen's local flag so both places show the same state.
class FormSync extends ChangeNotifier {
  static const excelFileName = 'Cocktail- & Barservice Anftragformular.xlsx';
  static const oneDriveFormUrl =
      'https://1drv.ms/x/c/80c90daf53662538/IQAw81_OoMv4QpDZTEsq13cvAf3yftB-9O812MAPGRy6mfs?e=FfusWZ';

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  void _setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  void _showFailed(BuildContext context) {
    final p = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'orders.sync_failed'.tr(),
          style: TextStyle(color: p.onError),
        ),
        backgroundColor: p.error,
      ),
    );
  }

  void openOneDriveForm() {
    launchUrl(Uri.parse(oneDriveFormUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _loginAndSync(BuildContext context) async {
    final account = await microsoftGraphService.login();
    if (!context.mounted) return;
    if (account != null) {
      notifyListeners();
      sync(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders.sync_login_required'.tr())),
      );
    }
  }

  Future<void> sync(BuildContext context) async {
    if (!microsoftGraphService.isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('orders.sync_login_required'.tr()),
          content: Text('orders.sync_login_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: Text('orders.sync_login_button'.tr()),
              onPressed: () {
                Navigator.pop(ctx);
                _loginAndSync(context);
              },
            ),
          ],
        ),
      );
      return;
    }

    _setSyncing(true);

    try {
      // Read Excel data from OneDrive
      final rows = await microsoftGraphService.readExcelFromOneDrive(
        oneDrivePath: excelFileName,
        startRow: 2, // Skip header row
      );

      if (!context.mounted) return;

      if (rows == null) {
        _showFailed(context);
        return;
      }

      // Pass rows to repository for syncing
      final count = await orderRepository.syncFormSubmissions(rows: rows);
      if (!context.mounted) return;

      if (count == -1) {
        _showFailed(context);
      } else if (count == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('orders.sync_no_new'.tr())));
      } else {
        // The neutral palette has no green; success uses the default
        // snackbar.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.sync_success'.tr(args: [count.toString()])),
          ),
        );
      }
    } finally {
      _setSyncing(false);
    }
  }

  Future<void> resetAndSync(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('orders.reset_sync_title'.tr()),
        content: Text('orders.reset_sync_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('orders.reset_sync_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _setSyncing(true);

    try {
      // Delete all form submissions first
      final deletedCount = await orderRepository.deleteAllFormSubmissions();
      debugPrint('Deleted $deletedCount old form submissions');

      // Now sync fresh
      if (context.mounted) await sync(context);
    } finally {
      _setSyncing(false);
    }
  }
}

final formSync = FormSync();

/// The orders app-bar sync menu as a sheet (for "Mehr"): the Excel hint,
/// the OneDrive form link, sync and re-import. [context] must outlive the
/// sheet (it shows the snackbars and dialogs).
Future<void> showFormSyncSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (sheet) {
      final p = AppPalette.of(sheet);
      void run(VoidCallback action) {
        Navigator.of(sheet).pop();
        action();
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'more.form_sync'.tr(),
            style: AppText.heroTitle.copyWith(color: p.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'orders.sync_excel_hint'.tr(),
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpace.s12),
          SettingsRow(
            icon: Icons.table_chart_outlined,
            title: 'orders.sync_onedrive_form'.tr(),
            onTap: () => run(formSync.openOneDriveForm),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.sync,
            title: 'orders.sync_forms'.tr(),
            onTap: () => run(() => formSync.sync(context)),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: Icons.refresh,
            title: 'orders.reset_sync'.tr(),
            onTap: () => run(() => formSync.resetAndSync(context)),
          ),
        ],
      );
    },
  );
}
