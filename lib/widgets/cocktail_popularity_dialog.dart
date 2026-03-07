import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../state/app_state.dart';

/// Dialog to set popularity/probability for each selected cocktail.
/// This helps Gemini AI predict material quantities more accurately.
class CocktailPopularityDialog extends StatefulWidget {
  final List<Recipe> cocktails;
  final VoidCallback onConfirm;

  const CocktailPopularityDialog({
    super.key,
    required this.cocktails,
    required this.onConfirm,
  });

  @override
  State<CocktailPopularityDialog> createState() =>
      _CocktailPopularityDialogState();
}

class _CocktailPopularityDialogState extends State<CocktailPopularityDialog> {
  final Map<String, double> _localPopularity = {};

  @override
  void initState() {
    super.initState();
    // Initialize with current values from AppState
    for (final cocktail in widget.cocktails) {
      _localPopularity[cocktail.name] =
          appState.cocktailPopularity[cocktail.name] ?? 50.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'cocktail_popularity.title'.tr(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'cocktail_popularity.description'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            
            // Cocktail list with sliders
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: widget.cocktails.length,
                itemBuilder: (context, index) {
                  final cocktail = widget.cocktails[index];
                  final popularity = _localPopularity[cocktail.name] ?? 50.0;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cocktail.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPopularityColor(popularity)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${popularity.round()}%',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getPopularityColor(popularity),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'cocktail_popularity.low'.tr(),
                                style: theme.textTheme.bodySmall,
                              ),
                              Expanded(
                                child: Slider(
                                  value: popularity,
                                  min: 0,
                                  max: 100,
                                  divisions: 20,
                                  label: '${popularity.round()}%',
                                  onChanged: (value) {
                                    setState(() {
                                      _localPopularity[cocktail.name] = value;
                                    });
                                  },
                                ),
                              ),
                              Text(
                                'cocktail_popularity.high'.tr(),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Info box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'cocktail_popularity.hint'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('cocktail_popularity.cancel'.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      // Save to AppState
                      appState.setCocktailPopularities(_localPopularity);
                      Navigator.pop(context);
                      widget.onConfirm();
                    },
                    icon: const Icon(Icons.check),
                    label: Text('cocktail_popularity.confirm'.tr()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPopularityColor(double popularity) {
    if (popularity >= 70) {
      return Colors.green;
    } else if (popularity >= 40) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
