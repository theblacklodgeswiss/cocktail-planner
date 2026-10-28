import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../ui/tokens.dart';
import '../../../utils/currency.dart';
import 'detail_header.dart';
import 'form_details_section.dart';
import 'info_section.dart';
import 'order_detail_controller.dart';
import 'order_detail_services.dart';
import 'shopping_section.dart';

/// The order detail sheet content (shown in a full `showAppSheet`): header
/// with name, status, date, the one primary action and the "..." menu, then
/// the decline reason, form details (form orders), info, shopping-list box
/// and shopping-list tile as floating cards.
///
/// VM-testable: the browser-only Microsoft integration comes in through
/// [services]; `showOrderDetails` passes the real one.
class OrderDetailView extends StatefulWidget {
  const OrderDetailView({
    super.key,
    required this.order,
    required this.currency,
    required this.services,
  });

  final SavedOrder order;
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
    const gap = SizedBox(height: AppSpace.s12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderDetailHeader(controller: _c),
        Expanded(
          child: ListView(
            children: [
              if (_c.currentStatus == OrderStatus.declined) ...[
                DeclineReasonCard(controller: _c),
                gap,
              ],
              if (widget.order.isFromForm) ...[
                FormDetailsCard(controller: _c),
                gap,
              ],
              OrderInfoCard(controller: _c, currency: widget.currency),
              gap,
              ShoppingListSection(controller: _c),
              if (widget.order.items.isNotEmpty) ...[
                gap,
                ShoppingListTile(controller: _c, currency: widget.currency),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
