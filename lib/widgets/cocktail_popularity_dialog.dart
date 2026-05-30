import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../state/app_state.dart';

/// Dialog to set popularity/probability for each selected cocktail.
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
    for (final cocktail in widget.cocktails) {
      _localPopularity[cocktail.name] =
          appState.cocktailPopularity[cocktail.name] ?? 50.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'cocktail_popularity.description'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                itemCount: widget.cocktails.length,
                itemBuilder: (context, index) {
                  final cocktail = widget.cocktails[index];
                  final popularity = _localPopularity[cocktail.name] ?? 50.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cocktail.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 120,
                          child: Slider(
                            value: popularity,
                            min: 0,
                            max: 100,
                            divisions: 20,
                            onChanged: (value) {
                              setState(() {
                                _localPopularity[cocktail.name] = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${popularity.round()}%',
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getPopularityColor(popularity),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Info + buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                children: [
                  Text(
                    'cocktail_popularity.hint'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('cocktail_popularity.cancel'.tr()),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          appState.setCocktailPopularities(_localPopularity);
                          Navigator.pop(context);
                          widget.onConfirm();
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: Text('cocktail_popularity.confirm'.tr()),
                      ),
                    ],
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
    if (popularity >= 70) return Colors.green;
    if (popularity >= 40) return Colors.orange;
    return Colors.red;
  }
}
