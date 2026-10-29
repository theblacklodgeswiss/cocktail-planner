import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/load_error.dart';
import '../../models/stock.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/pill_filter.dart';
import '../../ui/widgets/pressable.dart';
import '../../ui/widgets/staff_scaffold.dart';
import '../../ui/widgets/staff_tab_bar.dart';
import '../../ui/widgets/states.dart';
import 'inventory_rows.dart';

/// How long the inventory waits for the first stock snapshot (and for the
/// article catalog) before it shows an error with a retry button instead of
/// an endless spinner.
const inventoryLoadTimeout = Duration(seconds: 12);

/// Catalog articles of the inventory and how many catalog documents could
/// not be read (skipped instead of failing the whole catalog).
class InventoryCatalog {
  const InventoryCatalog(this.items, {this.skipped = 0});

  final List<({String id, String name})> items;
  final int skipped;
}

typedef CatalogLoader = Future<InventoryCatalog> Function();

/// "Alle" or "Mit Bestand".
enum InventoryFilter { all, inStock }

/// Rows shown for [filter], [locationId] (null: all locations) and [query].
/// With a location chosen, "Mit Bestand" looks at that location only.
List<InventoryRow> filterInventoryRows(
  List<InventoryRow> rows, {
  required InventoryFilter filter,
  String? locationId,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  double amount(InventoryRow r) {
    if (locationId == null) return r.total;
    final cell = r.perLocation[locationId];
    if (cell == null) return 0;
    return cell.values.fold(0.0, (a, b) => a + b);
  }

  return [
    for (final r in rows)
      if ((q.isEmpty || r.materialName.toLowerCase().contains(q)) &&
          (filter == InventoryFilter.all || amount(r) > 0))
        r,
  ];
}

/// The inventory tab: every catalog article (with 0 where nothing is
/// stocked) plus stock of articles no longer in the catalog, as one card per
/// article with the per-location quantities. Filters "Alle | Mit Bestand",
/// one pill per location and a search field.
///
/// Stock and locations come from the given stream factories (loading, error
/// with the technical cause and a retry that re-subscribes). The catalog is
/// loaded once on start, on its own: while it loads or after it failed the
/// stocked articles are already listed, with an inline note (and retry).
///
/// Free of Firebase, so it can be pumped in VM tests with fake streams.
class InventoryView extends StatefulWidget {
  const InventoryView({
    super.key,
    required this.watchStock,
    required this.watchLocations,
    required this.loadCatalog,
    required this.onArticleTap,
    required this.onCellTap,
    required this.originLabel,
    required this.onManageLocations,
    this.onImport,
    this.timeout = inventoryLoadTimeout,
  });

  final Stream<List<StockEntry>> Function() watchStock;
  final Stream<List<StorageLocation>> Function() watchLocations;
  final CatalogLoader loadCatalog;
  final void Function(InventoryRow row, List<StorageLocation> locations)
  onArticleTap;
  final void Function(
    InventoryRow row,
    StorageLocation location,
    StockOrigin origin,
  )
  onCellTap;
  final String Function(StockOrigin origin) originLabel;
  final VoidCallback onManageLocations;

  /// Excel import; null hides it (only admins may import).
  final VoidCallback? onImport;
  final Duration timeout;

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final _search = TextEditingController();
  StreamSubscription<List<StockEntry>>? _stockSub;
  StreamSubscription<List<StorageLocation>>? _locSub;
  Timer? _timeout;
  List<StockEntry>? _entries;
  List<StorageLocation>? _locations;
  Object? _error;

  List<({String id, String name})>? _catalog;
  int _skipped = 0;
  Object? _catalogError;
  int _catalogRun = 0;

  InventoryFilter _filter = InventoryFilter.all;
  String? _locationId;

  // Rows are only rebuilt when an input changes, not on every rebuild.
  List<InventoryRow>? _rows;
  Object? _rowsKey;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadCatalog();
  }

  @override
  void dispose() {
    _cancel();
    _catalogRun++;
    _search.dispose();
    super.dispose();
  }

  void _cancel() {
    _timeout?.cancel();
    _stockSub?.cancel();
    _locSub?.cancel();
    _timeout = null;
    _stockSub = null;
    _locSub = null;
  }

  void _subscribe() {
    _cancel();
    _entries = null;
    _locations = null;
    _error = null;
    _stockSub = widget.watchStock().listen((entries) {
      _timeout?.cancel();
      if (mounted) setState(() => _entries = entries);
    }, onError: _fail);
    _locSub = widget.watchLocations().listen((locations) {
      if (mounted) setState(() => _locations = locations);
    }, onError: _fail);
    _timeout = Timer(widget.timeout, () {
      if (_entries == null) {
        _fail(TimeoutException('No stock snapshot', widget.timeout));
      }
    });
  }

  void _fail(Object error, [StackTrace? stack]) {
    // debugPrint reaches the browser console in release web builds too.
    debugPrint(
      'Inventory load failed: ${describeLoadError(error, translate: (k) => k)}'
      ' | ${error.runtimeType}: $error',
    );
    _cancel();
    if (mounted) setState(() => _error = error);
  }

  void _retry() => setState(_subscribe);

  Future<void> _loadCatalog() async {
    final run = ++_catalogRun;
    _catalogError = null;
    _catalog = null;
    try {
      final result = await widget.loadCatalog().timeout(widget.timeout);
      if (mounted && run == _catalogRun) {
        setState(() {
          _catalog = result.items;
          _skipped = result.skipped;
        });
      }
    } catch (e) {
      debugPrint(
        'Inventory catalog failed: '
        '${describeLoadError(e, translate: (k) => k)} | ${e.runtimeType}: $e',
      );
      if (mounted && run == _catalogRun) setState(() => _catalogError = e);
    }
  }

  List<InventoryRow> _allRows(
    List<StockEntry> entries,
    List<StorageLocation> locations,
  ) {
    final catalog = _catalog ?? const [];
    final key = (entries, locations, catalog);
    final cached = _rows;
    if (cached != null && _rowsKey == key) return cached;
    _rowsKey = key;
    return _rows = buildInventoryRows(entries, locations, catalog: catalog);
  }

  @override
  Widget build(BuildContext context) {
    return StaffScaffold(
      tab: StaffTab.inventory,
      title: 'inventory.title'.tr(),
      actions: [
        if (widget.onImport != null)
          GlassIconButton(
            icon: Icons.upload_file,
            semanticLabel: 'excel_import.button'.tr(),
            onPressed: widget.onImport!,
          ),
        GlassIconButton(
          icon: Icons.warehouse_outlined,
          semanticLabel: 'inventory.manage_locations'.tr(),
          onPressed: widget.onManageLocations,
        ),
      ],
      slivers: _content(context),
    );
  }

  List<Widget> _content(BuildContext context) {
    final error = _error;
    if (error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: 'inventory.load_failed'.tr(),
            detail: describeLoadError(error),
            onRetry: _retry,
          ),
        ),
      ];
    }
    final entries = _entries;
    if (entries == null) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }
    final locations = _locations ?? const <StorageLocation>[];
    if (_locationId != null && !locations.any((l) => l.id == _locationId)) {
      _locationId = null;
    }
    final all = _allRows(entries, locations);

    // Nothing in the catalog and no stock: the inventory has not started.
    if (all.isEmpty && _catalog != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'inventory_list.catalog_empty_title'.tr(),
            body: widget.onImport != null
                ? 'inventory_list.catalog_empty_admin'.tr()
                : 'inventory_list.catalog_empty_hint'.tr(),
            action: widget.onImport == null
                ? null
                : PrimaryButton(
                    label: 'excel_import.button'.tr(),
                    onPressed: widget.onImport,
                  ),
          ),
        ),
      ];
    }

    final query = _search.text;
    final rows = filterInventoryRows(
      all,
      filter: _filter,
      locationId: _locationId,
      query: query,
    );
    final shown = _locationId == null
        ? locations
        : [
            for (final l in locations)
              if (l.id == _locationId) l,
          ];
    const side = EdgeInsets.symmetric(horizontal: AppSpace.s16);

    return [
      SliverPadding(
        padding: side.copyWith(bottom: AppSpace.s8),
        sliver: SliverToBoxAdapter(
          child: _SearchPill(
            controller: _search,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      SliverPadding(
        padding: side,
        sliver: SliverToBoxAdapter(
          child: PillFilter<InventoryFilter>(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
            options: [
              PillOption(InventoryFilter.all, 'inventory_list.filter_all'.tr()),
              PillOption(
                InventoryFilter.inStock,
                'inventory_list.filter_in_stock'.tr(),
              ),
            ],
          ),
        ),
      ),
      if (locations.length > 1)
        SliverPadding(
          padding: side,
          sliver: SliverToBoxAdapter(
            child: PillFilter<String?>(
              value: _locationId,
              onChanged: (id) => setState(() => _locationId = id),
              options: [
                PillOption(null, 'inventory_list.all_locations'.tr()),
                for (final l in locations) PillOption(l.id, l.name),
              ],
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s8)),
      if (_catalog == null)
        SliverPadding(
          padding: side.copyWith(bottom: AppSpace.s12),
          sliver: SliverToBoxAdapter(
            child: _catalogError == null
                ? const _CatalogLoading()
                : _CatalogFailed(
                    detail: describeLoadError(_catalogError!),
                    onRetry: () => setState(() {
                      _loadCatalog();
                    }),
                  ),
          ),
        ),
      if (_catalog != null && _skipped > 0)
        SliverPadding(
          padding: side.copyWith(bottom: AppSpace.s12),
          sliver: SliverToBoxAdapter(
            child: Text(
              'inventory_list.catalog_skipped'.tr(
                namedArgs: {'count': '$_skipped'},
              ),
              style: AppText.caption.copyWith(
                color: AppPalette.of(context).textSecondary,
              ),
            ),
          ),
        ),
      if (_locations != null && locations.isEmpty)
        SliverPadding(
          padding: side.copyWith(bottom: AppSpace.s12),
          sliver: SliverToBoxAdapter(
            child: _NoLocations(onManage: widget.onManageLocations),
          ),
        ),
      if (rows.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: query.trim().isNotEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: 'inventory_list.no_results'.tr(),
                )
              : _catalog == null
              ? const SizedBox.shrink()
              : EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'inventory.empty'.tr(),
                ),
        )
      else
        SliverPadding(
          padding: side,
          sliver: SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s8),
            itemBuilder: (context, i) => InventoryCard(
              row: rows[i],
              locations: shown,
              originLabel: widget.originLabel,
              onOpen: () => widget.onArticleTap(rows[i], locations),
              onCellTap: (l, o) => widget.onCellTap(rows[i], l, o),
            ),
          ),
        ),
    ];
  }
}

