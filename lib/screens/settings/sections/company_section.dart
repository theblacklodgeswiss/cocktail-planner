import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/app_settings.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import 'settings_widgets.dart';

/// Company profile card with edit action.
class CompanySection extends StatelessWidget {
  const CompanySection({
    super.key,
    required this.settings,
    required this.onEdit,
  });

  final AppSettings settings;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final has = settings.companyName.isNotEmpty;
    final address = [
      settings.companyStreet,
      settings.companyCity,
    ].where((s) => s.isNotEmpty).join(', ');

    return KeyedSubtree(
      key: const Key('settings-company'),
      child: SettingsGroup(
        caption: 'settings.company_section'.tr(),
        children: [
          SettingsRow(
            icon: Icons.business,
            title: has
                ? settings.companyName
                : 'settings.company_section'.tr(),
            subtitle: has && settings.companyOwner.isNotEmpty
                ? settings.companyOwner
                : null,
            trailing: TextAction(
              label: 'common.edit'.tr(),
              onPressed: onEdit,
            ),
          ),
          if (!has)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'settings.company_empty'.tr(),
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  SecondaryButton(
                    label: 'settings.company_add'.tr(),
                    onPressed: onEdit,
                  ),
                ],
              ),
            )
          else ...[
            if (address.isNotEmpty)
              SettingsRow(icon: Icons.location_on_outlined, title: address),
            if (settings.companyPhone.isNotEmpty)
              SettingsRow(
                icon: Icons.phone_outlined,
                title: settings.companyPhone,
              ),
            if (settings.companyEmail.isNotEmpty)
              SettingsRow(
                icon: Icons.email_outlined,
                title: settings.companyEmail,
              ),
            if (settings.bankIban.isNotEmpty)
              SettingsRow(
                icon: Icons.account_balance_outlined,
                title: 'settings.iban'.tr(),
                subtitle: settings.bankIban,
                selectableSubtitle: true,
              ),
            if (settings.twintNumber.isNotEmpty)
              SettingsRow(
                icon: Icons.payment_outlined,
                title: 'settings.twint'.tr(),
                subtitle: settings.twintNumber,
                selectableSubtitle: true,
              ),
          ],
        ],
      ),
    );
  }
}
