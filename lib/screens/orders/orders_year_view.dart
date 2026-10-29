import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/states.dart';
import 'orders_logic.dart';
import 'widgets/order_card.dart';

/// Archive (`/orders/years`): one card per event year with its order count;
/// a year opens all its orders as the month-grouped card list. Back closes
/// the year first, then the page ([onBack], default `maybePop`).
class OrdersYearView extends StatefulWidget {
  const OrdersYearView({
    super.key,
    required this.orders,
    this.error,
    required this.onRetry,
    required this.onOpen,
    this.onBack,
  });

  /// Null while loading.
  final List<SavedOrder>? orders;
  final Object? error;
  final VoidCallback onRetry;
  final void Function(SavedOrder order) onOpen;
  final VoidCallback? onBack;

  @override
  State<OrdersYearView> createState() => _OrdersYearViewState();
}

class _OrdersYearViewState extends State<OrdersYearView> {
  int? _year;

  void _back() {
    if (_year != null) {
      setState(() => _year = null);
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final orders = widget.orders;
    const side = EdgeInsets.symmetric(horizontal: AppSpace.s16);

    final List<Widget> slivers;
    if (widget.error != null && orders == null) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: 'orders.load_error'.tr(),
            onRetry: widget.onRetry,
          ),
        ),
      ];
    } else if (orders == null) {
      slivers = const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    } else if (_year != null) {
      final yearOrders = ordersOfYear(orders, _year!);
      slivers = [
        if (yearOrders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: '${'orders.no_orders'.tr()} $_year',
            ),
          )
        else
          SliverOrderMonthList(orders: yearOrders, onOpen: widget.onOpen),
      ];
    } else {
      final counts = ordersPerYear(orders);
      slivers = [
        if (counts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'orders.no_orders'.tr(),
            ),
          )
        else
          SliverPadding(
            padding: side,
            sliver: SliverList.builder(
              itemCount: counts.length,
              itemBuilder: (context, i) {
                final year = counts.keys.elementAt(i);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: FloatingCard(
                    onTap: () => setState(() => _year = year),
                    child: Row(
                      children: [
                        Text(
                          '$year',
                          style: AppText.number.copyWith(color: p.text),
                        ),
                        const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Text(
                            '${counts[year]} ${'orders.order_count'.tr()}',
                            textAlign: TextAlign.end,
                            style: AppText.body.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ];
    }

    return LargeTitleScaffold(
      title: _year == null
          ? 'orders.years_overview_title'.tr()
          : '${'orders.order_count'.tr()} $_year',
      leading: GlassIconButton(
        icon: Icons.arrow_back,
        semanticLabel: 'ui.back'.tr(),
        onPressed: _back,
      ),
      slivers: slivers,
    );
  }
}
