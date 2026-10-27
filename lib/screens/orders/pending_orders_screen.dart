import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import 'order_detail_sheet.dart';
import 'pending_orders_view.dart';

import 'package:cocktail_planer/models/app_role.dart';
import 'package:cocktail_planer/widgets/role_protected_screen.dart';

/// Screen displaying orders with pending issues (total = 0)
/// (`/pending-orders`, `/orders/pending`).
class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  Stream<List<SavedOrder>> _stream = orderRepository.watchPendingOrders();

  /// Dismisses like before (`isPendingDismissed = true`) and offers undo.
  Future<bool> _dismiss(SavedOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await orderRepository.dismissPendingOrder(order.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'orders.pending_dismissed'.tr(namedArgs: {'name': order.name})
              : 'orders.pending_dismiss_error'.tr(),
        ),
        action: success
            ? SnackBarAction(
                label: 'orders.pending_dismiss_undo'.tr(),
                onPressed: () async {
                  // Re-activate pending order
                  await orderRepository.updateOrder(order.id, {
                    'isPendingDismissed': false,
                  });
                },
              )
            : null,
      ),
    );
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      minimumRole: AppRole.employee,
      child: StreamBuilder<List<SavedOrder>>(
        stream: _stream,
        builder: (context, snapshot) => PendingOrdersView(
          orders: snapshot.data,
          error: snapshot.error,
          onRetry: () =>
              setState(() => _stream = orderRepository.watchPendingOrders()),
          onOpen: (order) => showOrderDetails(context, order),
          onDismiss: _dismiss,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
    );
  }
}
