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

/// "Alle", "Mit Bestand" or "Leer".
enum InventoryFilter { all, inStock, empty }

/// Stock of [r] at [locationId] (null: all locations).
double inventoryAmount(InventoryRow r, String? locationId) {
  if (locationId == null) return r.total;
  final cell = r.perLocation[locationId];
  if (cell == null) return 0;
  return cell.values.fold(0.0, (a, b) => a + b);
}

/// Rows shown for [filter], [locationId] (null: all locations) and [query].
/// With a location chosen, "Mit Bestand" and "Leer" look at that location
/// only.
List<InventoryRow> filterInventoryRows(
  List<InventoryRow> rows, {
  required InventoryFilter filter,
  String? locationId,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  bool keep(InventoryRow r) => switch (filter) {
    InventoryFilter.all => true,
    InventoryFilter.inStock => inventoryAmount(r, locationId) > 0,
    InventoryFilter.empty => inventoryAmount(r, locationId) <= 0,
  };
  return [
    for (final r in rows)
      if ((q.isEmpty || r.materialName.toLowerCase().contains(q)) && keep(r)) r,
  ];
}

/// "Mit Bestand" as soon as any article has stock, else "Alle".
InventoryFilter defaultInventoryFilter(List<InventoryRow> rows) =>
    rows.any((r) => r.total > 0)
    ? InventoryFilter.inStock
    : InventoryFilter.all;

/// Grey second line of a row: only the non-zero parts, per location
/// ("Biri 2 · Mario 1,5") or, with [locationId], per origin ("Auftrag 2 ·
/// Investition 1"). Null when there is no stock (the row says "Kein
/// Bestand").
String? inventoryRowSubtitle(
  InventoryRow row, {
  required List<StorageLocation> locations,
  String? locationId,
  required String Function(StockOrigin origin) originLabel,
}) {
  final parts = <String>[];
  if (locationId != null) {
    final cell = row.perLocation[locationId] ?? const {};
    for (final o in StockOrigin.values) {
      final q = cell[o] ?? 0;
      if (q > 0) parts.add('${originLabel(o)} ${formatQuantity(q)}');
    }
  } else {
    final names = {for (final l in locations) l.id: l.name};
    // Known locations in their order, then stock at unknown ones.
    final ids = [
      for (final l in locations) l.id,
      for (final id in row.perLocation.keys)
        if (!names.containsKey(id)) id,
    ];
    for (final id in ids) {
      final cell = row.perLocation[id];
      if (cell == null) continue;
      final q = cell.values.fold(0.0, (a, b) => a + b);
      if (q > 0) parts.add('${names[id] ?? id} ${formatQuantity(q)}');
    }
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Section letter of an article name: its first letter, upper case, or "#"
/// for anything else (digits, symbols).
String inventoryLetter(String name) {
  final t = name.trim();
  if (t.isEmpty) return '#';
  final c = t.substring(0, 1).toUpperCase();
  return RegExp(r'[A-ZÄÖÜ]').hasMatch(c) ? c : '#';
}

/// One entry of the grouped list: a letter header or an article row with
/// its position in the letter group (for the rounded corners).
sealed class InventoryListItem {
  const InventoryListItem();
}

class InventoryLetterItem extends InventoryListItem {
  const InventoryLetterItem(this.letter);
  final String letter;
}

class InventoryRowItem extends InventoryListItem {
  const InventoryRowItem(this.row, {required this.first, required this.last});
  final InventoryRow row;
  final bool first;
  final bool last;
}

/// Flattens sorted [rows] into letter headers and rows, for a lazy list.
List<InventoryListItem> groupInventoryRows(List<InventoryRow> rows) {
  final items = <InventoryListItem>[];
  for (var i = 0; i < rows.length; i++) {
    final letter = inventoryLetter(rows[i].materialName);
    final first = i == 0 || inventoryLetter(rows[i - 1].materialName) != letter;
    final last =
        i == rows.length - 1 ||
        inventoryLetter(rows[i + 1].materialName) != letter;
    if (first) items.add(InventoryLetterItem(letter));
    items.add(InventoryRowItem(rows[i], first: first, last: last));
  }
  return items;
}

/// The inventory tab: a prominent "Bestand erfassen" action (voice or text
/// capture), then every catalog article (with 0 where nothing is stocked)
/// plus stock of articles no longer in the catalog as a dense, lazily built
/// list: one row per article (name, the non-zero breakdown, total), grouped
/// by letter. Search, a summary line, the pills "Alle | Mit Bestand | Leer"
/// (default "Mit Bestand" once anything is stocked) and one pill per
/// location. Tapping a row calls [onArticleTap] (the article editor).
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
    required this.onCapture,
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

  /// Opens the stock capture (voice or text).
  final VoidCallback onCapture;
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

  /// Null until the user picks one: then [defaultInventoryFilter] applies.
  InventoryFilter? _filter;
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
    const side = EdgeInsets.symmetric(horizontal: AppSpace.s16);
    final capture = SliverPadding(
      padding: side.copyWith(bottom: AppSpace.s12),
      sliver: SliverToBoxAdapter(
        child: PrimaryButton(
          key: const ValueKey('inventory-capture'),
          icon: Icons.mic_none,
          label: 'inventory_list.capture'.tr(),
          caption: 'inventory_list.capture_caption'.tr(),
          expand: true,
          onPressed: widget.onCapture,
        ),
      ),
    );

    // Nothing in the catalog and no stock: the inventory has not started.
    if (all.isEmpty && _catalog != null) {
      return [
        capture,
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

    final p = AppPalette.of(context);
    final query = _search.text;
    final filter = _filter ?? defaultInventoryFilter(all);
    // A search looks through all articles, whatever the stock pill says.
    final rows = filterInventoryRows(
      all,
      filter: query.trim().isEmpty ? filter : InventoryFilter.all,
      locationId: _locationId,
      query: query,
    );
    final stocked = all
        .where((r) => inventoryAmount(r, _locationId) > 0)
        .length;
    final items = groupInventoryRows(rows);

    return [
      capture,
      SliverPadding(
        padding: side.copyWith(bottom: AppSpace.s4),
        sliver: SliverToBoxAdapter(
          child: _SearchPill(
            controller: _search,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      SliverPadding(
        padding: side.copyWith(bottom: AppSpace.s4),
        sliver: SliverToBoxAdapter(
          child: Text(
            'inventory_list.summary'.tr(
              namedArgs: {'count': '${all.length}', 'stocked': '$stocked'},
            ),
            style: AppText.caption.copyWith(color: p.textSecondary),
          ),
        ),
      ),
      SliverPadding(
        padding: side,
        sliver: SliverToBoxAdapter(
          child: PillFilter<InventoryFilter>(
            value: filter,
            onChanged: (f) => setState(() => _filter = f),
            options: [
              PillOption(InventoryFilter.all, 'inventory_list.filter_all'.tr()),
              PillOption(
                InventoryFilter.inStock,
                'inventory_list.filter_in_stock'.tr(),
              ),
              PillOption(
                InventoryFilter.empty,
                'inventory_list.filter_empty'.tr(),
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
              style: AppText.caption.copyWith(color: p.textSecondary),
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
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => switch (items[i]) {
              InventoryLetterItem(:final letter) => _LetterHeader(letter),
              InventoryRowItem(:final row, :final first, :final last) =>
                InventoryListRow(
                  key: ValueKey('inventory-row ${row.materialId}'),
                  row: row,
                  amount: inventoryAmount(row, _locationId),
                  subtitle: inventoryRowSubtitle(
                    row,
                    locations: locations,
                    locationId: _locationId,
                    originLabel: widget.originLabel,
                  ),
                  first: first,
                  last: last,
                  onTap: () => widget.onArticleTap(row, locations),
                ),
            },
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
        constraints: const BoxConstraints.tightFor(height: AppSize.minTap),
        contentPadding: EdgeInsets.zero,
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

/// Letter above a group of rows ("A", "B", ...).
class _LetterHeader extends StatelessWidget {
  const _LetterHeader(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s4,
      AppSpace.s12,
      AppSpace.s4,
      AppSpace.s4,
    ),
    child: Semantics(
      header: true,
      child: Text(
        letter,
        style: AppText.kicker.copyWith(
          color: AppPalette.of(context).textSecondary,
        ),
      ),
    ),
  );
}

/// One article as a compact row inside its rounded letter group: name and
/// the non-zero breakdown ([subtitle], "Kein Bestand" when null) on the
/// left, the bold [amount] and a chevron on the right. Tap: [onTap].
class InventoryListRow extends StatelessWidget {
  const InventoryListRow({
    super.key,
    required this.row,
    required this.amount,
    required this.subtitle,
    required this.onTap,
    this.first = true,
    this.last = true,
  });

  final InventoryRow row;
  final double amount;
  final String? subtitle;
  final VoidCallback onTap;

  /// Position in the letter group: rounds the top / bottom corners.
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const r = Radius.circular(AppRadius.card);
    final empty = amount <= 0;
    final secondLine = subtitle ?? 'inventory_list.no_stock'.tr();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.vertical(
          top: first ? r : Radius.zero,
          bottom: last ? r : Radius.zero,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            onTap: onTap,
            expand: true,
            radius: first || last ? AppRadius.card : AppRadius.tile,
            semanticLabel: 'inventory_list.open_article'.tr(
              namedArgs: {
                'name': row.materialName,
                'quantity': formatQuantity(amount),
              },
            ),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.minTap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                    vertical: AppSpace.s8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              row.materialName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.section.copyWith(
                                color: empty ? p.textSecondary : p.text,
                              ),
                            ),
                            Text(
                              secondLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: empty ? p.disabled : p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Text(
                        formatQuantity(amount),
                        style: AppText.number.copyWith(
                          color: empty ? p.disabled : p.text,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s4),
                      Icon(
                        Icons.chevron_right,
                        size: AppSize.rowIcon,
                        color: p.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!last)
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.s16),
              child: Divider(
                height: AppSize.hairline,
                thickness: AppSize.hairline,
                color: p.border,
              ),
            ),
        ],
      ),
    );
  }
}
