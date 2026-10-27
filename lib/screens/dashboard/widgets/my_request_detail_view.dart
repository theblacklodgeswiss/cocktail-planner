import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/status_dot.dart';
import '../../orders/order_status_helpers.dart';
import 'my_requests_list.dart';

/// Content of the request detail sheet. Pure view: the PDF action and the
/// staff shortcut are injected, so it has no dependency on the PDF generator
/// or on auth. [onConfirmation] is only used for accepted requests.
class MyRequestDetailView extends StatelessWidget {
  const MyRequestDetailView({
    super.key,
    required this.request,
    required this.showStaffAction,
    required this.onOpenOrder,
    required this.onConfirmation,
    required this.confirmationLoading,
  });

  final SavedOrder request;
  final bool showStaffAction;
  final VoidCallback onOpenOrder;
  final VoidCallback? onConfirmation;
  final bool confirmationLoading;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final shots = request.shotSelections.isNotEmpty
        ? request.shotSelections
              .map((s) => '${s.name} (${s.quantity})')
              .toList()
        : request.shots;
    final time = request.effectiveEventTime;

    Widget gap(Widget w) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: w,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(request.name, style: AppText.heroTitle.copyWith(color: p.text)),
        const SizedBox(height: AppSpace.s4),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusDot(customerStatusKind(request)),
        ),
        const SizedBox(height: AppSpace.s16),
        if (request.isAccepted)
          gap(
            PrimaryButton(
              label: 'dashboard.request_confirmation_pdf'.tr(),
              loading: confirmationLoading,
              onPressed: onConfirmation,
            ),
          )
        else
          gap(
            Text(
              'dashboard.request_pending_hint'.tr(),
              style: AppText.body.copyWith(color: p.textSecondary),
            ),
          ),
        if (showStaffAction)
          gap(
            SecondaryButton(
              label: 'dashboard.open_order'.tr(),
              onPressed: onOpenOrder,
            ),
          ),
        const SizedBox(height: AppSpace.s8),
        gap(
          _SectionCard(
            title: 'dashboard.request_when'.tr(),
            lines: [formatDate(request.date), if (time.isNotEmpty) time],
          ),
        ),
        if (request.location.isNotEmpty)
          gap(
            _SectionCard(
              title: 'dashboard.request_location'.tr(),
              lines: [request.location],
            ),
          ),
        gap(
          _SectionCard(
            title: 'dashboard.request_guests'.tr(),
            lines: ['${request.personCount}'],
            groups: [
              if (request.serviceType.isNotEmpty)
                ('dashboard.request_service_type'.tr(), [request.serviceType]),
            ],
          ),
        ),
        if (request.cocktails.isNotEmpty || shots.isNotEmpty)
          gap(
            _SectionCard(
              title: 'dashboard.request_drinks'.tr(),
              groups: [
                if (request.cocktails.isNotEmpty)
                  ('dashboard.request_cocktails'.tr(), request.cocktails),
                if (shots.isNotEmpty) ('dashboard.request_shots'.tr(), shots),
              ],
            ),
          ),
        if (request.remarks.isNotEmpty)
          gap(
            _SectionCard(
              title: 'dashboard.request_remarks'.tr(),
              lines: [request.remarks],
            ),
          ),
      ],
    );
  }
}

/// A titled card. Either plain [lines] or labelled [groups] of lines.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.lines = const [],
    this.groups = const [],
  });

  final String title;
  final List<String> lines;
  final List<(String, List<String>)> groups;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget line(String t) =>
        Text(t, style: AppText.body.copyWith(color: p.text));

    return FloatingCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          for (final l in lines) line(l),
          for (final (label, items) in groups) ...[
            const SizedBox(height: AppSpace.s4),
            Text(label, style: AppText.section.copyWith(color: p.text)),
            for (final item in items) line(item),
          ],
        ],
      ),
    );
  }
}
