import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/pill_filter.dart';
import '../../ui/widgets/states.dart';
import 'orders_logic.dart';
import 'orders_overview_view.dart' show OrderSearchField;
import 'widgets/order_card.dart';

/// Orders with total = 0 ("Pendenzen"): search, sort pills and one card per
/// order with a visible "Erledigt" action. Swiping a card to the left still
/// works; both ask first. Pure view: [onDismiss] performs the dismissal
/// (`isPendingDismissed`) and reports success.
class PendingOrdersView extends StatefulWidget {
  const PendingOrdersView({
    super.key,
    required this.orders,
    this.error,
    required this.onRetry,
    required this.onOpen,
    required this.onDismiss,
    this.onBack,
  });

  /// Null while loading.
  final List<SavedOrder>? orders;
  final Object? error;
  final VoidCallback onRetry;
  final void Function(SavedOrder order) onOpen;
  final Future<bool> Function(SavedOrder order) onDismiss;

  /// Back button; hidden when null.
  final VoidCallback? onBack;

  @override
  State<PendingOrdersView> createState() => _PendingOrdersViewState();
}

class _PendingOrdersViewState extends State<PendingOrdersView> {
  final _search = TextEditingController();
  String _query = '';
  PendingSortOption _sort = PendingSortOption.eventDate;
  bool _ascending = true;

  /// Dismissed here but not yet gone from [PendingOrdersView.orders].
  final _hidden = <String>{};

  @override
  void didUpdateWidget(PendingOrdersView old) {
    super.didUpdateWidget(old);
    final ids = {for (final o in widget.orders ?? const []) o.id};
    // Once the stream drops an order, forget it, so an undo shows it again.
    _hidden.removeWhere((id) => !ids.contains(id));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<bool> _confirm(SavedOrder order) => showConfirmSheet(
    context,
    title: 'orders.pending_dismiss_title'.tr(),
    body: 'orders.pending_dismiss_message'.tr(namedArgs: {'name': order.name}),
    confirmLabel: 'orders.pending_dismiss_confirm'.tr(),
  );

  Future<void> _dismiss(SavedOrder order) async {
    setState(() => _hidden.add(order.id));
    final ok = await widget.onDismiss(order);
    if (!ok && mounted) setState(() => _hidden.remove(order.id));
  }

  Future<void> _dismissWithConfirm(SavedOrder order) async {
    if (await _confirm(order)) await _dismiss(order);
  }

  String _sortLabel(PendingSortOption o) => switch (o) {
    PendingSortOption.eventDate => 'orders.sort_event_date'.tr(),
    PendingSortOption.createdAt => 'orders.sort_created_at'.tr(),
    PendingSortOption.guests => 'orders.sort_guests'.tr(),
    PendingSortOption.name => 'orders.sort_name'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const side = EdgeInsets.symmetric(horizontal: AppSpace.s16);
    final all = widget.orders;

    final List<Widget> slivers;
    if (widget.error != null && all == null) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: 'orders.load_error'.tr(),
            onRetry: widget.onRetry,
          ),
        ),
      ];
    } else if (all == null) {
      slivers = const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    } else {
      final remaining = [
        for (final o in all)
          if (!_hidden.contains(o.id)) o,
      ];
      if (remaining.isEmpty) {
        slivers = [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'orders.no_pending'.tr(),
            ),
          ),
        ];
      } else {
        final orders = filterAndSortPending(
          remaining,
          query: _query,
          sort: _sort,
          ascending: _ascending,
        );
        slivers = [
          SliverPadding(
            padding: side.copyWith(bottom: AppSpace.s12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'orders.pending_info'.tr(),
                style: AppText.body.copyWith(color: p.textSecondary),
              ),
            ),
          ),
          SliverPadding(
            padding: side.copyWith(bottom: AppSpace.s8),
            sliver: SliverToBoxAdapter(
              child: OrderSearchField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          SliverPadding(
            padding: side,
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: PillFilter<PendingSortOption>(
                      value: _sort,
                      onChanged: (o) => setState(() => _sort = o),
                      options: [
                        for (final o in PendingSortOption.values)
                          PillOption(o, _sortLabel(o)),
                      ],
                    ),
                  ),
                  TextAction(
                    label: _ascending
                        ? 'orders.sort_asc'.tr()
                        : 'orders.sort_desc'.tr(),
                    onPressed: () => setState(() => _ascending = !_ascending),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: side.copyWith(top: AppSpace.s8, bottom: AppSpace.s8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'orders.pending_count'.tr(args: [orders.length.toString()]),
                style: AppText.caption.copyWith(color: p.textSecondary),
              ),
            ),
          ),
          SliverPadding(
            padding: side,
            sliver: SliverList.builder(
              itemCount: orders.length,
              itemBuilder: (context, i) => _card(orders[i], p),
            ),
          ),
        ];
      }
    }

    return LargeTitleScaffold(
      title: 'orders.pending_title'.tr(),
      leading: widget.onBack == null
          ? null
          : GlassIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'ui.back'.tr(),
              onPressed: widget.onBack!,
            ),
      slivers: slivers,
    );
  }

  Widget _card(SavedOrder order, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Dismissible(
        key: ValueKey(order.id),
        direction: DismissDirection.endToStart,
        background: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.check_circle_outline, color: p.text),
                const SizedBox(width: AppSpace.s8),
                Text(
                  'orders.pending_dismiss_done'.tr(),
                  style: AppText.button.copyWith(color: p.text),
                ),
              ],
            ),
          ),
        ),
        confirmDismiss: (_) => _confirm(order),
        onDismissed: (_) => _dismiss(order),
        child: OrderCard(
          order: order,
          showTotal: false,
          onTap: () => widget.onOpen(order),
          trailing: TextAction(
            label: 'orders.pending_dismiss_done'.tr(),
            onPressed: () => _dismissWithConfirm(order),
          ),
        ),
      ),
    );
  }
}
