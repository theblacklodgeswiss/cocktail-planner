import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../admin/admin_denied_page.dart';
import 'user_management_view.dart';

/// Screen for managing allowed users (data wrapper around the view).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AllowedUser> _users = [];
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final users = await authService.getAllowedUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  /// Pull-to-refresh: reloads without the full-screen spinner.
  Future<void> _refresh() async {
    try {
      final users = await authService.getAllowedUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _failed = false;
      });
    } catch (_) {
      // Keep the current list; the pull gesture just ends.
    }
  }

  Future<void> _toggleAdmin(UserRow row, bool value) async {
    final index = _users.indexWhere((u) => u.email == row.email);
    if (index < 0) return;
    final user = _users[index];
    // Optimistic UI: update local state immediately.
    setState(() => _users[index] = user.copyWith(isAdmin: value));
    final success = await authService.updateAdminStatus(user.email, value);
    if (!success && mounted) {
      // Revert local state on error.
      setState(() => _users[index] = user);
    }
  }

  Future<bool> _remove(String email) async {
    final success = await authService.removeAllowedUser(email);
    if (success) await _loadUsers();
    return success;
  }

  Future<bool> _add(String email, String name, bool isAdmin) async {
    final success = await authService.addAllowedUser(
      email,
      name: name,
      isAdmin: isAdmin,
    );
    if (success) await _loadUsers();
    return success;
  }

  @override
  Widget build(BuildContext context) {
    if (!authService.canManageUsers) {
      return AdminDeniedPage(title: 'admin_panel.title'.tr());
    }
    return UserManagementView(
      users: [
        for (final u in _users)
          UserRow(email: u.email, name: u.name, isAdmin: u.isAdmin),
      ],
      loading: _isLoading,
      errorMessage: _failed ? 'admin2.load_error'.tr() : null,
      onRetry: _loadUsers,
      onRefresh: _refresh,
      currentEmail: authService.email,
      superAdminEmail: superAdminEmail,
      viewerIsAdmin: authService.isAdmin,
      onToggleAdmin: _toggleAdmin,
      onRemove: _remove,
      onAdd: _add,
    );
  }
}
