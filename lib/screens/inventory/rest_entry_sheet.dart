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
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/pressable.dart';
import 'inventory_rows.dart';
import 'location_prompt_dialog.dart';
import 'rest_lines.dart';

/// Asks what is left over after an order and books it into the stock.
/// Returns true if the rest was saved. Skipping or cancelling books nothing.
Future<bool> showRestEntrySheet(
  BuildContext context, {
  required SavedOrder order,
  RestEntryServices services = const RestEntryServices(),
}) async {
  if (!services.canRecord()) return false;
  // Full-screen sheet. Closing it by drag or tap outside runs through the
  // sheet's PopScope, i.e. the same path as "Überspringen".
  final saved = await showAppSheet<bool>(
    context,
    full: true,
    builder: (_) => RestEntrySheet(orderId: order.id, services: services),
  );
  return saved == true;
}

/// Standalone stock capture from the inventory page: the same voice/text
/// flow as [showRestEntrySheet], without an order. Books with reason
/// `manual` and no order id, and never touches an order. A mode toggle
/// chooses between adding the quantities ("Dazu") and setting the stock to
/// the counted quantities ("Zählung"). Returns true if anything was booked.
Future<bool> showStockCaptureSheet(
  BuildContext context, {
  RestEntryServices services = const RestEntryServices(),
}) async {
  if (!services.canRecord()) return false;
  final saved = await showAppSheet<bool>(
    context,
    full: true,
    builder: (_) => RestEntrySheet(services: services),
  );
  return saved == true;
}

typedef BookMovement =
    Future<void> Function({
      required String materialId,
      required String materialName,
      required String locationId,
      required StockOrigin origin,
      required double delta,
      required String reason,
      String? orderId,
      String? movementId,
    });

typedef SetStockQuantity =
    Future<void> Function({
      required String materialId,
      required String materialName,
      required String locationId,
      required StockOrigin origin,
      required double quantity,
    });

bool _defaultCanRecord() => authService.isEmployeeOrHigher;

bool _defaultIsAdmin() => authService.isAdmin;

Future<List<(String, MaterialItem)>> _defaultLoadCatalog() async => [
  for (final m in await adminRepository.getMaterialsWithIds(
    isFixedValue: false,
  ))
    (m.id, m.item),
];

Future<List<StorageLocation>> _defaultLoadLocations() =>
    stockRepository.watchLocations().first;

Future<List<StockEntry>> _defaultLoadStock() =>
    stockRepository.watchStock().first;

Future<void> _defaultApplyMovement({
  required String materialId,
  required String materialName,
  required String locationId,
  required StockOrigin origin,
  required double delta,
  required String reason,
  String? orderId,
  String? movementId,
}) => stockRepository.applyMovement(
  materialId: materialId,
  materialName: materialName,
  locationId: locationId,
  origin: origin,
  delta: delta,
  reason: reason,
  orderId: orderId,
  movementId: movementId,
);

Future<void> _defaultSetQuantity({
  required String materialId,
  required String materialName,
  required String locationId,
  required StockOrigin origin,
  required double quantity,
}) => stockRepository.setQuantity(
  materialId: materialId,
  materialName: materialName,
  locationId: locationId,
  origin: origin,
  quantity: quantity,
);

Future<bool> _defaultUpdateOrder(String id, Map<String, dynamic> data) =>
    orderRepository.updateOrder(id, data);

/// External collaborators of [RestEntrySheet], bundled so tests can pump
/// the sheet without Firebase. Every default delegates to the global
/// singleton the sheet has always used.
class RestEntryServices {
  const RestEntryServices({
    this.canRecord = _defaultCanRecord,
    this.isAdmin = _defaultIsAdmin,
    this.ownLocation = ensureOwnLocation,
    this.loadCatalog = _defaultLoadCatalog,
    this.loadLocations = _defaultLoadLocations,
    this.loadStock = _defaultLoadStock,
    this.applyMovement = _defaultApplyMovement,
    this.setQuantity = _defaultSetQuantity,
    this.updateOrder = _defaultUpdateOrder,
    this.speechInput = createSpeechInput,
  });

  /// Employee or higher (may record stock at all).
  final bool Function() canRecord;

  /// May create catalog articles (`/materials` is admin-only).
  final bool Function() isAdmin;

