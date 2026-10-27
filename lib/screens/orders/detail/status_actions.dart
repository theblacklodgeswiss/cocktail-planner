import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../order_status_helpers.dart';
import 'order_detail_controller.dart';
import 'order_detail_logic.dart';

/// Status card: current status, decline reason, and the status actions
/// from [availableActions].
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({super.key, required this.controller});

  final OrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    final actions = controller.actions;

    return Card(
      color: statusColor(controller.currentStatus).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  statusIcon(controller.currentStatus),
                  color: statusColor(controller.currentStatus),
                ),
                const SizedBox(width: 8),
                Text(
                  '${"orders.status".tr()}: ${statusLabel(controller.currentStatus)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor(controller.currentStatus),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (actions.contains(OrderDetailAction.editDeclineReason)) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: controller.editDeclineReason,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          controller.declineReason.isEmpty
                              ? 'orders.decline_reason_add'.tr()
                              : '${'orders.decline_reason'.tr()}: ${controller.declineReason}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontStyle: controller.declineReason.isEmpty
                                    ? FontStyle.italic
                                    : null,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Show "Complete Offer" button if offer is incomplete and status is quote
            if (actions.contains(OrderDetailAction.completeOffer)) ...[
              Text(
                'orders.offer_incomplete'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.isOpeningOffer
                      ? null
                      : controller.openOfferEditor,
                  icon: controller.isOpeningOffer
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.edit_document),
                  label: Text('orders.complete_offer'.tr()),
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
            ] else ...[
              if (actions.contains(OrderDetailAction.recordRest)) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.recordRest,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text('rest.record'.tr()),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'orders.change_status'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (actions.contains(OrderDetailAction.complete))
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.isUpdatingStatus
                            ? null
                            : () => controller.updateStatus(
                                OrderStatus.completed,
                              ),
                        icon: controller.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified),
                        label: Text('orders.complete'.tr()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.complete))
                    const SizedBox(width: 8),
                  if (actions.contains(OrderDetailAction.backToAccepted))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.isUpdatingStatus
                            ? null
                            : () =>
                                  controller.updateStatus(OrderStatus.accepted),
                        icon: controller.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.undo),
                        label: Text('orders.back_to_accepted'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.accept))
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                (!acceptBlockedByTotal(
                                      controller.order.total,
                                    ) &&
                                    !controller.isUpdatingStatus)
                                ? () => controller.tryUpdateStatus(
                                    OrderStatus.accepted,
                                  )
                                : null,
                            icon: controller.isUpdatingStatus
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text('orders.accept'.tr()),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                          if (acceptBlockedByTotal(controller.order.total))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Erst Einkaufsliste erstellen',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: Colors.orange),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.accept) &&
                      actions.contains(OrderDetailAction.decline))
                    const SizedBox(width: 8),
                  if (actions.contains(OrderDetailAction.decline))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.isUpdatingStatus
                            ? null
                            : () =>
                                  controller.updateStatus(OrderStatus.declined),
                        icon: controller.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.close),
                        label: Text('orders.decline'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.backToQuote)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.isUpdatingStatus
                            ? null
                            : () => controller.updateStatus(OrderStatus.quote),
                        icon: controller.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.undo),
                        label: Text('orders.status_quote'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Auftrag löschen" at the bottom (super admin only, decided by the
/// caller via [OrderDetailAction.delete]).
class DeleteOrderSection extends StatelessWidget {
  const DeleteOrderSection({super.key, required this.controller});

  final OrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: controller.deleteOrder,
            icon: const Icon(Icons.delete_forever),
            label: Text('orders.delete_order'.tr()),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ),
      ],
    );
  }
}
