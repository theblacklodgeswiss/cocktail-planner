import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/employee.dart';

/// Widget for assigning employees to an order with multi-select chips
class EmployeeAssignmentWidget extends StatefulWidget {
  const EmployeeAssignmentWidget({
    super.key,
    required this.assignedEmployeeIds,
    required this.onAssignmentChanged,
    required this.watchEmployees,
  });

  final List<String> assignedEmployeeIds;
  final Function(List<String>) onAssignmentChanged;

  /// `employeeRepository.watchEmployees()` (via OrderDetailServices).
  final Stream<List<Employee>> Function() watchEmployees;

  @override
  State<EmployeeAssignmentWidget> createState() =>
      _EmployeeAssignmentWidgetState();
}

class _EmployeeAssignmentWidgetState extends State<EmployeeAssignmentWidget> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.assignedEmployeeIds);
  }

  @override
  void didUpdateWidget(EmployeeAssignmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignedEmployeeIds != widget.assignedEmployeeIds) {
      _selectedIds = Set.from(widget.assignedEmployeeIds);
    }
  }

  void _toggleEmployee(String employeeId) {
    setState(() {
      if (_selectedIds.contains(employeeId)) {
        _selectedIds.remove(employeeId);
      } else {
        _selectedIds.add(employeeId);
      }
    });
    widget.onAssignmentChanged(_selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: widget.watchEmployees(),
      builder: (context, snapshot) {
        final employees = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_ind,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'orders.assigned_employees'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (employees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'orders.no_employees_assigned'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 400;
                  return Wrap(
                    spacing: isSmall ? 6 : 8,
                    runSpacing: isSmall ? 6 : 8,
                    children: employees.map((employee) {
                      final isSelected = _selectedIds.contains(employee.name);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          employee.name,
                          style: TextStyle(fontSize: isSmall ? 12 : 14),
                        ),
                        avatar: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          child: Text(
                            employee.name.isNotEmpty
                                ? employee.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: isSmall ? 10 : 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        onSelected: (_) => _toggleEmployee(employee.name),
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
