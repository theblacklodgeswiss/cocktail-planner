import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../admin/employees_tab.dart';

/// Screen for managing employees, accessible from settings.
class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!authService.canManageUsers) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text('admin.tab_employees'.tr()),
        ),
        body: Center(
          child: Text('admin.access_denied'.tr()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('admin.tab_employees'.tr()),
      ),
      body: const EmployeesTab(),
    );
  }
}
