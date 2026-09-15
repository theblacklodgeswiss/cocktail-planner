import 'package:flutter/material.dart';

import '../models/app_role.dart';
import 'role_protected_screen.dart';

/// Gates [child] behind admin access. Thin wrapper over
/// [RoleProtectedScreen] kept for source compatibility with existing call
/// sites.
class AdminProtectedScreen extends StatelessWidget {
  final Widget child;

  const AdminProtectedScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(minimumRole: AppRole.admin, child: child);
  }
}
