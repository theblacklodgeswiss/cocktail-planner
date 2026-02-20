import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/settings_repository.dart';
import '../../models/app_settings.dart';
import '../../services/auth_service.dart';

/// Admin settings screen for configuring app-wide settings.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late TextEditingController _distanceController;
  bool _isLoading = true;
  bool _isSaving = false;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _distanceController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _distanceController.text = settings.longDistanceThresholdKm.toString();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final newThreshold = int.tryParse(_distanceController.text);
    if (newThreshold == null || newThreshold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.invalid_distance'.tr())),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newSettings = _settings.copyWith(longDistanceThresholdKm: newThreshold);
      await settingsRepository.save(newSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.saved'.tr())),
      );
      setState(() => _settings = newSettings);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.error'.tr())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!authService.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text('settings.admin_section'.tr()),
        ),
        body: Center(
          child: Text('admin.access_denied'.tr()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('settings.admin_section'.tr()),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'settings.distance_section'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'settings.distance_description'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _distanceController,
                  decoration: InputDecoration(
                    labelText: 'settings.long_distance_threshold'.tr(),
                    suffixText: 'km',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
