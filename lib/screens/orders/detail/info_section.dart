import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../utils/currency.dart';
import '../order_status_helpers.dart';
import '../widgets/order_info_chip.dart';
import 'employee_section.dart';
import 'order_detail_controller.dart';

/// Date (tap to edit), total, persons, drinker type and the employee
/// assignment.
class OrderInfoCard extends StatelessWidget {
  const OrderInfoCard({
    super.key,
    required this.controller,
    required this.colorScheme,
    required this.currency,
  });

  final OrderDetailController controller;
  final ColorScheme colorScheme;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: controller.editDate,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatDate(controller.currentDate)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: colorScheme.outline),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    currency.format(controller.order.total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OrderInfoChip(
                  icon: Icons.people,
                  label:
                      '${controller.order.personCount} ${'orders.persons'.tr()}',
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 8),
                OrderInfoChip(
                  icon: Icons.local_bar,
                  label: drinkerLabel(controller.order.drinkerType),
                  colorScheme: colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            EmployeeAssignmentWidget(
              watchEmployees: controller.services.watchEmployees,
              assignedEmployeeIds: controller.assignedEmployees,
              onAssignmentChanged: controller.updateAssignedEmployees,
            ),
          ],
        ),
      ),
    );
  }
}
