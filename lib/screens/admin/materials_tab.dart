import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../models/material_item.dart';
import 'material_edit_dialog.dart';
import 'material_item_card.dart';

/// Tab for managing materials/fixed values in the admin screen.
class MaterialsTab extends StatefulWidget {
  const MaterialsTab({super.key, required this.isFixedValue});

  final bool isFixedValue;

  @override
  State<MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<MaterialsTab> {
  List<({String id, MaterialItem item})> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await adminRepository.getMaterialsWithIds(
      isFixedValue: widget.isFixedValue,
    );
    if (mounted) {
      setState(() {
        _items = _sortItems(items);
        _isLoading = false;
      });
    }
  }

  List<({String id, MaterialItem item})> _sortItems(
    List<({String id, MaterialItem item})> items,
  ) {
    if (widget.isFixedValue) {
      // Sort by manual sortOrder; fall back to name for unsorted items.
      return items
        ..sort((a, b) {
          final aOrder = a.item.sortOrder;
          final bOrder = b.item.sortOrder;
          if (aOrder != null && bOrder != null) return aOrder.compareTo(bOrder);
          if (aOrder != null) return -1;
          if (bOrder != null) return 1;
          return a.item.name.compareTo(b.item.name);
        });
    } else {
      return items..sort((a, b) => a.item.name.compareTo(b.item.name));
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final visible = _filteredItems;
    final newVisible = List.of(visible)
      ..removeAt(oldIndex)
      ..insert(newIndex, visible[oldIndex]);
    final hiddenItems = _items.where((i) => !i.item.visible).toList();
    setState(() {
      _items = [...newVisible, ...hiddenItems];
    });
    await adminRepository.updateFixedValueSortOrders(
      _items.map((e) => e.id).toList(),
    );
  }

  List<({String id, MaterialItem item})> get _filteredItems {
    var list =
        _showHidden ? _items : _items.where((i) => i.item.visible).toList();
    if (_searchQuery.isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list
        .where((i) =>
            i.item.name.toLowerCase().contains(query) ||
            i.item.note.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _showEditDialog({String? docId, MaterialItem? item}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await showMaterialEditDialog(context, item: item);

    if (result != null) {
      bool success;
      if (docId == null) {
        success = await adminRepository.addMaterial(
          name: result.name,
          unit: result.unit,
          price: result.price,
          currency: result.currency,
          note: result.note,
          isFixedValue: widget.isFixedValue,
          active: result.active,
          visible: result.visible,
          category: result.category,
        );
      } else {
        success = await adminRepository.updateMaterial(
          docId: docId,
          name: result.name,
          unit: result.unit,
          price: result.price,
          currency: result.currency,
          note: result.note,
          isFixedValue: widget.isFixedValue,
          active: result.active,
          visible: result.visible,
          category: result.category,
        );
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(success ? 'Gespeichert!' : 'Fehler beim Speichern')),
      );

      if (success) {
        _loadItems();
      }
    }
  }

  Future<void> _deleteItem(String docId, String name) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Artikel löschen?'),
        content: Text('"$name" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await adminRepository.deleteMaterial(
        docId: docId,
        isFixedValue: widget.isFixedValue,
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(success ? 'Gelöscht!' : 'Fehler beim Löschen')),
      );

      if (success) {
        _loadItems();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildSearchBar(),
        _buildListHeader(context),
        const SizedBox(height: 8),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Suchen...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildListHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredItems.length} Artikel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              if (_items.any((i) => !i.item.visible))
                TextButton.icon(
                  onPressed: () => setState(() => _showHidden = !_showHidden),
                  icon: Icon(
                      _showHidden ? Icons.visibility_off : Icons.visibility),
                  label: Text(
                      _showHidden ? 'Versteckte ausblenden' : 'Versteckte anzeigen'),
                ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _showEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Neu'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_filteredItems.isEmpty) {
      return const Center(child: Text('Keine Artikel gefunden'));
    }

    if (widget.isFixedValue && _searchQuery.isEmpty) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredItems.length,
        onReorder: _onReorder,
        itemBuilder: (context, index) {
          final record = _filteredItems[index];
          return MaterialItemCard(
            key: ValueKey(record.id),
            item: record.item,
            leading: const Icon(Icons.drag_handle),
            onEdit: () => _showEditDialog(docId: record.id, item: record.item),
            onDelete: () => _deleteItem(record.id, record.item.name),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final record = _filteredItems[index];
        return MaterialItemCard(
          key: ValueKey(record.id),
          item: record.item,
          onEdit: () => _showEditDialog(docId: record.id, item: record.item),
          onDelete: () => _deleteItem(record.id, record.item.name),
        );
      },
    );
  }
}
