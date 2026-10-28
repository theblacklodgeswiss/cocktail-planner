import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/glass_icon_button.dart';
import '../../../ui/widgets/pressable.dart';
import '../../../ui/widgets/status_dot.dart';
import '../order_status_helpers.dart' show formatDate;
import '../widgets/order_card.dart' show staffStatusKind;
import 'order_detail_controller.dart';
import 'order_detail_logic.dart';

/// Name, status dot, date, the one primary action (from [primaryAction])
/// and the "..." menu with the further actions.
class OrderDetailHeader extends StatelessWidget {
  const OrderDetailHeader({super.key, required this.controller});

  final OrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = controller;
    final actions = c.actions;
    final primary = primaryAction(c.currentStatus, actions);
    final menu = menuActions(c.currentStatus, actions);
    final busy = c.isOpeningOffer || c.isOpeningInvoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.order.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heroTitle.copyWith(color: p.text),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Wrap(
                    spacing: AppSpace.s12,
                    runSpacing: AppSpace.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusDot(staffStatusKind(c.currentStatus)),
                      Text(
                        formatDate(c.currentDate),
                        style: AppText.status.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (menu.isNotEmpty) ...[
              const SizedBox(width: AppSpace.s8),
              GlassIconButton(
                icon: Icons.more_horiz,
                semanticLabel: 'order_detail.more_actions'.tr(),
                onPressed: () => _showMenu(context, menu),
              ),
            ],
          ],
        ),
        if (busy) ...[
          const SizedBox(height: AppSpace.s8),
          const LinearProgressIndicator(minHeight: AppSize.progressHeight),
        ],
        if (primary != null) ...[
          const SizedBox(height: AppSpace.s12),
          _primaryButton(primary),
          ..._hint(p, primary),
        ],
        const SizedBox(height: AppSpace.s12),
      ],
    );
  }

  List<Widget> _hint(AppPalette p, OrderDetailAction primary) {
    final String? text = switch (primary) {
      OrderDetailAction.completeOffer => 'orders.offer_incomplete'.tr(),
      OrderDetailAction.accept =>
        acceptBlockedByTotal(controller.order.total)
            ? 'order_detail.accept_needs_list'.tr()
            : null,
      _ => null,
    };
    if (text == null) return const [];
    return [
      const SizedBox(height: AppSpace.s4),
      Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: p.textSecondary),
      ),
    ];
  }

  Widget _primaryButton(OrderDetailAction action) {
    final c = controller;
    switch (action) {
      case OrderDetailAction.completeOffer:
        return PrimaryButton(
          label: 'orders.complete_offer'.tr(),
          loading: c.isOpeningOffer,
          onPressed: c.openOfferEditor,
        );
      case OrderDetailAction.accept:
        return PrimaryButton(
          label: 'orders.accept'.tr(),
          loading: c.isUpdatingStatus,
          onPressed: acceptBlockedByTotal(c.order.total)
              ? null
              : () => c.tryUpdateStatus(OrderStatus.accepted),
        );
      case OrderDetailAction.complete:
        return PrimaryButton(
          label: 'orders.complete'.tr(),
          loading: c.isUpdatingStatus,
          onPressed: () => c.updateStatus(OrderStatus.completed),
        );
      case OrderDetailAction.recordRest:
        return PrimaryButton(label: 'rest.record'.tr(), onPressed: c.recordRest);
      default:
        return const SizedBox.shrink();
    }
  }

  void _showMenu(BuildContext context, List<OrderDetailAction> menu) {
    showAppSheet<void>(
      context,
      builder: (sheet) {
        final p = AppPalette.of(sheet);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'order_detail.more_actions'.tr(),
              style: AppText.heroTitle.copyWith(color: p.text),
            ),
            const SizedBox(height: AppSpace.s8),
            for (final a in menu)
              _MenuRow(sheet: sheet, action: a, c: controller),
          ],
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.sheet, required this.action, required this.c});

  final BuildContext sheet;
  final OrderDetailAction action;
  final OrderDetailController c;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (IconData icon, String label, VoidCallback? run, bool danger) =
        switch (action) {
          OrderDetailAction.finalizeOffer => (
            Icons.description_outlined,
            'orders.finalize_offer'.tr(),
            c.openOfferEditor,
            false,
          ),
          OrderDetailAction.invoice => (
            Icons.receipt_long,
            'orders.invoice'.tr(),
            c.generateInvoice,
            false,
          ),
          OrderDetailAction.accept => (
            Icons.check,
            'orders.accept'.tr(),
            acceptBlockedByTotal(c.order.total)
                ? null
                : () => c.tryUpdateStatus(OrderStatus.accepted),
            false,
          ),
          OrderDetailAction.backToAccepted => (
            Icons.undo,
            'orders.back_to_accepted'.tr(),
            () => c.updateStatus(OrderStatus.accepted),
            false,
          ),
          OrderDetailAction.backToQuote => (
            Icons.undo,
            'orders.status_quote'.tr(),
            () => c.updateStatus(OrderStatus.quote),
            false,
          ),
          OrderDetailAction.decline => (
            Icons.close,
            'orders.decline'.tr(),
            () => c.updateStatus(OrderStatus.declined),
            false,
          ),
          OrderDetailAction.delete => (
            Icons.delete_forever,
            'orders.delete_order'.tr(),
            c.deleteOrder,
            true,
          ),
          _ => (Icons.circle, '', null, false),
        };
    final color = run == null ? p.disabled : (danger ? p.error : p.text);
    return Pressable(
      minSize: AppSize.minTap,
      onTap: run == null
          ? null
          : () {
              Navigator.of(sheet).pop();
              run();
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.minTap),
        child: Row(
          children: [
            Icon(icon, size: AppSize.rowIcon, color: color),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(label, style: AppText.button.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reason of a declined order; tap to edit it in place.
class DeclineReasonCard extends StatelessWidget {
  const DeclineReasonCard({super.key, required this.controller});

  final OrderDetailController controller;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final empty = controller.declineReason.isEmpty;
    return FloatingCard(
      onTap: controller.editDeclineReason,
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              empty
                  ? 'orders.decline_reason_add'.tr()
                  : '${'orders.decline_reason'.tr()}: ${controller.declineReason}',
              style: AppText.body.copyWith(
                color: empty ? p.textSecondary : p.text,
                fontStyle: empty ? FontStyle.italic : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Icon(
            Icons.edit_outlined,
            size: AppSize.metaIcon,
            color: p.textSecondary,
          ),
        ],
      ),
    );
  }
}
