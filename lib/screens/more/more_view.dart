import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/staff_scaffold.dart';
import '../../ui/widgets/staff_tab_bar.dart';
import '../../ui/widgets/states.dart';
import '../settings/sections/settings_widgets.dart';

/// Role and platform flags that decide which "Mehr" rows exist.
@immutable
class MoreFlags {
  const MoreFlags({
    required this.isAdmin,
    required this.canManageUsers,
    required this.isAnonymous,
    required this.web,
  });

  final bool isAdmin;
  final bool canManageUsers;
  final bool isAnonymous;

  /// OneDrive form sync only works on web.
  final bool web;

  @override
  String toString() =>
      'MoreFlags(admin: $isAdmin, manage: $canManageUsers, '
      'anonymous: $isAnonymous, web: $web)';
}

/// Action ids for rows that do not navigate.
const moreLinkGoogle = 'link-google';
const moreFormSync = 'form-sync';
const moreLogout = 'logout';

/// One row: [destination] is a route (pushed) or one of the action ids.
@immutable
class MoreItem {
  const MoreItem(
    this.destination,
    this.icon,
    this.titleKey, [
    this.subtitleKey,
  ]);

  final String destination;
  final IconData icon;
  final String titleKey;
  final String? subtitleKey;

  bool get isRoute => destination.startsWith('/');

  Key get key => Key(
    'more-${isRoute ? destination.split('/').where((s) => s.isNotEmpty).last : destination}',
  );
}

@immutable
class MoreGroup {
  const MoreGroup(this.captionKey, this.items);

  final String captionKey;
  final List<MoreItem> items;
}

/// The rows of "Mehr" for [f]. Orders and inventory are tabs, "new order" is
/// the "+" button; everything else the old user menu and the staff app bars
/// offered lives here (see the Task 10 report).
List<MoreGroup> moreGroups(MoreFlags f) {
  final admin = [
    if (f.isAdmin)
      const MoreItem(
        '/admin',
        Icons.admin_panel_settings_outlined,
        'dashboard.action_admin',
        'drawer.inventory_subtitle',
      ),
    if (f.canManageUsers) ...const [
      MoreItem(
        '/settings/users',
        Icons.people_outline,
        'drawer.users_title',
        'drawer.users_subtitle',
      ),
      MoreItem(
        '/settings/employees',
        Icons.badge_outlined,
        'admin.tab_employees',
        'admin.employees_subtitle',
      ),
      MoreItem(
        '/settings/services',
        Icons.room_service_outlined,
        'admin.tab_services',
        'admin.services_subtitle',
      ),
    ],
    // Same rule as the orders app-bar sync menu: every staff member on web.
    if (f.web)
      const MoreItem(
        moreFormSync,
        Icons.sync,
        'more.form_sync',
        'orders.sync_forms_tooltip',
      ),
  ];
  return [
    MoreGroup('more.section_overview', [
      // Admin only, like the old orders app-bar dashboard icon.
      if (f.isAdmin)
        const MoreItem(
          '/dashboard',
          Icons.insights_outlined,
          'more.dashboard',
          'more.dashboard_subtitle',
        ),
      const MoreItem(
        '/pending-orders',
        Icons.pending_actions,
        'orders.pending_title',
      ),
    ]),
    if (admin.isNotEmpty) MoreGroup('more.section_admin', admin),
    MoreGroup('more.section_account', [
      const MoreItem('/settings', Icons.settings_outlined, 'settings.title'),
      if (f.isAnonymous)
        const MoreItem(
          moreLinkGoogle,
          Icons.login,
          'drawer.link_google_title',
          'drawer.link_google_subtitle',
        ),
      const MoreItem(moreLogout, Icons.logout, 'drawer.logout'),
    ]),
  ];
}

/// Who is signed in, for the header card.
@immutable
class MoreUser {
  const MoreUser({
    required this.name,
    required this.email,
    this.photoUrl,
    this.isAnonymous = false,
  });

  final String? name;
  final String? email;
  final String? photoUrl;
  final bool isAnonymous;
}