  /// The user's own location; asks for one if missing (null: cancelled).
  final Future<StorageLocation?> Function(BuildContext context) ownLocation;
  final Future<List<(String, MaterialItem)>> Function() loadCatalog;
  final Future<List<StorageLocation>> Function() loadLocations;

  /// Current stock, read once for the "Zählung" before/after view.
  final Future<List<StockEntry>> Function() loadStock;
  final BookMovement applyMovement;
  final SetStockQuantity setQuantity;
  final Future<bool> Function(String orderId, Map<String, dynamic> data)
  updateOrder;
  final SpeechInput Function() speechInput;
}

String _formatQuantity(double q) {
  final text = q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
  return text.replaceAll('.', ',');
}

/// The capture flow: voice or text input, then a confirmation view of the
/// parsed lines (always before saving), then booking.
///
/// With [orderId] it records the rest of that order (reason `rest`, marks
/// the order `restRecorded`). Without it, it is the standalone capture of
/// the inventory page (reason `manual`, no order involved) with the modes
/// "Dazu" (add) and "Zählung" (set the counted quantity).
class RestEntrySheet extends StatefulWidget {
  const RestEntrySheet({
    super.key,
    this.orderId,
    this.services = const RestEntryServices(),
  });

  final String? orderId;
  final RestEntryServices services;

  bool get standalone => orderId == null;

  @override
  State<RestEntrySheet> createState() => _RestEntrySheetState();
}

class _RestEntrySheetState extends State<RestEntrySheet> {
  final _textController = TextEditingController();
  late final SpeechInput _speech = widget.services.speechInput();
  StreamSubscription<String>? _speechSub;
  bool _listening = false;
  String? _micError;

  bool _loading = false;
  bool _confirming = false;
  bool _saving = false;
  String? _saveError;

  CaptureMode _mode = CaptureMode.add;
  List<StockEntry> _stock = const [];

  late List<(String, MaterialItem)> _catalog;
  late List<StorageLocation> _locations;
  late StorageLocation _defaultLocation;
  List<RestLine> _lines = [];
  // Fragments the parser could not turn into a line (manual lines, no quantity).
  int _unparsedCount = 0;
  RestLine? _focusLine;
  // Lines already booked, kept so a retry after a partial failure never
  // books them twice.
  final Set<RestLine> _booked = {};

