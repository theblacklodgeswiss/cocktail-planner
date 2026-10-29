import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/employee.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/pressable.dart';

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
    final p = AppPalette.of(context);
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
                  Icons.assignment_ind_outlined,
                  size: AppSize.metaIcon,
                  color: p.textSecondary,
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    'orders.assigned_employees'.tr(),
                    style: AppText.section.copyWith(color: p.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            if (employees.isEmpty)
              Text(
                'orders.no_employees_assigned'.tr(),
                style: AppText.body.copyWith(color: p.textSecondary),
              )
            else
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s4,
                children: [
                  for (final employee in employees)
                    _EmployeeChip(
                      name: employee.name,
                      selected: _selectedIds.contains(employee.name),
                      onTap: () => _toggleEmployee(employee.name),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _EmployeeChip extends StatelessWidget {
  const _EmployeeChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      selected: selected,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.minTap),
        child: Center(
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? p.primary : p.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: selected ? p.primary : p.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              child: Text(
                name,
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? p.onPrimary : p.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
