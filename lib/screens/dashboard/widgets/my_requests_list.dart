import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/order.dart';
import '../../orders/order_status_helpers.dart';
import '../../orders/widgets/order_info_chip.dart';

/// Customer-facing list of the signed-in user's own submitted requests.
/// Deliberately does not show total price or article count (see design
/// spec section 4) - only what a customer should see before an offer is
/// formally sent.
class MyRequestsList extends StatelessWidget {
  const MyRequestsList({
    super.key,
    required this.requests,
    required this.onTap,
  });

  final List<SavedOrder> requests;
  final void Function(SavedOrder request) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'dashboard.no_requests_yet'.tr(),
            style: TextStyle(color: colorScheme.outline),
          ),
        ),
      );
    }

    return Column(
      children: requests.map((request) => _buildCard(context, request)).toList(),
    );
  }

  Widget _buildCard(BuildContext context, SavedOrder request) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(request),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(request.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon(request.status),
                            size: 14, color: statusColor(request.status)),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel(request.status),
                          style: TextStyle(
                            color: statusColor(request.status),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatDate(request.date),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              OrderInfoChip(
                icon: Icons.people,
                label: '${request.personCount}',
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
