import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';

/// Shows the user menu as a bottom sheet.
Future<void> showUserMenu(BuildContext context) async {
  final user = authService.currentUser;
  if (user == null) return;

  await showModalBottomSheet(
    context: context,
    builder: (ctx) => _UserMenuSheet(
      onShowAdminPanel: () {
        Navigator.pop(ctx);
        showAdminPanel(context);
      },
    ),
  );
}

class _UserMenuSheet extends StatelessWidget {
  const _UserMenuSheet({required this.onShowAdminPanel});

  final VoidCallback onShowAdminPanel;

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserHeader(context, user),
          const Divider(),
          if (authService.isAdmin) _buildAdminTile(context),
          if (authService.isAdmin || authService.isSuperAdmin)
            _buildOrdersTile(context),
          if (authService.isAdmin) _buildSettingsTile(context),
          if (authService.canManageUsers) _buildUsersTile(),
          if (user.isAnonymous) _buildLinkGoogleTile(context),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, dynamic user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            user.photoURL != null ? NetworkImage(user.photoURL!) : null,
        child: user.photoURL == null
            ? Icon(user.isAnonymous ? Icons.person_outline : Icons.person)
            : null,
      ),
      title: Row(
        children: [
          Text(user.displayName ??
              (user.isAnonymous ? 'Gast' : 'Benutzer')),
          if (authService.isAdmin) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'drawer.admin_badge'.tr(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(user.email ??
          (user.isAnonymous ? 'drawer.anonymous_user'.tr() : '')),
    );
  }

  Widget _buildAdminTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.inventory),
      title: Text('drawer.inventory_title'.tr()),
      subtitle: Text('drawer.inventory_subtitle'.tr()),
      onTap: () {
        Navigator.pop(context);
        context.push('/admin');
      },
    );
  }

  Widget _buildOrdersTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bar_chart),
      title: Text('drawer.orders_title'.tr()),
      subtitle: Text('drawer.orders_subtitle'.tr()),
      onTap: () {
        Navigator.pop(context);
        context.push('/orders');
      },
    );
  }

  Widget _buildSettingsTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.settings),
      title: Text('settings.title'.tr()),
      onTap: () {
        Navigator.pop(context);
        context.push('/settings');
      },
    );
  }

  Widget _buildUsersTile() {
    return ListTile(
      leading: const Icon(Icons.admin_panel_settings),
      title: Text('drawer.users_title'.tr()),
      subtitle: Text('drawer.users_subtitle'.tr()),
      onTap: onShowAdminPanel,
    );
  }

  Widget _buildLinkGoogleTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.login),
      title: Text('drawer.link_google_title'.tr()),
      subtitle: Text('drawer.link_google_subtitle'.tr()),
      onTap: () async {
        Navigator.pop(context);
        try {
          await authService.linkWithGoogle();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('drawer.link_success'.tr())),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${'common.error'.tr()}: $e')),
            );
          }
        }
      },
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.logout),
      title: Text('drawer.logout'.tr()),
      onTap: () async {
        Navigator.pop(context);
        await authService.signOut();
        if (context.mounted) {
          context.go('/login');
        }
      },
    );
  }
}

/// Shows the admin panel dialog for managing users.
Future<void> showAdminPanel(BuildContext context) async {
  final users = await authService.getAllowedUsers();

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings),
          const SizedBox(width: 8),
          Text('admin_panel.title'.tr()),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text('admin_panel.add_user'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _showAddUserDialog(context);
              },
            ),
            const Divider(),
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('admin_panel.no_users'.tr()),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (listContext, index) {
                    final user = users[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(
                          user.name.isNotEmpty ? user.name : user.email),
                      subtitle: Text(user.email),
                      trailing: authService.isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmRemoveUser(
                                  listContext, context, user.email),
                            )
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('common.close'.tr()),
        ),
      ],
    ),
  );
}

Future<void> _confirmRemoveUser(
  BuildContext listContext,
  BuildContext parentContext,
  String email,
) async {
  final navigator = Navigator.of(listContext);
  final confirm = await showDialog<bool>(
    context: listContext,
    builder: (c) => AlertDialog(
      title: Text('admin_panel.remove_user_title'.tr()),
      content:
          Text('admin_panel.remove_user_message'.tr(namedArgs: {'email': email})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text('admin_panel.remove'.tr()),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await authService.removeAllowedUser(email);
    if (parentContext.mounted) {
      navigator.pop();
      showAdminPanel(parentContext); // Refresh
    }
  }
}

Future<void> _showAddUserDialog(BuildContext context) async {
  final emailController = TextEditingController();
  final nameController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('admin_panel.add_user'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: 'admin_panel.email_label'.tr(),
              hintText: 'admin_panel.email_hint'.tr(),
              prefixIcon: const Icon(Icons.email),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'admin_panel.name_label'.tr(),
              hintText: 'admin_panel.name_hint'.tr(),
              prefixIcon: const Icon(Icons.person),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('common.add'.tr()),
        ),
      ],
    ),
  );

  if (result == true && emailController.text.trim().isNotEmpty) {
    final success = await authService.addAllowedUser(
      emailController.text.trim(),
      name: nameController.text.trim(),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              success ? 'common.user_added'.tr() : 'common.add_error'.tr()),
        ),
      );
      if (success) {
        showAdminPanel(context); // Reopen panel
      }
    }
  }
}
