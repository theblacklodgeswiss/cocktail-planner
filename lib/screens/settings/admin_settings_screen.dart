import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_repository.dart';
import '../../data/settings_repository.dart';
import '../../models/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/claude_service.dart';
import '../../services/microsoft_graph_service.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/states.dart';
import 'admin_settings_view.dart';

/// Admin settings screen for configuring app-wide settings.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isImporting = false;
  bool _isEnrichingRecipes = false;
  AdminStatus? _enrichStatus;
  bool _isGeneratingRecipe = false;
  AdminStatus? _generateStatus;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings(int newThreshold) async {
    setState(() => _isSaving = true);

    try {
      final newSettings = _settings.copyWith(
        longDistanceThresholdKm: newThreshold,
      );
      await settingsRepository.save(newSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('settings.saved'.tr())));
      setState(() => _settings = newSettings);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.error'.tr())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!authService.isAdmin || _isLoading) {
      final denied = !authService.isAdmin;
      return LargeTitleScaffold(
        title: 'settings.admin_section'.tr(),
        leading: GlassIconButton(
          icon: Icons.arrow_back,
          semanticLabel: 'ui.back'.tr(),
          onPressed: () => context.pop(),
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: denied
                ? EmptyState(
                    icon: Icons.lock_outline,
                    title: 'admin.access_denied'.tr(),
                  )
                : const LoadingState(),
          ),
        ],
      );
    }

    return AdminSettingsView(
      threshold: _settings.longDistanceThresholdKm,
      claudeConfigured: claudeService.isConfigured,
      microsoftLoggedIn: microsoftGraphService.isLoggedIn,
      isImporting: _isImporting,
      onImport: _importHistoricalData,
      isEnriching: _isEnrichingRecipes,
      enrichStatus: _enrichStatus,
      onEnrich: _enrichRecipeAmounts,
      isGenerating: _isGeneratingRecipe,
      generateStatus: _generateStatus,
      onGenerate: _generateRecipeWithAI,
      onSave: _saveSettings,
      isSaving: _isSaving,
    );
  }

  void _setGenerate(String text, {bool error = false}) {
    if (mounted) setState(() => _generateStatus = AdminStatus(text, error));
  }

  Future<void> _generateRecipeWithAI(String raw) async {
    final input = raw.trim();
    if (input.isEmpty) return;
    setState(() => _isGeneratingRecipe = true);
    _setGenerate('admin_settings.status_ai_generating'.tr());
    try {
      final materials = await adminRepository.getMaterialsWithIds(
        isFixedValue: false,
      );
      final ingredientNames = materials.map((m) => m.item.name).toList();

      final result = await claudeService.generateRecipeFromDescription(
        input,
        ingredientNames,
      );
      if (result == null) {
        _setGenerate('admin_settings.status_no_response'.tr(), error: true);
        return;
      }

      _setGenerate('admin_settings.status_saving'.tr(args: [result.name]));
      final success = await adminRepository.addRecipe(
        name: result.name,
        ingredients: result.ingredients,
      );
      if (success && result.amounts.isNotEmpty) {
        final recipes = await adminRepository.getRecipesWithIds();
        final created = recipes
            .where((r) => r.item.name == result.name)
            .firstOrNull;
        if (created != null) {
          await adminRepository.updateRecipeAmounts(
            docId: created.id,
            amounts: result.amounts,
          );
        }
      }
      if (success) {
        _setGenerate(
          'admin_settings.status_added'.tr(
            args: [result.name, result.ingredients.length.toString()],
          ),
        );
      } else {
        _setGenerate('admin_settings.status_save_failed'.tr(), error: true);
      }
    } catch (e) {
      _setGenerate('admin_settings.error'.tr(args: ['$e']), error: true);
    } finally {
      if (mounted) setState(() => _isGeneratingRecipe = false);
    }
  }

  void _setEnrich(String text, {bool error = false}) {
    if (mounted) setState(() => _enrichStatus = AdminStatus(text, error));
  }

  Future<void> _enrichRecipeAmounts() async {
    setState(() => _isEnrichingRecipes = true);
    _setEnrich('admin_settings.status_loading_recipes'.tr());
    try {
      final recipes = await adminRepository.getRecipesWithIds();
      final toEnrich = recipes.where((r) => !r.item.hasAmounts).toList();

      if (toEnrich.isEmpty) {
        _setEnrich('admin_settings.status_all_done'.tr());
        return;
      }

      _setEnrich(
        'admin_settings.status_send_to_ai'.tr(args: ['${toEnrich.length}']),
      );

      final result = await claudeService.enrichRecipeAmounts(
        toEnrich.map((r) => (id: r.id, item: r.item)).toList(),
      );

      if (result.isEmpty) {
        _setEnrich('admin_settings.status_no_response'.tr(), error: true);
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
          _setEnrich(
            'admin_settings.status_saved_progress'.tr(
              args: ['$saved', '${toEnrich.length}'],
            ),
          );
        }
      }

      _setEnrich('admin_settings.status_enriched'.tr(args: ['$saved']));
    } catch (e) {
      _setEnrich('admin_settings.error'.tr(args: ['$e']), error: true);
    } finally {
      if (mounted) setState(() => _isEnrichingRecipes = false);
    }
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
          SnackBar(
            content: Text('admin_settings.import_done'.tr(args: ['$count'])),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin_settings.import_failed'.tr(args: ['$e'])),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}
