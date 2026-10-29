import 'package:cocktail_planer/data/firestore_service.dart';
import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/app_role.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/services/auth_service.dart';
import 'package:cocktail_planer/services/microsoft_graph_service.dart';
import 'package:cocktail_planer/ui/tokens.dart';
import 'package:cocktail_planer/ui/widgets/glass_icon_button.dart';
import 'package:cocktail_planer/widgets/role_protected_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'form_sync.dart';
import 'order_detail_sheet.dart';
import 'orders_logic.dart';
import 'orders_overview_view.dart';

/// Staff orders list (`/orders`, and the staff home `/` via `StaffHome`):
/// wires [OrdersOverviewView] to the order streams.
class OrdersOverviewScreen extends StatefulWidget {
  final String? initialStatus;

  /// Changes with every link to the orders tab (see [ordersLinkNonce]), so
  /// a repeated link with the same status still resets the filter.
  final Object? filterNonce;

  const OrdersOverviewScreen({super.key, this.initialStatus, this.filterNonce});

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {
  Stream<List<SavedOrder>>? _orders;
  Stream<List<SavedOrder>>? _pending;

  @override
  void initState() {
    super.initState();
    if (firestoreService.isAvailable) _subscribe();
    // Ensure Firestore is initialized (screen can be reached directly
    // without going through the dashboard).
    firestoreService.availabilityKnown.then((_) {
      if (mounted) setState(_subscribe);
    });
  }

  /// (Re)subscribes; also the retry after a stream error.
  void _subscribe() {
    // No year filter - always fetch all orders, sorted by createdAt desc.
    _orders = orderRepository.watchOrders();
    _pending = orderRepository.watchPendingOrders();
  }

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      minimumRole: AppRole.employee,
      child: StreamBuilder<List<SavedOrder>>(
        stream: _pending,
        builder: (context, pending) => StreamBuilder<List<SavedOrder>>(
          stream: _orders,
          builder: (context, snapshot) => OrdersOverviewView(
            orders: snapshot.data,
            error: snapshot.error,
            onRetry: () => setState(_subscribe),
            now: DateTime.now(),
            initialFilter: statusFilterFromQuery(widget.initialStatus),
            filterNonce: widget.filterNonce,
            pendingCount: pending.data?.length ?? 0,
            actions: _actions(context),
            onOpen: (order) => showOrderDetails(context, order),
            onOpenPending: () => context.push('/orders/pending'),
            onOpenArchive: () => context.push('/orders/years'),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) => [
    if (authService.isAdmin)
      GlassIconButton(
        icon: Icons.insights_outlined,
        semanticLabel: 'more.dashboard'.tr(),
        onPressed: () => context.push('/dashboard'),
      ),
    // Same entries as before (Excel hint, OneDrive form, sync, re-import),
    // now in the shared sheet.
    if (microsoftGraphService.isSupported)
      ListenableBuilder(
        listenable: formSync,
        builder: (context, _) => formSync.isSyncing
            ? Semantics(
                label: 'orders.syncing'.tr(),
                child: const SizedBox.square(
                  dimension: AppSize.minTap,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpace.s12),
                    child: CircularProgressIndicator(
                      strokeWidth: AppSize.spinnerStroke,
                    ),
                  ),
                ),
              )
            : GlassIconButton(
                icon: Icons.sync,
                semanticLabel: 'orders.sync_forms_tooltip'.tr(),
                onPressed: () => showFormSyncSheet(context),
              ),
      ),
  ];
}
