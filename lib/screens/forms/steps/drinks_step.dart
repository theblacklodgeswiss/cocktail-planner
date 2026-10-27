import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../order_form_state.dart';
import 'bar_drinks_section.dart';
import 'cocktail_picker.dart';
import 'popularity_section.dart';

/// Step 3 "Was soll im Glas sein?": cocktails/shots, the optional
/// popularity section (once something is selected) and, for services with
/// a bar, bar drinks and alcohol purchase. Nothing here is required to
/// continue; the cocktail check happens on submit.
class DrinksStep extends StatelessWidget {
  const DrinksStep({super.key, required this.form, required this.onRetry});

  final OrderFormState form;

  /// Reloads the recipe catalog after a failed load.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CocktailPicker(form: form, onRetry: onRetry),
        const SizedBox(height: AppSpace.s16),
        if (form.selectedRecipes.isNotEmpty) PopularitySection(form: form),
        if (serviceIncludesBar(form.serviceType)) BarDrinksSection(form: form),
      ],
    );
  }
}
