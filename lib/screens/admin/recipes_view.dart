import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/states.dart';
import 'admin_widgets.dart';
import 'material_logic.dart';
import 'recipe_edit_sheet.dart';

/// Pure recipe list: search, FloatingCard rows, add via FAB, two-step full
/// sheet to edit, delete after a confirm sheet. Data and writes are injected.
class RecipesView extends StatefulWidget {
  const RecipesView({
    super.key,
    required this.title,
    required this.header,
    required this.items,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.loadMaterials,
    required this.onAddIngredient,
    required this.onSave,
    required this.onDelete,
  });

  final String title;
  final Widget header;
  final List<RecipeRecord> items;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Future<List<String>> Function() loadMaterials;
  final Future<bool> Function(String name) onAddIngredient;

  /// [docId] is null when creating.
  final Future<bool> Function(String? docId, RecipeEditResult result) onSave;
  final Future<bool> Function(String docId) onDelete;

  @override
  State<RecipesView> createState() => _RecipesViewState();
}

class _RecipesViewState extends State<RecipesView> {
  String _query = '';

  Future<void> _edit({String? docId, Recipe? recipe}) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showRecipeEditSheet(
      context,
      initialName: recipe?.name ?? '',
      initialIngredients: recipe?.ingredients ?? const [],
      initialAmounts: recipe?.ingredientAmounts ?? const {},
      loadMaterials: widget.loadMaterials,
      onAddIngredient: widget.onAddIngredient,
      onSave: (r) => widget.onSave(docId, r),
    );
    if (result != null) {
      messenger.showSnackBar(SnackBar(content: Text('admin2.saved'.tr())));
    }
  }

  Future<void> _delete(RecipeRecord r) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmSheet(
      context,
      title: 'admin2.delete_recipe_title'.tr(),
      body: 'admin2.delete_body'.tr(args: [r.item.name]),
      confirmLabel: 'common.delete'.tr(),
      destructive: true,
      errorText: 'admin2.delete_error'.tr(),
      confirmAction: () async {
        if (!await widget.onDelete(r.id)) throw StateError('delete failed');
      },
    );
    if (!ok) return;
    messenger.showSnackBar(SnackBar(content: Text('admin2.deleted'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final filtered = filterRecipes(widget.items, _query);
    return AdminPage(
      title: widget.title,
      loading: widget.loading,
      errorMessage: widget.errorMessage,
      onRetry: widget.onRetry,
      onAdd: () => _edit(),
      addLabel: 'admin2.new_recipe'.tr(),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.header,
          const SizedBox(height: AppSpace.s8),
          SearchPill(onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: AppSpace.s8),
          CountLine(
            text: 'admin2.recipes_count'.tr(args: ['${filtered.length}']),
          ),
        ],
      ),
      slivers: [
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.local_bar_outlined,
              title: 'admin2.none_recipes'.tr(),
            ),
          )
        else
          AdminSliverList(
            count: filtered.length,
            idAt: (i) => filtered[i].id,
            itemBuilder: (context, i, _) {
              final r = filtered[i];
              final recipe = r.item;
              return AdminRowCard(
                title: recipe.name,
                onTap: () => _edit(docId: r.id, recipe: recipe),
                extra: [
                  for (final ing in recipe.ingredients)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ing,
                            style: AppText.body.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          recipe.ingredientAmounts[ing] ?? '—',
                          style: AppText.body.copyWith(
                            color: p.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
                trailing: [
                  RowIconButton(
                    icon: Icons.delete_outline,
                    label: 'common.delete'.tr(),
                    destructive: true,
                    onPressed: () => _delete(r),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
