import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/auth_service.dart';
import '../../services/user_preferences_service.dart';

/// Settings screen for app configuration.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load package info
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    } catch (e) {
      _appVersion = '1.0.0';
      _buildNumber = '1';
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('settings.title'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSettingsList(),
    );
  }

  Widget _buildSettingsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAppearanceSection(),
        const SizedBox(height: 16),
        _buildLegalSection(),
        const SizedBox(height: 16),
        _buildAboutSection(),
        if (authService.isAdmin) ...[
          const SizedBox(height: 16),
          _buildAdminSection(),
        ],
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'settings.appearance_section'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // Theme Mode
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text('settings.theme'.tr()),
            subtitle: Text(_getThemeModeName(userPreferencesService.themeMode)),
            onTap: () => _showThemePicker(),
          ),
          // Language
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('settings.language'.tr()),
            subtitle: Text(_getLanguageName(context.locale)),
            onTap: () => _showLanguagePicker(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'settings.legal_section'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: Text('legal.imprint_title'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/legal/imprint'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: Text('legal.terms_title'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/legal/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text('legal.privacy_title'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/legal/privacy'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final userId = authService.currentUser?.uid ?? '';
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'settings.about_section'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('settings.app_version'.tr()),
            subtitle: SelectableText('$_appVersion ($_buildNumber)'),
          ),
          if (userId.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: Text('settings.user_id'.tr()),
              subtitle: SelectableText(
                userId,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'settings.admin_section'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text('settings.distance_section'.tr()),
            subtitle: Text('settings.admin_settings_subtitle'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/admin'),
          ),
          if (authService.canManageUsers)
            ListTile(
              leading: const Icon(Icons.people),
              title: Text('drawer.users_title'.tr()),
              subtitle: Text('drawer.users_subtitle'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/users'),
            ),
        ],
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'settings.theme_system'.tr();
      case ThemeMode.light:
        return 'settings.theme_light'.tr();
      case ThemeMode.dark:
        return 'settings.theme_dark'.tr();
    }
  }

  String _getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'de':
        return 'Deutsch';
      case 'en':
        return 'English';
      default:
        return locale.languageCode;
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text('settings.theme_system'.tr()),
              trailing: userPreferencesService.themeMode == ThemeMode.system
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                userPreferencesService.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text('settings.theme_light'.tr()),
              trailing: userPreferencesService.themeMode == ThemeMode.light
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                userPreferencesService.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text('settings.theme_dark'.tr()),
              trailing: userPreferencesService.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                userPreferencesService.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇩🇪', style: TextStyle(fontSize: 24)),
              title: const Text('Deutsch'),
              trailing: context.locale.languageCode == 'de'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                context.setLocale(const Locale('de'));
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: context.locale.languageCode == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                context.setLocale(const Locale('en'));
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