/// Rounded search field on top of the list.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppText.body.copyWith(color: p.text),
      decoration: InputDecoration(
        hintText: 'inventory.search'.tr(),
        hintStyle: AppText.body.copyWith(color: p.textSecondary),
        isDense: true,
        filled: true,
        fillColor: p.card,
        prefixIcon: Icon(
          Icons.search,
          size: AppSize.rowIcon,
          color: p.textSecondary,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: Icon(Icons.close, size: AppSize.rowIcon, color: p.text),
                  tooltip: 'ui.close'.tr(),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        border: border(p.border),
        enabledBorder: border(p.border),
        focusedBorder: border(p.text),
      ),
    );
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppSize.metaIcon,
            child: CircularProgressIndicator(
              strokeWidth: AppSize.spinnerStroke,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              'inventory_list.catalog_loading'.tr(),
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogFailed extends StatelessWidget {
  const _CatalogFailed({required this.detail, required this.onRetry});

  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FloatingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'inventory_list.catalog_failed'.tr(),
              style: AppText.body.copyWith(color: p.error),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          SelectableText(
            detail,
            style: AppText.caption.copyWith(color: p.textSecondary),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextAction(label: 'ui.retry'.tr(), onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}

class _NoLocations extends StatelessWidget {
  const _NoLocations({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return FloatingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'inventory_list.no_locations'.tr(),
            style: AppText.body.copyWith(color: p.textSecondary),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextAction(
              label: 'inventory.manage_locations'.tr(),
              onPressed: onManage,
            ),
          ),
        ],
      ),
    );
  }
}

