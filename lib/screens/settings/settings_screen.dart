import 'dart:js_interop';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/settings_repository.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/states.dart';
import '../../services/auth_service.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/user_preferences_service.dart';
import 'sections/company_edit_sheet.dart';
import 'sections/microsoft_section.dart';
import 'sections/microsoft_setup_sheet.dart';
import 'settings_view.dart';

@JS('window.location.reload')
external void _jsReload();

@JS('eval')
external void _jsEval(String code);

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
    // Company data / Microsoft status / save() base read settingsRepository
    // synchronously: stay in the loading state until the startup load is done.
    await settingsRepository.awaitReady();
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
    if (_isLoading) {
      return LargeTitleScaffold(
        title: 'settings.title'.tr(),
        leading: GlassIconButton(
          icon: Icons.arrow_back,
          semanticLabel: 'ui.back'.tr(),
          onPressed: () => context.pop(),
        ),
        slivers: const [SliverFillRemaining(child: LoadingState())],
      );
    }
    final isAdmin = authService.isAdmin;
    return SettingsView(
      appVersion: _appVersion,
      buildNumber: _buildNumber,
      userId: authService.currentUser?.uid ?? '',
      isAdmin: isAdmin,
      canManageUsers: authService.canManageUsers,
      themeMode: userPreferencesService.themeMode,
      onThemeMode: (mode) {
        userPreferencesService.setThemeMode(mode);
        setState(() {});
      },
      microsoft: kIsWeb && isAdmin ? _buildMicrosoft() : null,
      company: isAdmin ? settingsRepository.current : null,
      onEditCompany: _showCompanyEdit,
      onRefreshApp: kIsWeb ? _refreshPwa : null,
    );
  }

  Widget _buildMicrosoft() {
    final isConfigured = microsoftGraphService.isConfigured;
    final isLoggedIn = microsoftGraphService.isLoggedIn;
    final account = microsoftGraphService.getAccount();

    // Firestore has the config but MSAL did not pick it up yet.
    final firestoreClientId = settingsRepository.current.microsoftClientId;
    final hasFirestoreConfig =
        firestoreClientId != null && firestoreClientId.isNotEmpty;
    final needsReload = hasFirestoreConfig && !isConfigured;

    final status = needsReload
        ? MicrosoftStatus.needsReload
        : !isConfigured
        ? MicrosoftStatus.notConfigured
        : isLoggedIn
        ? MicrosoftStatus.connected
        : MicrosoftStatus.disconnected;

    return MicrosoftSection(
      status: status,
      name: account?.name,
      email: account?.email,
      onReload: _reloadPage,
      onSetup: _showClientIdSheet,
      onConnect: _loginMicrosoft,
      onDisconnect: _logoutMicrosoft,
    );
  }

  Future<void> _showClientIdSheet() async {
    final result = await showMicrosoftSetupSheet(context);
    if (result == null) return;

    // Save to Firestore
    try {
      final currentSettings = settingsRepository.current;
      await settingsRepository.save(
        currentSettings.copyWith(
          microsoftClientId: result.clientId,
          microsoftTenantId: result.tenantId,
        ),
      );
    } catch (e) {
      debugPrint('Failed to save to Firestore: $e');
    }

    // Also save to localStorage for MSAL (synchronous read)
    final success = microsoftGraphService.setClientId(
      result.clientId,
      tenantId: result.tenantId,
    );

    if (!mounted) return;

    if (success) {
      final reload = await showMicrosoftReloadSheet(context);
      if (reload && mounted) _reloadPage();
    }
  }

  void _reloadPage() {
    if (kIsWeb) {
      _jsReload();
    }
  }

  Future<void> _refreshPwa() async {
    if (!kIsWeb) return;
    // Unregister all service workers, then hard-reload to fetch latest version
    _jsEval('''
      (async () => {
        if ('serviceWorker' in navigator) {
          const regs = await navigator.serviceWorker.getRegistrations();
          for (const reg of regs) { await reg.unregister(); }
        }
        window.location.reload(true);
      })();
    ''');
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

  Future<void> _showCompanyEdit() async {
    final updated = await showCompanyEditSheet(
      context,
      settingsRepository.current,
    );
    if (updated == null) return;
    await settingsRepository.save(updated);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.company_saved'.tr())),
      );
    }
  }
}
