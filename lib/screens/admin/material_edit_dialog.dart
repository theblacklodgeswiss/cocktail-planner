import 'package:flutter/material.dart';

import '../../models/material_item.dart';
import '../../utils/currency.dart';

/// Result from the material edit dialog.
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

/// Shows a dialog for editing or creating a material item.
///
/// [onSave] performs the actual (Firestore) write and should return whether
/// it succeeded. The dialog stays open with a spinner on the Save button
/// while [onSave] is awaited, and only closes after it resolves
/// successfully; on failure it stays open and shows an inline error so the
/// user can retry.
///
/// Returns the saved result if saved, or null if cancelled.
Future<MaterialEditResult?> showMaterialEditDialog(
  BuildContext context, {
  MaterialItem? item,
  required Future<bool> Function(MaterialEditResult result) onSave,
}) async {
  final nameController = TextEditingController(text: item?.name ?? '');
  final unitController = TextEditingController(text: item?.unit ?? '');
  final priceController = TextEditingController(
    text: item?.price.toString() ?? '0',
  );
  final currencyController = TextEditingController(
    text: item?.currency ?? defaultCurrency.code,
  );
  final noteController = TextEditingController(text: item?.note ?? '');
  bool activeValue = item?.active ?? true;
  bool visibleValue = item?.visible ?? true;
  String? categoryValue = item?.category;

  final isNew = item == null;
  var saving = false;
  String? error;

  const categories = [
    (value: 'supervisor', label: 'Supervisor/Barkeeper'),
    (value: 'purchase', label: 'Zu kaufen'),
    (value: 'bring', label: 'Mitbringen'),
    (value: 'other', label: 'Sonstige'),
  ];

  return showDialog<MaterialEditResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(isNew ? 'Neuer Artikel' : 'Artikel bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Einheit',
                        hintText: 'z.B. 0.7L, Stk',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Preis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: currencyController,
                      decoration: const InputDecoration(
                        labelText: 'Währung',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryValue,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  hintText: 'Wähle eine Kategorie',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Keine Kategorie'),
                  ),
                  ...categories.map(
                    (cat) => DropdownMenuItem<String>(
                      value: cat.value,
                      child: Text(cat.label),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => categoryValue = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Bemerkung',
                  hintText: 'z.B. Lieferant',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Aktiv'),
                subtitle: const Text('In Einkaufsliste einschliessen'),
                value: activeValue,
                onChanged: (v) => setDialogState(() => activeValue = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Sichtbar'),
                subtitle: const Text('In Inventarliste anzeigen'),
                value: visibleValue,
                onChanged: (v) => setDialogState(() => visibleValue = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (nameController.text.trim().isEmpty) return;
                    final result = (
                      name: nameController.text.trim(),
                      unit: unitController.text.trim(),
                      price: double.tryParse(priceController.text) ?? 0,
                      currency: currencyController.text.trim(),
                      note: noteController.text.trim(),
                      active: activeValue,
                      visible: visibleValue,
                      category: categoryValue,
                    );
                    setDialogState(() {
                      saving = true;
                      error = null;
                    });
                    final success = await onSave(result);
                    if (success) {
                      if (ctx.mounted) Navigator.pop(ctx, result);
                    } else {
                      setDialogState(() {
                        saving = false;
                        error = 'Fehler beim Speichern';
                      });
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}