/// One article: name and total (tap: history), then per location the
/// quantities "Auftrag" and "Investition" (tap: correct or take out).
class InventoryCard extends StatelessWidget {
  const InventoryCard({
    super.key,
    required this.row,
    required this.locations,
    required this.originLabel,
    required this.onOpen,
    required this.onCellTap,
  });

  final InventoryRow row;
  final List<StorageLocation> locations;
  final String Function(StockOrigin origin) originLabel;
  final VoidCallback onOpen;
  final void Function(StorageLocation location, StockOrigin origin) onCellTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final note = row.note;
    return FloatingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: onOpen,
            radius: AppRadius.tile,
            semanticLabel: 'inventory_list.open_history'.tr(
              namedArgs: {
                'name': row.materialName,
                'quantity': formatQuantity(row.total),
              },
            ),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.minTap),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            row.materialName,
                            style: AppText.section.copyWith(color: p.text),
                          ),
                          if (note != null)
                            Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Text(
                      formatQuantity(row.total),
                      style: AppText.title.copyWith(
                        color: row.total > 0 ? p.text : p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final l in locations) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              l.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpace.s4),
            Row(
              children: [
                for (final o in StockOrigin.values) ...[
                  if (o != StockOrigin.values.first)
                    const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: _QuantityCell(
                      label: originLabel(o),
                      quantity: row.perLocation[l.id]?[o] ?? 0,
                      semanticLabel: 'inventory_list.cell'.tr(
                        namedArgs: {
                          'location': l.name,
                          'origin': originLabel(o),
                          'quantity': formatQuantity(
                            row.perLocation[l.id]?[o] ?? 0,
                          ),
                        },
                      ),
                      onTap: () => onCellTap(l, o),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityCell extends StatelessWidget {
  const _QuantityCell({
    required this.label,
    required this.quantity,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final double quantity;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      minSize: AppSize.minTap,
      radius: AppRadius.tile,
      semanticLabel: semanticLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTap),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s4),
                  Text(
                    formatQuantity(quantity),
                    style: AppText.number.copyWith(
                      color: quantity > 0 ? p.text : p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
