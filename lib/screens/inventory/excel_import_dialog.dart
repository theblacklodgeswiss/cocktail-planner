import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../data/stock_repository.dart';
import '../../models/material_item.dart';
import '../../models/stock.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_import.dart';
import '../../services/voice_inventory_parser.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import 'rest_entry_sheet.dart';

/// Excel column headers C..H and the location each one defaults to. The
/// Excel column "Inthusan" is Tuji's.
const _excelColumnNames = [
  'Biri',
  'Inthusan',
  'Mario',
  'Biri',
  'Inthusan',
  'Mario',
];
const _defaultLocations = ['Biri', 'Tuji', 'Mario', 'Biri', 'Tuji', 'Mario'];
const _columnOrigins = [
  StockOrigin.order,
  StockOrigin.order,
  StockOrigin.order,
  StockOrigin.investment,
  StockOrigin.investment,
  StockOrigin.investment,
];

/// One-time import of the Excel Materialliste. Admin only.
Future<void> showExcelImportDialog(BuildContext context) {
  // NOTE: authService.isAdmin includes the super admin, but the Firestore
  // rules' isAdmin() does not. A super admin who is not also a rules-admin
  // passes this gate and the location/stock writes then fail. Known, no
  // behavior change on purpose.
  if (!authService.isAdmin) return Future.value();
  // Full-screen sheet; it cannot be closed while booking (PopScope).
  return showAppSheet<void>(
    context,
    full: true,
    builder: (_) => const ExcelImportDialog(),
  );
}

class _RowState {
  _RowState(this.row);

  final ImportRow row;
  String? materialId;
  String? materialName;
  bool skipped = false;

  bool get hasQuantities => row.cells.isNotEmpty;
  bool get active => !skipped && hasQuantities;
}

class ExcelImportDialog extends StatefulWidget {
  const ExcelImportDialog({super.key});

