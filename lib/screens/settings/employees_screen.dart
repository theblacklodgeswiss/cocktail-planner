import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../admin/admin_denied_page.dart';
import '../admin/employees_tab.dart';

/// Screen for managing employees, accessible from settings.
class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!authService.canManageUsers) {
      return AdminDeniedPage(title: 'admin.tab_employees'.tr());
    }
    return const EmployeesTab();
  }
}
