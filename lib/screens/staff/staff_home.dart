import 'package:flutter/material.dart';

import '../orders/orders_overview_screen.dart';

/// Staff landing at `/`: the same orders list as `/orders` (one
/// implementation, a root page of the orders tab in the staff shell).
class StaffHome extends StatelessWidget {
  const StaffHome({super.key});

  @override
  Widget build(BuildContext context) => const OrdersOverviewScreen();
}
