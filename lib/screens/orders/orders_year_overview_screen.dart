import 'package:cocktail_planer/data/firestore_service.dart';
import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/app_role.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/widgets/role_protected_screen.dart';
import 'package:flutter/material.dart';

import 'order_detail_sheet.dart';
import 'orders_year_view.dart';

/// Screen showing all orders grouped by year (`/orders/years`). Tapping a
/// year reveals the full list of orders (accepted / declined / offer) for
/// that year.
class OrdersYearOverviewScreen extends StatefulWidget {
  const OrdersYearOverviewScreen({super.key});

  @override
  State<OrdersYearOverviewScreen> createState() =>
      _OrdersYearOverviewScreenState();
}

class _OrdersYearOverviewScreenState extends State<OrdersYearOverviewScreen> {
  Stream<List<SavedOrder>>? _stream;

  @override
  void initState() {
    super.initState();
    if (firestoreService.isAvailable) _subscribe();
    firestoreService.availabilityKnown.then((_) {
      if (mounted) setState(_subscribe);
    });
  }

  void _subscribe() => _stream = orderRepository.watchOrders();

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      minimumRole: AppRole.employee,
      child: StreamBuilder<List<SavedOrder>>(
        stream: _stream,
        builder: (context, snapshot) => OrdersYearView(
          orders: snapshot.data,
          error: snapshot.error,
          onRetry: () => setState(_subscribe),
          onOpen: (order) => showOrderDetails(context, order),
        ),
      ),
    );
  }
}
