import '../models/stock.dart';
import 'voice_inventory_parser.dart';

/// One quantity from the pasted table. [column] is the index of the quantity
/// column (0..5 for Excel columns C..H); [location] and [origin] are the
/// defaults it was parsed with and may be remapped in the preview.
class ImportCell {
  const ImportCell({
    required this.column,
    required this.location,
    required this.origin,
    required this.quantity,
  });

  final int column;
  final String location;
  final StockOrigin origin;
  final double quantity;
}

/// One article row of the pasted Materialliste.
class ImportRow {
  ImportRow({
    required this.unit,
    required this.name,
    required this.cells,
    this.note,
    this.invalidColumns = const [],
    this.candidates = const [],
  });

  final String unit;
  final String name;

  /// Only non-empty, non-zero, valid quantities.
  final List<ImportCell> cells;
  final String? note;

  /// Quantity-column indices whose cell was filled but not a valid number.
  /// These are never booked; the preview should flag the row.
  final List<int> invalidColumns;

  /// Catalog suggestions, filled in by the caller via matchCatalog.
  List<CatalogMatch> candidates;
}

const _firstQuantityColumn = 2; // Excel column C
const _quantityColumns = 6; // C..H; I is the Gesamt formula and ignored
const _noteColumns = [9, 10]; // J, K

final _plainNumber = RegExp(r'^\d+([.,]\d+)?$');

/// Splits tab-separated text into rows. Double-quoted cells may contain tabs,
/// line breaks and doubled quotes ("") as Excel writes them.
List<List<String>> _splitTsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var cellStart = true;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
    cellStart = true;
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cellStart) {
      inQuotes = true;
      cellStart = false;
    } else if (c == '\t') {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else if (c == '\r') {
      // Part of CRLF; a lone CR also ends the line.
      if (i + 1 >= text.length || text[i + 1] != '\n') endRow();
    } else {
      cell.write(c);
      cellStart = false;
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

bool _isHeader(List<String> cells) {
  for (final c in cells) {
    final l = c.trim().toLowerCase();
    if (l.startsWith('lagerbestand') || l.startsWith('artikelname')) {
      return true;
    }
  }
  final first = cells.isEmpty ? '' : cells.first.trim().toLowerCase();
  return first.startsWith('einheit');
}

/// Parses a table pasted from Excel (columns A..K of the Materialliste).
/// [columnLocations] / [columnOrigins] describe the six quantity columns
/// C..H in order. Header rows, blank rows and rows without an article name
/// are skipped. Numbers use a decimal comma; empty and zero cells book
/// nothing; anything else non-numeric lands in [ImportRow.invalidColumns].
List<ImportRow> parseInventoryPaste(
  String tsv, {
  required List<String> columnLocations,
  required List<StockOrigin> columnOrigins,
}) {
  assert(columnLocations.length == _quantityColumns);
  assert(columnOrigins.length == _quantityColumns);
  final result = <ImportRow>[];
  for (final raw in _splitTsv(tsv)) {
    final cells = [for (final c in raw) c.trim()];
    if (cells.every((c) => c.isEmpty) || _isHeader(cells)) continue;
    String at(int i) => i < cells.length ? cells[i] : '';
    final name = at(1);
    if (name.isEmpty) continue;

    final parsed = <ImportCell>[];
    final invalid = <int>[];
    for (var col = 0; col < _quantityColumns; col++) {
      final text = at(_firstQuantityColumn + col);
      if (text.isEmpty) continue;
      final value = _plainNumber.hasMatch(text)
          ? double.tryParse(text.replaceAll(',', '.'))
          : null;
      if (value == null) {
        invalid.add(col);
      } else if (value > 0) {
        parsed.add(
          ImportCell(
            column: col,
            location: columnLocations[col],
            origin: columnOrigins[col],
            quantity: value,
          ),
        );
      }
    }

    final noteParts = [
      for (final i in _noteColumns)
        if (at(i).isNotEmpty) at(i),
    ];
    result.add(
      ImportRow(
        unit: at(0),
        name: name,
        cells: parsed,
        note: noteParts.isEmpty ? null : noteParts.join(' '),
        invalidColumns: invalid,
      ),
    );
  }
  return result;
}
