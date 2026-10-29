import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/stock.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/pill_filter.dart';
import '../../ui/widgets/pressable.dart';
import 'inventory_rows.dart';

/// One changed quantity of the article editor.
typedef QuantityChange = ({
  String locationId,
  StockOrigin origin,
  double quantity,
});

/// Changed values only: every cell of [edited] that differs from [row].
List<QuantityChange> changedQuantities(
  InventoryRow row,
  Map<String, Map<StockOrigin, double>> edited,
) {
  final changes = <QuantityChange>[];
  edited.forEach((locationId, cells) {
    cells.forEach((origin, value) {
      final old = row.perLocation[locationId]?[origin] ?? 0;
      if ((value - old).abs() > 1e-9) {
        changes.add((locationId: locationId, origin: origin, quantity: value));
      }
    });
  });
  return changes;
}

/// Text field look of the inventory sheets (rounded, filled).
InputDecoration inventoryFieldDecoration(
  BuildContext context, {
  String? label,
  String? error,
  String? helper,
}) {
  final p = AppPalette.of(context);
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    labelText: label,
    errorText: error,
    helperText: helper,
    helperMaxLines: 2,
    errorMaxLines: 2,
    filled: true,
    fillColor: p.surface,
    border: border(p.border),
    enabledBorder: border(p.border),
    focusedBorder: border(p.text),
  );
}

/// Title of an inventory sheet.
class InventorySheetTitle extends StatelessWidget {
  const InventorySheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: AppText.heroTitle.copyWith(color: AppPalette.of(context).text),
    ),
  );
}

/// "Artikel" sheet of one inventory row: per location the quantities
/// "Auftrag" and "Investition" as steppers (comma decimals), a note, and
/// "Speichern" (only changed values), "Verlauf" and "Entnehmen".
///
/// Pure widget: [onSave] gets the changed cells and the new note (null when
/// the note is unchanged); the caller books them. [onHistory] and [onTake]
/// are called after the sheet closed itself.
class InventoryArticleEditor extends StatefulWidget {
  const InventoryArticleEditor({
    super.key,
    required this.row,
    required this.locations,
    required this.originLabel,
    required this.onSave,
    required this.onHistory,
    required this.onTake,
  });

  final InventoryRow row;
  final List<StorageLocation> locations;
  final String Function(StockOrigin origin) originLabel;
  final Future<void> Function(List<QuantityChange> changes, String? note)
  onSave;
  final VoidCallback onHistory;
  final VoidCallback onTake;

  @override
  State<InventoryArticleEditor> createState() => _InventoryArticleEditorState();
}

class _InventoryArticleEditorState extends State<InventoryArticleEditor> {
  late final Map<String, Map<StockOrigin, TextEditingController>> _fields = {
    for (final l in widget.locations)
      l.id: {
        for (final o in StockOrigin.values)
          o: TextEditingController(
            text: formatQuantity(widget.row.perLocation[l.id]?[o] ?? 0),
          ),
      },
  };
  late final _note = TextEditingController(text: widget.row.note ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final cells in _fields.values) {
      for (final c in cells.values) {
        c.dispose();
      }
    }
    _note.dispose();
    super.dispose();
  }

  bool _valid(TextEditingController c) =>
      parseQuantity(c.text, allowZero: true) != null;

  Future<void> _save() async {
    final edited = <String, Map<StockOrigin, double>>{};
    for (final MapEntry(key: id, value: cells) in _fields.entries) {
      for (final MapEntry(key: origin, value: c) in cells.entries) {
        final v = parseQuantity(c.text, allowZero: true);
        if (v == null) {
          setState(() => _error = 'inventory.quantity_invalid'.tr());
          return;
        }
        (edited[id] ??= {})[origin] = v;
      }
    }
    final changes = changedQuantities(widget.row, edited);
    final note = _note.text.trim();
    final noteChanged = note != (widget.row.note ?? '').trim();
    if (changes.isEmpty && !noteChanged) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(changes, noteChanged ? note : null);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'inventory.save_failed'.tr();
        });
      }
    }
  }

  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final locations = widget.locations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InventorySheetTitle(widget.row.materialName),
        const SizedBox(height: AppSpace.s4),
        Text(
          locations.isEmpty
              ? 'inventory_list.no_locations'.tr()
              : 'inventory_list.editor_hint'.tr(),
          style: AppText.caption.copyWith(color: p.textSecondary),
        ),
        for (final l in locations) ...[
          const SizedBox(height: AppSpace.s12),
          Text(
            l.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.section.copyWith(color: p.text),
          ),
          for (final o in StockOrigin.values)
            QuantityStepper(
              key: ValueKey('stepper ${l.id} ${o.name}'),
              label: widget.originLabel(o),
              controller: _fields[l.id]![o]!,
              enabled: !_saving,
              onChanged: () => setState(() => _error = null),
            ),
        ],
        if (locations.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.body.copyWith(color: p.text),
            decoration: inventoryFieldDecoration(
              context,
              label: 'inventory.note'.tr(),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpace.s8),
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: AppText.body.copyWith(color: p.error)),
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        PrimaryButton(
          label: 'common.save'.tr(),
          loading: _saving,
          expand: true,
          onPressed:
              locations.isEmpty ||
                  _fields.values.any((m) => m.values.any((c) => !_valid(c)))
              ? null
              : _save,
        ),
        const SizedBox(height: AppSpace.s4),
        Row(
          children: [
            Expanded(
              child: TextAction(
                label: 'inventory.history'.tr(),
                onPressed: _saving ? null : () => _closeThen(widget.onHistory),
              ),
            ),
            Expanded(
              child: TextAction(
                label: 'inventory.take'.tr(),
                onPressed: _saving || locations.isEmpty
                    ? null
                    : () => _closeThen(widget.onTake),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Auftrag  [−] [ 2,5 ] [+]": one quantity with 44 px steppers (whole
/// steps, never below 0) and a comma-decimal field.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool enabled;

  void _step(double by) {
    final current = parseQuantity(controller.text, allowZero: true) ?? 0;
    final next = current + by < 0 ? 0.0 : current + by;
    controller.text = formatQuantity(next);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final invalid = parseQuantity(controller.text, allowZero: true) == null;
    Widget step(IconData icon, String semantic, double by) => Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: semantic,
      onTap: enabled ? () => _step(by) : null,
      child: SizedBox.square(
        dimension: AppSize.minTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
          child: Icon(
            icon,
            size: AppSize.rowIcon,
            color: enabled ? p.text : p.disabled,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(color: p.textSecondary),
            ),
          ),
          step(
            Icons.remove,
            'inventory_list.decrease'.tr(namedArgs: {'label': label}),
            -1,
          ),
          const SizedBox(width: AppSpace.s4),
          SizedBox(
            width: AppSize.quantityField + AppSpace.s24,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => onChanged(),
              style: AppText.number.copyWith(color: invalid ? p.error : p.text),
              decoration: inventoryFieldDecoration(context).copyWith(
                isDense: true,
                constraints: const BoxConstraints(minHeight: AppSize.minTap),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s8,
                ),
                enabledBorder: invalid
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        borderSide: BorderSide(color: p.error),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s4),
          step(
            Icons.add,
            'inventory_list.increase'.tr(namedArgs: {'label': label}),
            1,
          ),
        ],
      ),
    );
  }
}

