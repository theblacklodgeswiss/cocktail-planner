import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/firestore_service.dart';
import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/states.dart';
import '../orders/order_detail_sheet.dart';
import 'customer_landing_screen.dart';
import 'staff_dashboard_view.dart';
import 'user_menu_sheet.dart';

/// `/dashboard`: the staff dashboard ([StaffDashboardView]) for employees
/// and up, otherwise the customer landing.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _initialized = false;
  Stream<List<SavedOrder>>? _stream;

  /// All years (no pending): upcoming appointments and all-time KPIs.
  Stream<List<SavedOrder>>? _all;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_initialized) {
      await authService.checkIsAdmin();
      await firestoreService.initialize();
      if (mounted) {
        setState(() {
          _subscribe();
          _initialized = true;
        });
      }
    }
  }

  void _subscribe() {
    _stream = orderRepository.watchOrders(
      includePending: true,
      year: DateTime.now().year, // Only current year
    );
    _all = orderRepository.watchOrders();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking admin status
    if (!_initialized) {
      return const Scaffold(body: LoadingState());
    }

    // Non-staff users see the customer landing screen
    if (!authService.isEmployeeOrHigher) {
      return const CustomerLandingScreen();
    }

    return StreamBuilder<List<SavedOrder>>(
      stream: _all,
      builder: (context, all) => StreamBuilder<List<SavedOrder>>(
        stream: _stream,
        builder: (context, snapshot) => StaffDashboardView(
          orders: snapshot.data,
          allOrders: all.data,
          error: snapshot.error,
          onRetry: () => setState(_subscribe),
          now: DateTime.now(),
          isAdmin: authService.isAdmin,
          onOpen: (order) => showOrderDetails(context, order),
          actions: [
            GlassIconButton(
              icon: Icons.settings_outlined,
              semanticLabel: 'settings.title'.tr(),
              onPressed: () => context.push('/settings'),
            ),
            GlassIconButton(
              icon: Icons.person_outline,
              semanticLabel: 'dashboard.user_tooltip'.tr(),
              onPressed: () => showUserMenu(context),
            ),
          ],
        ),
      ),
    );
  }
}
