import 'package:flutter/material.dart';

/// Picks the home page for `/`: the staff home for employees and up,
/// otherwise the customer start (customers, guests, and users whose role is
/// still resolving). [initialStaff] is the role known at first build;
/// [staffChanges] reports later resolves (e.g. the role arriving after
/// sign-in). Repeated equal values do not rebuild.
///
/// Pure widget: the caller wires `authService`, so this stays VM-testable.
class HomeSwitch extends StatefulWidget {
  const HomeSwitch({
    super.key,
    required this.initialStaff,
    required this.staffChanges,
    required this.staff,
    required this.customer,
  });

  final bool initialStaff;
  final Stream<bool> staffChanges;
  final WidgetBuilder staff;
  final WidgetBuilder customer;

  @override
  State<HomeSwitch> createState() => _HomeSwitchState();
}

class _HomeSwitchState extends State<HomeSwitch> {
  // One subscription for the widget's life, not one per rebuild.
  late final Stream<bool> _changes = widget.staffChanges.distinct();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _changes,
      initialData: widget.initialStaff,
      builder: (context, snapshot) {
        final staff = snapshot.data ?? false;
        // Keyed so a role flip swaps the whole subtree (no stale state).
        return KeyedSubtree(
          key: ValueKey(staff),
          child: staff ? widget.staff(context) : widget.customer(context),
        );
      },
    );
  }
}
