import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/staff/staff_shell_host.dart';
import '../ui/widgets/staff_scaffold.dart';
import '../ui/widgets/staff_tab_bar.dart';

/// Every page the router can show. app_router.dart maps them to the real
/// screens; tests map them to stand-ins, so the route table itself (paths,
/// shell branches, order) is VM-testable.
enum AppPage {
  login,
  sharedDocument,
  home,
  orders,
  inventory,
  more,
  dashboard,
  myRequests,
  pendingOrders,
  shoppingList,
  orderForm,
  orderSuccess,
  admin,
  settings,
  legalImprint,
  legalTerms,
  legalPrivacy,
  adminSettings,
  userManagement,
  employees,
  services,
  ordersYears,
  createOffer,
  createInvoice,
}

typedef AppPageBuilder =
    Widget Function(BuildContext context, GoRouterState state, AppPage page);

GoRoute _route(String path, AppPage page, AppPageBuilder build) => GoRoute(
  path: path,
  builder: (context, state) => build(context, state, page),
);

/// The app's route table.
///
/// Staff tabs live in a persistent shell (bar and "+" stay, only the content
/// swaps, every tab keeps its state); branch order = [staffBranchTabs]. `/`
/// belongs to the orders branch: staff get the orders list there, everyone
/// else the customer start (the shell then shows no bar). All other pages
/// are top-level routes on the root navigator, i.e. pushed full-screen
/// without the bar.
List<RouteBase> buildAppRoutes({
  required AppPageBuilder page,
  required bool Function() isStaff,
  required Stream<bool> staffChanges,
}) => [
  _route('/login', AppPage.login, page),
  _route('/s/:code', AppPage.sharedDocument, page),
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => StaffShellHost(
      shell: shell,
      isStaff: isStaff,
      staffChanges: staffChanges,
    ),
    branches: [
      StatefulShellBranch(
        routes: [
          _route('/', AppPage.home, page),
          _route(staffTabRoutes[StaffTab.orders]!, AppPage.orders, page),
        ],
      ),
      StatefulShellBranch(
        routes: [
          _route(staffTabRoutes[StaffTab.inventory]!, AppPage.inventory, page),
        ],
      ),
      StatefulShellBranch(
        routes: [_route(staffTabRoutes[StaffTab.more]!, AppPage.more, page)],
      ),
    ],
  ),
  _route('/dashboard', AppPage.dashboard, page),
  _route('/my-requests', AppPage.myRequests, page),
  _route('/pending-orders', AppPage.pendingOrders, page),
  _route('/shopping-list', AppPage.shoppingList, page),
  _route('/order-form', AppPage.orderForm, page),
  _route('/order-success', AppPage.orderSuccess, page),
  _route('/admin', AppPage.admin, page),
  _route('/settings', AppPage.settings, page),
  _route('/settings/legal/imprint', AppPage.legalImprint, page),
  _route('/settings/legal/terms', AppPage.legalTerms, page),
  _route('/settings/legal/privacy', AppPage.legalPrivacy, page),
  _route('/settings/admin', AppPage.adminSettings, page),
  _route('/settings/users', AppPage.userManagement, page),
  _route('/settings/employees', AppPage.employees, page),
  _route('/settings/services', AppPage.services, page),
  _route('/orders/pending', AppPage.pendingOrders, page),
  _route('/orders/years', AppPage.ordersYears, page),
  _route('/create-offer', AppPage.createOffer, page),
  _route('/create-invoice', AppPage.createInvoice, page),
];
