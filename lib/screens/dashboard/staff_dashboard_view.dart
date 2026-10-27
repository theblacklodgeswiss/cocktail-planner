import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/order.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/pill_filter.dart';
import '../../ui/widgets/states.dart';
import '../orders/orders_logic.dart';
import '../orders/widgets/order_card.dart';

/// Number of appointments listed below the hero.
const dashboardUpcomingLimit = 5;

/// Staff dashboard (`/dashboard`): number row (Pendenzen, Angenommen,
/// Diese Woche), "Kennzahlen" (year / all time), "Nächster Termin", the
/// following appointments and quick actions.
///
/// [orders] is the dashboard stream
/// (`watchOrders(includePending: true, year: <current year>)`, null while
/// loading); the number row follows [dashboardCounts], the year KPIs
/// [dashboardStats]. [allOrders] is `watchOrders()` (all years): the
/// appointments, so December sees January, and the all-time KPIs
/// ([overviewTotals]).
class StaffDashboardView extends StatelessWidget {
  const StaffDashboardView({
    super.key,
    required this.orders,
    required this.allOrders,
    this.error,
    required this.onRetry,
    required this.now,
    required this.isAdmin,
    required this.onOpen,
    this.actions = const [],
  });

  final List<SavedOrder>? orders;
  final List<SavedOrder>? allOrders;
  final Object? error;
  final VoidCallback onRetry;
  final DateTime now;
  final bool isAdmin;
  final void Function(SavedOrder order) onOpen;

  /// Top bar buttons (settings, user menu).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = orders;
    const side = EdgeInsets.symmetric(horizontal: AppSpace.s16);

    final List<Widget> slivers;
    if (error != null && list == null) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: 'dashboard.load_error'.tr(),
            onRetry: onRetry,
          ),
        ),
      ];
    } else if (list == null) {
      slivers = const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    } else {
      final counts = dashboardCounts(list);
      final upcoming = upcomingAppointments(allOrders ?? const [], now);
      final next = upcoming.isEmpty ? null : upcoming.first;
      final following = upcoming.skip(1).take(dashboardUpcomingLimit).toList();

      Widget section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s12,
          AppSpace.s4,
          AppSpace.s8,
        ),
        child: Semantics(
          header: true,
          child: Text(text, style: AppText.section.copyWith(color: p.text)),
        ),
      );

      slivers = [
        SliverPadding(
          padding: side,
          sliver: SliverList.list(
            children: [
              Text(
                '${'dashboard.year'.tr()} ${now.year}',
                style: AppText.caption.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: AppSpace.s8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Stat(
                      value: counts.pending,
                      label: 'dashboard.stat_open'.tr(),
                      onTap: () => context.push('/pending-orders'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: _Stat(
                      value: counts.accepted,
                      label: 'dashboard.stat_accepted'.tr(),
                      onTap: () => context.push('/orders?status=accepted'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: _Stat(
                      value: acceptedThisWeek(list, now),
                      label: 'dashboard.stat_this_week'.tr(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              _KpiCard(year: list, all: allOrders),
              const SizedBox(height: AppSpace.s12),
              if (next != null)
                NextAppointmentHero(
                  order: next,
                  now: now,
                  onTap: () => onOpen(next),
                ),
              section('dashboard.upcoming'.tr()),
              if (next == null)
                Text(
                  'dashboard.no_upcoming'.tr(),
                  style: AppText.body.copyWith(color: p.textSecondary),
                ),
              for (final o in following)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: OrderCard(order: o, onTap: () => onOpen(o)),
                ),
              section('dashboard.section_actions'.tr()),
              _Action(
                icon: Icons.add,
                title: 'dashboard.new_order'.tr(),
                onTap: () => context.push('/order-form?step=0'),
              ),
              _Action(
                icon: Icons.pending_actions,
                title: 'dashboard.nav_pending'.tr(),
                subtitle: 'dashboard.pending_count'.tr(
                  args: [counts.pending.toString()],
                ),
                onTap: () => context.push('/pending-orders'),
              ),
              _Action(
                icon: Icons.description_outlined,
                title: 'dashboard.nav_offers'.tr(),
                subtitle: 'dashboard.offers_count'.tr(
                  args: [counts.openOffers.toString()],
                ),
                onTap: () => context.push('/orders?status=quote'),
              ),
              _Action(
                icon: Icons.list_alt,
                title: 'dashboard.action_all_orders'.tr(),
                subtitle: 'dashboard.action_all_orders_subtitle'.tr(),
                onTap: () => context.push('/orders'),
              ),
              if (isAdmin)
                _Action(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'dashboard.action_admin'.tr(),
                  subtitle: 'dashboard.action_admin_subtitle'.tr(),
                  onTap: () => context.push('/admin'),
                ),
            ],
          ),
        ),
      ];
    }

    return LargeTitleScaffold(
      title: 'dashboard.title'.tr(),
      // Reached by push (Mehr, orders) or by `go` after the order form;
      // without a page below, back leads to the staff home.
      leading: GlassIconButton(
        icon: Icons.arrow_back,
        semanticLabel: 'ui.back'.tr(),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
      actions: actions,
      slivers: slivers,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FloatingCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: AppText.number.copyWith(color: p.text)),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: FloatingCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: AppSize.rowIcon, color: p.text),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _KpiScope { year, all }

/// "Kennzahlen": revenue, persons and average, for the current year (old
/// dashboard stats bar) or all time (old orders summary cards).
class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.year, required this.all});

  final List<SavedOrder> year;

  /// Null while the all-years stream loads.
  final List<SavedOrder>? all;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  _KpiScope _scope = _KpiScope.year;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final yearScope = _scope == _KpiScope.year;
    final all = widget.all;
    final KpiStats? s = yearScope
        ? dashboardStats(widget.year)
        : (all == null ? null : overviewTotals(all));

    return FloatingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'dashboard.kpi_title'.tr(),
                    style: AppText.section.copyWith(color: p.text),
                  ),
                ),
              ),
              Flexible(
                child: PillFilter<_KpiScope>(
                  value: _scope,
                  onChanged: (v) => setState(() => _scope = v),
                  options: [
                    PillOption(_KpiScope.year, 'dashboard.year'.tr()),
                    PillOption(_KpiScope.all, 'dashboard.kpi_all'.tr()),
                  ],
                ),
              ),
            ],
          ),
          if (s == null)
            const Padding(
              padding: EdgeInsets.all(AppSpace.s12),
              child: LoadingState(),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Kpi(
                    value: '${s.offers} / ${s.offersOf}',
                    label: yearScope
                        ? 'dashboard.stats_offers'.tr()
                        : 'orders.open_quotes'.tr(),
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: _Kpi(
                    value: kpiMoney(s.revenue, s.currency),
                    label: yearScope
                        ? 'dashboard.stats_revenue'.tr()
                        : 'orders.total_revenue'.tr(),
                    subtitle: yearScope
                        ? '${s.accepted} ${'dashboard.stats_accepted_suffix'.tr()}'
                        : '${s.accepted} ${'orders.accepted_only'.tr()}',
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Kpi(
                    value: '${s.persons}',
                    label: yearScope
                        ? 'dashboard.stats_persons'.tr()
                        : 'orders.persons'.tr(),
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: _Kpi(
                    value: kpiMoney(s.average, s.currency),
                    label: yearScope
                        ? 'dashboard.stats_avg_per_order'.tr()
                        : 'orders.avg_order'.tr(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, this.subtitle});

  final String value;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large amounts shrink instead of overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppText.number.copyWith(color: p.text),
            ),
          ),
          Text(
            subtitle == null ? label : '$label · $subtitle',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}
