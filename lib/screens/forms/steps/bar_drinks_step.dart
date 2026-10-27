import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../order_form_state.dart';

/// Step 4: bar drink categories and alcohol purchase (bar services only).
class BarDrinksStep extends StatelessWidget {
  const BarDrinksStep({
    super.key,
    required this.form,
    required this.desktopActions,
  });

  /// The shared wizard state (read for display, mutated via `update`).
  final OrderFormState form;

  /// Builds the desktop back/next row (only shown at width >= 600).
  final Widget Function() desktopActions;

  @override
  Widget build(BuildContext context) {
    // Skip this step if service type doesn't include bar service
    if (form.serviceType != 'cocktail_barservice' &&
        form.serviceType != 'bar_service') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Dieser Schritt ist für Ihren ausgewählten Service nicht erforderlich.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Barservice - Welche Getränke sollen ausgeschenkt werden?',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Wähle alle zutreffenden Kategorien',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          _buildBarDrinksSelector(context),
          const SizedBox(height: 32),
          _buildAlcoholPurchaseSelector(context),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            desktopActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildBarDrinksSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.bar_drinks_title'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'order_setup.bar_drinks_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBarDrinkCheckbox(
              context,
              'whiskey_mix',
              'Whiskey & Mischgetränke',
            ),
            _buildBarDrinkCheckbox(
              context,
              'vodka_mix',
              'Vodka & Mischgetränke',
            ),
            _buildBarDrinkCheckbox(context, 'gin_mix', 'Gin & Mischgetränke'),
            _buildBarDrinkCheckbox(context, 'shots', 'Shots'),
            _buildBarDrinkCheckbox(context, 'other', 'Sonstiges'),
          ],
        ),
      ],
    );
  }

  Widget _buildBarDrinkCheckbox(
    BuildContext context,
    String value,
    String label,
  ) {
    final isSelected = form.selectedBarDrinks.contains(value);
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        HapticFeedback.selectionClick();
        form.update(() {
          if (selected) {
            form.selectedBarDrinks.add(value);
          } else {
            form.selectedBarDrinks.remove(value);
          }
        });
      },
      showCheckmark: true,
    );
  }

  Widget _buildAlcoholPurchaseSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.alcohol_purchase_title'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'order_setup.alcohol_purchase_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAlcoholCheckbox(
              context,
              'whiskey_chivas',
              'Whiskey Chivas 0.7L - 35,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'whiskey_black_label',
              'Whiskey Black Label 0.7L - 35,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'vodka_absolut',
              'Vodka Absolut 0.7L - 25,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'vodka_three_sixty',
              'Vodka Three Sixty 0.7L - 25,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'vodka_ciroc',
              'Vodka Ciroc 0.7L - 40,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'vodka_belvedere',
              'Vodka Belvedere 0.7L - 45,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'vodka_grey_goose',
              'Vodka Grey Goose 0.7L - 45,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'gin_bombay',
              'Gin Bombay Saphire 0.7L - 25,-',
            ),
            _buildAlcoholCheckbox(
              context,
              'gin_bulldog',
              'Gin Bulldog 0.7L - 35,-',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlcoholCheckbox(
    BuildContext context,
    String value,
    String label,
  ) {
    final isSelected = form.selectedAlcoholItems.contains(value);
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        HapticFeedback.selectionClick();
        form.update(() {
          if (selected) {
            form.selectedAlcoholItems.add(value);
          } else {
            form.selectedAlcoholItems.remove(value);
          }
        });
      },
      showCheckmark: true,
    );
  }
}
