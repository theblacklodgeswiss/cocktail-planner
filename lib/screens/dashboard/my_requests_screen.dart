import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import 'widgets/my_request_detail_sheet.dart';
import 'widgets/my_requests_list.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('dashboard.my_requests_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: userId == null
          ? Center(child: Text('dashboard.sign_in_to_see_requests'.tr()))
          : StreamBuilder<List<SavedOrder>>(
              stream: orderRepository.watchOrdersForOwner(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = snapshot.data ?? [];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: MyRequestsList(
                        requests: requests,
                        onTap: (request) => showMyRequestDetails(context, request),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
