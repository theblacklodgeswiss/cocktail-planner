import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/material_item.dart';
import '../models/order.dart';
import '../utils/currency.dart';

/// Data class for an order item with quantity
class OrderItem {
  const OrderItem({
    required this.item,
    required this.quantity,
  });

  final MaterialItem item;
  final int quantity;

  double get total => item.price * quantity;
}

/// Simple item data for PDF generation from saved orders
class _SimpleOrderItem {
  const _SimpleOrderItem({
    required this.name,
    required this.unit,
    required this.price,
    required this.note,
    required this.quantity,
  });

  final String name;
  final String unit;
  final double price;
  final String note;
  final int quantity;

  double get total => price * quantity;
}

/// Service to generate PDF shopping lists sorted by purchase location
class PdfGenerator {
  /// Generate and download PDF for the given order
  static Future<void> generateAndDownload({
    required String orderName,
    required DateTime orderDate,
    required List<OrderItem> items,
    required double grandTotal,
    required String currency,
    int personCount = 0,
    String drinkerType = 'normal',
  }) async {
    // Load Unicode-compatible fonts
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );
    final curr = Currency.fromCode(currency);

    // Group items by purchase location (note field)
    final groupedByLocation = <String, List<OrderItem>>{};
    for (final orderItem in items) {
      final location = orderItem.item.note.isEmpty ? 'Sonstige' : orderItem.item.note;
      groupedByLocation.putIfAbsent(location, () => []).add(orderItem);
    }

    // Sort locations alphabetically, but BlackLodge always at the bottom
    final sortedLocations = groupedByLocation.keys.toList()
      ..sort((a, b) {
        final aIsBlackLodge = a.toLowerCase() == 'blacklodge';
        final bIsBlackLodge = b.toLowerCase() == 'blacklodge';
        if (aIsBlackLodge && !bIsBlackLodge) return 1;
        if (!aIsBlackLodge && bIsBlackLodge) return -1;
        return a.compareTo(b);
      });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(orderName, orderDate, personCount, drinkerType),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary section
          _buildSummarySection(items.length, grandTotal, personCount, drinkerType, curr),
          pw.SizedBox(height: 20),
          