  @override
  State<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<ExcelImportDialog> {
  final _paste = TextEditingController();
  final _owners = <String, TextEditingController>{};

  bool _loading = false;
  bool _previewing = false;
  bool _saving = false;
  String? _error;
  String? _success;

  List<(String, MaterialItem)> _catalog = [];
  List<StorageLocation> _locations = [];
  List<String> _columnLocations = List.of(_defaultLocations);
  List<_RowState> _rows = [];

  // Survive a retry after a partial failure, so nothing is booked or created
  // twice.
  final Set<(int, int)> _booked = {};
  final Map<String, String> _createdLocationIds = {};

  @override
  void dispose() {
    _paste.dispose();
    for (final c in _owners.values) {
      c.dispose();
    }
    super.dispose();
  }

  StorageLocation? _existing(String name) {
    final wanted = name.trim().toLowerCase();
    for (final l in _locations) {
      if (l.name.trim().toLowerCase() == wanted) return l;
    }
    return null;
  }

  Future<void> _preview() async {
    if (_loading || _saving) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final catalog = await adminRepository.getMaterialsWithIds(
        isFixedValue: false,
      );
      final locations = await stockRepository.watchLocations().first;
      if (!mounted) return;
      _catalog = [for (final m in catalog) (m.id, m.item)];
      _locations = locations;
      _columnLocations = List.of(_defaultLocations);
      final parsed = parseInventoryPaste(
        _paste.text,
        columnLocations: _columnLocations,
        columnOrigins: _columnOrigins,
      );
      _rows = [
        for (final r in parsed)
          _RowState(r..candidates = matchCatalog(r.name, _catalog)),
      ];
      for (final s in _rows) {
        if (isConfident(s.row.candidates)) {
          s.materialId = s.row.candidates.first.materialId;
          s.materialName = s.row.candidates.first.name;
        }
      }
      _booked.clear();
      setState(() {
        _previewing = true;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Excel import preparation failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'excel_import.load_failed'.tr();
        });
      }
    }
  }

  Future<void> _pickAny(_RowState s) async {
    final picked = await showDialog<(String, MaterialItem)>(
      context: context,
      builder: (_) => CatalogPickerDialog(catalog: _catalog),
    );
    if (picked == null || !mounted) return;
    setState(() {
      s.materialId = picked.$1;
      s.materialName = picked.$2.name;
    });
  }

  Future<void> _createItem(_RowState s) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => NewItemDialog(initialName: s.row.name),
    );
    if (result == null || !mounted) return;
    final (name, unit) = result;
    final ok = await adminRepository.addMaterial(
      name: name,
      unit: unit,
      price: 0,
      currency: 'EUR',
      note: '',
      isFixedValue: false,
    );
    if (!mounted) return;
    // addMaterial returns no ID, so look the new item up by name.
    final fresh = ok
        ? await adminRepository.getMaterialsWithIds(isFixedValue: false)
        : const <({String id, MaterialItem item})>[];
    if (!mounted) return;
    final created = fresh.where((m) => m.item.name == name);
    if (created.isEmpty) {
      setState(() => _error = 'excel_import.create_failed'.tr());
      return;
    }
    setState(() {
      _catalog = [for (final m in fresh) (m.id, m.item)];
      s.materialId = created.first.id;
      s.materialName = name;
      _error = null;
    });
  }

  int get _movementCount =>
      _rows.where((s) => s.active).fold(0, (n, s) => n + s.row.cells.length);

  bool get _canImport =>
      !_saving &&
      _movementCount > 0 &&
      _rows.every((s) => !s.active || s.materialId != null);

  /// The import is meant to run once. If an earlier import exists, ask before
  /// booking everything a second time. Only checked on the first attempt (a
  /// retry after a partial failure continues the same import). Fails closed.
  Future<bool> _confirmRepeat() async {
    if (_booked.isNotEmpty || _createdLocationIds.isNotEmpty) return true;
    final bool exists;
    try {
      exists = await stockRepository.hasImportMovements();
    } catch (e) {
      debugPrint('Import check failed: $e');
      if (mounted) setState(() => _error = 'excel_import.failed'.tr());
      return false;
    }
    if (!exists) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('excel_import.repeat_title'.tr()),
        content: Text('excel_import.repeat_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('excel_import.repeat_confirm'.tr()),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _import() async {
    if (!_canImport) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    if (!await _confirmRepeat()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    try {
      // Create locations that are used by an active cell and do not exist.
      final used = <String>{
        for (final s in _rows)
          if (s.active)
            for (final c in s.row.cells) _columnLocations[c.column].trim(),
      };
      final ids = <String, String>{};
      for (final name in used) {
        final existing = _existing(name);
        if (existing != null) {
          ids[name] = existing.id;
          continue;
        }
        var id = _createdLocationIds[name];
        if (id == null) {
          final owner = _owners[name]?.text.trim() ?? '';
          final created = await stockRepository.createLocation(
            name,
            ownerEmail: owner.isEmpty ? null : owner.toLowerCase(),
          );
          id = created.id;
          _createdLocationIds[name] = id;
        }
        ids[name] = id;
      }

      var booked = 0;
      for (var i = 0; i < _rows.length; i++) {
        final s = _rows[i];
        if (!s.active) continue;
        for (final cell in s.row.cells) {
          if (_booked.contains((i, cell.column))) continue;
          await stockRepository.applyMovement(
            materialId: s.materialId!,
            materialName: s.materialName ?? s.row.name,
            locationId: ids[_columnLocations[cell.column].trim()]!,
            origin: _columnOrigins[cell.column],
            delta: cell.quantity,
            reason: 'import',
            note: s.row.note,
          );
          _booked.add((i, cell.column));
          booked++;
        }
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _previewing = false;
        _paste.clear();
        _rows = [];
        _booked.clear();
        _createdLocationIds.clear();
        _success = 'excel_import.done'.tr(namedArgs: {'count': '$booked'});
      });
    } catch (e) {
      debugPrint('Excel import failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'excel_import.failed'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopScope(
      canPop: !_saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'excel_import.title'.tr(),
              style: AppText.heroTitle.copyWith(color: p.text),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Expanded(child: _previewing ? _buildPreview() : _buildInput()),
          const SizedBox(height: AppSpace.s12),
          if (_previewing)
            PrimaryButton(
              label: 'excel_import.import'.tr(),
              loading: _saving,
              onPressed: _canImport ? _import : null,
            )
          else
            PrimaryButton(
              label: 'excel_import.preview'.tr(),
              loading: _loading,
              onPressed: _paste.text.trim().isEmpty ? null : _preview,
            ),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              if (_previewing)
                Expanded(
                  child: TextAction(
                    label: 'excel_import.back'.tr(),
                    onPressed: _saving || _booked.isNotEmpty
                        ? null
                        : () => setState(() => _previewing = false),
                  ),
                ),
              Expanded(
                child: TextAction(
                  label: 'common.close'.tr(),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _warning() {
    final p = AppPalette.of(context);
    return FloatingCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: AppSize.rowIcon,
            color: p.goldText,
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              'excel_import.warning'.tr(),
              style: AppText.body.copyWith(color: p.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _warning(),
          const SizedBox(height: 12),
          TextField(
            controller: _paste,
            minLines: 6,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'excel_import.paste_label'.tr(),
              hintText: 'excel_import.paste_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_success != null) ...[
            const SizedBox(height: 12),
            Text(
              _success!,
              style: AppText.body.copyWith(
                color: AppPalette.of(context).text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppText.body.copyWith(color: AppPalette.of(context).error),
            ),
          ],
        ],
      ),
    );
  }

  List<String> get _locationChoices {
    final names = <String>{
      for (final l in _locations) l.name,
      ..._defaultLocations,
    };
    return names.toList()..sort();
  }

  Widget _buildPreview() {
    final newNames = <String>{
      for (final n in _columnLocations)
        if (_existing(n) == null) n.trim(),
    };
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _warning(),
          const SizedBox(height: 12),
          Text(
            'excel_import.columns'.tr(),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (var col = 0; col < _columnLocations.length; col++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButtonFormField<String>(
                initialValue: _columnLocations[col],
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'excel_import.column_label'.tr(
                    namedArgs: {
                      'origin': 'rest.origin_${_columnOrigins[col].name}'.tr(),
                      'name': _excelColumnNames[col],
                    },
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final n in _locationChoices)
                    DropdownMenuItem(
                      value: n,
                      child: Text(
                        _existing(n) == null
                            ? 'excel_import.location_new'.tr(
                                namedArgs: {'name': n},
                              )
                            : n,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(
                        () =>
                            _columnLocations[col] = v ?? _columnLocations[col],
                      ),
              ),
            ),
          for (final name in newNames)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _owners.putIfAbsent(
                  name,
                  () => TextEditingController(),
                ),
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  helperText: _owners[name]!.text.trim().isEmpty
                      ? 'excel_import.owner_missing'.tr()
                      : null,
                  helperMaxLines: 3,
                  helperStyle: AppText.caption.copyWith(
                    color: AppPalette.of(context).goldText,
                  ),
                  labelText: 'excel_import.owner_for'.tr(
                    namedArgs: {'name': name},
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const Divider(),
          if (_rows.isEmpty) Text('excel_import.no_rows'.tr()),
          for (var i = 0; i < _rows.length; i++) _buildRow(_rows[i]),
          const SizedBox(height: 8),
          Text(
            'excel_import.summary'.tr(
              namedArgs: {
                'movements': '$_movementCount',
                'rows': '${_rows.where((s) => s.active).length}',
              },
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppText.body.copyWith(color: AppPalette.of(context).error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_RowState s) {
    final unresolved = s.active && s.materialId == null;
    return Card(
      key: ObjectKey(s),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.row.unit.isEmpty ? '' : '${s.row.unit}  '}${s.row.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (s.materialName != null)
              Text('-> ${s.materialName}', style: AppText.body),
            if (!s.hasQuantities)
              Text('excel_import.no_quantities'.tr(), style: AppText.caption)
            else ...[
              Text(
                [
                  for (final c in s.row.cells)
                    '${_columnLocations[c.column]}, '
                        '${'rest.origin_${_columnOrigins[c.column].name}'.tr()}: '
                        '${c.quantity.toString().replaceAll('.', ',')}',
                ].join('  |  '),
                style: AppText.caption,
              ),
            ],
            if (s.row.invalidColumns.isNotEmpty)
              Text(
                'excel_import.invalid_cells'.tr(
                  namedArgs: {
                    'columns': s.row.invalidColumns
                        .map(
                          (c) =>
                              '${'rest.origin_${_columnOrigins[c].name}'.tr()} '
                              '${_excelColumnNames[c]}',
                        )
                        .join(', '),
                  },
                ),
                style: AppText.caption.copyWith(
                  color: AppPalette.of(context).error,
                ),
              ),
            if (s.row.note != null)
              Text(s.row.note!, style: const TextStyle(fontSize: 12)),
            if (s.skipped)
              Text(
                'excel_import.skipped'.tr(),
                style: AppText.caption.copyWith(
                  color: AppPalette.of(context).goldText,
                ),
              ),
            if (unresolved) ...[
              const SizedBox(height: 4),
              Text(
                'excel_import.no_match'.tr(),
                style: AppText.caption.copyWith(
                  color: AppPalette.of(context).goldText,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in s.row.candidates)
                    ActionChip(
                      label: Text(c.name),
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              s.materialId = c.materialId;
                              s.materialName = c.name;
                            }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.search, size: 16),
                    label: Text('excel_import.pick_other'.tr()),
                    onPressed: _saving ? null : () => _pickAny(s),
                  ),
                  // /materials is writable by admins only.
                  if (authService.isAdmin)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text('excel_import.create_item'.tr()),
                      onPressed: _saving ? null : () => _createItem(s),
                    ),
                ],
              ),
            ] else if (s.active && s.materialId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          s.materialId = null;
                          s.materialName = null;
                        }),
                  child: Text('rest.change_item'.tr()),
                ),
              ),
            if (s.hasQuantities)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => s.skipped = !s.skipped),
                  child: Text(
                    s.skipped
                        ? 'excel_import.unskip'.tr()
                        : 'excel_import.skip'.tr(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
