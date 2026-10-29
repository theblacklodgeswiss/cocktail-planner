import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import 'settings_widgets.dart';

enum MicrosoftStatus { needsReload, notConfigured, connected, disconnected }

/// Pure view of the Microsoft/OneDrive card; the screen owns the logic.
class MicrosoftSection extends StatelessWidget {
  const MicrosoftSection({
    super.key,
    required this.status,
    this.name,
    this.email,
    required this.onReload,
    required this.onSetup,
    required this.onConnect,
    required this.onDisconnect,
  });

  final MicrosoftStatus status;
  final String? name;
  final String? email;
  final VoidCallback onReload;
  final VoidCallback onSetup;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final connected = status == MicrosoftStatus.connected;
    return KeyedSubtree(
      key: const Key('settings-microsoft'),
      child: SettingsGroup(
        caption: 'settings.microsoft_section'.tr(),
        captionTrailing: connected
            ? Icon(
                Icons.check_circle,
                size: AppSize.glassButtonIcon,
                color: p.goldText,
              )
            : null,
        children: [
          switch (status) {
            MicrosoftStatus.needsReload => SettingsRow(
              icon: Icons.refresh,
              title: 'settings.microsoft_reload_title'.tr(),
              subtitle: 'settings.microsoft_reload_message'.tr(),
              chevron: true,
              onTap: onReload,
            ),
            MicrosoftStatus.notConfigured => SettingsRow(
              icon: Icons.settings,
              title: 'settings.microsoft_not_configured'.tr(),
              subtitle: 'settings.microsoft_setup_hint'.tr(),
              chevron: true,
              onTap: onSetup,
            ),
            MicrosoftStatus.connected => SettingsRow(
              icon: Icons.account_circle,
              title: name ?? 'settings.microsoft_connected'.tr(),
              subtitle: email ?? '',
              trailing: TextAction(
                label: 'settings.microsoft_disconnect'.tr(),
                onPressed: onDisconnect,
              ),
            ),
            MicrosoftStatus.disconnected => SettingsRow(
              icon: Icons.login,
              title: 'settings.microsoft_connect'.tr(),
              subtitle: 'settings.microsoft_connect_hint'.tr(),
              chevron: true,
              onTap: onConnect,
            ),
          },
        ],
      ),
    );
  }
}
