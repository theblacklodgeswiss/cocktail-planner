import 'package:flutter/material.dart';

import '../orders/orders_overview_screen.dart';

/// Staff landing at `/`: the same orders list as `/orders` (one
/// implementation, framed by `StaffScaffold`), without the back arrow.
class StaffHome extends StatelessWidget {
  const StaffHome({super.key});

  @override
  Widget build(BuildContext context) =>
      const OrdersOverviewScreen(showBack: false);
}
