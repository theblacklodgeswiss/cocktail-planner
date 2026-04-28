import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/cocktail_repository.dart';
import '../../models/cocktail_data.dart';
import '../../models/recipe.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../state/app_state.dart';
import '../../widgets/recipe_selection_dialog.dart';
import '../../widgets/order_setup_dialog.dart';
import '../../widgets/gemini_material_review_dialog.dart';
import '../../widgets/cocktail_popularity_dialog.dart';
import '../forms/modern_order_form_screen.dart';
import 'user_menu_sheet.dart';
import 'widgets/empty_state.dart';
import 'widgets/selected_cocktails.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.loadData});

  final Future<CocktailData> Function()? loadData;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<CocktailData>? _dataFuture;
  bool _initialized = false;
  bool _cocktailMatchingDone = false;
  OrderSetupData? _orderSetup;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  /// Validiert die OrderSetupData und setzt bei Problemen alles zurück
  bool _validateOrderSetup() {
    if (_orderSetup == null) return false;
    
    // Prüfe Pflichtfelder
    if (_orderSetup!.orderName.trim().isEmpty ||
        _orderSetup!.personCount <= 0 ||
        _orderSetup!.currency.isEmpty ||
        _orderSetup!.drinkerType.isEmpty ||
        _orderSetup!.serviceType.isEmpty) {
      // Bei unvollständigen Daten: alles zurücksetzen
      setState(() => _orderSetup = null);
      appState.setSelectedRecipes([]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('dashboard.incomplete_data'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _initializeAndLoad() async {
    if (!_initialized) {
      await authService.checkIsAdmin();
      if (!authService.isAdmin && mounted) {
        context.go('/');
        return;
      }
      await cocktailRepository.initialize();
      _initialized = true;
    }
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = (widget.loadData ?? cocktailRepository.load)();
    });
  }

  /// Auto-select recipes from linked order if available.
  /// Uses Gemini AI for fuzzy matching if exact match fails.
  Future<void> _applyLinkedOrderCocktails(List<Recipe> allRecipes) async {
    final requested = appState.linkedOrderRequestedCocktails;
    if (requested == null || requested.isEmpty) return;
    if (appState.selectedRecipes.isNotEmpty) return; // Already has selection

    final matchedRecipes = <Recipe>[];
    final unmatchedNames = <String>[];

    // First try exact match (case-insensitive)
    for (final cocktailName in requested) {
      final lower = cocktailName.toLowerCase().trim();
      final recipe = allRecipes.firstWhere(
        (r) => r.name.toLowerCase().trim() == lower,
        orElse: () => Recipe(id: '', name: '', ingredients: [], type: ''),
      );
      if (recipe.id.isNotEmpty &&
          !matchedRecipes.any((r) => r.id == recipe.id)) {
        matchedRecipes.add(recipe);
      } else if (recipe.id.isEmpty) {
        unmatchedNames.add(cocktailName);
      }
    }

    // Use Gemini AI for fuzzy matching of unmatched names
    if (unmatchedNames.isNotEmpty && geminiService.isConfigured) {
      try {
        final availableNames = allRecipes.map((r) => r.name).toList();
        final aiMatches = await geminiService.matchCocktailNames(
          requestedNames: unmatchedNames,
          availableRecipeNames: availableNames,
        );

        for (final entry in aiMatches.entries) {
          final matchedName = entry.value;
          if (matchedName != null) {
            final recipe = allRecipes.firstWhere(
              (r) => r.name == matchedName,
              orElse: () => Recipe(id: '', name: '', ingredients: [], type: ''),
            );
            if (recipe.id.isNotEmpty &&
                !matchedRecipes.any((r) => r.id == recipe.id)) {
              matchedRecipes.add(recipe);
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini cocktail matching failed: $e');
      }
    }

    if (matchedRecipes.isNotEmpty) {
      appState.setSelectedRecipes(matchedRecipes);
    }
  }

  Future<void> _showCocktailPopularityDialog(List<Recipe> cocktails) async {
    if (cocktails.isEmpty) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CocktailPopularityDialog(
        cocktails: cocktails,
        onConfirm: () {
          // Dialog already saves to AppState, nothing else needed here
        },
      ),
    );
  }

  Future<void> _editSingleCocktailPopularity(Recipe recipe) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CocktailPopularityDialog(
        cocktails: [recipe],
        onConfirm: () {
          // Dialog already saves to AppState, nothing else needed here
        },
      ),
    );
  }

  Future<void> _openRecipeSelection(List<Recipe> allRecipes) async {
    final result = await showDialog<List<Recipe>>(
      context: context,
      builder: (_) => RecipeSelectionDialog(
        recipes: allRecipes,
        initialSelection: List<Recipe>.from(appState.selectedRecipes),
      ),
    );
    if (!mounted || result == null) return;
    appState.setSelectedRecipes(result);
  }

  Future<void> _generateMaterialSuggestionsWithGemini(
    CocktailData cocktailData,
  ) async {
    if (!_validateOrderSetup()) return;
    if (!geminiService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders.gemini_not_configured'.tr())),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('orders.gemini_generating'.tr()),
          ],
        ),
      ),
    );

    try {
      // Get available materials
      final materials = cocktailData.materials
          .where((m) => m.visible)
          .map(
            (m) => {
              'name': m.name,
              'unit': m.unit,
              'price': m.price,
              'currency': m.currency,
            },
          )
          .toList();

      // Get recipe ingredients
      final selectedCocktails = appState.selectedRecipes;
      final recipeIngredients = selectedCocktails
          .map((r) => {'cocktail': r.name, 'ingredients': r.ingredients})
          .toList();

      // Generate material suggestions
      final suggestion = await geminiService.generateMaterialSuggestions(
        guestCount: _orderSetup!.personCount,
        guestRange: '',  // Not available from OrderSetupData
        requestedCocktails: selectedCocktails.map((r) => r.name).toList(),
        eventType: _orderSetup!.drinkerType,
        drinkerType: _orderSetup!.drinkerType,
        availableMaterials: materials,
        recipeIngredients: recipeIngredients,
        cocktailPopularity: appState.cocktailPopularity,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (suggestion.hasError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(suggestion.errorMessage ?? 'orders.gemini_error'.tr()),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      // Show review dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => GeminiMaterialReviewDialog(
            suggestion: suggestion,
            personCount: _orderSetup!.personCount,
            cocktailNames: selectedCocktails.map((r) => r.name).toList(),
            onConfirm: (confirmedSuggestions, explanation) {
              // Auto-select recipes when none are selected.
              // Three-tier fallback to reliably find which cocktails Gemini used.
              if (appState.selectedRecipes.isEmpty) {
                List<Recipe> matched = [];

                // Tier 1: exact match from the JSON cocktails field
                if (suggestion.usedCocktails.isNotEmpty) {
                  matched = suggestion.usedCocktails
                      .map(
                        (name) => cocktailData.recipes.firstWhere(
                          (r) => r.name == name,
                          orElse: () => Recipe(
                            id: '',
                            name: '',
                            ingredients: [],
                            type: '',
                          ),
                        ),
                      )
                      .where((r) => r.id.isNotEmpty)
                      .toList();
                }

                // Tier 2: scan explanation text for known recipe names
                if (matched.isEmpty && suggestion.explanation.isNotEmpty) {
                  final exp = suggestion.explanation;
                  matched = cocktailData.recipes
                      .where((r) => exp.contains(r.name))
                      .toList();
                }

                // Tier 3: find recipes whose ingredients appear in suggestions
                if (matched.isEmpty) {
                  final suggestedNames =
                      confirmedSuggestions.map((s) => s.name).toSet();
                  matched = cocktailData.recipes
                      .where(
                        (r) => r.ingredients
                            .any((ing) => suggestedNames.contains(ing)),
                      )
                      .toList();
                }

                if (matched.isNotEmpty) {
                  appState.setSelectedRecipes(matched);
                }
              }

              // Store suggestions in app state
              appState.setMaterialSuggestions(
                confirmedSuggestions,
                explanation,
              );

              // Navigate to shopping list
              context.push('/shopping-list', extra: _orderSetup);
            },
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.gemini_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dataFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FutureBuilder<CocktailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text('dashboard.title'.tr())),
            body: Center(child: Text('dashboard.load_error'.tr())),
          );
        }
        final data = snapshot.data!;
        // Auto-apply linked order cocktails after data loads (only once)
        if (!_cocktailMatchingDone &&
            appState.linkedOrderRequestedCocktails != null) {
          _cocktailMatchingDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyLinkedOrderCocktails(data.recipes);
          });
        }
        return AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final hasSelection = appState.selectedRecipes.isNotEmpty;
            final hasLinkedOrder = appState.linkedOrderId != null;
            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Scaffold(
                  appBar: _buildAppBar(),
                  body: Column(
                    children: [
                      if (_orderSetup == null)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment,
                                    size: 120,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Auftragsdaten eingeben',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Erstelle einen neuen Auftrag und gib die\nwichtigen Details für dein Event ein',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 48),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      
                                      final result = await context.push<OrderFormResult>(
                                        '/order-form?step=0',
                                      );
                                      if (result != null && mounted) {
                                        // Validiere die empfangenen Daten
                                        if (result.setupData.orderName.trim().isEmpty ||
                                            result.setupData.personCount <= 0) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('dashboard.required_fields'.tr()),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        setState(() => _orderSetup = result.setupData);
                                        appState.setSelectedRecipes(result.selectedRecipes);
                                        // Show cocktail popularity dialog after selection
                                        if (result.selectedRecipes.isNotEmpty) {
                                          _showCocktailPopularityDialog(result.selectedRecipes);
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Neuen Auftrag erstellen'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_orderSetup != null) ...[
                        if (hasLinkedOrder) _buildLinkedOrderBanner(),
                        if (hasSelection && isDesktop)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 24,
                              right: 32,
                              bottom: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _generateMaterialSuggestionsWithGemini(data),
                                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                                  label: Text('orders.generate_with_gemini'.tr(), style: const TextStyle(color: Colors.white)),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton(
                                  onPressed: () {
                                    if (!_validateOrderSetup()) return;
                                    if (appState.selectedRecipes.isNotEmpty) {
                                      context.push(
                                        '/shopping-list',
                                        extra: _orderSetup,
                                      );
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  child: Text('dashboard.manual_create'.tr()),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: hasSelection
                              ? SelectedCocktails(
                                  recipes: appState.selectedRecipes,
                                  onEdit: () =>
                                      _openRecipeSelection(data.recipes),
                                  onEditPopularity: _editSingleCocktailPopularity,
                                )
                              : DashboardEmptyState(
                                  onAdd: () =>
                                      _openRecipeSelection(data.recipes),
                                ),
                        ),
                      ],
                    ],
                  ),
                  bottomNavigationBar:
                      hasSelection && isDesktop == false && _orderSetup != null
                      ? _buildBottomBar()
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('dashboard.title'.tr()),
      actions: [
        AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            if (appState.selectedRecipes.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Reset?'),
                    content: Text(
                      'Do you want to reset your selection and start over?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  appState.setSelectedRecipes([]);
                  appState.clearLinkedOrder();
                }
              },
            );
          },
        ),
        const _FlavorChip(),
        _UserMenuButton(onPressed: () => showUserMenu(context)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: FutureBuilder<CocktailData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  final enabled = snapshot.hasData;
                  return FilledButton.icon(
                    onPressed: enabled && snapshot.data != null
                        ? () => _generateMaterialSuggestionsWithGemini(snapshot.data!)
                        : null,
                    icon: const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
                    label: Text('orders.generate_with_gemini'.tr(), style: const TextStyle(color: Colors.white)),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                if (_validateOrderSetup() && appState.selectedRecipes.isNotEmpty) {
                  context.push('/shopping-list', extra: _orderSetup);
                }
              },
              style: TextButton.styleFrom(minimumSize: const Size(0, 56)),
              child: Text('dashboard.manual_create'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedOrderBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.link, color: colorScheme.onPrimaryContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'dashboard.linked_order'.tr(
                args: [appState.linkedOrderName ?? ''],
              ),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: colorScheme.onPrimaryContainer,
              size: 20,
            ),
            onPressed: () => appState.clearLinkedOrder(),
            visualDensity: VisualDensity.compact,
            tooltip: 'dashboard.unlink_order'.tr(),
          ),
        ],
      ),
    );
  }
}

class _FlavorChip extends StatelessWidget {
  const _FlavorChip();

  @override
  Widget build(BuildContext context) {
    const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    if (flavor == 'prod') {
      return const SizedBox.shrink();
    }

    return const Padding(
      padding: EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          'DEV',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide.none,
      ),
    );
  }
}

class _UserMenuButton extends StatelessWidget {
  const _UserMenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: CircleAvatar(
        radius: 16,
        backgroundImage: authService.photoUrl != null
            ? NetworkImage(authService.photoUrl!)
            : null,
        child: authService.photoUrl == null
            ? Icon(
                authService.isAnonymous ? Icons.person_outline : Icons.person,
                size: 20,
              )
            : null,
      ),
      onPressed: onPressed,
      tooltip: authService.displayName ?? 'dashboard.user_tooltip'.tr(),
    );
  }
}
