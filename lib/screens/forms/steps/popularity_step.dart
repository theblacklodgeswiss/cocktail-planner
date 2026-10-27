import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../order_form_state.dart';

/// Step 6: expected popularity (0-100 %) per selected cocktail.
class PopularityStep extends StatelessWidget {
  const PopularityStep({
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
    if (form.selectedRecipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
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
                'Bitte zuerst Cocktails auswählen (Schritt 6).',
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

    form.syncPopularityWithSelection();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wie beliebt werden die Cocktails sein?',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Schätze die Wahrscheinlichkeit, wie oft jeder Cocktail bestellt wird. Das hilft uns, die richtigen Mengen einzukaufen.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          ...form.selectedRecipes.map((recipe) {
            final popularity = form.cocktailPopularity[recipe.name] ?? 50.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${popularity.round()}%',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: popularity,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        form.update(
                          () => form.cocktailPopularity[recipe.name] = val,
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selten',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          'Sehr beliebt',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            desktopActions(),
          ],
        ],
      ),
    );
  }
}
