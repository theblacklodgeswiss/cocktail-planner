import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/cocktail_data.dart';
import '../../../models/recipe.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/pill_filter.dart';
import '../../../ui/widgets/pressable.dart';
import '../../../ui/widgets/states.dart';
import '../order_form_state.dart';
import 'wizard_widgets.dart';

/// Cocktail and shot selection: search, type filter (all / cocktails or
/// mocktails / shots - no shots for the mocktail service), a card list
/// with check marks and a quantity stepper for selected shots.
class CocktailPicker extends StatelessWidget {
  const CocktailPicker({super.key, required this.form, required this.onRetry});

  final OrderFormState form;

  /// Reloads the recipe catalog after a failed load.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CocktailData>(
      future: form.dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.s24),
            child: LoadingState(),
          );
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: 'order_wizard.drinks_error'.tr(),
            onRetry: onRetry,
          );
        }
        return _content(context, snapshot.data?.recipes ?? const []);
      },
    );
  }

  Widget _content(BuildContext context, List<Recipe> recipes) {
    final isMocktail = form.serviceType == 'mocktail_service';
    final filtered = recipes.where((recipe) {
      if (form.searchQuery.isNotEmpty &&
          !recipe.name.toLowerCase().contains(form.searchQuery)) {
        return false;
      }
      // The mocktail service never offers shots.
      if (isMocktail && recipe.isShot) return false;
      if (form.cocktailFilter == 'cocktails' && recipe.isShot) return false;
      if (form.cocktailFilter == 'shots' && !recipe.isShot) return false;
      return true;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'dialog.search_hint'.tr(),
            prefixIcon: const Icon(Icons.search, size: AppSize.rowIcon),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) =>
              form.update(() => form.searchQuery = value.toLowerCase()),
        ),
        const SizedBox(height: AppSpace.s8),
        PillFilter<String>(
          options: [
            PillOption('all', 'order_wizard.filter_all'.tr()),
            PillOption(
              'cocktails',
              isMocktail
                  ? 'order_wizard.filter_mocktails'.tr()
                  : 'order_wizard.filter_cocktails'.tr(),
            ),
            if (!isMocktail)
              PillOption('shots', 'order_wizard.filter_shots'.tr()),
          ],
          value: form.cocktailFilter,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            form.update(() => form.cocktailFilter = value);
          },
        ),
        KeyedSubtree(
          key: form.fieldKeys[FormFieldId.cocktails],
          child: FieldHint(form.visibleHint(FormFieldId.cocktails)),
        ),
        const SizedBox(height: AppSpace.s8),
        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.search_off,
            title: 'order_wizard.no_drinks'.tr(),
          )
        else
          FloatingCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: AppSize.hairline,
                      color: AppPalette.of(context).border,
                    ),
                  _row(context, filtered[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Recipe recipe) {
    final p = AppPalette.of(context);
    final selected = form.selectedRecipes.any((r) => r.id == recipe.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          minSize: AppSize.minTap,
          selected: selected,
          onTap: () {
            HapticFeedback.selectionClick();
            form.update(() => form.toggleRecipeSelection(recipe));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    recipe.name,
                    style: AppText.button.copyWith(color: p.text),
                  ),
                ),
                if (recipe.isShot) ...[
                  const SizedBox(width: AppSpace.s8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s8,
                        vertical: AppSpace.s4,
                      ),
                      child: Text(
                        'order_wizard.shot_badge'.tr(),
                        style: AppText.pill.copyWith(color: p.textSecondary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpace.s12),
                CheckMark(selected: selected),
              ],
            ),
          ),
        ),
        if (recipe.isShot && selected)
          _ShotQuantity(form: form, recipe: recipe),
      ],
    );
  }
}

/// Compact quantity stepper (44 px targets) for a selected shot; the number
/// itself stays typeable.
class _ShotQuantity extends StatelessWidget {
  const _ShotQuantity({required this.form, required this.recipe});

  final OrderFormState form;
  final Recipe recipe;

  void _set(int quantity) {
    final controller = form.shotQuantityController(recipe);
    form.update(() {
      form.setShotQuantity(recipe, quantity);
      controller.text = '${form.shotQuantities[recipe.name] ?? 1}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final controller = form.shotQuantityController(recipe);
    final quantity = form.shotQuantities[recipe.name] ?? 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'order_wizard.shot_quantity'.tr(),
              style: AppText.body.copyWith(color: p.textSecondary),
            ),
          ),
          InfoButton(
            tooltip: 'order_setup.shot_quantity_info'.tr(),
            title: 'order_setup.shot_quantity_info_title'.tr(),
            message: 'order_setup.shot_quantity_info_message'.tr(),
          ),
          StepperButton(
            icon: Icons.remove,
            semanticLabel: 'order_wizard.decrease'.tr(),
            onTap: quantity > 1 ? () => _set(quantity - 1) : null,
          ),
          SizedBox(
            width: AppSize.quantityField,
            child: Semantics(
              label: '${recipe.name}: $quantity',
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppText.button.copyWith(color: p.text),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: AppSpace.s12,
                    horizontal: AppSpace.s4,
                  ),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed >= 1) {
                    form.update(() => form.setShotQuantity(recipe, parsed));
                  }
                },
                onEditingComplete: () {
                  controller.text = '${form.shotQuantities[recipe.name] ?? 1}';
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
          ),
          StepperButton(
            icon: Icons.add,
            semanticLabel: 'order_wizard.increase'.tr(),
            onTap: () => _set(quantity + 1),
          ),
        ],
      ),
    );
  }
}