          // Items grouped by location
          ...sortedLocations.expand((location) => [
            _buildLocationHeader(location),
            _buildItemsTable(groupedByLocation[location]!, curr),
            pw.SizedBox(height: 16),
          ]),
        ],
      ),
    );

    // Download the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'einkaufsliste_${_sanitizeFilename(orderName)}_${_formatDate(orderDate)}.pdf',
    );
  }

  /// Generate and download PDF from a saved order
  static Future<void> generateFromSavedOrder(SavedOrder order) async {
    final bytes = await generateBytesFromSavedOrder(order);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'einkaufsliste_${_sanitizeFilename(order.name)}_${_formatDate(order.date)}.pdf',
    );
  }

  /// Generate PDF bytes from a saved order without downloading
  static Future<Uint8List> generateBytesFromSavedOrder(SavedOrder order) async {
    // Load Unicode-compatible fonts
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );
    final curr = Currency.fromCode(order.currency);

    // Convert saved items to simple order items
    final items = order.items.map((item) => _SimpleOrderItem(
      name: item['name'] as String? ?? '',
      unit: item['unit'] as String? ?? '',
      price: (item['price'] as num?)?.toDouble() ?? 0,
      note: item['note'] as String? ?? '',
      quantity: (item['quantity'] as num?)?.toInt() ?? 1,
    )).toList();

    // Group items by purchase location (note field)
    final groupedByLocation = <String, List<_SimpleOrderItem>>{};
    for (final orderItem in items) {
      final location = orderItem.note.isEmpty ? 'Sonstige' : orderItem.note;
      groupedByLocation.putIfAbsent(location, () => []).add(orderItem);
    }

    // Sort locations alphabetically, but BlackLodge always at the bottom
    final sortedLocations = groupedByLocation.keys.toList()
      ..sort((a, b) {
        final aIsBlackLodge = a.toLowerCase() == 'blacklodge';
        final bIsBlackLodge = b.toLowerCase() == 'blacklodge';
        if (aIsBlackLodge && !bIsBlackLodge) return 1;
        if (!aIsBlackLodge && bIsBlackLodge) return -1;
        return a.compareTo(b);
      });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(order.name, order.date, order.personCount, order.drinkerType),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary section
          _buildSummarySection(items.length, order.total, order.personCount, order.drinkerType, curr),
          pw.SizedBox(height: 20),
          
          // Items grouped by location
          ...sortedLocations.expand((location) => [
            _buildLocationHeader(location),
            _buildSimpleItemsTable(groupedByLocation[location]!, curr),
            pw.SizedBox(height: 16),
          ]),
        ],
      ),
    );

    // Return the PDF bytes
    return await pdf.save();
  }

  static pw.Widget _buildSimpleItemsTable(List<_SimpleOrderItem> items, Currency currency) {
    // Sort items by name within each location
    final sortedItems = List<_SimpleOrderItem>.from(items)
      ..sort((a, b) => a.name.compareTo(b.name));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3), // Name
        1: const pw.FlexColumnWidth(1.5), // Unit
        2: const pw.FlexColumnWidth(1), // Qty
        3: const pw.FlexColumnWidth(1.2), // Price
        4: const pw.FlexColumnWidth(1.2), // Total
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeader('Artikel'),
            _tableHeader('Einheit'),
            _tableHeader('Menge'),
            _tableHeader('Preis'),
            _tableHeader('Summe'),
          ],
        ),
        // Data rows
        ...sortedItems.map((orderItem) => pw.TableRow(
          children: [
            _tableCell(orderItem.name),
            _tableCell(orderItem.unit),
            _tableCell(orderItem.quantity.toString(), align: pw.TextAlign.center),
            _tableCell(currency.format(orderItem.price), align: pw.TextAlign.right),
            _tableCell(currency.format(orderItem.total), align: pw.TextAlign.right, bold: true),
          ],
        )),
        // Subtotal row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: [
            _tableCell('Zwischensumme', bold: true),
            _tableCell(''),
            _tableCell(''),
            _tableCell(''),
            _tableCell(
              currency.format(sortedItems.fold<double>(0, (sum, i) => sum + i.total)),
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildHeader(String orderName, DateTime date, int personCount, String drinkerType) {
    final drinkerLabel = switch (drinkerType) {
      'light' => 'Wenig Trinker',
      'heavy' => 'Starke Trinker',
      _ => 'Normal',
    };
    
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Einkaufsliste',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                orderName,
                style: const pw.TextStyle(
                  fontSize: 16,
                  color: PdfColors.grey700,
                ),
              ),
              if (personCount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  '$personCount Personen • $drinkerLabel',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'BlackLodge',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _formatDateFull(date),
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generiert am ${_formatDateFull(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
          pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(int itemCount, double total, int personCount, String drinkerType, Currency currency) {
    final drinkerLabel = switch (drinkerType) {
      'light' => 'Wenig Trinker',
      'heavy' => 'Starke Trinker',
      _ => 'Normal',
    };
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Zusammenfassung',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$itemCount Artikel ausgewählt',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              if (personCount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  '$personCount Personen • $drinkerLabel',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Gesamtsumme',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
              pw.Text(
                currency.format(total),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLocationHeader(String location) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: const pw.BoxDecoration(
              color: PdfColors.green600,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            location,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<OrderItem> items, Currency currency) {
    // Sort items by name within each location
    final sortedItems = List<OrderItem>.from(items)
      ..sort((a, b) => a.item.name.compareTo(b.item.name));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3), // Name
        1: const pw.FlexColumnWidth(1.5), // Unit
        2: const pw.FlexColumnWidth(1), // Qty
        3: const pw.FlexColumnWidth(1.2), // Price
        4: const pw.FlexColumnWidth(1.2), // Total
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeader('Artikel'),
            _tableHeader('Einheit'),
            _tableHeader('Menge'),
            _tableHeader('Preis'),
            _tableHeader('Summe'),
          ],
        ),
        // Data rows
        ...sortedItems.map((orderItem) => pw.TableRow(
          children: [
            _tableCell(orderItem.item.name),
            _tableCell(orderItem.item.unit),
            _tableCell(orderItem.quantity.toString(), align: pw.TextAlign.center),
            _tableCell(currency.format(orderItem.item.price), align: pw.TextAlign.right),
            _tableCell(currency.format(orderItem.total), align: pw.TextAlign.right, bold: true),
          ],
        )),
        // Subtotal row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: [
            _tableCell('Zwischensumme', bold: true),
            _tableCell(''),
            _tableCell(''),
            _tableCell(''),
            _tableCell(
              currency.format(sortedItems.fold<double>(0, (sum, i) => sum + i.total)),
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateFull(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static String _sanitizeFilename(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }
}
