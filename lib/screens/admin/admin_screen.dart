import 'package:flutter/material.dart';

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
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
          child: Text('Zugriff verweigert - nur für Admins'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventar verwalten'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory), text: 'Materialien'),
            Tab(icon: Icon(Icons.build), text: 'Verbrauch'),
            Tab(icon: Icon(Icons.local_bar), text: 'Rezepte'),
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
