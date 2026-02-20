import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../utils/currency.dart';

/// Preview card showing the calculated price breakdown.
class OfferPricePreview extends StatelessWidget {
  const OfferPricePreview({
    super.key,
    required this.currency,
    required this.orderTotal,
    required this.distanceKm,
    required this.travelCostPerKm,
    required this.barCost,
    required this.discount,
    this.extraPositionsTotal = 0,
  });

  final Currency currency;
  final double orderTotal;
  final int distanceKm;
  final double travelCostPerKm;
  final double barCost;
  final double discount;
  final double extraPositionsTotal;

  @override
  Widget build(BuildContext context) {
    final travel = distanceKm * 2 * travelCostPerKm;
    // barServiceCost is orderTotal minus travel and theke (already included)
    final barService = orderTotal - travel - barCost;
    final total = orderTotal + extraPositionsTotal - discount;

    return Card(
      color: Theme.of(context)
          .colorScheme
          .secondaryContainer
          .withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'offer.price_preview'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _PreviewRow(
              label: 'offer.bar_service_cost'.tr(),
              value: currency.format(barService),
            ),
            if (distanceKm > 0)
              _PreviewRow(
                label: 'offer.travel_cost'.tr(),
                value:
                    '${distanceKm * 2} km × ${currency.format(travelCostPerKm)} = ${currency.format(travel)}',
              ),
            if (barCost > 0)
              _PreviewRow(
                label: 'offer.bar_cost'.tr(),
                value: currency.format(barCost),
              ),
            if (extraPositionsTotal > 0)
              _PreviewRow(
                label: 'offer.extra_positions'.tr(),
                value: currency.format(extraPositionsTotal),
              ),
            if (discount > 0)
              _PreviewRow(
                label: 'offer.discount'.tr(),
                value: '-${currency.format(discount)}',
              ),
            const Divider(),
            _PreviewRow(
              label: 'offer.total'.tr(),
              value: currency.format(total),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
          Text(
            value,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}
