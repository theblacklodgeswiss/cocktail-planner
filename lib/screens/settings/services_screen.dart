import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../admin/admin_denied_page.dart';
import '../admin/services_tab.dart';

/// Screen for managing the additional-services catalog, accessible from
/// settings. Mirrors `employees_screen.dart`'s thin-wrapper pattern.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!authService.canManageUsers) {
      return AdminDeniedPage(title: 'admin.tab_services'.tr());
    }
    return const ServicesTab();
  }
}
