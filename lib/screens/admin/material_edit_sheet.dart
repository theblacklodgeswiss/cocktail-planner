import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/material_item.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../utils/currency.dart';
import 'admin_widgets.dart';

/// Result from the material edit sheet.
typedef MaterialEditResult = ({
  String name,
  String unit,
  double price,
  String currency,
  String note,
  bool active,
  bool visible,
  String? category,
});

const materialCategories = ['supervisor', 'purchase', 'bring', 'other'];

/// Shows a sheet for editing or creating a material item.
///
/// [onSave] performs the actual (Firestore) write and returns whether it
/// succeeded. The sheet stays open with a spinner on the save button while
/// it is awaited and only closes after success; on failure it shows an
/// inline error so the user can retry.
///
/// Returns the saved result, or null if dismissed.
Future<MaterialEditResult?> showMaterialEditSheet(
  BuildContext context, {
  MaterialItem? item,
  required Future<bool> Function(MaterialEditResult result) onSave,
}) async {
  MaterialEditResult? saved;
  final ok = await showAppSheet<bool>(
    context,
    scrollable: false,
    builder: (_) => MaterialEditForm(
      item: item,
      onSave: (r) async {
        final success = await onSave(r);
        if (success) saved = r;
        return success;
      },
    ),
  );
  return ok == true ? saved : null;
}

/// Form content of the material sheet (7 inputs, 2 switches, stacked).
class MaterialEditForm extends StatefulWidget {
  const MaterialEditForm({super.key, this.item, required this.onSave});

  final MaterialItem? item;
  final Future<bool> Function(MaterialEditResult result) onSave;

  @override
  State<MaterialEditForm> createState() => _MaterialEditFormState();
}

class _MaterialEditFormState extends State<MaterialEditForm> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _unit = TextEditingController(text: widget.item?.unit ?? '');
  late final _price = TextEditingController(
    text: widget.item?.price.toString() ?? '0',
  );
  late final _currency = TextEditingController(
    text: widget.item?.currency ?? defaultCurrency.code,
  );
  late final _note = TextEditingController(text: widget.item?.note ?? '');
  late bool _active = widget.item?.active ?? true;
  late bool _visible = widget.item?.visible ?? true;
  late String? _category = widget.item?.category;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _price.dispose();
    _currency.dispose();
    _note.dispose();
    super.dispose();
  }

  String _categoryLabel(String c) => 'admin2.cat_$c'.tr();

  @override
  Widget build(BuildContext context) {
    return AdminFormSheet(
      title: widget.item == null
          ? 'admin2.new_material'.tr()
          : 'admin2.edit_material'.tr(),
      saveLabel: 'common.save'.tr(),
      errorText: 'admin2.save_error'.tr(),
      validate: () => _name.text.trim().isNotEmpty,
      onSubmit: () => widget.onSave((
        name: _name.text.trim(),
        unit: _unit.text.trim(),
        price: double.tryParse(_price.text) ?? 0,
        currency: _currency.text.trim(),
        note: _note.text.trim(),
        active: _active,
        visible: _visible,
        category: _category,
      )),
      fields: [
        TextField(
          key: const Key('material-name'),
          controller: _name,
          decoration: InputDecoration(labelText: 'admin2.f_name'.tr()),
        ),
        AdminFormSheet.gap,
        TextField(
          controller: _unit,
          decoration: InputDecoration(
            labelText: 'admin2.f_unit'.tr(),
            hintText: 'admin2.f_unit_hint'.tr(),
          ),
        ),
        AdminFormSheet.gap,
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'admin2.f_price'.tr()),
        ),
        AdminFormSheet.gap,
        TextField(
          controller: _currency,
          decoration: InputDecoration(labelText: 'admin2.f_currency'.tr()),
        ),
        AdminFormSheet.gap,
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'admin2.f_category'.tr(),
            hintText: 'admin2.f_category_hint'.tr(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('admin2.cat_none'.tr()),
            ),
            for (final c in materialCategories)
              DropdownMenuItem<String>(value: c, child: Text(_categoryLabel(c))),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        AdminFormSheet.gap,
        TextField(
          controller: _note,
          decoration: InputDecoration(
            labelText: 'admin2.f_note'.tr(),
            hintText: 'admin2.f_note_hint'.tr(),
          ),
        ),
        SwitchListTile(
          title: Text('admin2.f_active'.tr()),
          subtitle: Text('admin2.f_active_hint'.tr()),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: Text('admin2.f_visible'.tr()),
          subtitle: Text('admin2.f_visible_hint'.tr()),
          value: _visible,
          onChanged: (v) => setState(() => _visible = v),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
