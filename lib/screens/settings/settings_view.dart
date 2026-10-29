import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_settings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import 'sections/about_section.dart';
import 'sections/admin_section.dart';
import 'sections/appearance_section.dart';
import 'sections/company_section.dart';
import 'sections/legal_section.dart';

/// Pure settings layout. Role flags and platform-specific pieces are injected
/// so the view carries no web/JS dependencies.
class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.appVersion,
    required this.buildNumber,
    required this.userId,
    required this.isAdmin,
    required this.canManageUsers,
    required this.themeMode,
    required this.onThemeMode,
    required this.onEditCompany,
    this.microsoft,
    this.company,
    this.onRefreshApp,
  });

  final String appVersion;
  final String buildNumber;
  final String userId;
  final bool isAdmin;
  final bool canManageUsers;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final VoidCallback onEditCompany;

  /// Microsoft card; only shown to admins (the caller passes it on web only).
  final Widget? microsoft;

  /// Company data; only shown to admins.
  final AppSettings? company;

  /// Web only.
  final VoidCallback? onRefreshApp;

  @override
  Widget build(BuildContext context) {
    return LargeTitleScaffold(
      title: 'settings.title'.tr(),
      leading: GlassIconButton(
        icon: Icons.arrow_back,
        semanticLabel: 'ui.back'.tr(),
        onPressed: () => context.pop(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverList.list(
            children: [
              AppearanceSection(
                themeMode: themeMode,
                onThemeMode: onThemeMode,
              ),
              if (isAdmin && microsoft != null) microsoft!,
              const LegalSection(),
              AboutSection(
                appVersion: appVersion,
                buildNumber: buildNumber,
                userId: userId,
                onRefreshApp: onRefreshApp,
              ),
              if (isAdmin) ...[
                AdminSection(canManageUsers: canManageUsers),
                if (company != null)
                  CompanySection(settings: company!, onEdit: onEditCompany),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
