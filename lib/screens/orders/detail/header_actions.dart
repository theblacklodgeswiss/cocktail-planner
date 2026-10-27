import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'order_detail_controller.dart';
import 'order_detail_logic.dart';
import 'shopping_section.dart';

/// Top of the sheet: "Angebot finalisieren", "Rechnung" (accepted and
/// completed) and the shopping-list box; vertical below 700 px.
class OrderHeaderActions extends StatelessWidget {
  const OrderHeaderActions({super.key, required this.controller});

  final OrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          if (isNarrow) {
            // Vertical layout for narrow screens
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: controller.isOpeningOffer
                        ? null
                        : controller.openOfferEditor,
                    icon: controller.isOpeningOffer
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: Text('orders.finalize_offer'.tr()),
                  ),
                  if (controller.actions.contains(
                    OrderDetailAction.invoice,
                  )) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: controller.isOpeningInvoice
                          ? null
                          : controller.generateInvoice,
                      icon: controller.isOpeningInvoice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_long),
                      label: Text('orders.invoice'.tr()),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ShoppingListSection(controller: controller, vertical: true),
                ],
              ),
            );
          } else {
            // Horizontal layout for wider screens
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: controller.isOpeningOffer
                        ? null
                        : controller.openOfferEditor,
                    icon: controller.isOpeningOffer
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: Text('orders.finalize_offer'.tr()),
                  ),
                  if (controller.actions.contains(
                    OrderDetailAction.invoice,
                  )) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: controller.isOpeningInvoice
                          ? null
                          : controller.generateInvoice,
                      icon: controller.isOpeningInvoice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_long),
                      label: Text('orders.invoice'.tr()),
                    ),
                  ],
                  const SizedBox(width: 8),
                  ShoppingListSection(controller: controller, vertical: false),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
