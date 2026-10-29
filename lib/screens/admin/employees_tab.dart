import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/employee_repository.dart';
import '../../models/employee.dart';
import 'employees_view.dart';

/// Data wrapper of the employees page (stream + repository writes).
class EmployeesTab extends StatefulWidget {
  const EmployeesTab({super.key});

  @override
  State<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<EmployeesTab> {
  bool _isReordering = false;
  List<Employee> _local = [];
  late Stream<List<Employee>> _stream = employeeRepository.watchEmployees();

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    setState(() => _isReordering = true);
    final employee = _local.removeAt(oldIndex);
    _local.insert(newIndex, employee);
    await employeeRepository.reorderEmployees(_local);
    if (mounted) setState(() => _isReordering = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasData && !_isReordering) {
          _local = List.from(snapshot.data!);
        }
        return EmployeesView(
          employees: _local,
          loading: !snapshot.hasData && !snapshot.hasError,
          errorMessage: snapshot.hasError && !snapshot.hasData
              ? 'admin2.load_error'.tr()
              : null,
          onRetry: () => setState(() {
            _stream = employeeRepository.watchEmployees();
          }),
          onAdd: (name, email, role) => employeeRepository.addEmployee(
            name: name,
            email: email,
            role: role,
          ),
          onUpdate: (previous, name, email, role) =>
              employeeRepository.updateEmployee(
                previous: previous,
                name: name,
                email: email,
                role: role,
              ),
          onDelete: employeeRepository.deleteEmployee,
          onReorder: _onReorder,
          onRebuildAccess: employeeRepository.rebuildEmployeeAccessIndex,
        );
      },
    );
  }
}
