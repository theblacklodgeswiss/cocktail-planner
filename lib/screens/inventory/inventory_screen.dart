import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_repository.dart';
import '../../data/load_error.dart';
import '../../data/stock_repository.dart';
import '../../models/app_role.dart';
import '../../models/stock.dart';
import '../../services/auth_service.dart';
import '../../ui/widgets/staff_scaffold.dart';
import '../../ui/widgets/staff_tab_bar.dart';
import '../../ui/widgets/states.dart';
import '../../widgets/role_protected_screen.dart';
import 'excel_import_dialog.dart';
import 'inventory_rows.dart';
import 'inventory_view.dart';

/// Stock overview. Layout: one table, horizontally scrollable so it stays
/// usable on a phone (columns: article, Auftrag/Investition per location,
/// total, note).
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, this.showBack = true});

  /// False when opened from the staff bar (the back arrow would only lead
  /// to another tab).
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      minimumRole: AppRole.employee,
      child: StaffFrame(
        tab: StaffTab.inventory,
        child: _InventoryPage(showBack: showBack),
      ),
    );
  }
}

class _InventoryPage extends StatelessWidget {
  const _InventoryPage({required this.showBack});

  final bool showBack;

  static String _originLabel(StockOrigin o) => o == StockOrigin.order
      ? 'rest.origin_order'.tr()
      : 'rest.origin_investment'.tr();

