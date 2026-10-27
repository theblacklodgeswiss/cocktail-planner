import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/tokens.dart';
import 'settings_widgets.dart';

/// Admin entries; users/employees/services only when [canManageUsers].
class AdminSection extends StatelessWidget {
  const AdminSection({super.key, required this.canManageUsers});

  final bool canManageUsers;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return KeyedSubtree(
      key: const Key('settings-admin-card'),
      child: SettingsGroup(
        caption: 'settings.admin_section'.tr(),
        captionTrailing: Text(
          'settings.admin_badge'.tr(),
          style: AppText.pill.copyWith(color: p.goldText),
        ),
        children: [
          SettingsRow(
            key: const Key('settings-admin-settings'),
            icon: Icons.tune,
            title: 'settings.distance_section'.tr(),
            subtitle: 'settings.admin_settings_subtitle'.tr(),
            chevron: true,
            onTap: () => context.push('/settings/admin'),
          ),
          if (canManageUsers) ...[
            SettingsRow(
              key: const Key('settings-users'),
              icon: Icons.people,
              title: 'drawer.users_title'.tr(),
              subtitle: 'drawer.users_subtitle'.tr(),
              chevron: true,
              onTap: () => context.push('/settings/users'),
            ),
            SettingsRow(
              key: const Key('settings-employees'),
              icon: Icons.badge,
              title: 'admin.tab_employees'.tr(),
              subtitle: 'admin.employees_subtitle'.tr(),
              chevron: true,
              onTap: () => context.push('/settings/employees'),
            ),
            SettingsRow(
              key: const Key('settings-services'),
              icon: Icons.room_service,
              title: 'admin.tab_services'.tr(),
              subtitle: 'admin.services_subtitle'.tr(),
              chevron: true,
              onTap: () => context.push('/settings/services'),
            ),
          ],
        ],
      ),
    );
  }
}
