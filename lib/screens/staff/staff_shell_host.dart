import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/staff_scaffold.dart';
import '../../ui/widgets/staff_tab_bar.dart';

/// Branch order of the staff shell route (see app_routes.dart).
const staffBranchTabs = [StaffTab.orders, StaffTab.inventory, StaffTab.more];

/// Wires [StaffShell] to go_router's [StatefulNavigationShell] and to the
/// user's role: staff (role resolved, employee or higher) see the bar and
/// the "+"; everyone else sees the branch content alone (e.g. the customer
/// start at `/`). Follows role changes like the home switch at `/`.
///
/// Pure widget: the app passes `authService` through [isStaff] and
/// [staffChanges], so it stays VM-testable.
class StaffShellHost extends StatefulWidget {
  const StaffShellHost({
    super.key,
    required this.shell,
    required this.isStaff,
    required this.staffChanges,
  });

  final StatefulNavigationShell shell;

  /// Current role, read when the host is first built.
  final bool Function() isStaff;

  /// Later role resolves (true: staff). Equal repeats do not rebuild.
  final Stream<bool> staffChanges;

  @override
  State<StaffShellHost> createState() => _StaffShellHostState();
}

class _StaffShellHostState extends State<StaffShellHost> {
  // One subscription for the widget's life; equal values do not rebuild.
  late final Stream<bool> _staff = widget.staffChanges.distinct();
  late final bool _initial = widget.isStaff();

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    return StreamBuilder<bool>(
      stream: _staff,
      initialData: _initial,
      builder: (context, snapshot) => StaffShell(
        showChrome: snapshot.data ?? false,
        current: staffBranchTabs[shell.currentIndex],
        onSwitch: (tab) => shell.goBranch(staffBranchTabs.indexOf(tab)),
        onNewOrder: () => context.push(staffNewOrderRoute),
        child: shell,
      ),
    );
  }
}
