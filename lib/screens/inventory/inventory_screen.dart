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
import '../../ui/widgets/states.dart';
import '../../widgets/role_protected_screen.dart';
import 'excel_import_dialog.dart';
import 'inventory_actions.dart';
import 'inventory_article_editor.dart';
import 'inventory_rows.dart';
import 'inventory_view.dart';
import 'rest_entry_sheet.dart';

/// Inventory tab (`/inventory`, inside the staff shell): wires
/// [InventoryView] to the stock repository and the article catalog, and
/// opens the stock capture, the article editor (with history and take-out)
/// and the locations sheet.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, this.services = const InventoryServices()});

  final InventoryServices services;

  InventoryActions get _actions => InventoryActions(services);

  static String _originLabel(StockOrigin o) => o == StockOrigin.order
      ? 'rest.origin_order'.tr()
      : 'rest.origin_investment'.tr();

  /// All catalog articles of the inventory (non-fixed-value materials that
  /// are not archived). Throws on failure, so the view can show the cause
  /// and a retry.
  static Future<InventoryCatalog> _loadCatalog() async {
    final catalog = await adminRepository.getMaterialCatalogOrThrow();
    return InventoryCatalog([
      for (final m in catalog.items)
        if (m.item.visible) (id: m.id, name: m.item.name),
    ], skipped: catalog.skipped);
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
        onCapture: () => showStockCaptureSheet(context),
        onArticleTap: (row, locations) => _showEditor(context, row, locations),
      ),
    );
  }

  /// The "Artikel" sheet: quantities per location and origin, note,
  /// history and take-out.
  Future<void> _showEditor(
    BuildContext context,
    InventoryRow row,
    List<StorageLocation> locations,
  ) {
    return showAppSheet<void>(
      context,
      builder: (_) => InventoryArticleEditor(
        row: row,
        locations: locations,
        originLabel: _originLabel,
        saveQuantity: (c) => _actions.saveQuantity(row, c),
        saveNote: (note) => _actions.saveNote(row, locations, note),
        onHistory: () => _showHistory(context, row, locations),
        onTake: () => _showTake(context, row, locations),
      ),
    );
  }

  Future<void> _showTake(
    BuildContext context,
    InventoryRow row,
    List<StorageLocation> locations,
  ) {
    if (locations.isEmpty) return Future.value();
    return showAppSheet<void>(
      context,
      builder: (_) => InventoryTakeSheet(
        row: row,
        locations: locations,
        originLabel: _originLabel,
        onTake: (locationId, origin, amount) =>
            _actions.take(row, locationId, origin, amount),
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
        InventorySheetTitle('${'inventory.history'.tr()}: ${row.materialName}'),
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
    if (reason == 'manual') return 'inventory_list.reason_manual'.tr();
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
            InventorySheetTitle('inventory.manage_locations'.tr()),
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
        InventorySheetTitle('stock.location_name'.tr()),
        const SizedBox(height: AppSpace.s16),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submit(),
          style: AppText.section.copyWith(color: p.text),
          decoration: inventoryFieldDecoration(
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
            decoration: inventoryFieldDecoration(
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