/// "Entnehmen": takes an amount out of one location and origin. More than
/// is available is rejected. [onTake] books it (negative movement).
class InventoryTakeSheet extends StatefulWidget {
  const InventoryTakeSheet({
    super.key,
    required this.row,
    required this.locations,
    required this.originLabel,
    required this.onTake,
  });

  final InventoryRow row;
  final List<StorageLocation> locations;
  final String Function(StockOrigin origin) originLabel;
  final Future<void> Function(
    String locationId,
    StockOrigin origin,
    double amount,
  )
  onTake;

  @override
  State<InventoryTakeSheet> createState() => _InventoryTakeSheetState();
}

class _InventoryTakeSheetState extends State<InventoryTakeSheet> {
  final _controller = TextEditingController();
  late String _locationId = _initialLocation();
  StockOrigin _origin = StockOrigin.order;
  bool _saving = false;
  String? _error;

  /// The first location that has stock, else the first one.
  String _initialLocation() {
    for (final l in widget.locations) {
      final cells = widget.row.perLocation[l.id];
      if (cells != null && cells.values.any((q) => q > 0)) return l.id;
    }
    return widget.locations.first.id;
  }

  double get _available => widget.row.perLocation[_locationId]?[_origin] ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    final value = parseQuantity(_controller.text, allowZero: false);
    if (value == null) {
      setState(() => _error = 'inventory.quantity_invalid'.tr());
      return;
    }
    if (value > _available + 1e-9) {
      setState(
        () => _error = 'inventory.only_available'.tr(
          namedArgs: {'quantity': formatQuantity(_available)},
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onTake(_locationId, _origin, value);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'inventory.save_failed'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InventorySheetTitle(
          'inventory_list.take_title'.tr(
            namedArgs: {'name': widget.row.materialName},
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        if (widget.locations.length > 1) ...[
          PillFilter<String>(
            value: _locationId,
            onChanged: (id) => setState(() {
              _locationId = id;
              _error = null;
            }),
            options: [
              for (final l in widget.locations) PillOption(l.id, l.name),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
        ],
        PillFilter<StockOrigin>(
          value: _origin,
          onChanged: (o) => setState(() {
            _origin = o;
            _error = null;
          }),
          options: [
            for (final o in StockOrigin.values)
              PillOption(o, widget.originLabel(o)),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => _saving ? null : _take(),
          style: AppText.section.copyWith(color: p.text),
          decoration: inventoryFieldDecoration(
            context,
            label: 'inventory.take_amount'.tr(),
            helper: 'inventory.only_available'.tr(
              namedArgs: {'quantity': formatQuantity(_available)},
            ),
            error: _error,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        PrimaryButton(
          label: 'inventory.take'.tr(),
          loading: _saving,
          expand: true,
          onPressed: _take,
        ),
        const SizedBox(height: AppSpace.s4),
        TextAction(
          label: 'common.cancel'.tr(),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
