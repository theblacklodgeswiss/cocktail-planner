import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/pill_filter.dart';
import '../../ui/widgets/staff_scaffold.dart';
import '../../ui/widgets/staff_tab_bar.dart';
import '../../ui/widgets/states.dart';
import 'orders_logic.dart';
import 'widgets/order_card.dart';

/// Rounded search field of the order lists.
class OrderSearchField extends StatelessWidget {
  const OrderSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppText.body.copyWith(color: p.text),
      decoration: InputDecoration(
        hintText: 'orders.search_hint'.tr(),
        hintStyle: AppText.body.copyWith(color: p.textSecondary),
        isDense: true,
        filled: true,
        fillColor: p.card,
        prefixIcon: Icon(
          Icons.search,
          size: AppSize.rowIcon,
          color: p.textSecondary,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: Icon(Icons.close, size: AppSize.rowIcon, color: p.text),
                  tooltip: 'ui.close'.tr(),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        border: border(p.border),
        enabledBorder: border(p.border),
        focusedBorder: border(p.text),
      ),
    );
  }
}

/// Staff orders list (`/orders` and the staff home `/`): "Nächster Termin",
/// status pills with counts, search, and the latest orders as cards under
/// month headings. Pure view; the screen passes the stream state in.
///
/// [orders] null means loading. Filter, cap and search follow
/// [filterLatestOrders]; counts follow [listCounts] over all [orders].
class OrdersOverviewView extends StatefulWidget {
  const OrdersOverviewView({
    super.key,
    required this.orders,
    this.error,
    required this.onRetry,
    required this.now,
    this.initialFilter = OrderStatusFilter.quotes,
    this.filterNonce,
    this.pendingCount = 0,
    this.actions = const [],
    required this.onOpen,
    required this.onOpenPending,
    required this.onOpenArchive,
  });

  final List<SavedOrder>? orders;
  final Object? error;
  final VoidCallback onRetry;
  final DateTime now;
  final OrderStatusFilter initialFilter;

  /// A new value re-applies [initialFilter] (a repeated link to the tab).
  final Object? filterNonce;
  final int pendingCount;

  /// Extra top bar buttons (dashboard, OneDrive sync).
  final List<Widget> actions;
  final void Function(SavedOrder order) onOpen;
  final VoidCallback onOpenPending;
  final VoidCallback onOpenArchive;

  @override
  State<OrdersOverviewView> createState() => _OrdersOverviewViewState();
}

class _OrdersOverviewViewState extends State<OrdersOverviewView> {
  late OrderStatusFilter _filter = widget.initialFilter;
  final _search = TextEditingController();
  bool _searchOpen = false;
  String _query = '';

  // The orders tab keeps its page; a new `/orders?status=` link (e.g. from
  // the dashboard) only changes this parameter.
  @override
  void didUpdateWidget(OrdersOverviewView old) {
    super.didUpdateWidget(old);
    if (widget.initialFilter != old.initialFilter ||
        widget.filterNonce != old.filterNonce) {
      _filter = widget.initialFilter;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _search.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final orders = widget.orders;
    const side = EdgeInsets.symmetric(horizontal: AppSpace.s16);

    final List<Widget> content;
    if (widget.error != null && orders == null) {
      content = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: 'orders.load_error'.tr(),
            onRetry: widget.onRetry,
          ),
        ),
      ];
    } else if (orders == null) {
      content = const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    } else {
      final counts = listCounts(orders);
      final visible = filterLatestOrders(
        orders,
        query: _query,
        filter: _filter,
      );
      final next = _query.isEmpty ? nextAppointment(orders, widget.now) : null;
      content = [
        if (next != null)
          SliverPadding(
            padding: side.copyWith(bottom: AppSpace.s12),
            sliver: SliverToBoxAdapter(
              child: NextAppointmentHero(
                order: next,
                now: widget.now,
                onTap: () => widget.onOpen(next),
              ),
            ),
          ),
        SliverPadding(
          padding: side,
          sliver: SliverToBoxAdapter(
            child: PillFilter<OrderStatusFilter>(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
              options: [
                for (final f in OrderStatusFilter.values)
                  PillOption(f, _label(f), count: counts.of(f)),
              ],
            ),
          ),
        ),
        // List header as before ("Bestellungen · n" / search results)
        // with the way to the full year archive.
        SliverPadding(
          padding: side,
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _query.isNotEmpty
                        ? '${visible.length} ${'orders.search_results'.tr()}'
                        // Counts cover all orders; the list only the latest.
                        : counts.of(_filter) > visible.length
                        ? 'orders.latest_of'.plural(
                            visible.length,
                            args: [
                              '${visible.length}',
                              '${counts.of(_filter)}',
                            ],
                          )
                        : '${'orders.order_count'.tr()} · ${visible.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
                ),
                TextAction(
                  label: 'orders.archive'.tr(),
                  onPressed: widget.onOpenArchive,
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _query.isNotEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    title: 'orders.no_results'.tr(),
                  )
                : EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'orders.no_orders'.tr(),
                    body: 'orders.empty_body'.tr(),
                  ),
          )
        else
          SliverOrderList(orders: visible, onOpen: widget.onOpen),
      ];
    }

    return StaffScaffold(
      tab: StaffTab.orders,
      title: 'orders.title'.tr(),
      actions: [
        GlassIconButton(
          icon: _searchOpen ? Icons.search_off : Icons.search,
          semanticLabel: _searchOpen
              ? 'orders.search_close'.tr()
              : 'orders.search_hint'.tr(),
          onPressed: _toggleSearch,
        ),
        ...widget.actions,
      ],
      slivers: [
        if (_searchOpen)
          SliverPadding(
            padding: side.copyWith(bottom: AppSpace.s12),
            sliver: SliverToBoxAdapter(
              child: OrderSearchField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
        if (widget.pendingCount > 0)
          SliverPadding(
            padding: side.copyWith(bottom: AppSpace.s12),
            sliver: SliverToBoxAdapter(
              child: FloatingCard(
                onTap: widget.onOpenPending,
                // Icon row + card padding = 44 px tap target.
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      size: AppSize.rowIcon,
                      color: p.goldText,
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Text(
                        'orders.pending_banner'.tr(
                          args: [widget.pendingCount.toString()],
                        ),
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: p.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ...content,
      ],
    );
  }

  String _label(OrderStatusFilter f) => switch (f) {
    OrderStatusFilter.all => 'orders.filter_all'.tr(),
    OrderStatusFilter.quotes => 'orders.filter_open_quotes'.tr(),
    OrderStatusFilter.accepted => 'orders.filter_accepted'.tr(),
    OrderStatusFilter.completed => 'status.completed'.tr(),
  };
}
