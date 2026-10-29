import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/order.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/dashboard/customer_landing_screen.dart';
import '../screens/dashboard/my_requests_screen.dart';
import '../screens/dashboard/simple_dashboard_screen.dart';
import '../screens/forms/modern_order_form_screen.dart';
import '../screens/forms/order_success_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/invoice/create_invoice_screen.dart';
import '../screens/login_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/offer/create_offer_screen.dart';
import '../screens/share/shared_document_screen.dart';
import '../screens/orders/orders_overview_screen.dart';
import '../screens/orders/orders_year_overview_screen.dart';
import '../screens/orders/pending_orders_screen.dart';
import '../screens/settings/admin_settings_screen.dart';
import '../screens/settings/employees_screen.dart';
import '../screens/settings/legal_info_screen.dart';
import '../screens/settings/services_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/user_management_screen.dart';
import '../screens/shopping_list/shopping_list_screen.dart';
import '../services/auth_service.dart';
import 'app_routes.dart';

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
    final isPublicShareRoute = state.matchedLocation.startsWith('/s/');

    // Not logged in and not on login page or a public share link -> redirect to login
    if (!isLoggedIn && !isLoginRoute && !isPublicShareRoute) {
      return '/login';
    }

    // Logged in and on login page -> redirect to home
    if (isLoggedIn && isLoginRoute) {
      return '/';
    }

    // No redirect needed
    return null;
  },
  routes: buildAppRoutes(
    page: _page,
    isStaff: _isStaff,
    staffChanges: authService.roleChanges.map((_) => _isStaff()),
  ),
);

bool _isStaff() => authService.roleResolved && authService.isEmployeeOrHigher;

/// The real screen of each [AppPage]; route params and extras as before.
Widget _page(
  BuildContext context,
  GoRouterState state,
  AppPage page,
) => switch (page) {
  AppPage.login => const LoginScreen(),
  AppPage.sharedDocument => SharedDocumentScreen(
    code: state.pathParameters['code']!,
  ),
  AppPage.home => const CustomerLandingScreen(),
  // `extra` of a link to the orders tab (e.g. from the dashboard) is a
  // fresh nonce, so a repeated link resets the filter of the kept page.
  AppPage.orders => OrdersOverviewScreen(
    initialStatus: state.uri.queryParameters['status'],
    filterNonce: state.extra,
  ),
  AppPage.inventory => const InventoryScreen(),
  AppPage.more => const MoreScreen(),
  AppPage.dashboard => const DashboardScreen(),
  AppPage.myRequests => const MyRequestsScreen(),
  AppPage.pendingOrders => const PendingOrdersScreen(),
  AppPage.shoppingList => ShoppingListScreen(orderSetup: state.extra),
  AppPage.orderForm => ModernOrderFormScreen(
    prefill: state.extra is SavedOrder ? state.extra as SavedOrder : null,
  ),
  AppPage.orderSuccess => const OrderSuccessScreen(),
  AppPage.admin => const AdminScreen(),
  AppPage.settings => const SettingsScreen(),
  AppPage.legalImprint => const LegalInfoScreen(type: LegalInfoType.imprint),
  AppPage.legalTerms => const LegalInfoScreen(type: LegalInfoType.terms),
  AppPage.legalPrivacy => const LegalInfoScreen(type: LegalInfoType.privacy),
  AppPage.adminSettings => const AdminSettingsScreen(),
  AppPage.userManagement => const UserManagementScreen(),
  AppPage.employees => const EmployeesScreen(),
  AppPage.services => const ServicesScreen(),
  AppPage.ordersYears => const OrdersYearOverviewScreen(),
  AppPage.createOffer => CreateOfferScreen(order: state.extra as SavedOrder),
  AppPage.createInvoice => CreateInvoiceScreen(
    order: state.extra as SavedOrder,
  ),
};
