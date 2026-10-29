import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../utils/currency.dart';
import 'detail/microsoft_integration.dart';
import 'detail/order_detail_services.dart';
import 'detail/order_detail_view.dart';

/// Shows the order details in a full app sheet.
/// For form orders without a shopping list, starts the shopping list creation
/// flow with all available data pre-filled.
void showOrderDetails(BuildContext context, SavedOrder order) {
  if (order.isFromForm && !order.hasShoppingList) {
    appState.setPendingFormOrder(order);
    context.push('/order-form');
    return;
  }

  final currency = Currency.fromCode(order.currency);

  showAppSheet<void>(
    context,
    full: true,
    builder: (context) => OrderDetailView(
      order: order,
      currency: currency,
      services: const OrderDetailServices(
        triggerMicrosoftIntegration: runMicrosoftIntegration,
      ),
    ),
  );
}
