import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../models/order.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/offer/create_offer_screen.dart';
import '../screens/orders/orders_overview_screen.dart';
import '../screens/orders/pending_orders_screen.dart';
import '../screens/settings/admin_settings_screen.dart';
import '../screens/settings/employees_screen.dart';
import '../screens/settings/legal_info_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/user_management_screen.dart';
import '../screens/shopping_list/shopping_list_screen.dart';

/// Notifier that listens to Firebase Auth state changes
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final isLoginRoute = state.matchedLocation == '/login';

    // Not logged in and not on login page -> redirect to login
    if (!isLoggedIn && !isLoginRoute) {
      return '/login';
    }

    // Logged in and on login page -> redirect to home
    if (isLoggedIn && isLoginRoute) {
      return '/';
    }

    // No redirect needed
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/shopping-list',
      builder: (context, state) => const ShoppingListScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/legal/imprint',
      builder: (context, state) => const LegalInfoScreen(type: LegalInfoType.imprint),
    ),
    GoRoute(
      path: '/settings/legal/terms',
      builder: (context, state) => const LegalInfoScreen(type: LegalInfoType.terms),
    ),
    GoRoute(
      path: '/settings/legal/privacy',
      builder: (context, state) => const LegalInfoScreen(type: LegalInfoType.privacy),
    ),
    GoRoute(
      path: '/settings/admin',
      builder: (context, state) => const AdminSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/users',
      builder: (context, state) => const UserManagementScreen(),
    ),
    GoRoute(
      path: '/settings/employees',
      builder: (context, state) => const EmployeesScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersOverviewScreen(),
    ),
    GoRoute(
      path: '/orders/pending',
      builder: (context, state) => const PendingOrdersScreen(),
    ),
    GoRoute(
      path: '/create-offer',
      builder: (context, state) {
        final order = state.extra as SavedOrder;
        return CreateOfferScreen(order: order);
      },
    ),
  ],
);
