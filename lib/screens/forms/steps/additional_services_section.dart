import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/additional_service.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/pressable.dart';
import '../../../utils/order_option_labels.dart';
import '../order_form_state.dart';
import 'wizard_widgets.dart';

/// Catalog services (one variant each, picked in a sheet), "Sonstiges" and
/// the read-only legacy service IDs of old orders.
class AdditionalServicesSection extends StatelessWidget {
  const AdditionalServicesSection({super.key, required this.form});

  final OrderFormState form;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isEnglish = context.locale.languageCode == 'en';
    return WizardSection(
      caption: 'order_wizard.services_caption'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'order_setup.additional_services_subtitle'.tr(),
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpace.s12),
          if (form.serviceCatalog.isEmpty)
            Text(
              'order_setup.additional_services_empty'.tr(),
              style: AppText.body.copyWith(color: p.textSecondary),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: AppSize.serviceTileExtent,
                childAspectRatio: AppSize.serviceTileAspect,
                crossAxisSpacing: AppSpace.s8,
                mainAxisSpacing: AppSpace.s8,
              ),
              itemCount: form.serviceCatalog.length,
              itemBuilder: (context, index) =>
                  _ServiceTile(form: form, service: form.serviceCatalog[index]),
            ),
          const SizedBox(height: AppSpace.s12),
          PillGroup(
            children: [
              // Legacy bare IDs round-trip unchanged but can't be edited.
              for (final value in form.legacyAdditionalServiceIds)
                _LegacyChip(
                  label: formatOrderAdditionalServiceLabel(
                    value,
                    isEnglish: isEnglish,
                    currencyCode: form.currency,
                  ),
                ),
              SelectPill(
                label: 'order_wizard.other_service'.tr(),
                selected: form.otherServicesSelected,
                onTap: () => form.update(
                  () =>
                      form.otherServicesSelected = !form.otherServicesSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegacyChip extends StatelessWidget {
  const _LegacyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.minTap),
      child: Align(
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s8,
            ),
            child: Text(label, style: AppText.body.copyWith(color: p.text)),
          ),
        ),
      ),
    );
  }
}

/// One catalog service: image (or placeholder), name and - once a variant
/// is picked - a check and the variant with its price. Tap opens the
/// variant sheet.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.form, required this.service});

  final OrderFormState form;
  final AdditionalService service;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final variantId = form.selectedAdditionalServices[service.id];
    final variant = variantId != null ? service.variantById(variantId) : null;
    final selected = variant != null;
    return Pressable(
      radius: AppRadius.tile,
      selected: selected,
      onTap: () => _pickVariant(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: selected ? p.primary : p.border,
            width: selected ? AppSize.focusRing : AppSize.hairline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        child:
                            service.imageUrl != null &&
                                service.imageUrl!.isNotEmpty
                            ? Image.network(
                                service.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _placeholder(context),
                              )
                            : _placeholder(context),
                      ),
                    ),
                    Positioned(
                      top: AppSpace.s4,
                      right: AppSpace.s4,
                      child: CheckMark(selected: selected),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: p.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (variant != null)
                Text(
                  _variantSummary(context, variant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: p.goldText),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final p = AppPalette.of(context);
    return ColoredBox(
      color: p.surface,
      child: Center(
        child: Icon(
          Icons.room_service,
          size: AppSize.placeholderIcon,
          color: p.textSecondary,
        ),
      ),
    );
  }

  String _price(BuildContext context, ServiceVariant variant) =>
      variant.price != null
      ? '${variant.price!.toStringAsFixed(0)} ${form.currency}'
      : 'order_wizard.price_on_request'.tr();

  String _variantSummary(BuildContext context, ServiceVariant variant) =>
      '${variant.name} (${_price(context, variant)})';

  /// Single-select sheet of [service]'s variants; OK applies the choice
  /// (none clears it).
  Future<void> _pickVariant(BuildContext context) async {
    if (service.variants.isEmpty) return;
    var choice = form.selectedAdditionalServices[service.id];
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheetState) {
          final p = AppPalette.of(sheet);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                service.name,
                style: AppText.heroTitle.copyWith(color: p.text),
              ),
              const SizedBox(height: AppSpace.s8),
              for (final variant in service.variants)
                Pressable(
                  minSize: AppSize.minTap,
                  selected: choice == variant.id,
                  onTap: () => setSheetState(() => choice = variant.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                    child: Row(
                      children: [
                        CheckMark(selected: choice == variant.id),
                        const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                variant.name,
                                style: AppText.button.copyWith(color: p.text),
                              ),
                              Text(
                                _price(sheet, variant),
                                style: AppText.caption.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s16),
              PrimaryButton(
                label: 'common.ok'.tr(),
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
              if (form.selectedAdditionalServices.containsKey(service.id)) ...[
                const SizedBox(height: AppSpace.s8),
                TextAction(
                  label: 'order_wizard.clear_variant'.tr(),
                  onPressed: () => setSheetState(() => choice = null),
                ),
              ],
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.selectionClick();
    form.update(() {
      if (choice == null) {
        form.selectedAdditionalServices.remove(service.id);
      } else {
        form.selectedAdditionalServices[service.id] = choice!;
      }
    });
  }
}
