import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../data/order_repository.dart';
import '../../data/stock_repository.dart';
import '../../models/material_item.dart';
import '../../models/order.dart';
import '../../models/stock.dart';
import '../../services/auth_service.dart';
import '../../services/speech_input.dart';
import '../../services/voice_inventory_parser.dart';
import 'location_prompt_dialog.dart';
import 'rest_lines.dart';

/// Asks what is left over after an order and books it into the stock.
/// Returns true if the rest was saved. Skipping or cancelling books nothing.
Future<bool> showRestEntrySheet(
  BuildContext context, {
  required SavedOrder order,
}) async {
  if (!authService.isEmployeeOrHigher) return false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _RestEntrySheet(order: order),
  );
  return saved == true;
}

String _formatQuantity(double q) {
  final text = q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
  return text.replaceAll('.', ',');
}

double? _parseQuantity(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return null;
  }
  return value;
}

class _RestEntrySheet extends StatefulWidget {
  const _RestEntrySheet({required this.order});

  final SavedOrder order;

  @override
  State<_RestEntrySheet> createState() => _RestEntrySheetState();
}

class _RestEntrySheetState extends State<_RestEntrySheet> {
  final _textController = TextEditingController();
  final SpeechInput _speech = createSpeechInput();
  StreamSubscription<String>? _speechSub;
  bool _listening = false;
  String? _micError;

  bool _loading = false;
  bool _confirming = false;
  bool _saving = false;
  String? _saveError;

  late List<(String, MaterialItem)> _catalog;
  late List<StorageLocation> _locations;
  late StorageLocation _defaultLocation;
  List<RestLine> _lines = [];
  // Lines already booked, kept so a retry after a partial failure never
  // books them twice.
  final Set<RestLine> _booked = {};

