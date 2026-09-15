import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';

/// Gates [child] behind [minimumRole]. Shows a loading spinner while the
/// role is still resolving (see [AuthService.roleResolved]) rather than
/// flashing an access-denied screen during that window, then an
/// access-denied screen if the resolved role does not meet [minimumRole].
class RoleProtectedScreen extends StatefulWidget {
  const RoleProtectedScreen({
    super.key,
    required this.minimumRole,
    required this.child,
  });

  final AppRole minimumRole;
  final Widget child;

  @override
  State<RoleProtectedScreen> createState() => _RoleProtectedScreenState();
}

class _RoleProtectedScreenState extends State<RoleProtectedScreen> {
  late final Stream<AppRole> _roleChanges = authService.roleChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppRole>(
      stream: _roleChanges,
      initialData: authService.roleResolved ? authService.role : null,
      builder: (context, snapshot) {
        if (!authService.roleResolved && !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentRole = snapshot.data ?? authService.role;
        if (!currentRole.atLeast(widget.minimumRole)) {
          return Scaffold(
            appBar: AppBar(
              title: Text('admin.access_denied'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'admin.access_denied'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'admin.access_denied_message'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home),
                      label: Text('common.back'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return widget.child;
      },
    );
  }
}
