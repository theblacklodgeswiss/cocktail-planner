import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/cocktail_repository.dart';
import '../../data/settings_repository.dart';
import '../../models/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../services/microsoft_graph_service.dart';

/// Admin settings screen for configuring app-wide settings.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late TextEditingController _distanceController;
  late TextEditingController _geminiKeyController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isImporting = false;
  AppSettings _settings = const AppSettings();
  bool _showGeminiKey = false;

  @override
  void initState() {
    super.initState();
    _distanceController = TextEditingController();
    _geminiKeyController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await settingsRepository.load();
    // Also reload Gemini usage from Firestore
    await GeminiService().reloadUsage();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _distanceController.text = settings.longDistanceThresholdKm.toString();
      _geminiKeyController.text = settings.geminiApiKey ?? '';
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
      final geminiKey = _geminiKeyController.text.trim();
      final newSettings = _settings.copyWith(
        longDistanceThresholdKm: newThreshold,
        geminiApiKey: geminiKey.isNotEmpty ? geminiKey : null,
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
        // Gemini AI Settings
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
                      'settings.gemini_section'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (geminiService.isConfigured)
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
                              'settings.gemini_active'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'settings.gemini_description'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                // Firebase Sync
                _buildFirebaseSyncSection(),
                const SizedBox(height: 16),
                // Usage statistics
                if (geminiService.isConfigured) ...[
                  _buildGeminiUsageSection(),
                  const SizedBox(height: 16),
                  _buildHistoricalImportSection(),
                  const SizedBox(height: 16),
                ],
                // Show env key status
                if (GeminiService.hasEnvKey) ...[  
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
                            'settings.gemini_from_env'.tr(),
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
                    'settings.gemini_override_hint'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ] else ...[  
                  TextField(
                    controller: _geminiKeyController,
                    decoration: InputDecoration(
                      labelText: 'settings.gemini_api_key'.tr(),
                      hintText: 'AIza...',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(_showGeminiKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showGeminiKey = !_showGeminiKey),
                      ),
                    ),
                    obscureText: !_showGeminiKey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'settings.gemini_hint'.tr(),
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

  Widget _buildFirebaseSyncSection() {
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
                Icons.cloud_sync,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'admin.firebase_sync_title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (cocktailRepository.isUsingFirebase)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Firebase',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Lokal',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'admin.firebase_sync_description'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _syncFirebaseData,
            icon: const Icon(Icons.sync, size: 18),
            label: Text('admin.firebase_sync_button'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _syncFirebaseData() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.firebase_sync_confirm_title'.tr()),
        content: Text('admin.firebase_sync_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('admin.firebase_sync_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('admin.firebase_sync_progress'.tr())),
      );
      await cocktailRepository.forceReseed();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('admin.firebase_sync_success'.tr())),
        );
      }
    }
  }

  Widget _buildGeminiUsageSection() {
    final geminiService = GeminiService();
    
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
                Icons.bar_chart,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'settings.gemini_usage'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Today's usage stats
          _buildUsageStat(
            'Anfragen',
            '${geminiService.requestsToday} / ${GeminiService.dailyRequestLimit}',
            geminiService.requestUsagePercentage,
          ),
          const SizedBox(height: 8),
          _buildUsageStat(
            'Tokens',
            '${_formatNumber(geminiService.totalTokensToday)} / ${_formatNumber(GeminiService.dailyTokenLimit)}',
            geminiService.tokenUsagePercentage,
          ),
          const SizedBox(height: 8),
          // Token breakdown
          Row(
            children: [
              Expanded(
                child: Text(
                  '↓ ${_formatNumber(geminiService.inputTokensToday)} input',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
              Text(
                '↑ ${_formatNumber(geminiService.outputTokensToday)} output',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reset time info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reset in ${GeminiService.resetTimeFormatted} (Mitternacht PT)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'settings.gemini_usage_hint'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          // Link to Google AI Studio
          OutlinedButton.icon(
            onPressed: _openAiStudio,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('settings.gemini_open_studio'.tr()),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUsageStat(String label, String value, double percentage) {
    final color = percentage > 0.9 
        ? Colors.red 
        : percentage > 0.7 
            ? Colors.orange 
            : Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            )),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
  
  void _openAiStudio() {
    // Open Google AI Studio in browser
    // ignore: deprecated_member_use
    launchUrl(Uri.parse('https://aistudio.google.com/apikey'));
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
            'Kombiniert Auftrag (Metadaten: Name, Datum, Gäste, Cocktails) und Einkaufsliste (Zutaten) aus OneDrive/Aufträge. Gemini AI extrahiert die Daten.',
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
      final count = await GeminiService().importHistoricalShoppingLists(
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