  static Future<List<({String id, String name})>> _loadCatalog() async {
    final items = await adminRepository.getMaterialsWithIds(
      isFixedValue: false,
    );
    return [for (final m in items) (id: m.id, name: m.item.name)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('inventory.title'.tr()),
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              )
            : null,
        actions: [
          if (authService.isAdmin)
            IconButton(
              tooltip: 'excel_import.button'.tr(),
              icon: const Icon(Icons.upload_file),
              onPressed: () => showExcelImportDialog(context),
            ),
          IconButton(
            tooltip: 'inventory.manage_locations'.tr(),
            icon: const Icon(Icons.warehouse_outlined),
            onPressed: () => _showLocations(context),
          ),
        ],
      ),
      body: InventoryView(
        watchStock: stockRepository.watchStock,
        watchLocations: stockRepository.watchLocations,
        loadCatalog: _loadCatalog,
        originLabel: _originLabel,
        // Room to scroll the last row clear of the bar and the "+" button.
        endPadding: staffFrameFabClearance(context),
        onArticleTap: (row, locations) => _showHistory(context, row, locations),
        onCellTap: (row, location, origin) =>
            _showQuantityDialog(context, row, location, origin),
      ),
    );
  }

  Future<void> _showQuantityDialog(
    BuildContext context,
    InventoryRow row,
    StorageLocation location,
    StockOrigin origin,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _QuantityDialog(
        row: row,
        location: location,
        origin: origin,
        originLabel: _originLabel(origin),
      ),
    );
  }

  Future<void> _showHistory(
    BuildContext context,
    InventoryRow row,
    List<StorageLocation> locations,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HistorySheet(
        row: row,
        locations: locations,
        originLabel: _originLabel,
      ),
    );
  }

  Future<void> _showLocations(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _LocationsSheet(),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.row,
    required this.location,
    required this.origin,
    required this.originLabel,
  });

  final InventoryRow row;
  final StorageLocation location;
  final StockOrigin origin;
  final String originLabel;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final double _current =
      widget.row.perLocation[widget.location.id]![widget.origin] ?? 0;
  late final TextEditingController _controller = TextEditingController(
    text: formatQuantity(_current),
  );
  bool _take = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = parseQuantity(_controller.text, allowZero: !_take);
    if (value == null) {
      setState(() => _error = 'inventory.quantity_invalid'.tr());
      return;
    }
    if (_take && value > _current + 1e-9) {
      setState(
        () => _error = 'inventory.only_available'.tr(
          namedArgs: {'quantity': formatQuantity(_current)},
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_take) {
        await stockRepository.applyMovement(
          materialId: widget.row.materialId,
          materialName: widget.row.materialName,
          locationId: widget.location.id,
          origin: widget.origin,
          delta: -value,
          reason: 'take',
        );
      } else {
        await stockRepository.setQuantity(
          materialId: widget.row.materialId,
          materialName: widget.row.materialName,
          locationId: widget.location.id,
          origin: widget.origin,
          quantity: value,
        );
      }
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
    return AlertDialog(
      title: Text(widget.row.materialName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.location.name}, ${widget.originLabel}: '
            '${formatQuantity(_current)}',
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('inventory.correct'.tr()),
              ),
              ButtonSegment(value: true, label: Text('inventory.take'.tr())),
            ],
            selected: {_take},
            onSelectionChanged: (s) => setState(() {
              _take = s.first;
              _controller.text = _take ? '' : formatQuantity(_current);
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _saving ? null : _save(),
            decoration: InputDecoration(
              labelText: _take
                  ? 'inventory.take_amount'.tr()
                  : 'inventory.new_quantity'.tr(),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({
    required this.row,
    required this.locations,
    required this.originLabel,
  });

  final InventoryRow row;
  final List<StorageLocation> locations;
  final String Function(StockOrigin) originLabel;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late Stream<List<StockMovement>> _movements = _watch();

  // Needs the composite index stockMovements(materialId asc, at desc).
  Stream<List<StockMovement>> _watch() =>
      stockRepository.watchMovements(materialId: widget.row.materialId);

  InventoryRow get row => widget.row;
  String Function(StockOrigin) get originLabel => widget.originLabel;

  String _locationName(String id) {
    for (final l in widget.locations) {
      if (l.id == id) return l.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${'inventory.history'.tr()}: ${row.materialName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StockMovement>>(
              stream: _movements,
              builder: (context, snap) {
                if (snap.hasError) {
                  final error = snap.error!;
                  debugPrint(
                    'Inventory history failed: ${snap.error.runtimeType}: '
                    '$error',
                  );
                  return ErrorState(
                    message: 'inventory.load_failed'.tr(),
                    detail: describeLoadError(error),
                    onRetry: () => setState(() => _movements = _watch()),
                  );
                }
                if (!snap.hasData) return const LoadingState();
                final items = snap.data!;
                if (items.isEmpty) {
                  return Center(child: Text('inventory.history_empty'.tr()));
                }
                return ListView.builder(
                  controller: scroll,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final m = items[i];
                    final sign = m.delta > 0 ? '+' : '';
                    return ListTile(
                      dense: true,
                      title: Text(
                        '$sign${formatQuantity(m.delta)}  '
                        '${_locationName(m.locationId)}, '
                        '${originLabel(m.origin)}',
                      ),
                      subtitle: Text(
                        '${fmt.format(m.at)}  ${m.byEmail}  '
                        '${_reason(m.reason)}'
                        '${m.orderId == null ? '' : '  ${'inventory.order_ref'.tr(namedArgs: {'id': shortOrderId(m.orderId!)})}'}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _reason(String reason) {
    const known = {'rest', 'take', 'correction', 'import', 'order_deduction'};
    return known.contains(reason) ? 'inventory.reason_$reason'.tr() : reason;
  }
}

class _LocationsSheet extends StatefulWidget {
  const _LocationsSheet();

  @override
  State<_LocationsSheet> createState() => _LocationsSheetState();
}

class _LocationsSheetState extends State<_LocationsSheet> {
  // Own subscription, so the sheet works regardless of the page's stream.
  late final Stream<List<StorageLocation>> _stream = stockRepository
      .watchLocations();

  // NOTE: authService.isAdmin includes the super admin, but the Firestore
  // rules' isAdmin() does not. A super admin who is not also a rules-admin sees
  // these buttons and the write fails (shown via _fail). Known, no behavior
  // change on purpose.
  bool _canRename(StorageLocation l) {
    if (authService.isAdmin) return true;
    final mine = authService.email?.toLowerCase();
    return mine != null && l.ownerEmail?.toLowerCase() == mine;
  }

  void _fail() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('inventory.location_failed'.tr())));
  }

  Future<void> _create() async {
    final result = await showDialog<({String name, String owner})>(
      context: context,
      builder: (_) => _NameDialog(initial: '', askOwner: authService.isAdmin),
    );
    if (result == null) return;
    final owner = result.owner.isEmpty
        ? authService.email
        : result.owner.toLowerCase();
    try {
      await stockRepository.createLocation(result.name, ownerEmail: owner);
    } catch (_) {
      _fail();
    }
  }

  Future<void> _rename(StorageLocation l) async {
    final result = await showDialog<({String name, String owner})>(
      context: context,
      builder: (_) => _NameDialog(
        initial: l.name,
        askOwner: authService.isAdmin,
        initialOwner: l.ownerEmail ?? '',
      ),
    );
    if (result == null) return;
    final owner = normalizeOwnerEmail(result.owner);
    final ownerChanged =
        owner.isNotEmpty && owner != (l.ownerEmail ?? '').toLowerCase();
    if (result.name == l.name && !ownerChanged) return;
    try {
      // An empty owner field leaves the owner unchanged (it is never cleared).
      await stockRepository.renameLocation(
        l.id,
        result.name,
        ownerEmail: ownerChanged ? owner : null,
      );
    } catch (_) {
      _fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<StorageLocation>>(
        stream: _stream,
        builder: (context, snap) {
          final locations = snap.data ?? const <StorageLocation>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'inventory.manage_locations'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text('inventory.add_location'.tr()),
                  onPressed: _create,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in locations)
                      ListTile(
                        title: Text(l.name),
                        subtitle: l.ownerEmail == null
                            ? null
                            : Text(l.ownerEmail!),
                        trailing: _canRename(l)
                            ? IconButton(
                                tooltip: 'inventory.rename_location'.tr(),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _rename(l),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.initial,
    required this.askOwner,
    this.initialOwner = '',
  });

  final String initial;
  final String initialOwner;
  final bool askOwner;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  late final _owner = TextEditingController(text: widget.initialOwner);
  String? _error;
  String? _ownerError;

  @override
  void dispose() {
    _controller.dispose();
    _owner.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final owner = _owner.text.trim();
    final nameError = value.isEmpty
        ? 'stock.location_name_required'.tr()
        : null;
    final ownerError = !isValidOwnerEmail(owner)
        ? 'inventory.owner_invalid'.tr()
        : null;
    if (nameError != null || ownerError != null) {
      setState(() {
        _error = nameError;
        _ownerError = ownerError;
      });
      return;
    }
    Navigator.of(context).pop((name: value, owner: owner));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('stock.location_name'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'stock.location_name'.tr(),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.askOwner) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _owner,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'inventory.owner_email'.tr(),
                helperText: 'inventory.owner_hint'.tr(),
                errorText: _ownerError,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
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
