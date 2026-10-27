import 'package:flutter/material.dart';

import '../orders/orders_overview_screen.dart';

/// Staff landing at `/`: the orders list with the staff bar (the orders
/// screen frames itself with `StaffFrame`). Task 11 replaces the list with
/// the redesigned one inside `StaffScaffold`.
class StaffHome extends StatelessWidget {
  const StaffHome({super.key});

  @override
  Widget build(BuildContext context) =>
      const OrdersOverviewScreen(showBack: false);
}
