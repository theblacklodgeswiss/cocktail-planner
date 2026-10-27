import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'order_detail_controller.dart';
import 'shopping_actions.dart';

/// Details captured by the web form (form orders only), with "Einkaufsliste
/// erstellen" / "Mit Claude erstellen" while the order has no list.
class FormDetailsCard extends StatelessWidget {
  const FormDetailsCard({
    super.key,
    required this.controller,
    required this.colorScheme,
  });

  final OrderDetailController controller;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final order = controller.order;
    return Card(
      color: order.needsShoppingList
          ? Colors.orange.withValues(alpha: 0.1)
          : Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: order.needsShoppingList ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'orders.form_details'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: order.needsShoppingList
                        ? Colors.orange
                        : Colors.blue,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (order.needsShoppingList)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'orders.no_shopping_list'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFormDetailRow(
              Icons.phone,
              'orders.phone'.tr(),
              order.phone.isNotEmpty ? order.phone : '-',
            ),
            _buildFormDetailRow(
              Icons.location_on,
              'orders.location'.tr(),
              order.location.isNotEmpty ? order.location : '-',
            ),
            _buildFormDetailRow(
              Icons.people,
              'orders.guests'.tr(),
              order.guestCountRange.isNotEmpty ? order.guestCountRange : '-',
            ),
            _buildFormDetailRow(
              Icons.local_bar,
              'orders.mobile_bar'.tr(),
              order.mobileBar ? 'orders.yes'.tr() : 'orders.no'.tr(),
            ),
            _buildFormDetailRow(
              Icons.celebration,
              'orders.event_type'.tr(),
              order.eventType.isNotEmpty ? order.eventType : '-',
            ),
            _buildFormDetailRow(
              Icons.room_service,
              'orders.service_type'.tr(),
              order.serviceType.isNotEmpty ? order.serviceType : '-',
            ),
            if (order.needsShoppingList) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.isOpeningShoppingList
                          ? null
                          : controller.openShoppingList,
                      icon: controller.isOpeningShoppingList
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.shopping_cart),
                      label: Text('orders.create_shopping_list'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.isGeneratingList
                          ? null
                          : () => controller.generateWithGemini(),
                      icon: controller.isGeneratingList
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, color: Colors.white),
                      label: Text(
                        'orders.generate_with_claude'.tr(),
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.outline),
          const SizedBox(width: 8),
          Text('$label:', style: TextStyle(color: colorScheme.outline)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
