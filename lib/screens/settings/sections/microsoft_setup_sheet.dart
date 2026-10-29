import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';

typedef MicrosoftSetup = ({String clientId, String tenantId});

/// Asks for the Azure client/tenant id; null when cancelled.
Future<MicrosoftSetup?> showMicrosoftSetupSheet(BuildContext context) =>
    showAppSheet<MicrosoftSetup>(
      context,
      builder: (sheet) => const _SetupForm(),
    );

/// Tells the admin that the page has to reload; true when confirmed.
Future<bool> showMicrosoftReloadSheet(BuildContext context) async {
  final ok = await showAppSheet<bool>(
    context,
    builder: (sheet) {
      final p = AppPalette.of(sheet);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'settings.microsoft_reload_title'.tr(),
            style: AppText.heroTitle.copyWith(color: p.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'settings.microsoft_reload_message'.tr(),
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpace.s24),
          PrimaryButton(
            label: 'settings.microsoft_reload_button'.tr(),
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

class _SetupForm extends StatefulWidget {
  const _SetupForm();

  @override
  State<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<_SetupForm> {
  final _client = TextEditingController();
  final _tenant = TextEditingController(text: 'common');

  @override
  void dispose() {
    _client.dispose();
    _tenant.dispose();
    super.dispose();
  }

  void _save() {
    final id = _client.text.trim();
    if (id.isEmpty) return;
    final tenant = _tenant.text.trim();
    Navigator.of(
      context,
    ).pop((clientId: id, tenantId: tenant.isEmpty ? 'common' : tenant));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'settings.microsoft_setup'.tr(),
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'settings.microsoft_setup_description'.tr(),
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s16),
        TextField(
          controller: _client,
          decoration: const InputDecoration(
            labelText: 'Client ID *',
            hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        TextField(
          controller: _tenant,
          decoration: InputDecoration(
            labelText: 'Tenant ID',
            hintText: 'common',
            helperText: 'settings.microsoft_tenant_hint'.tr(),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        PrimaryButton(label: 'common.save'.tr(), onPressed: _save),
        const SizedBox(height: AppSpace.s8),
        TextAction(
          label: 'common.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
