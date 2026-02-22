import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/employee_repository.dart';
import '../../models/employee.dart';

/// Tab for managing employees (add/delete) with responsive design.
class EmployeesTab extends StatefulWidget {
  const EmployeesTab({super.key});

  @override
  State<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<EmployeesTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;
  bool _isReordering = false;
  List<Employee> _localEmployees = [];
  EmployeeRole _selectedRole = EmployeeRole.staff;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    final emailText = _emailController.text.trim();
    final success = await employeeRepository.addEmployee(
      name: _nameController.text.trim(),
      email: emailText.isEmpty ? null : emailText,
      role: _selectedRole,
    );
    setState(() => _isAdding = false);

    if (!mounted) return;

    if (success) {
      _nameController.clear();
      _emailController.clear();
      setState(() => _selectedRole = EmployeeRole.staff);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.employee_added'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.add_error'.tr())),
      );
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.delete_employee_confirm_title'.tr()),
        content: Text('admin.delete_employee_confirm_message'
            .tr(namedArgs: {'name': employee.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await employeeRepository.deleteEmployee(employee.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.employee_deleted'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.error'.tr())),
      );
    }
  }

  Future<void> _editEmployee(Employee employee) async {
    final nameController = TextEditingController(text: employee.name);
    final emailController = TextEditingController(text: employee.email ?? '');
    var selectedRole = employee.role;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('admin.edit_employee'.tr()),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'admin.employee_name'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'offer.field_required'.tr() : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'admin.employee_email'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!v.contains('@')) return 'admin.employee_email_hint'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EmployeeRole>(
                    initialValue: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'admin.employee_role'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                    items: EmployeeRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(_getRoleName(role)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final emailText = emailController.text.trim();
    final success = await employeeRepository.updateEmployee(
      id: employee.id,
      name: nameController.text.trim(),
      email: emailText.isEmpty ? null : emailText,
      role: selectedRole,
    );

    nameController.dispose();
    emailController.dispose();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.employee_updated'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.error'.tr())),
      );
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() => _isReordering = true);
    final employee = _localEmployees.removeAt(oldIndex);
    _localEmployees.insert(newIndex, employee);
    
    await employeeRepository.reorderEmployees(_localEmployees);
    if (mounted) {
      setState(() => _isReordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        return StreamBuilder<List<Employee>>(
          stream: employeeRepository.watchEmployees(),
          builder: (context, snapshot) {
            if (snapshot.hasData && !_isReordering) {
              _localEmployees = List.from(snapshot.data!);
            }
            final employees = _localEmployees;

            if (isDesktop) {
              return _buildDesktopLayout(employees);
            } else if (isTablet) {
              return _buildTabletLayout(employees);
            } else {
              return _buildMobileLayout(employees);
            }
          },
        );
      },
    );
  }

  Widget _buildDesktopLayout(List<Employee> employees) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildEmployeeList(employees, compact: false),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: _buildAddForm(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(List<Employee> employees) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddForm(),
          const SizedBox(height: 24),
          _buildEmployeeList(employees, compact: false),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(List<Employee> employees) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddForm(),
          const SizedBox(height: 16),
          _buildEmployeeList(employees, compact: true),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'admin.add_employee'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'admin.employee_name'.tr(),
                  hintText: 'admin.employee_name_hint'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'offer.field_required'.tr() : null,
                enabled: !_isAdding,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'admin.employee_email'.tr(),
                  hintText: 'admin.employee_email_hint'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // Email is optional
                  if (!v.contains('@')) return 'admin.employee_email_hint'.tr();
                  return null;
                },
                enabled: !_isAdding,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EmployeeRole>(
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'admin.employee_role'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.badge),
                ),
                items: EmployeeRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(_getRoleName(role)),
                  );
                }).toList(),
                onChanged: _isAdding ? null : (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isAdding ? null : _addEmployee,
                icon: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text('common.add'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeList(List<Employee> employees, {required bool compact}) {
    if (employees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'admin.employees_title'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      onReorder: _onReorder,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return Card(
          key: ValueKey(employee.id),
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 16,
            vertical: 4,
          ),
          child: ListTile(
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            title: Text(employee.name),
            subtitle: Text(_getRoleName(employee.role)),
            onTap: () => _editEmployee(employee),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editEmployee(employee),
                  tooltip: 'common.edit'.tr(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteEmployee(employee),
                  tooltip: 'common.delete'.tr(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRoleName(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.leadingSupervisor:
        return 'admin.role_leading_supervisor'.tr();
      case EmployeeRole.supervisor:
        return 'admin.role_supervisor'.tr();
      case EmployeeRole.staff:
        return 'admin.role_staff'.tr();
    }
  }
}
