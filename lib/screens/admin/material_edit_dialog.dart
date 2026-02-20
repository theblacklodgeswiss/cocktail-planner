import 'package:flutter/material.dart';

import '../../models/material_item.dart';

/// Result from the material edit dialog.
typedef MaterialEditResult = ({
  String name,
  String unit,
  double price,
  String currency,
  String note,
  bool active,
  bool visible,
});

/// Shows a dialog for editing or creating a material item.
/// Returns the result if saved, or null if cancelled.
Future<MaterialEditResult?> showMaterialEditDialog(
  BuildContext context, {
  MaterialItem? item,
}) async {
  final nameController = TextEditingController(text: item?.name ?? '');
  final unitController = TextEditingController(text: item?.unit ?? '');
  final priceController = TextEditingController(
    text: item?.price.toString() ?? '0',
  );
  final currencyController = TextEditingController(
    text: item?.currency ?? 'CHF',
  );
  final noteController = TextEditingController(text: item?.note ?? '');
  bool activeValue = item?.active ?? true;
  bool visibleValue = item?.visible ?? true;

  final isNew = item == null;

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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                (
                  name: nameController.text.trim(),
                  unit: unitController.text.trim(),
                  price: double.tryParse(priceController.text) ?? 0,
                  currency: currencyController.text.trim(),
                  note: noteController.text.trim(),
                  active: activeValue,
                  visible: visibleValue,
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}