  @override
  void dispose() {
    _speechSub?.cancel();
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (!_speech.supported) {
      setState(() => _micError = 'rest.mic_unsupported'.tr());
      return;
    }
    setState(() {
      _micError = null;
      _listening = true;
    });
    _speechSub = _speech.listen().listen(
      (text) {
        if (!mounted) return;
        setState(() => _textController.text = text);
      },
      onError: (Object e) {
        if (!mounted) return;
        final code = e is SpeechInputException ? e.code : '';
        setState(() {
          _listening = false;
          _micError = switch (code) {
            'unsupported' => 'rest.mic_unsupported'.tr(),
            'not-allowed' => 'rest.mic_denied'.tr(),
            _ => 'rest.mic_failed'.tr(),
          };
        });
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  Future<void> _skip() async {
    final count = _booked.length;
    if (!shouldMarkRecordedOnClose(count)) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    final ok = await orderRepository.updateOrder(widget.order.id, {
      'restRecorded': true,
    });
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _saveError = 'rest.mark_failed'.tr();
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'rest.partial_closed'.tr(namedArgs: {'count': '$count'}),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _continue() async {
    if (_loading) return;
    if (_listening) await _speech.stop();
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final location = await ensureOwnLocation(context);
      if (location == null || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final catalog = await adminRepository.getMaterialsWithIds(
        isFixedValue: false,
      );
      final locations = await stockRepository.watchLocations().first;
      if (!mounted) return;
      _defaultLocation = location;
      _catalog = [for (final m in catalog) (m.id, m.item)];
      _locations = locations;
      setState(() {
        _lines = buildRestLines(
          parseRestText(_textController.text),
          _catalog,
          _locations,
          _defaultLocation,
        );
        _confirming = true;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Rest entry preparation failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _micError = 'rest.load_failed'.tr();
        });
      }
    }
  }

  void _addManualLine() {
    setState(() {
      _lines.add(
        RestLine(
          parsed: const ParsedLine(quantity: 1, spokenName: ''),
          candidates: const [],
          location: _defaultLocation,
          origin: StockOrigin.order,
          quantity: 1,
        ),
      );
    });
  }

  Future<void> _pickAnyItem(RestLine line) async {
    final picked = await showDialog<(String, MaterialItem)>(
      context: context,
      builder: (_) => _CatalogPickerDialog(catalog: _catalog),
    );
    if (picked == null || !mounted) return;
    setState(() {
      line.chosenMaterialId = picked.$1;
      line.chosenMaterialName = picked.$2.name;
    });
  }

  Future<void> _createItem(RestLine line) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _NewItemDialog(initialName: line.parsed.spokenName),
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
    if (!ok) {
      setState(() => _saveError = 'rest.create_failed'.tr());
      return;
    }
    // addMaterial returns no ID, so look the new item up by name.
    final fresh = await adminRepository.getMaterialsWithIds(
      isFixedValue: false,
    );
    if (!mounted) return;
    final created = fresh.where((m) => m.item.name == name);
    if (created.isEmpty) {
      setState(() => _saveError = 'rest.create_failed'.tr());
      return;
    }
    setState(() {
      _catalog = [for (final m in fresh) (m.id, m.item)];
      line.chosenMaterialId = created.first.id;
      line.chosenMaterialName = name;
      _saveError = null;
    });
  }

  bool get _canSave =>
      !_saving &&
      _lines.isNotEmpty &&
      _lines.every((l) => l.chosenMaterialId != null && l.quantity > 0);

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      for (final line in _lines) {
        if (_booked.contains(line)) continue;
        await stockRepository.applyMovement(
          materialId: line.chosenMaterialId!,
          materialName: line.chosenMaterialName ?? line.parsed.spokenName,
          locationId: line.location.id,
          origin: line.origin,
          delta: line.quantity,
          reason: 'rest',
          orderId: widget.order.id,
        );
        _booked.add(line);
      }
      final ok = await orderRepository.updateOrder(widget.order.id, {
        'restRecorded': true,
      });
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _saving = false;
          _saveError = 'rest.mark_failed'.tr();
        });
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Rest booking failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'rest.save_failed'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('rest.title'.tr()),
          actions: [
            TextButton(
              onPressed: _saving ? null : _skip,
              child: Text('rest.skip'.tr()),
            ),
          ],
        ),
        body: _confirming ? _buildConfirm() : _buildInput(),
      ),
    );
  }

  Widget _buildInput() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('rest.intro'.tr()),
        const SizedBox(height: 16),
        TextField(
          controller: _textController,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'rest.text_label'.tr(),
            hintText: 'rest.text_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _toggleMic,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(
                _listening ? 'rest.mic_stop'.tr() : 'rest.mic_start'.tr(),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _loading ? null : _continue,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('rest.continue'.tr()),
            ),
          ],
        ),
        if (_micError != null) ...[
          const SizedBox(height: 12),
          Text(_micError!, style: const TextStyle(color: Colors.orange)),
        ],
      ],
    );
  }

  Widget _buildConfirm() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Fragments without number or name are dropped by the parser,
              // so the raw text stays visible to reveal anything missing.
              Text(
                'rest.heard'.tr(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _textController.text.trim().isEmpty
                    ? '-'
                    : _textController.text.trim(),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 4),
              Text(
                'rest.check_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_lines.isEmpty) Text('rest.no_lines'.tr()),
              for (final line in _lines) _buildLine(line),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _addManualLine,
                  icon: const Icon(Icons.add),
                  label: Text('rest.add_line'.tr()),
                ),
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _saveError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: _saving || mustLockRest(_booked.length)
                      ? null
                      : () => setState(() => _confirming = false),
                  child: Text('rest.back'.tr()),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('common.save'.tr()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLine(RestLine line) {
    final booked = _booked.contains(line);
    final unresolvedMaterial = line.chosenMaterialId == null;
    return Card(
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: _formatQuantity(line.quantity),
                    enabled: !booked && !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'rest.quantity'.tr(),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(
                      () => line.quantity = _parseQuantity(v) ?? 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    line.chosenMaterialName ??
                        (line.parsed.spokenName.isEmpty
                            ? 'rest.item_missing'.tr()
                            : '"${line.parsed.spokenName}"'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: unresolvedMaterial ? Colors.orange : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'common.delete'.tr(),
                  icon: const Icon(Icons.close),
                  onPressed: booked || _saving
                      ? null
                      : () => setState(() => _lines.remove(line)),
                ),
              ],
            ),
            if (line.quantity <= 0)
              Text(
                'rest.quantity_invalid'.tr(),
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            if (unresolvedMaterial && !booked) ...[
              const SizedBox(height: 8),
              Text(
                'rest.pick_item'.tr(),
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in line.candidates)
                    ActionChip(
                      label: Text(c.name),
                      onPressed: () => setState(() {
                        line.chosenMaterialId = c.materialId;
                        line.chosenMaterialName = c.name;
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.search, size: 16),
                    label: Text('rest.pick_other'.tr()),
                    onPressed: () => _pickAnyItem(line),
                  ),
                  // /materials is writable by admins only.
                  if (authService.isAdmin)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text('rest.create_item'.tr()),
                      onPressed: () => _createItem(line),
                    ),
                ],
              ),
              if (!authService.isAdmin)
                Text(
                  'rest.ask_admin'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
            ] else if (!booked)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          line.chosenMaterialId = null;
                          line.chosenMaterialName = null;
                        }),
                  child: Text('rest.change_item'.tr()),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.location.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'rest.location'.tr(),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final l in _locations)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: booked || _saving
                        ? null
                        : (id) => setState(() {
                            line.location = _locations.firstWhere(
                              (l) => l.id == id,
                            );
                            line.locationUnresolved = false;
                          }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<StockOrigin>(
                    initialValue: line.origin,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'rest.origin'.tr(),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final o in StockOrigin.values)
                        DropdownMenuItem(
                          value: o,
                          child: Text('rest.origin_${o.name}'.tr()),
                        ),
                    ],
                    onChanged: booked || _saving
                        ? null
                        : (o) => setState(() => line.origin = o ?? line.origin),
                  ),
                ),
              ],
            ),
            if (line.locationUnresolved)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'rest.location_unknown'.tr(
                    namedArgs: {'name': line.parsed.locationHint ?? ''},
                  ),
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            if (booked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'rest.booked'.tr(),
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CatalogPickerDialog extends StatefulWidget {
  const _CatalogPickerDialog({required this.catalog});

  final List<(String, MaterialItem)> catalog;

  @override
  State<_CatalogPickerDialog> createState() => _CatalogPickerDialogState();
}

class _CatalogPickerDialogState extends State<_CatalogPickerDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.catalog
        .where((e) => e.$2.name.toLowerCase().contains(_filter.toLowerCase()))
        .toList()
      ..sort((a, b) => a.$2.name.compareTo(b.$2.name));
    return AlertDialog(
      title: Text('rest.pick_other'.tr()),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'rest.search'.tr(),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final e in items)
                    ListTile(
                      title: Text(e.$2.name),
                      onTap: () => Navigator.of(context).pop(e),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
      ],
    );
  }
}

class _NewItemDialog extends StatefulWidget {
  const _NewItemDialog({required this.initialName});

  final String initialName;

  @override
  State<_NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<_NewItemDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  final _unit = TextEditingController(text: 'Fl.');

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final unit = _unit.text.trim();
    if (name.isEmpty || unit.isEmpty) return;
    Navigator.of(context).pop((name, unit));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('rest.create_item'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'rest.item_name'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unit,
            decoration: InputDecoration(
              labelText: 'rest.item_unit'.tr(),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(onPressed: _submit, child: Text('common.save'.tr())),
      ],
    );
  }
}
