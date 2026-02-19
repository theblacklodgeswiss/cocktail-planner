import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/cocktail_repository.dart';
import '../models/cocktail_data.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/recipe_selection_dialog.dart';

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
      // Check admin status from Firestore
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

  Future<void> _showUserMenu() async {
    final user = authService.currentUser;
    if (user == null) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? Icon(user.isAnonymous ? Icons.person_outline : Icons.person)
                    : null,
              ),
              title: Row(
                children: [
                  Text(user.displayName ?? (user.isAnonymous ? 'Gast' : 'Benutzer')),
                  if (authService.isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'drawer.admin_badge'.tr(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(user.email ?? (user.isAnonymous ? 'drawer.anonymous_user'.tr() : '')),
            ),
            const Divider(),
            if (authService.isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.inventory),
                title: Text('drawer.inventory_title'.tr()),
                subtitle: Text('drawer.inventory_subtitle'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/admin');
                },
              ),
            ],
            if (authService.isAdmin || authService.isSuperAdmin)
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: Text('drawer.orders_title'.tr()),
                subtitle: Text('drawer.orders_subtitle'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/orders');
                },
              ),
            if (authService.canManageUsers)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text('drawer.users_title'.tr()),
                subtitle: Text('drawer.users_subtitle'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAdminPanel();
                },
              ),
            if (user.isAnonymous)
              ListTile(
                leading: const Icon(Icons.login),
                title: Text('drawer.link_google_title'.tr()),
                subtitle: Text('drawer.link_google_subtitle'.tr()),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await authService.linkWithGoogle();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('drawer.link_success'.tr())),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${'common.error'.tr()}: $e')),
                      );
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text('drawer.logout'.tr()),
              onTap: () async {
                Navigator.pop(ctx);
                await authService.signOut();
                if (mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdminPanel() async {
    final users = await authService.getAllowedUsers();
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings),
            const SizedBox(width: 8),
            Text('admin_panel.title'.tr()),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add user button
              ListTile(
                leading: const Icon(Icons.person_add),
                title: Text('admin_panel.add_user'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddUserDialog();
                },
              ),
              const Divider(),
              // User list
              if (users.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('admin_panel.no_users'.tr()),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: users.length,
                    itemBuilder: (listContext, index) {
                      final user = users[index];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(user.name.isNotEmpty ? user.name : user.email),
                        subtitle: Text(user.email),
                        trailing: authService.isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final navigator = Navigator.of(listContext);
                                  final confirm = await showDialog<bool>(
                                    context: listContext,
                                    builder: (c) => AlertDialog(
                                      title: Text('admin_panel.remove_user_title'.tr()),
                                      content: Text('admin_panel.remove_user_message'.tr(namedArgs: {'email': user.email})),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c, false),
                                          child: Text('common.cancel'.tr()),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(c, true),
                                          child: Text('admin_panel.remove'.tr()),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await authService.removeAllowedUser(user.email);
                                    if (mounted) {
                                      navigator.pop();
                                      _showAdminPanel(); // Refresh
                                    }
                                  }
                                },
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddUserDialog() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin_panel.add_user'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'admin_panel.email_label'.tr(),
                hintText: 'admin_panel.email_hint'.tr(),
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'admin_panel.name_label'.tr(),
                hintText: 'admin_panel.name_hint'.tr(),
                prefixIcon: const Icon(Icons.person),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.add'.tr()),
          ),
        ],
      ),
    );
    
    if (result == true && emailController.text.trim().isNotEmpty) {
      final success = await authService.addAllowedUser(
        emailController.text.trim(),
        name: nameController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'common.user_added'.tr() 
                : 'common.add_error'.tr()),
          ),
        );
        if (success) {
          _showAdminPanel(); // Reopen panel
        }
      }
    }
  }

  Future<void> _openRecipeSelection(List<Recipe> allRecipes) async {
    final result = await showDialog<List<Recipe>>(
      context: context,
      builder: (_) => RecipeSelectionDialog(
        recipes: allRecipes,
        initialSelection: List<Recipe>.from(appState.selectedRecipes),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    appState.setSelectedRecipes(result);
  }

  Widget _buildEmptyState(VoidCallback onAdd) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_bar_outlined,
              size: 60,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Keine Cocktails ausgewählt',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge Cocktails hinzu um eine\nEinkaufsliste zu generieren',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Cocktails hinzufügen'),
          ),
        ],
      ),
    );
  }

  Widget _buildCocktailChip(Recipe recipe) {
    final isShot = recipe.name.toLowerCase().contains('shot');
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InputChip(
        label: Text(recipe.name),
        avatar: Icon(
          isShot ? Icons.wine_bar : Icons.local_bar,
          size: 18,
        ),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => appState.removeRecipe(recipe.id),
        backgroundColor: isShot 
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildSelectedCocktails(List<Recipe> recipes, VoidCallback onAdd) {
    final shots = recipes.where((r) => r.name.toLowerCase().contains('shot')).toList();
    final cocktails = recipes.where((r) => !r.name.toLowerCase().contains('shot')).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_bar,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${recipes.length} ausgewählt',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${cocktails.length} Cocktails • ${shots.length} Shots',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Bearbeiten'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Cocktails section
              if (cocktails.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.local_bar, size: 20, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Cocktails',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  children: cocktails.map(_buildCocktailChip).toList(),
                ),
                const SizedBox(height: 20),
              ],
              
              // Shots section
              if (shots.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.wine_bar, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Shots',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  children: shots.map(_buildCocktailChip).toList(),
                ),
              ],
              
              // Space for bottom bar
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
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
            body: Center(
              child: Text('dashboard.load_error'.tr()),
            ),
          );
        }

        final data = snapshot.data!;

        return AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final hasSelection = appState.selectedRecipes.isNotEmpty;
            
            return Scaffold(
              appBar: AppBar(
                title: Text('dashboard.title'.tr()),
                actions: [
                  if (cocktailRepository.isUsingFirebase)
                    IconButton(
                      icon: const Icon(Icons.sync),
                      tooltip: 'Daten neu laden',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Daten aktualisieren?'),
                            content: const Text(
                              'Dies lädt alle Materialien und Rezepte neu aus der lokalen Datei. '
                              'Bestehende Firebase-Daten werden überschrieben.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Aktualisieren'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Daten werden aktualisiert...')),
                          );
                          await cocktailRepository.forceReseed();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Daten erfolgreich aktualisiert!')),
                            );
                            setState(() {
                              _loadData();
                            });
                          }
                        }
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: Icon(
                        cocktailRepository.isUsingFirebase
                            ? Icons.cloud_done
                            : Icons.folder,
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
                  ),
                  // User menu
                  IconButton(
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
                    onPressed: _showUserMenu,
                    tooltip: authService.displayName ?? 'Benutzer',
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: hasSelection
                  ? _buildSelectedCocktails(
                      appState.selectedRecipes,
                      () => _openRecipeSelection(data.recipes),
                    )
                  : _buildEmptyState(() => _openRecipeSelection(data.recipes)),
              bottomNavigationBar: hasSelection
                  ? Container(
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
                          label: const Text('Einkaufsliste generieren'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                        ),
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
