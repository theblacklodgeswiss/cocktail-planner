import 'package:flutter/material.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import 'customer_start.dart';
import 'widgets/my_request_detail_sheet.dart';

/// Home screen shown to all users. Staff gets their own landing in a later
/// step; until then everyone sees the customer start.
class CustomerLandingScreen extends StatefulWidget {
  const CustomerLandingScreen({super.key});

  @override
  State<CustomerLandingScreen> createState() => _CustomerLandingScreenState();
}

class _CustomerLandingScreenState extends State<CustomerLandingScreen> {
  // One stream per user, not one per rebuild.
  String? _uid;
  Stream<List<SavedOrder>>? _orders;

  @override
  Widget build(BuildContext context) {
    final signedIn = authService.isSignedIn;
    final uid = signedIn ? authService.currentUser!.uid : null;
    if (uid != _uid) {
      _uid = uid;
      _orders = uid == null ? null : orderRepository.watchOrdersForOwner(uid);
    }
    return CustomerStart(
      signedIn: signedIn,
      onOpenRequest: (request) => showMyRequestDetails(context, request),
      orders: _orders,
    );
  }
}
