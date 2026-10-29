import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/states.dart';
import 'admin_widgets.dart';
import 'material_edit_sheet.dart';
import 'material_logic.dart';

/// Pure list of materials / fixed values: search, hidden toggle, FloatingCard
/// rows, add via FAB, edit in a sheet, delete after a confirm sheet. Data and
/// writes are injected.
class MaterialsView extends StatefulWidget {
  const MaterialsView({
    super.key,
    required this.title,
    required this.header,
    required this.isFixedValue,
    required this.items,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.onSave,
    required this.onDelete,
    required this.onReorder,
  });

  final String title;
  final Widget header;
  final bool isFixedValue;
  final List<MaterialRecord> items;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onRetry;

  /// [docId] is null when creating.
  final Future<bool> Function(String? docId, MaterialEditResult result) onSave;
  final Future<bool> Function(String docId) onDelete;

  /// Full new order (ids), fixed values only.
  final Future<void> Function(List<MaterialRecord> reordered) onReorder;

  @override
  State<MaterialsView> createState() => _MaterialsViewState();
}

class _MaterialsViewState extends State<MaterialsView> {
  String _query = '';
  bool _showHidden = false;

  List<MaterialRecord> get _filtered =>
      filterMaterials(widget.items, query: _query, showHidden: _showHidden);

  Future<void> _edit({String? docId, MaterialRecord? record}) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showMaterialEditSheet(
      context,
      item: record?.item,
      onSave: (r) => widget.onSave(docId, r),
    );
    if (result != null) {
      messenger.showSnackBar(SnackBar(content: Text('admin2.saved'.tr())));
    }
  }

  Future<void> _delete(MaterialRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmSheet(
      context,
      title: 'admin2.delete_material_title'.tr(),
      body: 'admin2.delete_body'.tr(args: [record.item.name]),
      confirmLabel: 'common.delete'.tr(),
      destructive: true,
      errorText: 'admin2.delete_error'.tr(),
      confirmAction: () async {
        if (!await widget.onDelete(record.id)) throw StateError('delete failed');
      },
    );
    if (!ok) return;
    messenger.showSnackBar(SnackBar(content: Text('admin2.deleted'.tr())));
  }

  Future<void> _reorder(int oldIndex, int newIndex) => widget.onReorder(
    reorderMaterials(widget.items, _filtered, oldIndex, newIndex),
  );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final filtered = _filtered;
    final hasHidden = widget.items.any((i) => !i.item.visible);
    final reorderable = widget.isFixedValue && _query.isEmpty;
    return AdminPage(
      title: widget.title,
      loading: widget.loading,
      errorMessage: widget.errorMessage,
      onRetry: widget.onRetry,
      onAdd: () => _edit(),
      addLabel: 'admin2.new_material'.tr(),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.header,
          const SizedBox(height: AppSpace.s8),
          SearchPill(onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: AppSpace.s8),
          CountLine(
            text: 'admin2.materials_count'.tr(args: ['${filtered.length}']),
            trailing: hasHidden
                ? TextAction(
                    label: _showHidden
                        ? 'admin2.hide_hidden'.tr()
                        : 'admin2.show_hidden'.tr(),
                    onPressed: () => setState(() => _showHidden = !_showHidden),
                  )
                : null,
          ),
        ],
      ),
      slivers: [
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'admin2.none_materials'.tr(),
            ),
          )
        else
          AdminSliverList(
            count: filtered.length,
            idAt: (i) => filtered[i].id,
            onReorder: reorderable ? _reorder : null,
            itemBuilder: (context, i, handle) {
              final r = filtered[i];
              final item = r.item;
              final category = item.category;
              return AdminRowCard(
                title: item.name,
                subtitle: [
                  item.unit,
                  '${item.price.toStringAsFixed(2)} ${item.currency}',
                  if (item.note.isNotEmpty) item.note,
                ].join(' • '),
                dimmed: !item.active || !item.visible,
                leading: handle,
                onTap: () => _edit(docId: r.id, record: r),
                extra: [
                  if (category != null ||
                      !item.active ||
                      !item.visible)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s4),
                      child: Wrap(
                        spacing: AppSpace.s4,
                        runSpacing: AppSpace.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (category != null)
                            MiniPill(
                              materialCategories.contains(category)
                                  ? 'admin2.chip_$category'.tr()
                                  : category,
                            ),
                          if (!item.active)
                            Semantics(
                              label: 'admin2.inactive_tip'.tr(),
                              child: Icon(
                                Icons.block,
                                size: AppSize.metaIcon,
                                color: p.textSecondary,
                              ),
                            ),
                          if (!item.visible)
                            Semantics(
                              label: 'admin2.hidden_tip'.tr(),
                              child: Icon(
                                Icons.visibility_off,
                                size: AppSize.metaIcon,
                                color: p.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                trailing: [
                  RowIconButton(
                    icon: Icons.delete_outline,
                    label: 'common.delete'.tr(),
                    destructive: true,
                    onPressed: () => _delete(r),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
