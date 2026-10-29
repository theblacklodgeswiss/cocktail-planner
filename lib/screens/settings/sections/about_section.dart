import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/widgets/buttons.dart';
import 'settings_widgets.dart';

/// Version, user id and (web only) the app refresh action.
class AboutSection extends StatelessWidget {
  const AboutSection({
    super.key,
    required this.appVersion,
    required this.buildNumber,
    required this.userId,
    this.onRefreshApp,
  });

  final String appVersion;
  final String buildNumber;
  final String userId;

  /// Only offered on web; null hides the row.
  final VoidCallback? onRefreshApp;

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      caption: 'settings.about_section'.tr(),
      children: [
        SettingsRow(
          icon: Icons.info_outline,
          title: 'settings.app_version'.tr(),
          subtitle: '$appVersion ($buildNumber)',
          selectableSubtitle: true,
        ),
        if (userId.isNotEmpty)
          SettingsRow(
            icon: Icons.fingerprint,
            title: 'settings.user_id'.tr(),
            subtitle: userId,
            selectableSubtitle: true,
          ),
        if (onRefreshApp != null)
          SettingsRow(
            icon: Icons.refresh,
            title: 'settings.refresh_app'.tr(),
            subtitle: 'settings.refresh_app_hint'.tr(),
            trailing: SecondaryButton(
              label: 'settings.refresh_button'.tr(),
              onPressed: onRefreshApp,
            ),
          ),
      ],
    );
  }
}
