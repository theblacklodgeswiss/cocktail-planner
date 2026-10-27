import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/date_tile.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/hero_card.dart';
import '../../../ui/widgets/status_dot.dart';
import '../../dashboard/widgets/my_requests_list.dart' show guestsMeta;
import '../order_status_helpers.dart' show formatDate;
import '../orders_logic.dart';

/// Staff view of the status: all four states are shown as they are.
StatusKind staffStatusKind(OrderStatus status) => switch (status) {
  OrderStatus.quote => StatusKind.offer,
  OrderStatus.accepted => StatusKind.accepted,
  OrderStatus.completed => StatusKind.completed,
  OrderStatus.declined => StatusKind.declined,
};

/// Total as the old staff list showed it ("1234.50 CHF").
String orderTotalLabel(SavedOrder o) =>
    '${o.total.toStringAsFixed(2)} ${o.currency}';

/// "Juni 2026" in the active language.
String monthHeading(int year, int month) => '${'months.$month'.tr()} $year';

/// "N Gäste · Ort" of an order.
String orderMeta(SavedOrder o) => guestsMeta(o.personCount, o.location);

/// One order: date tile, name, "N Gäste · Ort" (and the creator when set),
/// status dot and, for staff, the total. [trailing] replaces the total
/// (e.g. the "Erledigt" action of the pending list).
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showTotal = true,
    this.trailing,
  });

  final SavedOrder order;
  final VoidCallback onTap;
  final bool showTotal;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final creator = order.createdBy?.trim() ?? '';
    return FloatingCard(
      onTap: onTap,
      child: Row(
        children: [
          DateTile(order.date),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                Text(
                  orderMeta(order),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
                // "Bearbeiter" was a requested column of the old list.
                if (creator.isNotEmpty)
                  Text(
                    '${'orders.creator'.tr()}: $creator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Flexible(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Form request without a shopping list (opens the form).
                    if (order.needsShoppingList) ...[
                      Tooltip(
                        message: 'orders.no_shopping_list'.tr(),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          size: AppSize.metaIcon,
                          color: p.goldText,
                          semanticLabel: 'orders.no_shopping_list'.tr(),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s4),
                    ],
                    Flexible(child: StatusDot(staffStatusKind(order.status))),
                  ],
                ),
                if (trailing != null)
                  trailing!
                else if (showTotal)
                  Text(
                    orderTotalLabel(order),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: p.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Month heading above a group of cards.
class MonthHeading extends StatelessWidget {
  const MonthHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s12,
        AppSpace.s4,
        AppSpace.s8,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: p.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Lazily built list of [OrderCard]s under month headings (see
/// [groupByMonth]; the input order is kept).
class SliverOrderMonthList extends StatelessWidget {
  const SliverOrderMonthList({
    super.key,
    required this.orders,
    required this.onOpen,
  });

  final List<SavedOrder> orders;
  final void Function(SavedOrder order) onOpen;

  @override
  Widget build(BuildContext context) {
    // Flattened: a MonthGroup is a heading, a SavedOrder a card.
    final entries = <Object>[
      for (final g in groupByMonth(orders)) ...[g, ...g.orders],
    ];
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          if (e is MonthGroup) {
            return MonthHeading(monthHeading(e.year, e.month));
          }
          final o = e as SavedOrder;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: OrderCard(
              key: ValueKey(o.id),
              order: o,
              onTap: () => onOpen(o),
            ),
          );
        },
      ),
    );
  }
}

/// Black "Nächster Termin" card: name, date/time and guests, countdown in
/// days on the right (0 = "Heute").
class NextAppointmentHero extends StatelessWidget {
  const NextAppointmentHero({
    super.key,
    required this.order,
    required this.now,
    required this.onTap,
  });

  final SavedOrder order;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = daysUntil(order.date, now);
    final time = order.effectiveEventTime.trim();
    final when = time.isEmpty
        ? formatDate(order.date)
        : '${formatDate(order.date)} · $time';
    return HeroCard(
      kicker: 'orders.next_appointment'.tr(),
      title: order.name,
      meta: '$when · ${orderMeta(order)}',
      onTap: onTap,
      trailing: Semantics(
        label: 'orders.countdown_days'.plural(days),
        child: ExcludeSemantics(
          child: days == 0
              ? Text('orders.countdown_today'.tr())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$days'),
                    Text(
                      'orders.countdown_unit'.plural(days),
                      style: AppText.heroMeta.copyWith(
                        color: AppColors.goldLabelOnBlack,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
