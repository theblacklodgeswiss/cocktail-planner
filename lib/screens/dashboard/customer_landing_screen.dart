import 'package:flutter/material.dart';

import '../../data/order_repository.dart';
import '../../services/auth_service.dart';
import 'customer_start.dart';
import 'widgets/my_request_detail_sheet.dart';

/// Home screen shown to all users. Staff gets their own landing in a later
/// step; until then everyone sees the customer start.
class CustomerLandingScreen extends StatelessWidget {
  const CustomerLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = authService.isSignedIn;
    return CustomerStart(
      signedIn: signedIn,
      onOpenRequest: (request) => showMyRequestDetails(context, request),
      orders: signedIn
          ? orderRepository.watchOrdersForOwner(authService.currentUser!.uid)
          : null,
    );
  }
}