  RestEntryServices get _services => widget.services;
  bool get _counting => widget.standalone && _mode == CaptureMode.count;

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
    final orderId = widget.orderId;
    if (orderId == null) {
      // Standalone: nothing to mark; after a partial booking say so.
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'inventory_list.capture_partial'.tr(
                namedArgs: {'count': '$count'},
              ),
            ),
          ),
        );
      }
      Navigator.of(context).pop(count > 0);
      return;
    }
    if (!shouldMarkRecordedOnClose(count)) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    final ok = await _services.updateOrder(orderId, {'restRecorded': true});
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
        content: Text('rest.partial_closed'.tr(namedArgs: {'count': '$count'})),
        duration: const Duration(seconds: 8),
      ),
    );
    Navigator.of(context).pop(true);
  }

  /// Records "nothing left over": only sets restRecorded, books nothing.
  Future<void> _nothingLeft() async {
    final orderId = widget.orderId;
    if (orderId == null) return;
    if (_loading || _saving || _booked.isNotEmpty) return;
    if (_listening) await _speech.stop();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('rest.nothing_left'.tr()),
        content: Text('rest.nothing_left_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final saved = await _services.updateOrder(orderId, {'restRecorded': true});
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _saving = false;
        _micError = 'rest.mark_failed'.tr();
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _continue() async {
    if (_loading) return;
    if (_listening) await _speech.stop();
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final location = await _services.ownLocation(context);
      if (location == null || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final catalog = await _services.loadCatalog();
      final locations = await _services.loadLocations();
      // The count view shows the stock before and after.
      final stock = _counting
          ? await _services.loadStock()
          : const <StockEntry>[];
      if (!mounted) return;
      _defaultLocation = location;
      _catalog = catalog;
      _locations = locations;
      _stock = stock;
      final parsed = parseRestTextDetailed(_textController.text);
      setState(() {
        // An unparsed fragment becomes a line with the text as article search
        // and no quantity, so nothing is dropped and the user only types it.
        _lines = buildRestLines(
          [
            ...parsed.lines,
            for (final u in parsed.unparsed)
              ParsedLine(quantity: -1, spokenName: u),
          ],
          _catalog,
          _locations,
          _defaultLocation,
        );
        _unparsedCount = parsed.unparsed.length;
        _focusLine = parsed.unparsed.isEmpty
            ? null
            : _lines[parsed.lines.length];
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
      builder: (_) => CatalogPickerDialog(catalog: _catalog),
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
      builder: (_) => NewItemDialog(initialName: line.parsed.spokenName),
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
    final fresh = await _services.loadCatalog();
    if (!mounted) return;
    final created = fresh.where((m) => m.$2.name == name);
    if (created.isEmpty) {
      setState(() => _saveError = 'rest.create_failed'.tr());
      return;
    }
    setState(() {
      _catalog = fresh;
      line.chosenMaterialId = created.first.$1;
      line.chosenMaterialName = name;
      _saveError = null;
    });
  }

  CaptureMode get _effectiveMode =>
      _counting ? CaptureMode.count : CaptureMode.add;

  /// Count plans of the unbooked lines against the stock snapshot.
  Map<RestLine, CountPlan> _countPlans() {
    final duplicates = countDuplicates(_lines);
    return {
      for (final l in _lines)
        if (l.chosenMaterialId != null)
          l: planCountFor(l, _stock, duplicate: duplicates.contains(l)),
    };
  }

  bool get _canSave {
    if (_saving || _lines.isEmpty) return false;
    final mode = _effectiveMode;
    if (!_lines.every(
      (l) =>
          l.chosenMaterialId != null && isValidLineQuantity(l.quantity, mode),
    )) {
      return false;
    }
    if (!_counting) return true;
    final plans = _countPlans();
    return _lines.every((l) => _booked.contains(l) || plans[l]!.valid);
  }

  String _nameOf(RestLine line) =>
      line.chosenMaterialName ?? line.parsed.spokenName;

  /// Adds every unbooked line ("Dazu" and the rest of an order).
  Future<void> _bookAdditions() async {
    for (final line in _lines) {
      if (_booked.contains(line)) continue;
      await _services.applyMovement(
        materialId: line.chosenMaterialId!,
        materialName: _nameOf(line),
        locationId: line.location.id,
        origin: line.origin,
        delta: line.quantity,
        reason: widget.standalone ? 'manual' : 'rest',
        orderId: widget.orderId,
        // Standalone: a retry after a commit whose answer got lost is a no-op.
        movementId: widget.standalone ? manualMovementId(line) : null,
      );
      _booked.add(line);
    }
  }

  /// "Zählung": per line the planned corrections (changed origins only).
  Future<void> _bookCounts() async {
    final plans = _countPlans();
    for (final line in _lines) {
      if (_booked.contains(line)) continue;
      for (final (origin, quantity) in plans[line]!.writes) {
        await _services.setQuantity(
          materialId: line.chosenMaterialId!,
          materialName: _nameOf(line),
          locationId: line.location.id,
          origin: origin,
          quantity: quantity,
        );
      }
      _booked.add(line);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (_counting) {
        await _bookCounts();
      } else {
        await _bookAdditions();
      }
      final orderId = widget.orderId;
      if (orderId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'inventory_list.capture_saved'.tr(
                namedArgs: {'count': '${_booked.length}'},
              ),
            ),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      final ok = await _services.updateOrder(orderId, {'restRecorded': true});
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
    // System/browser back must not close the sheet silently after a partial
    // booking: it takes the same path as "Überspringen".
    return PopScope(
      canPop: !_saving && !shouldMarkRecordedOnClose(_booked.length),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _skip();
      },
      // The sheet lifts itself above the keyboard.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.standalone
                        ? 'inventory_list.capture'.tr()
                        : 'rest.title'.tr(),
                    style: AppText.heroTitle.copyWith(
                      color: AppPalette.of(context).text,
                    ),
                  ),
                ),
              ),
              TextAction(
                label: widget.standalone
                    ? 'inventory_list.capture_close'.tr()
                    : 'rest.skip'.tr(),
                onPressed: _saving ? null : _skip,
              ),
            ],
          ),
          Expanded(child: _confirming ? _buildConfirm() : _buildInput()),
        ],
      ),
    );
  }

  Widget _buildInput() {
    final p = AppPalette.of(context);
    final standalone = widget.standalone;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      children: [
        if (standalone) ...[
          _ModeToggle(
            value: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: AppSpace.s12),
        ],
        Text(
          !standalone
              ? 'rest.intro'.tr()
              : _mode == CaptureMode.count
              ? 'inventory_list.capture_intro_count'.tr()
              : 'inventory_list.capture_intro_add'.tr(),
        ),
        const SizedBox(height: AppSpace.s16),
        TextField(
          controller: _textController,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: standalone
                ? 'inventory_list.capture_text_label'.tr()
                : 'rest.text_label'.tr(),
            hintText: standalone ? null : 'rest.text_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        if (standalone) ...[
          const SizedBox(height: AppSpace.s4),
          Text(
            'inventory_list.capture_example'.tr(),
            style: AppText.caption.copyWith(color: p.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpace.s12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSize.minTap),
            ),
            onPressed: _toggleMic,
            icon: Icon(_listening ? Icons.stop : Icons.mic),
            label: Text(
              _listening ? 'rest.mic_stop'.tr() : 'rest.mic_start'.tr(),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        PrimaryButton(
          label: 'rest.continue'.tr(),
          loading: _loading,
          expand: true,
          onPressed: _continue,
        ),
        if (_micError != null) ...[
          const SizedBox(height: AppSpace.s12),
          Text(_micError!, style: const TextStyle(color: AppColors.warning)),
        ],
        if (!standalone) ...[
          const SizedBox(height: AppSpace.s16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading || _saving || _booked.isNotEmpty
                  ? null
                  : _nothingLeft,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('rest.nothing_left'.tr()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirm() {
    final plans = _counting ? _countPlans() : const <RestLine, CountPlan>{};
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            children: [
              // The raw text stays visible to reveal anything missing.
              Text(
                'rest.heard'.tr(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                _textController.text.trim().isEmpty
                    ? '-'
                    : _textController.text.trim(),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                'rest.check_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_unparsedCount > 0) ...[
                const SizedBox(height: AppSpace.s4),
                Text(
                  'rest.partly_recognized'.tr(),
                  style: AppText.body.copyWith(color: AppColors.warning),
                ),
              ],
              if (_counting) ...[
                const SizedBox(height: AppSpace.s4),
                Text(
                  'inventory_list.count_hint'.tr(),
                  style: AppText.body.copyWith(
                    color: AppPalette.of(context).text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s12),
              if (_lines.isEmpty) ...[
                Text('rest.no_lines'.tr()),
                Text(
                  'rest.no_lines_example'.tr(),
                  style: AppText.caption.copyWith(
                    color: AppPalette.of(context).textSecondary,
                  ),
                ),
              ],
              for (final line in _lines) _buildLine(line, plans),
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
                  padding: const EdgeInsets.only(top: AppSpace.s8),
                  child: Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpace.s12),
            child: Row(
              children: [
                TextAction(
                  label: 'rest.back'.tr(),
                  onPressed: _saving || mustLockRest(_booked.length)
                      ? null
                      : () => setState(() => _confirming = false),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: PrimaryButton(
                    label: 'common.save'.tr(),
                    loading: _saving,
                    expand: true,
                    onPressed: _canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLine(RestLine line, Map<RestLine, CountPlan> plans) {
    final booked = _booked.contains(line);
    final unresolvedMaterial = line.chosenMaterialId == null;
    final plan = plans[line];
    final isAdmin = _services.isAdmin();
    return Card(
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: AppSize.amountField,
                  child: TextFormField(
                    initialValue: line.quantity < 0
                        ? ''
                        : _formatQuantity(line.quantity),
                    autofocus: identical(line, _focusLine),
                    enabled: !booked && !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'rest.quantity'.tr(),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    // Invalid input is kept as -1 (shown as an error).
                    onChanged: (v) => setState(
                      () => line.quantity =
                          parseQuantity(v, allowZero: true) ?? -1,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    line.chosenMaterialName ??
                        (line.parsed.spokenName.isEmpty
                            ? 'rest.item_missing'.tr()
                            : '"${line.parsed.spokenName}"'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: unresolvedMaterial ? AppColors.warning : null,
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
            if (!isValidLineQuantity(line.quantity, _effectiveMode))
              Text(
                _counting
                    ? 'inventory.quantity_invalid'.tr()
                    : 'rest.quantity_invalid'.tr(),
                style: AppText.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            // "Zählung": total and per origin, before and after.
            if (plan != null && line.quantity >= 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: _CountChange(plan: plan),
              ),
            if (unresolvedMaterial && !booked) ...[
              const SizedBox(height: AppSpace.s8),
              Text(
                'rest.pick_item'.tr(),
                style: AppText.body.copyWith(color: AppColors.warning),
              ),
              Wrap(
                spacing: AppSpace.s8,
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
                    avatar: const Icon(Icons.search, size: AppSize.chipIcon),
                    label: Text('rest.pick_other'.tr()),
                    onPressed: () => _pickAnyItem(line),
                  ),
                  // /materials is writable by admins only.
                  if (isAdmin)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: AppSize.chipIcon),
                      label: Text('rest.create_item'.tr()),
                      onPressed: () => _createItem(line),
                    ),
                ],
              ),
              if (!isAdmin) Text('rest.ask_admin'.tr(), style: AppText.body),
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
            const SizedBox(height: AppSpace.s4),
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
                const SizedBox(width: AppSpace.s8),
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
                        : (o) => setState(() {
                            line.origin = o ?? line.origin;
                            line.originExplicit = true;
                          }),
                  ),
                ),
              ],
            ),
            if (line.locationUnresolved)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: Text(
                  'rest.location_unknown'.tr(
                    namedArgs: {'name': line.parsed.locationHint ?? ''},
                  ),
                  style: AppText.body.copyWith(color: AppColors.warning),
                ),
              ),
            if (booked)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: Text(
                  'rest.booked'.tr(),
                  style: AppText.body.copyWith(color: AppColors.success),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Gesamt 5 → 6 · Auftrag 3 → 4 · Investition 2 → 2", or the reason the
/// count line cannot be saved.
class _CountChange extends StatelessWidget {
  const _CountChange({required this.plan});

  final CountPlan plan;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final problem = plan.problem;
    if (problem != null) {
      return Text(switch (problem) {
        CountProblem.belowInvestment =>
          'inventory_list.count_below_investment'.tr(),
        CountProblem.duplicate => 'inventory_list.count_duplicate'.tr(),
      }, style: AppText.body.copyWith(color: p.error));
    }
    String change(String key, double old, double next, [String? origin]) =>
        key.tr(
          namedArgs: {
            'old': formatQuantity(old),
            'new': formatQuantity(next),
            'origin': ?origin,
          },
        );
    return Text(
      [
        change('inventory_list.count_change', plan.oldTotal, plan.newTotal),
        change(
          'inventory_list.count_origin_change',
          plan.oldOrder,
          plan.newOrder,
          'rest.origin_order'.tr(),
        ),
        change(
          'inventory_list.count_origin_change',
          plan.oldInvestment,
          plan.newInvestment,
          'rest.origin_investment'.tr(),
        ),
      ].join(' · '),
      style: AppText.body.copyWith(color: p.text, fontWeight: FontWeight.w600),
    );
  }
}

/// "Dazu | Zählung": two equal halves, so both labels stay readable at
/// large text sizes (they wrap instead of scrolling away).
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.value, required this.onChanged});

  final CaptureMode value;
  final ValueChanged<CaptureMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget half(CaptureMode mode, String label) {
      final active = mode == value;
      return Expanded(
        child: Pressable(
          minSize: AppSize.minTap,
          radius: AppRadius.pill,
          selected: active,
          expand: true,
          onTap: () => onChanged(mode),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? p.primary : p.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: active ? p.primary : p.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.minTap),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.pill.copyWith(
                      color: active ? p.onPrimary : p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        half(CaptureMode.add, 'inventory_list.mode_add'.tr()),
        const SizedBox(width: AppSpace.s8),
        half(CaptureMode.count, 'inventory_list.mode_count'.tr()),
      ],
    );
  }
}

class CatalogPickerDialog extends StatefulWidget {
  const CatalogPickerDialog({super.key, required this.catalog});

  final List<(String, MaterialItem)> catalog;

  @override
  State<CatalogPickerDialog> createState() => CatalogPickerDialogState();
}

class CatalogPickerDialogState extends State<CatalogPickerDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final items =
        widget.catalog
            .where(
              (e) => e.$2.name.toLowerCase().contains(_filter.toLowerCase()),
            )
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
            const SizedBox(height: AppSpace.s8),
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

class NewItemDialog extends StatefulWidget {
  const NewItemDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<NewItemDialog> createState() => NewItemDialogState();
}

class NewItemDialogState extends State<NewItemDialog> {
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
          const SizedBox(height: AppSpace.s12),
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
