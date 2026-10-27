import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/app_role.dart';
import '../../services/auth_service.dart';
import '../../services/microsoft_graph_service.dart';
import '../../widgets/role_protected_screen.dart';
import '../dashboard/link_google.dart';
import '../orders/form_sync.dart';
import 'more_view.dart';

/// "Mehr" tab (`/more`, employees and up): wires [MoreView] to the real
/// services. Holds what the old user menu and the staff app bars offered.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // No version line then.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Same sign-out call and target as the user menu, without the
    // access-denied frame in between.
    return LogoutTransition(
      signOut: authService.signOut,
      onSignedOut: () => context.go('/login'),
      builder: (context, logout) => RoleProtectedScreen(
        minimumRole: AppRole.employee,
        child: ListenableBuilder(
          listenable: formSync,
          builder: (context, _) {
            final user = authService.currentUser;
            return MoreView(
              user: MoreUser(
                name: user?.displayName,
                email: user?.email,
                photoUrl: user?.photoURL,
                isAnonymous: user?.isAnonymous ?? false,
              ),
              flags: MoreFlags(
                isAdmin: authService.isAdmin,
                canManageUsers: authService.canManageUsers,
                isAnonymous: user?.isAnonymous ?? false,
                web: microsoftGraphService.isSupported,
              ),
              version: _version,
              formSyncBusy: formSync.isSyncing,
              onLinkGoogle: () =>
                  linkGoogleAccount(ScaffoldMessenger.of(context)),
              onFormSync: () => showFormSyncSheet(context),
              onLogout: logout,
            );
          },
        ),
      ),
    );
  }
}
