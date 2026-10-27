import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../utils/currency.dart';
import 'form_details_section.dart';
import 'header_actions.dart';
import 'info_section.dart';
import 'order_detail_controller.dart';
import 'order_detail_logic.dart';
import 'order_detail_services.dart';
import 'shopping_section.dart';
import 'status_actions.dart';

/// The order detail sheet: a draggable sheet (0.9, 0.5-0.95) with the
/// header actions, status card, form details (form orders), info card,
/// shopping-list tile (orders with items) and delete (super admin).
///
/// VM-testable: the browser-only Microsoft integration comes in through
/// [services]; `showOrderDetails` passes the real one.
class OrderDetailView extends StatefulWidget {
  const OrderDetailView({
    super.key,
    required this.order,
    required this.colorScheme,
    required this.currency,
    required this.services,
  });

  final SavedOrder order;
  final ColorScheme colorScheme;
  final Currency currency;
  final OrderDetailServices services;

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView>
    implements OrderDetailHost {
  late final OrderDetailController _c;

  @override
  void initState() {
    super.initState();
    _c = OrderDetailController(
      order: widget.order,
      host: this,
      services: widget.services,
    );
    _c.addListener(_onControllerChanged);
  }

  /// The whole sheet rebuilds on every controller change, exactly as the
  /// old `setState` calls did.
  void _onControllerChanged() => setState(() {});

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Scaffold(
        appBar: _buildAppBar(),
        body: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            OrderHeaderActions(controller: _c),
            const SizedBox(height: 8),
            OrderStatusCard(controller: _c),
            const SizedBox(height: 16),
            if (widget.order.isFromForm) ...[
              FormDetailsCard(controller: _c, colorScheme: widget.colorScheme),
              const SizedBox(height: 16),
            ],
            OrderInfoCard(
              controller: _c,
              colorScheme: widget.colorScheme,
              currency: widget.currency,
            ),
            const SizedBox(height: 16),
            if (widget.order.items.isNotEmpty)
              ShoppingListTile(controller: _c, currency: widget.currency),
            if (_c.actions.contains(OrderDetailAction.delete))
              DeleteOrderSection(controller: _c),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.order.name),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}
