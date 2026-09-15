import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../orders/order_status_helpers.dart';

/// Shows a read-only summary of a customer's own submitted request. Unlike
/// `order_detail_sheet.dart`'s `showOrderDetails` (staff tooling: offer
/// generation, status transitions, employee assignment, deletion), this
/// exposes nothing actionable - a customer cannot edit or delete a request
/// from here.
Future<void> showMyRequestDetails(BuildContext context, SavedOrder request) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => MyRequestDetailSheet(request: request),
  );
}

class MyRequestDetailSheet extends StatelessWidget {
  const MyRequestDetailSheet({super.key, required this.request});

  final SavedOrder request;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon(request.status),
                    size: 16, color: statusColor(request.status)),
                const SizedBox(width: 4),
                Text(statusLabel(request.status),
                    style: TextStyle(color: statusColor(request.status))),
              ],
            ),
            const Divider(height: 32),
            _row(context, 'dashboard.request_date'.tr(), formatDate(request.date)),
            if (request.effectiveEventTime.isNotEmpty)
              _row(context, 'dashboard.request_time'.tr(), request.effectiveEventTime),
            if (request.location.isNotEmpty)
              _row(context, 'dashboard.request_location'.tr(), request.location),
            _row(context, 'dashboard.request_guests'.tr(), '${request.personCount}'),
            if (request.serviceType.isNotEmpty)
              _row(context, 'dashboard.request_service_type'.tr(), request.serviceType),
            if (request.cocktails.isNotEmpty)
              _row(context, 'dashboard.request_cocktails'.tr(),
                  request.cocktails.join(', ')),
            if (request.shotSelections.isNotEmpty)
              _row(
                context,
                'dashboard.request_shots'.tr(),
                request.shotSelections
                    .map((s) => '${s.name} (${s.quantity})')
                    .join(', '),
              )
            else if (request.shots.isNotEmpty)
              _row(context, 'dashboard.request_shots'.tr(), request.shots.join(', ')),
            if (request.remarks.isNotEmpty)
              _row(context, 'dashboard.request_remarks'.tr(), request.remarks),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
