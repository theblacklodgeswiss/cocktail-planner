import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/material_item.dart';
import '../models/order.dart';
import '../utils/currency.dart';

/// Data class for an order item with quantity
class OrderItem {
  const OrderItem({required this.item, required this.quantity});

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
    String serviceType = '',
  }) async {
    // Load Unicode-compatible fonts
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );
    final curr = Currency.fromCode(currency);

    // Group items by purchase location (note field)
    final groupedByLocation = <String, List<OrderItem>>{};
    for (final orderItem in items) {
      final location = orderItem.item.note.isEmpty
          ? 'Sonstige'
          : orderItem.item.note;
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        header: (context) => _buildHeader(orderName, orderDate, personCount, drinkerType, serviceType),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection(items.length, grandTotal, personCount, drinkerType, curr),
          pw.SizedBox(height: 8),
          ...sortedLocations.expand((location) => [
            _buildLocationHeader(location),
            _buildItemsTable(groupedByLocation[location]!, curr),
            pw.SizedBox(height: 6),
          ]),
        ],
      ),
    );

    // Download the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'einkaufsliste_${_sanitizeFilename(orderName)}_${_formatDate(orderDate)}.pdf',
    );
  }

  /// Generate and download PDF from a saved order
  static Future<void> generateFromSavedOrder(SavedOrder order, {bool includePrices = true}) async {
    final bytes = await generateBytesFromSavedOrder(order, includePrices: includePrices);
    final suffix = includePrices ? '' : '_ohne_preise';
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'einkaufsliste${suffix}_${_sanitizeFilename(order.name)}_${_formatDate(order.date)}.pdf',
    );
  }

  /// Generate PDF bytes from a saved order without downloading
  static Future<Uint8List> generateBytesFromSavedOrder(SavedOrder order, {bool includePrices = true}) async {
    // Load Unicode-compatible fonts
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );
    final curr = Currency.fromCode(order.currency);

    // Convert saved items to simple order items
    final items = order.items
        .map(
          (item) => _SimpleOrderItem(
            name: item['name'] as String? ?? '',
            unit: item['unit'] as String? ?? '',
            price: (item['price'] as num?)?.toDouble() ?? 0,
            note: item['note'] as String? ?? '',
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
          ),
        )
        .toList();

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
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        header: (context) => _buildHeader(order.name, order.date, order.personCount, order.drinkerType, order.serviceType),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection(items.length, includePrices ? order.total : 0, order.personCount, order.drinkerType, curr, includePrices: includePrices),
          pw.SizedBox(height: 8),
          ...sortedLocations.expand((location) => [
            _buildLocationHeader(location),
            _buildSimpleItemsTable(groupedByLocation[location]!, curr, includePrices: includePrices),
            pw.SizedBox(height: 6),
          ]),
        ],
      ),
    );

    // Return the PDF bytes
    return await pdf.save();
  }

  static pw.Widget _buildSimpleItemsTable(
    List<_SimpleOrderItem> items,
    Currency currency, {
    bool includePrices = true,
  }) {
    // Sort items by name within each location
    final sortedItems = List<_SimpleOrderItem>.from(items)
      ..sort((a, b) => a.name.compareTo(b.name));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: includePrices ? {
        0: const pw.FlexColumnWidth(3), // Name
        1: const pw.FlexColumnWidth(1.2), // Unit
        2: const pw.FlexColumnWidth(0.8), // Qty
        3: const pw.FlexColumnWidth(1), // Price
        4: const pw.FlexColumnWidth(1), // Total
        5: const pw.FlexColumnWidth(1.2), // Vorh.
        6: const pw.FlexColumnWidth(1.2), // Zu kaufen
        7: const pw.FixedColumnWidth(24), // Checkbox
      } : {
        0: const pw.FlexColumnWidth(3.5), // Name
        1: const pw.FlexColumnWidth(1.5), // Unit
        2: const pw.FlexColumnWidth(1), // Qty
        3: const pw.FlexColumnWidth(1.5), // Vorh.
        4: const pw.FlexColumnWidth(1.5), // Zu kaufen
        5: const pw.FixedColumnWidth(28), // Checkbox
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeader('Artikel'),
            _tableHeader('Einheit'),
            _tableHeader('Menge'),
            if (includePrices) ...[
              _tableHeader('Preis'),
              _tableHeader('Summe'),
            ],
            _tableHeader('Vorh.'),
            _tableHeader('Zu kaufen'),
            _tableHeader('✓'),
          ],
        ),
        // Data rows
        ...sortedItems.map(
          (orderItem) => pw.TableRow(
            children: [
              _tableCell(orderItem.name),
              _tableCell(orderItem.unit),
              _tableCell(orderItem.quantity.toString(), align: pw.TextAlign.center),
              if (includePrices) ...[
                _tableCell(currency.format(orderItem.price), align: pw.TextAlign.right),
                _tableCell(currency.format(orderItem.total), align: pw.TextAlign.right, bold: true),
              ],
              _tableCell(''),
              _tableCell(''),
              _checkboxCell(),
            ],
          ),
        ),
        // Subtotal row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: [
            _tableCell('Zwischensumme', bold: true),
            _tableCell(''),
            _tableCell(''),
            if (includePrices) ...[
              _tableCell(''),
              _tableCell(
                currency.format(sortedItems.fold<double>(0, (sum, i) => sum + i.total)),
                align: pw.TextAlign.right,
                bold: true,
              ),
            ],
            _tableCell(''),
            _tableCell(''),
            _tableCell(''),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildHeader(
    String orderName,
    DateTime date,
    int personCount,
    String drinkerType,
    String serviceType,
  ) {
    final serviceLabel = switch (serviceType) {
      'cocktail_barservice' => 'Cocktail- & Barservice',
      'cocktail_service' => 'Nur Cocktailservice',
      'cocktailservice' => 'Nur Cocktailservice',
      'mocktail_service' => 'Nur Mocktailservice',
      'bar_service' => 'Nur Barservice',
      'barservice' => 'Nur Barservice',
      _ => serviceType,
    };

    final drinkerLabel = switch (drinkerType) {
      'light' => 'Wenig Trinker',
      'heavy' => 'Starke Trinker',
      _ => 'Normal',
    };

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Einkaufsliste', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(orderName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (personCount > 0)
                pw.Text(
                  '$personCount Personen • $drinkerLabel${serviceLabel.isNotEmpty ? ' • $serviceLabel' : ''}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('BlackLodge', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              pw.Text(_formatDateFull(date), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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

  static pw.Widget _buildSummarySection(
    int itemCount,
    double total,
    int personCount,
    String drinkerType,
    Currency currency, {
    bool includePrices = true,
  }) {
    final drinkerLabel = switch (drinkerType) {
      'light' => 'Wenig Trinker',
      'heavy' => 'Starke Trinker',
      _ => 'Normal',
    };

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$itemCount Artikel${personCount > 0 ? ' • $personCount Personen • $drinkerLabel' : ''}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          if (includePrices)
            pw.Text(
              'Gesamt: ${currency.format(total)}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildLocationHeader(String location) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: const pw.BoxDecoration(color: PdfColors.green600, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 6),
          pw.Text(location, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
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
        ...sortedItems.map(
          (orderItem) => pw.TableRow(
            children: [
              _tableCell(orderItem.item.name),
              _tableCell(orderItem.item.unit),
              _tableCell(
                orderItem.quantity.toString(),
                align: pw.TextAlign.center,
              ),
              _tableCell(
                currency.format(orderItem.item.price),
                align: pw.TextAlign.right,
              ),
              _tableCell(
                currency.format(orderItem.total),
                align: pw.TextAlign.right,
                bold: true,
              ),
            ],
          ),
        ),
        // Subtotal row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: [
            _tableCell('Zwischensumme', bold: true),
            _tableCell(''),
            _tableCell(''),
            _tableCell(''),
            _tableCell(
              currency.format(
                sortedItems.fold<double>(0, (sum, i) => sum + i.total),
              ),
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _checkboxCell() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Container(
        width: 10,
        height: 10,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
          borderRadius: pw.BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
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
