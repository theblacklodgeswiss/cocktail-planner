import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import 'material_edit_sheet.dart';
import 'material_logic.dart';
import 'materials_view.dart';

/// Data wrapper of the materials / fixed values page in the admin screen.
class MaterialsTab extends StatefulWidget {
  const MaterialsTab({
    super.key,
    required this.isFixedValue,
    required this.header,
  });

  final bool isFixedValue;

  /// Tab pills shown under the title.
  final Widget header;

  @override
  State<MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<MaterialsTab> {
  List<MaterialRecord> _items = [];
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final items = await adminRepository.getMaterialsWithIds(
        isFixedValue: widget.isFixedValue,
      );
      if (!mounted) return;
      setState(() {
        _items = sortMaterials(items, isFixedValue: widget.isFixedValue);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  Future<bool> _save(String? docId, MaterialEditResult result) async {
    final ok = docId == null
        ? await adminRepository.addMaterial(
            name: result.name,
            unit: result.unit,
            price: result.price,
            currency: result.currency,
            note: result.note,
            isFixedValue: widget.isFixedValue,
            active: result.active,
            visible: result.visible,
            category: result.category,
          )
        : await adminRepository.updateMaterial(
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
    if (ok) _loadItems();
    return ok;
  }

  Future<bool> _delete(String docId) async {
    final ok = await adminRepository.deleteMaterial(
      docId: docId,
      isFixedValue: widget.isFixedValue,
    );
    if (ok) _loadItems();
    return ok;
  }

  Future<void> _reorder(List<MaterialRecord> reordered) async {
    setState(() => _items = reordered);
    await adminRepository.updateFixedValueSortOrders(
      reordered.map((e) => e.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialsView(
      title: 'admin.title'.tr(),
      header: widget.header,
      isFixedValue: widget.isFixedValue,
      items: _items,
      loading: _isLoading,
      errorMessage: _failed ? 'admin2.load_error'.tr() : null,
      onRetry: _loadItems,
      onSave: _save,
      onDelete: _delete,
      onReorder: _reorder,
    );
  }
}
