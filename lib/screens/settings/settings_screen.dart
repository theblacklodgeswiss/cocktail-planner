import 'dart:js_interop';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/settings_repository.dart';
import '../../services/auth_service.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/user_preferences_service.dart';

@JS('window.location.reload')
external void _jsReload();

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
        if (kIsWeb && authService.isAdmin) ...[
          const SizedBox(height: 16),
          _buildMicrosoftSection(),
        ],
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

  Widget _buildMicrosoftSection() {
    final isConfigured = microsoftGraphService.isConfigured;
    final isLoggedIn = microsoftGraphService.isLoggedIn;
    final account = microsoftGraphService.getAccount();
    
    // Check if Firestore has config but MSAL didn't pick it up yet
    final firestoreClientId = settingsRepository.current.microsoftClientId;
    final hasFirestoreConfig = firestoreClientId != null && firestoreClientId.isNotEmpty;
    final needsReload = hasFirestoreConfig && !isConfigured;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'settings.microsoft_section'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Icon(
                  isLoggedIn ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: isLoggedIn ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
          if (needsReload)
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: Text('settings.microsoft_reload_title'.tr()),
              subtitle: Text('settings.microsoft_reload_message'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _reloadPage,
            )
          else if (!isConfigured)
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.orange),
              title: Text('settings.microsoft_not_configured'.tr()),
              subtitle: Text('settings.microsoft_setup_hint'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showClientIdDialog,
            )
          else if (isLoggedIn)
            ListTile(
              leading: const Icon(Icons.account_circle, color: Colors.blue),
              title: Text(account?.name ?? 'settings.microsoft_connected'.tr()),
              subtitle: Text(account?.email ?? ''),
              trailing: TextButton(
                onPressed: _logoutMicrosoft,
                child: Text('settings.microsoft_disconnect'.tr()),
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.login),
              title: Text('settings.microsoft_connect'.tr()),
              subtitle: Text('settings.microsoft_connect_hint'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _loginMicrosoft,
            ),
        ],
      ),
    );
  }

  Future<void> _showClientIdDialog() async {
    final clientIdController = TextEditingController();
    final tenantIdController = TextEditingController(text: 'common');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.microsoft_setup'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.microsoft_setup_description'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: clientIdController,
                decoration: InputDecoration(
                  labelText: 'Client ID *',
                  hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tenantIdController,
                decoration: InputDecoration(
                  labelText: 'Tenant ID',
                  hintText: 'common',
                  border: const OutlineInputBorder(),
                  helperText: 'settings.microsoft_tenant_hint'.tr(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              if (clientIdController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );

    if (result == true && clientIdController.text.trim().isNotEmpty) {
      final clientId = clientIdController.text.trim();
      final tenantId = tenantIdController.text.trim().isEmpty 
          ? 'common' 
          : tenantIdController.text.trim();

      clientIdController.dispose();
      tenantIdController.dispose();

      // Save to Firestore
      try {
        final currentSettings = settingsRepository.current;
        await settingsRepository.save(currentSettings.copyWith(
          microsoftClientId: clientId,
          microsoftTenantId: tenantId,
        ));
      } catch (e) {
        debugPrint('Failed to save to Firestore: $e');
      }

      // Also save to localStorage for MSAL (synchronous read)
      final success = microsoftGraphService.setClientId(
        clientId,
        tenantId: tenantId,
      );

      if (!mounted) return;

      if (success) {
        // Show reload dialog
        final reload = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('settings.microsoft_reload_title'.tr()),
            content: Text('settings.microsoft_reload_message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('settings.microsoft_reload_button'.tr()),
              ),
            ],
          ),
        );

        if (reload == true && mounted) {
          // Reload the page
          _reloadPage();
        }
      }
    } else {
      clientIdController.dispose();
      tenantIdController.dispose();
    }
  }

  void _reloadPage() {
    if (kIsWeb) {
      // Use JavaScript to reload
      _jsReload();
    }
  }

  Future<void> _loginMicrosoft() async {
    final account = await microsoftGraphService.login();
    if (!mounted) return;
    if (account != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.microsoft_connected'.tr())),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.microsoft_connect_failed'.tr())),
      );
    }
  }

  Future<void> _logoutMicrosoft() async {
    await microsoftGraphService.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings.microsoft_disconnected'.tr())),
    );
    setState(() {});
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
          if (authService.canManageUsers) ...[            ListTile(
              leading: const Icon(Icons.people),
              title: Text('drawer.users_title'.tr()),
              subtitle: Text('drawer.users_subtitle'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/users'),
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: Text('admin.tab_employees'.tr()),
              subtitle: Text('admin.employees_subtitle'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/employees'),
            ),
          ],
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
