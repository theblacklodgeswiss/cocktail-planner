import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'settings_widgets.dart';

/// Theme and language rows; both open a choice sheet.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  String _themeName(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'settings.theme_system'.tr(),
    ThemeMode.light => 'settings.theme_light'.tr(),
    ThemeMode.dark => 'settings.theme_dark'.tr(),
  };

  String _languageName(Locale locale) => switch (locale.languageCode) {
    'de' => 'settings.language_de'.tr(),
    'en' => 'settings.language_en'.tr(),
    _ => locale.languageCode,
  };

  Future<void> _pickTheme(BuildContext context) async {
    final chosen = await showSettingsChoiceSheet<ThemeMode>(
      context,
      title: 'settings.theme'.tr(),
      current: themeMode,
      choices: [
        SettingsChoice(
          value: ThemeMode.system,
          label: 'settings.theme_system'.tr(),
          icon: Icons.brightness_auto,
        ),
        SettingsChoice(
          value: ThemeMode.light,
          label: 'settings.theme_light'.tr(),
          icon: Icons.light_mode,
        ),
        SettingsChoice(
          value: ThemeMode.dark,
          label: 'settings.theme_dark'.tr(),
          icon: Icons.dark_mode,
        ),
      ],
    );
    if (chosen != null) onThemeMode(chosen);
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final chosen = await showSettingsChoiceSheet<String>(
      context,
      title: 'settings.language'.tr(),
      current: context.locale.languageCode,
      choices: [
        SettingsChoice(
          value: 'de',
          label: 'settings.language_de'.tr(),
          icon: Icons.language,
        ),
        SettingsChoice(
          value: 'en',
          label: 'settings.language_en'.tr(),
          icon: Icons.language,
        ),
      ],
    );
    if (chosen != null && context.mounted) {
      await context.setLocale(Locale(chosen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      caption: 'settings.appearance_section'.tr(),
      children: [
        SettingsRow(
          key: const Key('settings-theme'),
          icon: Icons.brightness_6,
          title: 'settings.theme'.tr(),
          subtitle: _themeName(themeMode),
          chevron: true,
          onTap: () => _pickTheme(context),
        ),
        SettingsRow(
          key: const Key('settings-language'),
          icon: Icons.language,
          title: 'settings.language'.tr(),
          subtitle: _languageName(context.locale),
          chevron: true,
          onTap: () => _pickLanguage(context),
        ),
      ],
    );
  }
}
