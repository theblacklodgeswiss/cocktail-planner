import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../order_form_state.dart';
import 'bar_drinks_section.dart';
import 'cocktail_picker.dart';
import 'popularity_section.dart';

/// Step 3 "Was soll im Glas sein?": for services with a bar first bar
/// drinks and alcohol purchase, then cocktails/shots and the optional
/// popularity section (once something is selected). Nothing here is required to
/// continue; the cocktail check happens on submit.
class DrinksStep extends StatelessWidget {
  const DrinksStep({super.key, required this.form, required this.onRetry});

  final OrderFormState form;

  /// Reloads the recipe catalog after a failed load.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Bar services start with the (short) bar drinks section so it is not
    // buried below the whole cocktail list.
    final barFirst = serviceIncludesBar(form.serviceType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (barFirst) BarDrinksSection(form: form),
        CocktailPicker(form: form, onRetry: onRetry),
        const SizedBox(height: AppSpace.s16),
        if (form.selectedRecipes.isNotEmpty) PopularitySection(form: form),
      ],
    );
  }
}
