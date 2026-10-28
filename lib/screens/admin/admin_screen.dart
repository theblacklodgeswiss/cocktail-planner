import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../ui/widgets/pill_filter.dart';
import '../../widgets/admin_protected_screen.dart';
import 'materials_tab.dart';
import 'recipes_tab.dart';

enum AdminTab { materials, fixed, recipes }

/// Tab pills of the admin screen (materials / fixed values / recipes).
class AdminTabPills extends StatelessWidget {
  const AdminTabPills({super.key, required this.current, required this.onChanged});

  final AdminTab current;
  final ValueChanged<AdminTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return PillFilter<AdminTab>(
      value: current,
      onChanged: onChanged,
      options: [
        PillOption(AdminTab.materials, 'admin.tab_materials'.tr()),
        PillOption(AdminTab.fixed, 'admin.tab_fixed'.tr()),
        PillOption(AdminTab.recipes, 'admin.tab_recipes'.tr()),
      ],
    );
  }
}

/// Admin screen for managing inventory (materials, fixed values, recipes).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  AdminTab _tab = AdminTab.materials;

  @override
  Widget build(BuildContext context) {
    final pills = AdminTabPills(
      current: _tab,
      onChanged: (t) => setState(() => _tab = t),
    );
    return AdminProtectedScreen(
      child: switch (_tab) {
        AdminTab.materials => MaterialsTab(
          key: const ValueKey('materials'),
          isFixedValue: false,
          header: pills,
        ),
        AdminTab.fixed => MaterialsTab(
          key: const ValueKey('fixed'),
          isFixedValue: true,
          header: pills,
        ),
        AdminTab.recipes => RecipesTab(
          key: const ValueKey('recipes'),
          header: pills,
        ),
      },
    );
  }
}
