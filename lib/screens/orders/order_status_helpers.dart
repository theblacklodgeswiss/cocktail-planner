import 'package:easy_localization/easy_localization.dart';

import '../../models/order.dart';

/// Helper functions for order status display.

String drinkerLabel(String type) {
  switch (type) {
    case 'light':
      return 'orders.drinker_light'.tr();
    case 'heavy':
      return 'orders.drinker_heavy'.tr();
    default:
      return 'orders.drinker_normal'.tr();
  }
}

String statusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.quote:
      return 'orders.status_quote'.tr();
    case OrderStatus.accepted:
      return 'orders.status_accepted'.tr();
    case OrderStatus.completed:
      return 'orders.status_completed'.tr();
    case OrderStatus.declined:
      return 'orders.status_declined'.tr();
  }
}

/// Formats a DateTime to dd.MM.yyyy format.
String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
