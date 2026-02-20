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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    final success = await employeeRepository.addEmployee(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
    );
    setState(() => _isAdding = false);

    if (!mounted) return;

    if (success) {
      _nameController.clear();
      _emailController.clear();
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        return StreamBuilder<List<Employee>>(
          stream: employeeRepository.watchEmployees(),
          builder: (context, snapshot) {
            final employees = snapshot.data ?? [];

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
                  if (v?.trim().isEmpty ?? true) return 'offer.field_required'.tr();
                  if (!v!.contains('@')) return 'admin.employee_email_hint'.tr();
                  return null;
                },
                enabled: !_isAdding,
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

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 16,
            vertical: 4,
          ),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                employee.name.isNotEmpty
                    ? employee.name[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(employee.name),
            subtitle: Text(employee.email),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteEmployee(employee),
              tooltip: 'common.delete'.tr(),
            ),
          ),
        );
      },
    );
  }
}
