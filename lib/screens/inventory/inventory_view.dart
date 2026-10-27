import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/load_error.dart';
import '../../models/stock.dart';
import '../../ui/widgets/states.dart';
import 'inventory_rows.dart';

/// How long the inventory waits for the first stock snapshot before it shows
/// an error with a retry button instead of an endless spinner.
const inventoryLoadTimeout = Duration(seconds: 12);

typedef CatalogLoader = Future<List<({String id, String name})>> Function();

/// Body of the inventory page: loads stock and locations from the given
/// stream factories and shows loading, error (with the technical cause and a
/// retry that re-subscribes), empty or the table. Free of Firebase, so it
/// can be pumped in VM tests with fake streams.
///
/// The table appears as soon as the stock arrives; the location columns
/// follow when the locations arrive. The article catalog is only needed to
/// find articles without stock, so it is loaded once, on the first search.
class InventoryView extends StatefulWidget {
  const InventoryView({
    super.key,
    required this.watchStock,
    required this.watchLocations,
    required this.loadCatalog,
    required this.onArticleTap,
    required this.onCellTap,
    required this.originLabel,
    this.timeout = inventoryLoadTimeout,
    this.endPadding = 0,
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
  final Duration timeout;

  /// Extra space after the last row (e.g. to scroll clear of a floating bar).
  final double endPadding;

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

  List<({String id, String name})> _catalog = const [];
  bool _catalogRequested = false;

  // Rows are only rebuilt when an input changes, not on every rebuild.
  List<InventoryRow>? _rows;
  Object? _rowsKey;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _cancel();
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

  Future<void> _ensureCatalog() async {
    if (_catalogRequested) return;
    _catalogRequested = true;
    try {
      final items = await widget.loadCatalog().timeout(widget.timeout);
      if (mounted) setState(() => _catalog = items);
    } catch (e) {
      // Only searching for articles without stock suffers; allow a retry.
      _catalogRequested = false;
      debugPrint('Inventory catalog failed: $e');
    }
  }

  List<InventoryRow> _rowsFor(
    List<StockEntry> entries,
    List<StorageLocation> locations,
    String query,
  ) {
    final key = (entries, locations, _catalog, query);
    final cached = _rows;
    if (cached != null && _rowsKey == key) return cached;
    // Articles without stock only show up when searched for, otherwise the
    // whole catalog would flood the table.
    final rows = buildInventoryRows(entries, locations, catalog: _catalog)
        .where(
          (r) => query.isEmpty
              ? r.total > 0
              : r.materialName.toLowerCase().contains(query),
        )
        .toList();
    _rowsKey = key;
    return _rows = rows;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return ErrorState(
        message: 'inventory.load_failed'.tr(),
        detail: describeLoadError(error),
        onRetry: _retry,
      );
    }
    final entries = _entries;
    if (entries == null) return const LoadingState();
    final locations = _locations ?? const <StorageLocation>[];
    final query = _search.text.trim().toLowerCase();
    final rows = _rowsFor(entries, locations, query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: (text) {
              if (text.trim().isNotEmpty) _ensureCatalog();
              setState(() {});
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'inventory.search'.tr(),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'inventory.empty'.tr(),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: widget.endPadding),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildTable(rows, locations),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTable(List<InventoryRow> rows, List<StorageLocation> locations) {
    final columns = <DataColumn>[
      DataColumn(label: Text('inventory.article'.tr())),
      for (final l in locations)
        for (final o in StockOrigin.values)
          DataColumn(
            numeric: true,
            label: Text('${l.name}\n${widget.originLabel(o)}'),
          ),
      DataColumn(numeric: true, label: Text('inventory.total'.tr())),
      DataColumn(label: Text('inventory.note'.tr())),
    ];
    return DataTable(
      columnSpacing: 20,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 56,
      columns: columns,
      rows: [
        for (final r in rows)
          DataRow(
            cells: [
              DataCell(
                Text(r.materialName),
                onTap: () => widget.onArticleTap(r, locations),
              ),
              for (final l in locations)
                for (final o in StockOrigin.values)
                  DataCell(
                    Text(formatQuantity(r.perLocation[l.id]?[o] ?? 0)),
                    onTap: () => widget.onCellTap(r, l, o),
                  ),
              DataCell(
                Text(
                  formatQuantity(r.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(r.note ?? '')),
            ],
          ),
      ],
    );
  }
}
