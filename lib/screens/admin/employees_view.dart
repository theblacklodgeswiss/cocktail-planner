import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/states.dart';
import 'admin_widgets.dart';

String employeeRoleName(EmployeeRole role) => switch (role) {
  EmployeeRole.leadingSupervisor => 'admin.role_leading_supervisor'.tr(),
  EmployeeRole.supervisor => 'admin.role_supervisor'.tr(),
  EmployeeRole.staff => 'admin.role_staff'.tr(),
};

/// Email is optional; if given it needs an "@" (validation unchanged).
String? validateEmployeeEmail(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  if (!v.contains('@')) return 'admin.employee_email_hint'.tr();
  return null;
}

/// Pure employee list: FloatingCard rows (drag to reorder), add via FAB,
/// edit in a sheet, delete after a confirm sheet. Writes are injected.
class EmployeesView extends StatefulWidget {
  const EmployeesView({
    super.key,
    required this.employees,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onReorder,
    required this.onRebuildAccess,
  });

  final List<Employee> employees;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Future<bool> Function(String name, String? email, EmployeeRole role)
  onAdd;
  final Future<bool> Function(
    Employee previous,
    String name,
    String? email,
    EmployeeRole role,
  )
  onUpdate;
  final Future<bool> Function(Employee employee) onDelete;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  /// Returns the number of synchronized accesses.
  final Future<int> Function() onRebuildAccess;

  @override
  State<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<EmployeesView> {
  bool _rebuilding = false;

  Future<void> _edit([Employee? employee]) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showAppSheet<bool>(
      context,
      scrollable: false,
      builder: (_) => EmployeeForm(
        employee: employee,
        onSubmit: (name, email, role) => employee == null
            ? widget.onAdd(name, email, role)
            : widget.onUpdate(employee, name, email, role),
      ),
    );
    if (ok == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (employee == null ? 'admin.employee_added' : 'admin.employee_updated')
                .tr(),
          ),
        ),
      );
    }
  }

  Future<void> _delete(Employee employee) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmSheet(
      context,
      title: 'admin.delete_employee_confirm_title'.tr(),
      body: 'admin.delete_employee_confirm_message'.tr(
        namedArgs: {'name': employee.name},
      ),
      confirmLabel: 'common.delete'.tr(),
      destructive: true,
      errorText: 'common.error'.tr(),
      confirmAction: () async {
        if (!await widget.onDelete(employee)) throw StateError('delete failed');
      },
    );
    if (!ok) return;
    messenger.showSnackBar(SnackBar(content: Text('admin.employee_deleted'.tr())));
  }

  Future<void> _rebuildAccess() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _rebuilding = true);
    final count = await widget.onRebuildAccess();
    if (!mounted) return;
    setState(() => _rebuilding = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text('admin.employee_access_rebuilt'.tr(args: ['$count'])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final employees = widget.employees;
    return AdminPage(
      title: 'admin.tab_employees'.tr(),
      loading: widget.loading,
      errorMessage: widget.errorMessage,
      onRetry: widget.onRetry,
      onAdd: () => _edit(),
      addLabel: 'admin.add_employee'.tr(),
      header: Align(
        alignment: Alignment.centerLeft,
        child: TextAction(
          label: 'admin.rebuild_employee_access'.tr(),
          loading: _rebuilding,
          onPressed: _rebuilding ? null : _rebuildAccess,
        ),
      ),
      slivers: [
        if (employees.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.badge_outlined,
              title: 'admin.employees_title'.tr(),
            ),
          )
        else
          AdminSliverList(
            count: employees.length,
            idAt: (i) => employees[i].id,
            onReorder: widget.onReorder,
            itemBuilder: (context, i, handle) {
              final e = employees[i];
              final noAccess = e.email == null || e.email!.trim().isEmpty;
              return AdminRowCard(
                title: e.name,
                subtitle: employeeRoleName(e.role),
                leading: handle,
                onTap: () => _edit(e),
                extra: [
                  if (noAccess)
                    Text(
                      'admin.employee_no_app_access'.tr(),
                      style: AppText.caption.copyWith(color: p.error),
                    ),
                ],
                trailing: [
                  RowIconButton(
                    icon: Icons.delete_outline,
                    label: 'common.delete'.tr(),
                    destructive: true,
                    onPressed: () => _delete(e),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// Sheet form for adding or editing an employee.
class EmployeeForm extends StatefulWidget {
  const EmployeeForm({super.key, this.employee, required this.onSubmit});

  final Employee? employee;
  final Future<bool> Function(String name, String? email, EmployeeRole role)
  onSubmit;

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.employee?.name ?? '');
  late final _email = TextEditingController(text: widget.employee?.email ?? '');
  late EmployeeRole _role = widget.employee?.role ?? EmployeeRole.staff;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adding = widget.employee == null;
    return AdminFormSheet(
      title: adding
          ? 'admin.add_employee'.tr()
          : 'admin.edit_employee'.tr(),
      saveLabel: adding ? 'common.add'.tr() : 'common.save'.tr(),
      errorText: adding ? 'common.add_error'.tr() : 'common.error'.tr(),
      validate: () => _formKey.currentState!.validate(),
      onSubmit: () {
        final email = _email.text.trim();
        return widget.onSubmit(
          _name.text.trim(),
          email.isEmpty ? null : email,
          _role,
        );
      },
      fields: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('employee-name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'admin.employee_name'.tr(),
                  hintText: 'admin.employee_name_hint'.tr(),
                ),
                validator: (v) => v?.trim().isEmpty ?? true
                    ? 'offer.field_required'.tr()
                    : null,
              ),
              AdminFormSheet.gap,
              TextFormField(
                key: const Key('employee-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'admin.employee_email'.tr(),
                  hintText: 'admin.employee_email_hint'.tr(),
                ),
                validator: validateEmployeeEmail,
              ),
              AdminFormSheet.gap,
              DropdownButtonFormField<EmployeeRole>(
                initialValue: _role,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'admin.employee_role'.tr(),
                ),
                items: [
                  for (final r in EmployeeRole.values)
                    DropdownMenuItem(value: r, child: Text(employeeRoleName(r))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _role = v);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
