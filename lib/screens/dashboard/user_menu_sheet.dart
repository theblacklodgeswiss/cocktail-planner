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
    builder: (ctx) => const _UserMenuSheet(),
  );
}

class _UserMenuSheet extends StatelessWidget {
  const _UserMenuSheet();

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
          _buildSettingsTile(context),
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
