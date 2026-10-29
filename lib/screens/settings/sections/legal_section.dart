import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'settings_widgets.dart';

/// Links to imprint, terms and privacy.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      caption: 'settings.legal_section'.tr(),
      children: [
        SettingsRow(
          icon: Icons.business,
          title: 'legal.imprint_title'.tr(),
          chevron: true,
          onTap: () => context.push('/settings/legal/imprint'),
        ),
        SettingsRow(
          icon: Icons.description,
          title: 'legal.terms_title'.tr(),
          chevron: true,
          onTap: () => context.push('/settings/legal/terms'),
        ),
        SettingsRow(
          icon: Icons.privacy_tip,
          title: 'legal.privacy_title'.tr(),
          chevron: true,
          onTap: () => context.push('/settings/legal/privacy'),
        ),
      ],
    );
  }
}
