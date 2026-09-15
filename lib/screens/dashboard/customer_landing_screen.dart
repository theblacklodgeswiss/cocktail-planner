import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/order_repository.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import 'user_menu_sheet.dart';
import 'widgets/my_request_detail_sheet.dart';
import 'widgets/my_requests_list.dart';

/// Home screen shown to all users.
/// The person-icon menu shows more options for admins (orders, inventory).
class CustomerLandingScreen extends StatelessWidget {
  const CustomerLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('dashboard.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => showUserMenu(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_bar,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'customer.welcome_title'.tr(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'customer.welcome_message'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () => context.push('/order-form'),
                icon: const Icon(Icons.add),
                label: Text('dashboard.new_order'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              if (authService.isSignedIn) ...[
                const SizedBox(height: 24),
                Text(
                  'dashboard.my_requests_title'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<SavedOrder>>(
                  stream: orderRepository
                      .watchOrdersForOwner(authService.currentUser!.uid),
                  builder: (context, snapshot) {
                    final requests = (snapshot.data ?? []).take(3).toList();
                    final hasMore = (snapshot.data ?? []).length > 3;
                    return Column(
                      children: [
                        MyRequestsList(
                          requests: requests,
                          onTap: (request) =>
                              showMyRequestDetails(context, request),
                        ),
                        if (hasMore)
                          TextButton(
                            onPressed: () => context.push('/my-requests'),
                            child: Text('dashboard.show_all_requests'.tr()),
                          ),
                      ],
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 24),
                Text(
                  'dashboard.sign_in_to_see_requests'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'customer.info_title'.tr(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'customer.info_message'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
