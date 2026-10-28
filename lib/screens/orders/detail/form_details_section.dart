import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import 'order_detail_controller.dart';
import 'shopping_actions.dart';

/// Details captured by the web form (form orders only), with "Einkaufsliste
/// erstellen" / "Mit Claude erstellen" while the order has no list.
class FormDetailsCard extends StatelessWidget {
  const FormDetailsCard({super.key, required this.controller});

  final OrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final order = controller.order;
    return FloatingCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: AppSize.rowIcon,
                color: p.textSecondary,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'orders.form_details'.tr(),
                  style: AppText.section.copyWith(color: p.text),
                ),
              ),
              if (order.needsShoppingList) ...[
                const SizedBox(width: AppSpace.s8),
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s8,
                        vertical: AppSpace.s4,
                      ),
                      child: Text(
                        'orders.no_shopping_list'.tr(),
                        style: AppText.pill.copyWith(color: p.goldText),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          _row(
            p,
            Icons.phone_outlined,
            'orders.phone'.tr(),
            order.phone.isNotEmpty ? order.phone : '-',
          ),
          _row(
            p,
            Icons.location_on_outlined,
            'orders.location'.tr(),
            order.location.isNotEmpty ? order.location : '-',
          ),
          _row(
            p,
            Icons.people_outline,
            'orders.guests'.tr(),
            order.guestCountRange.isNotEmpty ? order.guestCountRange : '-',
          ),
          _row(
            p,
            Icons.local_bar_outlined,
            'orders.mobile_bar'.tr(),
            order.mobileBar ? 'orders.yes'.tr() : 'orders.no'.tr(),
          ),
          _row(
            p,
            Icons.celebration_outlined,
            'orders.event_type'.tr(),
            order.eventType.isNotEmpty ? order.eventType : '-',
          ),
          _row(
            p,
            Icons.room_service_outlined,
            'orders.service_type'.tr(),
            order.serviceType.isNotEmpty ? order.serviceType : '-',
          ),
          if (order.needsShoppingList) ...[
            const SizedBox(height: AppSpace.s8),
            SecondaryButton(
              label: 'orders.create_shopping_list'.tr(),
              loading: controller.isOpeningShoppingList,
              onPressed: controller.isOpeningShoppingList
                  ? null
                  : controller.openShoppingList,
            ),
            const SizedBox(height: AppSpace.s8),
            SecondaryButton(
              label: 'orders.generate_with_claude'.tr(),
              loading: controller.isGeneratingList,
              onPressed: controller.isGeneratingList
                  ? null
                  : () => controller.generateWithGemini(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(AppPalette p, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSize.metaIcon, color: p.textSecondary),
          const SizedBox(width: AppSpace.s8),
          Text('$label:', style: AppText.body.copyWith(color: p.textSecondary)),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              value,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w500,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
