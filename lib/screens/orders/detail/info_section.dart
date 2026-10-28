import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/date_tile.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/pressable.dart';
import '../../../utils/currency.dart';
import '../order_status_helpers.dart';
import 'employee_section.dart';
import 'order_detail_controller.dart';

/// Date (tap to edit), total, persons, drinker type and the employee
/// assignment.
class OrderInfoCard extends StatelessWidget {
  const OrderInfoCard({
    super.key,
    required this.controller,
    required this.currency,
  });

  final OrderDetailController controller;
  final Currency currency;

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
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Pressable(
                    minSize: AppSize.minTap,
                    onTap: controller.editDate,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DateTile(controller.currentDate),
                        const SizedBox(width: AppSpace.s8),
                        Flexible(
                          child: Text(
                            formatDate(controller.currentDate),
                            style: AppText.body.copyWith(color: p.text),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s4),
                        Icon(
                          Icons.edit_outlined,
                          size: AppSize.metaIcon,
                          color: p.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                currency.format(order.total),
                style: AppText.number.copyWith(color: p.text),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s16,
            runSpacing: AppSpace.s8,
            children: [
              _Meta(
                icon: Icons.people_outline,
                label: '${order.personCount} ${'orders.persons'.tr()}',
              ),
              _Meta(
                icon: Icons.local_bar_outlined,
                label: drinkerLabel(order.drinkerType),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Divider(
            height: AppSize.hairline,
            thickness: AppSize.hairline,
            color: p.border,
          ),
          const SizedBox(height: AppSpace.s12),
          EmployeeAssignmentWidget(
            watchEmployees: controller.services.watchEmployees,
            assignedEmployeeIds: controller.assignedEmployees,
            onAssignmentChanged: controller.updateAssignedEmployees,
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSize.metaIcon, color: p.textSecondary),
        const SizedBox(width: AppSpace.s4),
        Flexible(
          child: Text(
            label,
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    );
  }
}
