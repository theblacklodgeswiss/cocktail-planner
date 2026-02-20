import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import 'materials_tab.dart';
import 'recipes_tab.dart';

/// Admin screen for managing inventory (materials, fixed values, recipes).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!authService.canManageUsers) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text('admin.title_short'.tr()),
        ),
        body: Center(
          child: Text('admin.access_denied'.tr()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('admin.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.inventory), text: 'admin.tab_materials'.tr()),
            Tab(icon: const Icon(Icons.build), text: 'admin.tab_fixed'.tr()),
            Tab(icon: const Icon(Icons.local_bar), text: 'admin.tab_recipes'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MaterialsTab(isFixedValue: false),
          MaterialsTab(isFixedValue: true),
          RecipesTab(),
        ],
      ),
    );
  }
}
