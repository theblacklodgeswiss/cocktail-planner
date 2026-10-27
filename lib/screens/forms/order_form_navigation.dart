import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import 'order_form_state.dart';

/// The fixed bottom area of the wizard (inside `StepScaffold.bottom`).
///
/// Steps 0-3: one "Weiter" button (with the drink count on the drinks
/// step). It looks disabled while required fields are missing but stays
/// tappable: [onNext] then reveals the hints instead of doing nothing
/// (staff continue with a second tap).
/// Last step: the single submit button ("Antrag einreichen", staff:
/// "Einkaufsliste generieren"); staff also get the Claude button above.
class OrderFormBottomBar extends StatelessWidget {
  const OrderFormBottomBar({
    super.key,
    required this.form,
    required this.isEmployeeOrHigher,
    required this.onNext,
    required this.onGenerateShoppingList,
  });

  final OrderFormState form;
  final bool isEmployeeOrHigher;
  final VoidCallback onNext;
  final VoidCallback onGenerateShoppingList;

  /// Step of the drink selection (shows the counter in the button).
  static const int drinksStep = 3;

  String _nextLabel() {
    final count = form.selectedRecipes.length;
    if (form.currentStep != drinksStep || count == 0) {
      return 'common.next'.tr();
    }
    return count == 1
        ? 'order_wizard.next_one_drink'.tr()
        : 'order_wizard.next_drinks'.tr(args: ['$count']);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = form.currentStep == OrderFormState.totalSteps - 1;
    if (!isLast) {
      return PrimaryButton(
        label: _nextLabel(),
        dimmed: !form.canProceed(form.currentStep),
        onPressed: onNext,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEmployeeOrHigher) ...[
          SecondaryButton(
            label: 'order_form.generate_with_claude'.tr(),
            onPressed: form.isSubmitting ? null : onGenerateShoppingList,
          ),
          const SizedBox(height: AppSpace.s8),
        ],
        PrimaryButton(
          label: isEmployeeOrHigher
              ? 'dashboard.generate_list'.tr()
              : 'order_form.submit_request'.tr(),
          loading: form.isSubmitting,
          onPressed: onNext,
        ),
      ],
    );
  }
}
