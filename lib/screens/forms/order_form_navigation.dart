import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'order_form_state.dart';

/// Mobile bottom bar: back/next, or on the last step the submit button
/// (staff additionally get "generate with Claude").
class OrderFormMobileFooter extends StatelessWidget {
  const OrderFormMobileFooter({
    super.key,
    required this.form,
    required this.isEmployeeOrHigher,
    required this.onNext,
    required this.onBack,
    required this.onGenerateShoppingList,
  });

  final OrderFormState form;
  final bool isEmployeeOrHigher;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onGenerateShoppingList;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: form.currentStep == OrderFormState.totalSteps - 1
            ? isEmployeeOrHigher
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onGenerateShoppingList,
                            icon: const Icon(Icons.auto_awesome),
                            label: Text('order_form.generate_with_claude'.tr()),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: form.isSubmitting ? null : onNext,
                            icon: form.isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.shopping_cart),
                            label: Text('dashboard.generate_list'.tr()),
                            iconAlignment: IconAlignment.end,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: form.isSubmitting ? null : onNext,
                        icon: form.isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text('order_form.submit_request'.tr()),
                        iconAlignment: IconAlignment.end,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
            : Row(
                children: [
                  Expanded(
                    child: form.currentStep > 0
                        ? OutlinedButton(
                            onPressed: onBack,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('common.back'.tr()),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: form.canProceed(form.currentStep)
                          ? onNext
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('common.next'.tr()),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Desktop left column: title plus one tappable item per step.
class OrderFormStepperSidebar extends StatelessWidget {
  const OrderFormStepperSidebar({
    super.key,
    required this.form,
    required this.onStepSelected,
  });

  final OrderFormState form;

  /// Jumps to a step (no validation).
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'order_setup.title'.tr(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStepperItem(
                  context,
                  0,
                  Icons.celebration,
                  'order_setup.service_type_label'.tr(),
                  'Service auswählen',
                ),
                _buildStepperItem(
                  context,
                  1,
                  Icons.person_outline,
                  'order_setup.basic_info_title'.tr(),
                  'Kontaktdaten',
                ),
                _buildStepperItem(
                  context,
                  2,
                  Icons.calendar_today,
                  'order_setup.event_details_title'.tr(),
                  'Event-Details',
                ),
                _buildStepperItem(
                  context,
                  3,
                  Icons.tune,
                  'order_setup.preferences_title'.tr(),
                  'Präferenzen',
                ),
                _buildStepperItem(
                  context,
                  4,
                  Icons.liquor,
                  'Bargetränke & Alkohol',
                  'Optional',
                ),
                _buildStepperItem(
                  context,
                  5,
                  Icons.local_bar,
                  'Cocktail-Auswahl',
                  'Cocktails',
                ),
                _buildStepperItem(
                  context,
                  6,
                  Icons.bar_chart,
                  'Wahrscheinlichkeiten',
                  'Beliebtheit',
                ),
                _buildStepperItem(
                  context,
                  7,
                  Icons.miscellaneous_services,
                  'Zusatzleistungen',
                  'Optional',
                ),
                _buildStepperItem(
                  context,
                  8,
                  Icons.checklist,
                  'Übersicht',
                  'Zusammenfassung',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperItem(
    BuildContext context,
    int step,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isActive = form.currentStep == step;
    final isCompleted = form.currentStep > step;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onStepSelected(step);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : icon,
                    color: isActive || isCompleted
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        form.stepTitle(step),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isActive
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back/next row embedded at the bottom of each step's content on wide
/// layouts (and always on the overview step).
class OrderFormDesktopActions extends StatelessWidget {
  const OrderFormDesktopActions({
    super.key,
    required this.form,
    required this.isEmployeeOrHigher,
    required this.onNext,
    required this.onBack,
  });

  final OrderFormState form;
  final bool isEmployeeOrHigher;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (form.currentStep == OrderFormState.totalSteps - 1 &&
        !isEmployeeOrHigher) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: form.isSubmitting ? null : onNext,
            icon: form.isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text('order_form.submit_request'.tr()),
            iconAlignment: IconAlignment.end,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (form.currentStep > 0)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: Text('common.back'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          FilledButton.icon(
            onPressed: (form.canProceed(form.currentStep) && !form.isSubmitting)
                ? onNext
                : null,
            icon:
                (form.currentStep == OrderFormState.totalSteps - 1 &&
                    form.isSubmitting)
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    form.currentStep < OrderFormState.totalSteps - 1
                        ? Icons.arrow_forward
                        : Icons.shopping_cart,
                  ),
            label: Text(
              form.currentStep < OrderFormState.totalSteps - 1
                  ? 'common.next'.tr()
                  : 'dashboard.generate_list'.tr(),
            ),
            iconAlignment: IconAlignment.end,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
