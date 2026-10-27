import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../utils/currency.dart';
import 'detail/microsoft_integration.dart';
import 'detail/order_detail_services.dart';
import 'detail/order_detail_view.dart';

/// Shows the order details in a modal bottom sheet.
/// For form orders without a shopping list, starts the shopping list creation
/// flow with all available data pre-filled.
void showOrderDetails(BuildContext context, SavedOrder order) {
  if (order.isFromForm && !order.hasShoppingList) {
    appState.setPendingFormOrder(order);
    context.push('/order-form');
    return;
  }

  final colorScheme = Theme.of(context).colorScheme;
  final currency = Currency.fromCode(order.currency);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => OrderDetailView(
      order: order,
      colorScheme: colorScheme,
      currency: currency,
      services: const OrderDetailServices(
        triggerMicrosoftIntegration: runMicrosoftIntegration,
      ),
    ),
  );
}
