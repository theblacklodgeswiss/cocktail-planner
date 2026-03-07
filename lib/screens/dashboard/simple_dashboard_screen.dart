import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/order_repository.dart';
import '../../data/firestore_service.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import 'user_menu_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _initialized = false;

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
          _initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('dashboard.title'.tr()),
            Text(
              '${'dashboard.year'.tr()} ${DateTime.now().year}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => showUserMenu(context),
          ),
        ],
      ),
      body: StreamBuilder<List<SavedOrder>>(
        stream: orderRepository.watchOrders(
          includePending: true,
          year: DateTime.now().year, // Only current year
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('Dashboard error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Fehler beim Laden',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🔥 Firebase: ${firestoreService.isAvailable ? "✅ Verfügbar" : "❌ Nicht verfügbar"}'),
                            Text('👤 User: ${authService.currentUser?.email ?? "Nicht eingeloggt"}'),
                            Text('🔐 Authenticated: ${authService.isSignedIn ? "Ja" : "Nein"}'),
                            Text('👑 Admin: ${authService.isAdmin ? "Ja" : "Nein"}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          debugPrint('Dashboard loaded ${orders.length} orders from ${firestoreService.dataSourceLabel}');
          
          // Debug: Log all orders with their years
          for (final order in orders) {
            debugPrint('  Order: ${order.name} - Year: ${order.year} - Status: ${order.status.value} - Total: ${order.total}');
          }
          
          // Compute counts
          // Pending orders: total == 0 (incomplete forms), regardless of status
          final pendingCount = orders.where((o) => o.total == 0 && !o.isPendingDismissed).length;
          
          // Only count orders with total > 0 for status counts
          final completedOrders = orders.where((o) => o.total > 0).toList();
          final acceptedCount = completedOrders.where((o) => o.status == OrderStatus.accepted).length;
          final openOffersCount = completedOrders.where((o) => o.status == OrderStatus.quote).length;
          
          debugPrint('📊 Counts for year ${DateTime.now().year}: accepted=$acceptedCount, pending=$pendingCount, quotes=$openOffersCount');
          
          // Debug: Show pending orders details
          final pendingOrders = orders.where((o) => o.total == 0 && !o.isPendingDismissed).toList();
          debugPrint('🔵 Pending orders (${pendingOrders.length}):');
          for (final p in pendingOrders) {
            debugPrint('  - ${p.name}: total=${p.total}, dismissed=${p.isPendingDismissed}');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status-Kacheln
                _buildStatusCards(acceptedCount, pendingCount, openOffersCount),
                const SizedBox(height: 32),

                // Drei Haupt-Navigation Buttons
                Text(
                  'dashboard.section_orders'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildNavigationTiles(acceptedCount, pendingCount, openOffersCount),

                const SizedBox(height: 32),

                // Quick Actions
                Text(
                  'dashboard.section_actions'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildQuickActions(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/order-form?step=0'),
        icon: const Icon(Icons.add),
        label: Text('dashboard.new_order'.tr()),
      ),
    );
  }

  Widget _buildStatusCards(int acceptedCount, int pendingCount, int openOffersCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatusCard(
              title: 'dashboard.pending_confirmations'.tr(),
              value: pendingCount.toString(),
              icon: Icons.pending_outlined,
              color: Colors.blue,
              width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
            ),
            _StatusCard(
              title: 'dashboard.open_offers'.tr(),
              value: openOffersCount.toString(),
              icon: Icons.description_outlined,
              color: Colors.orange,
              width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
            ),
            _StatusCard(
              title: 'dashboard.accepted_orders'.tr(),
              value: acceptedCount.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.green,
              width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationTiles(int acceptedCount, int pendingCount, int openOffersCount) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
              child: const Icon(Icons.pending, color: Colors.blue),
            ),
            title: Text('dashboard.nav_pending'.tr()),
            subtitle: Text('dashboard.pending_count'.tr(args: [pendingCount.toString()])),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/pending-orders'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withValues(alpha: 0.2),
              child: const Icon(Icons.description, color: Colors.orange),
            ),
            title: Text('dashboard.nav_offers'.tr()),
            subtitle: Text('dashboard.offers_count'.tr(args: [openOffersCount.toString()])),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/orders?status=quote'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.2),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            title: Text('dashboard.nav_accepted'.tr()),
            subtitle: Text('dashboard.orders_count'.tr(args: [acceptedCount.toString()])),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/orders?status=accepted'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final bool isAdmin = authService.isAdmin;

    return Column(
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.list_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text('dashboard.action_all_orders'.tr()),
            subtitle: Text('dashboard.action_all_orders_subtitle'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/orders'),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              title: Text('dashboard.action_admin'.tr()),
              subtitle: Text('dashboard.action_admin_subtitle'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _StatusCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
