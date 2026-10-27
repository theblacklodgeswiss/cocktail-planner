import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/additional_service.dart';
import '../../../utils/order_option_labels.dart';
import '../order_form_state.dart';

/// Step 7: catalog services (variant picker), "other" and remarks.
class AdditionalServicesStep extends StatelessWidget {
  const AdditionalServicesStep({
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
            'order_setup.additional_services_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.additional_services_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          if (form.serviceCatalog.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'order_setup.additional_services_empty'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: form.serviceCatalog.length,
              itemBuilder: (context, index) =>
                  _buildServiceTile(context, form.serviceCatalog[index]),
            ),
          if (form.legacyAdditionalServiceIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: form.legacyAdditionalServiceIds
                  .map(
                    (value) => Chip(
                      label: Text(
                        formatOrderAdditionalServiceLabel(
                          value,
                          isEnglish: context.locale.languageCode == 'en',
                          currencyCode: form.currency,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: form.otherServicesSelected,
                label: Text(
                  context.locale.languageCode == 'en' ? 'Other' : 'Sonstiges',
                ),
                showCheckmark: true,
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  form.update(() => form.otherServicesSelected = selected);
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'order_setup.remarks_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.remarks_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: form.remarksController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'order_setup.remarks_hint'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            desktopActions(),
          ],
        ],
      ),
    );
  }

  /// One tile per catalog [AdditionalService]: shows its image (or a
  /// placeholder icon), name, and - once the customer has picked a variant
  /// for it - a check badge plus the chosen variant's name/price. Tapping
  /// opens [_showServiceVariantPicker].
  Widget _buildServiceTile(BuildContext context, AdditionalService service) {
    final selectedVariantId = form.selectedAdditionalServices[service.id];
    final selectedVariant = selectedVariantId != null
        ? service.variantById(selectedVariantId)
        : null;
    final isSelected = selectedVariant != null;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showServiceVariantPicker(context, service),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.2)
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          service.imageUrl != null &&
                              service.imageUrl!.isNotEmpty
                          ? Image.network(
                              service.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildServiceTilePlaceholder(
                                    context,
                                    colorScheme,
                                  ),
                            )
                          : _buildServiceTilePlaceholder(context, colorScheme),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (selectedVariant != null)
              Text(
                _formatVariantSummary(context, selectedVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTilePlaceholder(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.room_service,
        size: 40,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _formatVariantSummary(BuildContext context, ServiceVariant variant) {
    final isEnglish = context.locale.languageCode == 'en';
    final priceLabel = variant.price != null
        ? '${variant.price!.toStringAsFixed(0)} ${form.currency}'
        : (isEnglish ? 'price on request' : 'Preis auf Anfrage');
    return '${variant.name} ($priceLabel)';
  }

  /// Opens a single-select bottom sheet listing [service]'s variants; the
  /// customer picks at most one. Confirming updates
  /// [form.selectedAdditionalServices] and closes the sheet.
  Future<void> _showServiceVariantPicker(
    BuildContext context,
    AdditionalService service,
  ) async {
    if (service.variants.isEmpty) return;
    var selectedVariantId = form.selectedAdditionalServices[service.id];
    final isEnglish = context.locale.languageCode == 'en';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final variant in service.variants)
                  ListTile(
                    leading: Icon(
                      selectedVariantId == variant.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selectedVariantId == variant.id
                          ? Theme.of(ctx).colorScheme.primary
                          : null,
                    ),
                    title: Text(variant.name),
                    subtitle: Text(
                      variant.price != null
                          ? '${variant.price!.toStringAsFixed(0)} ${form.currency}'
                          : (isEnglish
                                ? 'Price on request'
                                : 'Preis auf Anfrage'),
                    ),
                    onTap: () =>
                        setSheetState(() => selectedVariantId = variant.id),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (form.selectedAdditionalServices.containsKey(service.id))
                      TextButton(
                        onPressed: () {
                          setSheetState(() => selectedVariantId = null);
                        },
                        child: Text(isEnglish ? 'Clear' : 'Entfernen'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('common.ok'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    HapticFeedback.selectionClick();
    form.update(() {
      if (selectedVariantId == null) {
        form.selectedAdditionalServices.remove(service.id);
      } else {
        form.selectedAdditionalServices[service.id] = selectedVariantId!;
      }
    });
  }
}
