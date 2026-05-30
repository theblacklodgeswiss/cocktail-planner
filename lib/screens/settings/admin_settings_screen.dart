import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_repository.dart';
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
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isImporting = false;
  bool _isEnrichingRecipes = false;
  String _enrichStatus = '';
  bool _isGeneratingRecipe = false;
  String _generateStatus = '';
  final _recipeInputCtrl = TextEditingController();
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
    _recipeInputCtrl.dispose();
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
      final newSettings = _settings.copyWith(
        longDistanceThresholdKm: newThreshold,
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
                const SizedBox(height: 16),
                _buildHistoricalImportSection(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildRecipeEnrichCard(),
        const SizedBox(height: 16),
        _buildRecipeGenerateCard(),
      ],
    );
  }

  Widget _buildRecipeGenerateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Rezept mit AI erstellen', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gib einen Cocktailnamen oder eine Beschreibung ein — AI erstellt das Rezept mit Zutaten und Mengen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recipeInputCtrl,
                    decoration: const InputDecoration(
                      hintText: 'z.B. "Aperol Spritz" oder "fruchtiger Sommercocktail mit Maracuja"',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _isGeneratingRecipe ? null : _generateRecipeWithAI(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isGeneratingRecipe ? null : _generateRecipeWithAI,
                  icon: _isGeneratingRecipe
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isGeneratingRecipe ? '...' : 'Erstellen'),
                ),
              ],
            ),
            if (_generateStatus.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _generateStatus,
                style: TextStyle(
                  fontSize: 13,
                  color: _generateStatus.contains('Fehler') ? Colors.red : Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateRecipeWithAI() async {
    final input = _recipeInputCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() { _isGeneratingRecipe = true; _generateStatus = 'AI generiert Rezept...'; });
    try {
      final materials = await adminRepository.getMaterialsWithIds(isFixedValue: false);
      final ingredientNames = materials.map((m) => m.item.name).toList();

      final result = await claudeService.generateRecipeFromDescription(input, ingredientNames);
      if (result == null) {
        setState(() => _generateStatus = 'Fehler: Keine Antwort von AI');
        return;
      }

      setState(() => _generateStatus = 'Speichere "${result.name}"...');
      final success = await adminRepository.addRecipe(name: result.name, ingredients: result.ingredients);
      if (success && result.amounts.isNotEmpty) {
        final recipes = await adminRepository.getRecipesWithIds();
        final created = recipes.where((r) => r.item.name == result.name).firstOrNull;
        if (created != null) {
          await adminRepository.updateRecipeAmounts(docId: created.id, amounts: result.amounts);
        }
      }
      _recipeInputCtrl.clear();
      setState(() => _generateStatus = success ? '"${result.name}" mit ${result.ingredients.length} Zutaten hinzugefügt ✓' : 'Fehler beim Speichern');
    } catch (e) {
      setState(() => _generateStatus = 'Fehler: $e');
    } finally {
      setState(() => _isGeneratingRecipe = false);
    }
  }

  Widget _buildRecipeEnrichCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Rezept-Mengen',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'AI ergänzt automatisch die Mengen pro Zutat für alle Rezepte (z.B. "50ml Vodka pro Drink"). Wird nur für Rezepte ohne Mengenangaben ausgeführt.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_enrichStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _enrichStatus,
                  style: TextStyle(
                    fontSize: 13,
                    color: _enrichStatus.contains('Fehler')
                        ? Colors.red
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: _isEnrichingRecipes ? null : _enrichRecipeAmounts,
              icon: _isEnrichingRecipes
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_isEnrichingRecipes ? 'Läuft...' : 'Mengen mit AI ergänzen'),
            ),
          ],
        ),
      ),
    );
  }

  
  Future<void> _enrichRecipeAmounts() async {
    setState(() {
      _isEnrichingRecipes = true;
      _enrichStatus = 'Rezepte laden...';
    });
    try {
      final recipes = await adminRepository.getRecipesWithIds();
      final toEnrich = recipes.where((r) => !r.item.hasAmounts).toList();

      if (toEnrich.isEmpty) {
        setState(() => _enrichStatus = 'Alle Rezepte haben bereits Mengen ✓');
        return;
      }

      setState(() => _enrichStatus = '${toEnrich.length} Rezepte an AI senden...');

      final result = await claudeService.enrichRecipeAmounts(
        toEnrich.map((r) => (id: r.id, item: r.item)).toList(),
      );

      if (result.isEmpty) {
        setState(() => _enrichStatus = 'Fehler: Keine Antwort von AI');
        return;
      }

      int saved = 0;
      for (final recipe in toEnrich) {
        final amounts = result[recipe.item.name];
        if (amounts != null && amounts.isNotEmpty) {
          await adminRepository.updateRecipeAmounts(
            docId: recipe.id,
            amounts: amounts,
          );
          saved++;
          setState(() => _enrichStatus = '$saved/${toEnrich.length} gespeichert...');
        }
      }

      setState(() => _enrichStatus = '$saved Rezepte erfolgreich ergänzt ✓');
    } catch (e) {
      setState(() => _enrichStatus = 'Fehler: $e');
    } finally {
      setState(() => _isEnrichingRecipes = false);
    }
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
