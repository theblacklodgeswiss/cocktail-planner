import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/admin_repository.dart';
import '../../data/load_error.dart';
import '../../data/stock_repository.dart';
import '../../models/app_role.dart';
import '../../models/stock.dart';
import '../../services/auth_service.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/pill_filter.dart';
import '../../ui/widgets/states.dart';
import '../../widgets/role_protected_screen.dart';
import 'excel_import_dialog.dart';
import 'inventory_rows.dart';
import 'inventory_view.dart';

/// Inventory tab (`/inventory`, inside the staff shell): wires
/// [InventoryView] to the stock repository and the article catalog, and
/// opens the correction, history and locations sheets.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  static String _originLabel(StockOrigin o) => o == StockOrigin.order
      ? 'rest.origin_order'.tr()
      : 'rest.origin_investment'.tr();

  /// All catalog articles of the inventory (non-fixed-value materials that
  /// are not archived). Throws on failure, so the view can show the cause
  /// and a retry.
  static Future<List<({String id, String name})>> _loadCatalog() async {
    final items = await adminRepository.getMaterialsWithIdsOrThrow();
    return [
      for (final m in items)
        if (m.item.visible) (id: m.id, name: m.item.name),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      minimumRole: AppRole.employee,
      child: InventoryView(
        watchStock: stockRepository.watchStock,
        watchLocations: stockRepository.watchLocations,
        loadCatalog: _loadCatalog,
        originLabel: _originLabel,
        onImport: authService.isAdmin
            ? () => showExcelImportDialog(context)
            : null,
        onManageLocations: () => _showLocations(context),
        onArticleTap: (row, locations) => _showHistory(context, row, locations),
        onCellTap: (row, location, origin) =>
            _showQuantity(context, row, location, origin),
      ),
    );
  }

  Future<void> _showQuantity(
    BuildContext context,
    InventoryRow row,
    StorageLocation location,
    StockOrigin origin,
  ) {
    return showAppSheet<void>(
      context,
      builder: (_) => _QuantitySheet(
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
    return showAppSheet<void>(
      context,
      full: true,
      builder: (_) => _HistorySheet(
        row: row,
        locations: locations,
        originLabel: _originLabel,
      ),
    );
  }

  Future<void> _showLocations(BuildContext context) {
    return showAppSheet<void>(context, builder: (_) => const _LocationsSheet());
  }
}

/// Text field look of the inventory sheets (rounded, filled).
InputDecoration _fieldDecoration(
  BuildContext context, {
  required String label,
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
class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

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

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({
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
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final double _current =
      widget.row.perLocation[widget.location.id]?[widget.origin] ?? 0;
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
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(widget.row.materialName),
        const SizedBox(height: AppSpace.s4),
        Text(
          'inventory_list.current'.tr(
            namedArgs: {
              'location': widget.location.name,
              'origin': widget.originLabel,
              'quantity': formatQuantity(_current),
            },
          ),
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s16),
        PillFilter<bool>(
          value: _take,
          onChanged: (take) => setState(() {
            _take = take;
            _controller.text = _take ? '' : formatQuantity(_current);
            _error = null;
          }),
          options: [
            PillOption(false, 'inventory.correct'.tr()),
            PillOption(true, 'inventory.take'.tr()),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => _saving ? null : _save(),
          style: AppText.section.copyWith(color: p.text),
          decoration: _fieldDecoration(
            context,
            label: _take
                ? 'inventory.take_amount'.tr()
                : 'inventory.new_quantity'.tr(),
            error: _error,
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        PrimaryButton(
          label: 'common.save'.tr(),
          loading: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpace.s8),
        TextAction(
          label: 'common.cancel'.tr(),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
    final p = AppPalette.of(context);
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle('${'inventory.history'.tr()}: ${row.materialName}'),
        const SizedBox(height: AppSpace.s12),
        Expanded(
          child: StreamBuilder<List<StockMovement>>(
            stream: _movements,
            builder: (context, snap) {
              if (snap.hasError) {
                final error = snap.error!;
                debugPrint(
                  'Inventory history failed: ${error.runtimeType}: $error',
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
                return EmptyState(
                  icon: Icons.history,
                  title: 'inventory.history_empty'.tr(),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => Divider(
                  height: AppSpace.s16,
                  thickness: AppSize.hairline,
                  color: p.border,
                ),
                itemBuilder: (context, i) {
                  final m = items[i];
                  final sign = m.delta > 0 ? '+' : '';
                  final order = m.orderId == null
                      ? ''
                      : '  ${'inventory.order_ref'.tr(namedArgs: {'id': shortOrderId(m.orderId!)})}';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$sign${formatQuantity(m.delta)}  '
                        '${_locationName(m.locationId)}, '
                        '${originLabel(m.origin)}',
                        style: AppText.body.copyWith(
                          color: p.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${fmt.format(m.at)}  ${m.byEmail}  '
                        '${_reason(m.reason)}$order',
                        style: AppText.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
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

  Future<({String name, String owner})?> _ask({
    required String initial,
    String initialOwner = '',
  }) => showAppSheet<({String name, String owner})>(
    context,
    builder: (_) => _NameSheet(
      initial: initial,
      askOwner: authService.isAdmin,
      initialOwner: initialOwner,
    ),
  );

  Future<void> _create() async {
    final result = await _ask(initial: '');
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
    final result = await _ask(
      initial: l.name,
      initialOwner: l.ownerEmail ?? '',
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
    final p = AppPalette.of(context);
    return StreamBuilder<List<StorageLocation>>(
      stream: _stream,
      builder: (context, snap) {
        final locations = snap.data ?? const <StorageLocation>[];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTitle('inventory.manage_locations'.tr()),
            const SizedBox(height: AppSpace.s12),
            for (final l in locations)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.minTap),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.name,
                            style: AppText.section.copyWith(color: p.text),
                          ),
                          if (l.ownerEmail != null)
                            Text(
                              l.ownerEmail!,
                              style: AppText.caption.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_canRename(l))
                      GlassIconButton(
                        icon: Icons.edit_outlined,
                        semanticLabel: 'inventory.rename_location'.tr(),
                        onPressed: () => _rename(l),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.s16),
            PrimaryButton(
              label: 'inventory.add_location'.tr(),
              onPressed: _create,
            ),
          ],
        );
      },
    );
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.initial,
    required this.askOwner,
    this.initialOwner = '',
  });

  final String initial;
  final String initialOwner;
  final bool askOwner;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
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
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle('stock.location_name'.tr()),
        const SizedBox(height: AppSpace.s16),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submit(),
          style: AppText.section.copyWith(color: p.text),
          decoration: _fieldDecoration(
            context,
            label: 'stock.location_name'.tr(),
            error: _error,
          ),
        ),
        if (widget.askOwner) ...[
          const SizedBox(height: AppSpace.s12),
          TextField(
            controller: _owner,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _submit(),
            style: AppText.section.copyWith(color: p.text),
            decoration: _fieldDecoration(
              context,
              label: 'inventory.owner_email'.tr(),
              helper: 'inventory.owner_hint'.tr(),
              error: _ownerError,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s24),
        PrimaryButton(label: 'common.save'.tr(), onPressed: _submit),
        const SizedBox(height: AppSpace.s8),
        TextAction(
          label: 'common.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
