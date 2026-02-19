import 'package:go_router/go_router.dart';

import '../screens/dashboard_screen.dart';
import '../screens/shopping_list_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/shopping-list',
      builder: (context, state) => const ShoppingListScreen(),
    ),
  ],
);
