import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'user_menu_sheet.dart';

/// Simple home screen – just a button to create a new order.
/// The user menu (person icon) shows more options based on role (admin vs. normal user).
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
        child: FilledButton.icon(
          onPressed: () => context.push('/order-form'),
          icon: const Icon(Icons.add),
          label: Text('dashboard.new_order'.tr()),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
