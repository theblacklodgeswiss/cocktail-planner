import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/cocktail_repository.dart';
import '../../models/cocktail_data.dart';
import '../../models/recipe.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../widgets/recipe_selection_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    if (!_initialized) {
      await authService.checkIsAdmin();
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

  Future<void> _confirmReseed() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('dashboard.reseed_title'.tr()),
        content: Text('dashboard.reseed_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('dashboard.reseed_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('dashboard.reseed_progress'.tr())),
      );
      await cocktailRepository.forceReseed();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('dashboard.reseed_success'.tr())),
        );
        setState(() => _loadData());
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text('dashboard.title'.tr())),
            body: Center(child: Text('dashboard.load_error'.tr())),
          );
        }

        final data = snapshot.data!;

        return AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final hasSelection = appState.selectedRecipes.isNotEmpty;

            return Scaffold(
              appBar: _buildAppBar(),
              body: hasSelection
                  ? SelectedCocktails(
                      recipes: appState.selectedRecipes,
                      onEdit: () => _openRecipeSelection(data.recipes),
                    )
                  : DashboardEmptyState(
                      onAdd: () => _openRecipeSelection(data.recipes),
                    ),
              bottomNavigationBar: hasSelection ? _buildBottomBar() : null,
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
        if (cocktailRepository.isUsingFirebase)
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'dashboard.sync_tooltip'.tr(),
            onPressed: _confirmReseed,
          ),
        _DataSourceChip(),
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
        child: FilledButton.icon(
          onPressed: () => context.push('/shopping-list'),
          icon: const Icon(Icons.shopping_cart),
          label: Text('dashboard.generate_list'.tr()),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ),
    );
  }
}

class _DataSourceChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: Icon(
          cocktailRepository.isUsingFirebase ? Icons.cloud_done : Icons.folder,
          size: 16,
        ),
        label: Text(
          cocktailRepository.dataSourceLabel,
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: cocktailRepository.isUsingFirebase
            ? Colors.green.shade100
            : Colors.orange.shade100,
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
