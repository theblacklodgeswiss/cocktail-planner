import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/settings_repository.dart';
import '../../models/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/claude_service.dart';
import '../../services/microsoft_graph_service.dart';

/// Admin settings screen for configuring app-wide settings.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late TextEditingController _distanceController;
  late TextEditingController _claudeKeyController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isImporting = false;
  AppSettings _settings = const AppSettings();
  bool _showClaudeKey = false;

  @override
  void initState() {
    super.initState();
    _distanceController = TextEditingController();
    _claudeKeyController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _claudeKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await settingsRepository.load();
    
    
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _distanceController.text = settings.longDistanceThresholdKm.toString();
      _claudeKeyController.text = settings.anthropicApiKey ?? '';
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
      final claudeKey = _claudeKeyController.text.trim();
      final newSettings = _settings.copyWith(
        longDistanceThresholdKm: newThreshold,
        anthropicApiKey: claudeKey.isNotEmpty ? claudeKey : null,
      );
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
        const SizedBox(height: 16),
        // Claude AI Settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'settings.claude_section'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (claudeService.isConfigured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'settings.claude_active'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'settings.claude_description'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (claudeService.isConfigured) ...[
                  _buildHistoricalImportSection(),
                  const SizedBox(height: 16),
                ],
                // Show env key status
                if (ClaudeService.hasEnvKey) ...[  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'settings.claude_from_env'.tr(),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'settings.claude_override_hint'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ] else ...[  
                  TextField(
                    controller: _claudeKeyController,
                    decoration: InputDecoration(
                      labelText: 'settings.claude_api_key'.tr(),
                      hintText: 'AIza...',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(_showClaudeKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showClaudeKey = !_showClaudeKey),
                      ),
                    ),
                    obscureText: !_showClaudeKey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'settings.claude_hint'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  
  Widget _buildHistoricalImportSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_download,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Historische Daten importieren (2025/2026)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kombiniert Auftrag (Metadaten: Name, Datum, Gäste, Cocktails) und Einkaufsliste (Zutaten) aus OneDrive/Aufträge. Claude AI extrahiert die Daten.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 12),
          if (!microsoftGraphService.isLoggedIn)
            Text(
              'Bitte zuerst bei Microsoft anmelden.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                  ),
            )
          else
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _importHistoricalData,
              icon: _isImporting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(_isImporting ? 'Importiere...' : 'Import starten'),
            ),
        ],
      ),
    );
  }
  
  Future<void> _importHistoricalData() async {
    setState(() => _isImporting = true);
    
    try {
      final count = await ClaudeService().importHistoricalShoppingLists(
        findEventPairs: microsoftGraphService.findEventFilePairs,
        downloadFile: microsoftGraphService.downloadFromOneDrive,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count Events importiert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}
