import 'package:flutter/material.dart';

import '../../data/order_repository.dart';
import '../../services/auth_service.dart';
import 'widgets/my_request_detail_sheet.dart';
import 'widgets/my_requests_list.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = authService.isSignedIn;
    return MyRequestsPage(
      signedIn: signedIn,
      streamFactory: () =>
          orderRepository.watchOrdersForOwner(authService.currentUser!.uid),
      onOpen: (request) => showMyRequestDetails(context, request),
    );
  }
}
