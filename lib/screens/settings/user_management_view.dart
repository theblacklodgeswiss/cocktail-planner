import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/states.dart';
import '../admin/admin_widgets.dart';

/// Light copy of an allowed user, so the view needs no Firebase imports.
class UserRow {
  const UserRow({required this.email, required this.name, required this.isAdmin});

  final String email;
  final String name;
  final bool isAdmin;

  UserRow copyWith({bool? isAdmin}) =>
      UserRow(email: email, name: name, isAdmin: isAdmin ?? this.isAdmin);

  String get displayName => name.isNotEmpty ? name : email;
}

/// Pure user list: FloatingCard rows with an admin switch, add via FAB,
/// delete after a confirm sheet. Rules are unchanged: nobody can change or
/// remove themselves, the super admin has no switch and cannot be removed,
/// and only admins may remove users.
class UserManagementView extends StatelessWidget {
  const UserManagementView({
    super.key,
    required this.users,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.currentEmail,
    required this.superAdminEmail,
    required this.viewerIsAdmin,
    required this.onToggleAdmin,
    required this.onRemove,
    required this.onAdd,
  });

  final List<UserRow> users;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final String? currentEmail;
  final String superAdminEmail;
  final bool viewerIsAdmin;
  final Future<void> Function(UserRow user, bool isAdmin) onToggleAdmin;
  final Future<bool> Function(String email) onRemove;
  final Future<bool> Function(String email, String name, bool isAdmin) onAdd;

  bool _isSuper(String email) =>
      email.toLowerCase() == superAdminEmail.toLowerCase();

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showAppSheet<bool>(
      context,
      scrollable: false,
      builder: (_) => _AddUserForm(onAdd: onAdd),
    );
    if (ok == true) {
      messenger.showSnackBar(
        SnackBar(content: Text('common.user_added'.tr())),
      );
    }
  }

  Future<void> _remove(BuildContext context, UserRow user) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmSheet(
      context,
      title: 'admin_panel.remove_user_title'.tr(),
      body: 'admin_panel.remove_user_message'.tr(
        namedArgs: {'email': user.email},
      ),
      confirmLabel: 'admin_panel.remove'.tr(),
      destructive: true,
    );
    if (!ok) return;
    final success = await onRemove(user.email);
    if (!success) {
      messenger.showSnackBar(SnackBar(content: Text('common.error'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdminPage(
      title: 'admin_panel.title'.tr(),
      loading: loading,
      errorMessage: errorMessage,
      onRetry: onRetry,
      onAdd: () => _add(context),
      addLabel: 'admin_panel.add_user'.tr(),
      slivers: [
        if (users.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.people_outline,
              title: 'admin_panel.no_users'.tr(),
            ),
          )
        else
          AdminSliverList(
            count: users.length,
            idAt: (i) => users[i].email,
            itemBuilder: (context, i, _) {
              final user = users[i];
              final isCurrent =
                  user.email.toLowerCase() == currentEmail?.toLowerCase();
              final isSuper = _isSuper(user.email);
              return AdminRowCard(
                title: user.displayName,
                leading: Padding(
                  padding: const EdgeInsets.only(left: AppSpace.s4),
                  child: _Avatar(user.displayName),
                ),
                extra: [
                  Wrap(
                    spacing: AppSpace.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SelectableText(
                        user.email,
                        style: AppText.body.copyWith(color: p.textSecondary),
                      ),
                      if (isCurrent) MiniPill('admin2.you'.tr()),
                    ],
                  ),
                  if (isCurrent)
                    Text(
                      'admin2.own_status_locked'.tr(),
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                ],
                trailing: [
                  if (!isSuper)
                    _AdminSwitch(
                      value: user.isAdmin,
                      onChanged: isCurrent
                          ? null
                          : (v) => onToggleAdmin(user, v),
                    )
                  else
                    Semantics(
                      label: 'admin2.super_admin'.tr(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s12,
                        ),
                        child: Icon(Icons.security, color: p.gold),
                      ),
                    ),
                  if (viewerIsAdmin && !isSuper && !isCurrent)
                    RowIconButton(
                      icon: Icons.delete_outline,
                      label: 'common.delete'.tr(),
                      destructive: true,
                      onPressed: () => _remove(context, user),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
        child: SizedBox.square(
          dimension: AppSize.avatar,
          child: Center(
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: AppText.section.copyWith(color: p.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSwitch extends StatelessWidget {
  const _AdminSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'admin2.admin_label'.tr(),
          style: AppText.pill.copyWith(
            color: value ? p.goldText : p.textSecondary,
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _AddUserForm extends StatefulWidget {
  const _AddUserForm({required this.onAdd});

  final Future<bool> Function(String email, String name, bool isAdmin) onAdd;

  @override
  State<_AddUserForm> createState() => _AddUserFormState();
}

class _AddUserFormState extends State<_AddUserForm> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  bool _isAdmin = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormSheet(
      title: 'admin_panel.add_user'.tr(),
      saveLabel: 'common.add'.tr(),
      errorText: 'common.add_error'.tr(),
      validate: () => _email.text.trim().isNotEmpty,
      onSubmit: () =>
          widget.onAdd(_email.text.trim(), _name.text.trim(), _isAdmin),
      fields: [
        TextField(
          key: const Key('user-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'admin_panel.email_label'.tr(),
            hintText: 'admin_panel.email_hint'.tr(),
          ),
        ),
        AdminFormSheet.gap,
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: 'admin_panel.name_label'.tr(),
            hintText: 'admin_panel.name_hint'.tr(),
          ),
        ),
        SwitchListTile(
          title: Text('admin2.admin_label'.tr()),
          subtitle: Text('admin2.admin_hint'.tr()),
          value: _isAdmin,
          onChanged: (v) => setState(() => _isAdmin = v),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