/// Pure "Mehr" page. Services are injected so it stays VM-testable;
/// [MoreScreen] wires the real ones.
class MoreView extends StatelessWidget {
  const MoreView({
    super.key,
    required this.user,
    required this.flags,
    required this.version,
    required this.onLinkGoogle,
    required this.onFormSync,
    required this.onLogout,
    this.formSyncBusy = false,
  });

  final MoreUser user;
  final MoreFlags flags;
  final String version;
  final VoidCallback onLinkGoogle;
  final VoidCallback onFormSync;

  /// Called after the user confirmed.
  final Future<void> Function() onLogout;
  final bool formSyncBusy;

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmSheet(
      context,
      title: 'more.logout_confirm_title'.tr(),
      body: 'more.logout_confirm_body'.tr(),
      confirmLabel: 'drawer.logout'.tr(),
      destructive: true,
    );
    if (ok) await onLogout();
  }

  VoidCallback? _onTap(BuildContext context, MoreItem item) {
    if (item.isRoute) return () => context.push(item.destination);
    return switch (item.destination) {
      moreLinkGoogle => onLinkGoogle,
      moreFormSync => formSyncBusy ? null : onFormSync,
      _ => () => _logout(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return StaffScaffold(
      tab: StaffTab.more,
      title: 'more.title'.tr(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s24),
                child: _Header(user: user, isAdmin: flags.isAdmin),
              ),
              for (final group in moreGroups(flags))
                SettingsGroup(
                  caption: group.captionKey.tr(),
                  children: [
                    for (final item in group.items)
                      SettingsRow(
                        key: item.key,
                        icon: item.icon,
                        title: item.titleKey.tr(),
                        subtitle:
                            item.destination == moreFormSync && formSyncBusy
                            ? 'orders.syncing'.tr()
                            : item.subtitleKey?.tr(),
                        chevron: item.isRoute,
                        leadingColor: item.destination == moreLogout
                            ? p.error
                            : null,
                        onTap: _onTap(context, item),
                      ),
                  ],
                ),
              if (version.isNotEmpty)
                Text(
                  '${'settings.app_version'.tr()} $version',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.isAdmin});

  final MoreUser user;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name =
        user.name ?? (user.isAnonymous ? 'more.guest' : 'more.user').tr();
    final email =
        user.email ?? (user.isAnonymous ? 'drawer.anonymous_user'.tr() : '');
    final photo = user.photoUrl;
    return FloatingCard(
      child: Row(
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: AppSize.avatar / 2,
              backgroundColor: p.surface,
              foregroundColor: p.textSecondary,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Icon(
                      user.isAnonymous ? Icons.person_outline : Icons.person,
                      size: AppSize.glassButtonIcon,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.section.copyWith(color: p.text)),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
              ],
            ),
          ),
          if (!user.isAnonymous) ...[
            const SizedBox(width: AppSpace.s8),
            _RolePill(
              label: (isAdmin ? 'drawer.admin_badge' : 'more.role_employee')
                  .tr(),
              gold: isAdmin,
            ),
          ],
        ],
      ),
    );
  }
}

/// Small role pill; gold text for admins.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.gold});

  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s4,
        ),
        child: Text(
          label,
          style: AppText.pill.copyWith(
            color: gold ? p.goldText : p.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Signs out without flashing the page underneath: signing out drops the
/// role first, which would turn a role-guarded page into "access denied"
/// for a frame before the redirect to the login. While [signOut] runs this
/// shows a plain loading page instead of [builder]'s output, then calls
/// [onSignedOut] (navigate to the login).
class LogoutTransition extends StatefulWidget {
  const LogoutTransition({
    super.key,
    required this.signOut,
    required this.onSignedOut,
    required this.builder,
  });

  final Future<void> Function() signOut;
  final VoidCallback onSignedOut;

  /// Builds the page; `logout` runs the guarded sign-out.
  final Widget Function(BuildContext context, Future<void> Function() logout)
  builder;

  @override
  State<LogoutTransition> createState() => _LogoutTransitionState();
}

class _LogoutTransitionState extends State<LogoutTransition> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await widget.signOut();
    } catch (_) {
      // Stay on the page if signing out failed.
      if (mounted) setState(() => _loggingOut = false);
      rethrow;
    }
    if (mounted) widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loggingOut) return const Scaffold(body: LoadingState());
    return widget.builder(context, _logout);
  }
}
