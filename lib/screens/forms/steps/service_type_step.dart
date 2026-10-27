import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../order_form_state.dart';

/// Step 0: which service (cocktail & bar, cocktails, mocktails, bar).
class ServiceTypeStep extends StatelessWidget {
  const ServiceTypeStep({
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.service_type_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.service_type_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          _buildServiceCard(
            context,
            'cocktail_barservice',
            Icons.celebration,
            'order_setup.service_cocktail_barservice'.tr(),
            'order_setup.service_cocktail_barservice_desc'.tr(),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            context,
            'cocktail_service',
            Icons.local_bar,
            'order_setup.service_cocktailservice'.tr(),
            'order_setup.service_cocktailservice_desc'.tr(),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            context,
            'mocktail_service',
            Icons.no_drinks,
            'order_setup.service_mocktailservice'.tr(),
            'order_setup.service_mocktailservice_desc'.tr(),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            context,
            'bar_service',
            Icons.liquor,
            'order_setup.service_barservice'.tr(),
            'order_setup.service_barservice_desc'.tr(),
          ),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            desktopActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String value,
    IconData icon,
    String title,
    String description,
  ) {
    final isSelected = form.serviceType == value;
    return Card(
      elevation: isSelected ? 8 : 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          form.update(() => form.selectServiceType(value));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
