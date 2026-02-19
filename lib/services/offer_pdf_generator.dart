import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/offer.dart';
import '../utils/currency.dart';

/// Generates a PDF offer document (Angebot) from [OfferData].
class OfferPdfGenerator {
  static const _blackLodgeAddress = [
    'Black Lodge',
    'Mario Kantharoobarajah',
    'Birkenstrasse 3',
    'CH-4123 Allschwil',
    'Telefon: +41 79 778 48 61',
    'E-Mail: the.blacklodge@outlook.com',
  ];

  /// Generates and shares an offer PDF.
  static Future<void> generateAndDownload(OfferData offer) async {
    final pdf = pw.Document();
    final curr = Currency.fromCode(offer.currency);
    final isEn = offer.language == 'en';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildCompanyHeader(),
          pw.SizedBox(height: 28),
          pw.Text(
            isEn ? 'Offer' : 'Angebot',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          _buildEditorAndClient(offer, isEn),
          pw.SizedBox(height: 20),
          _buildAnlass(offer, isEn),
          pw.SizedBox(height: 16),
          _buildGuestAndServices(offer, isEn),
          pw.SizedBox(height: 20),
          _buildPositionsTable(offer, curr, isEn),
          pw.SizedBox(height: 20),
          _buildAdditionalInfo(offer, isEn),
        ],
        footer: (context) => _buildFooter(context, isEn),
      ),
    );

    final dateTag =
        '${offer.eventDate.year}${offer.eventDate.month.toString().padLeft(2, '0')}${offer.eventDate.day.toString().padLeft(2, '0')}';
    final safeName =
        offer.orderName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'angebot_${safeName}_$dateTag.pdf',
    );
  }

  // ── Company header ────────────────────────────────────────────────────────

  static pw.Widget _buildCompanyHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: _blackLodgeAddress
              .map(
                (line) => pw.Text(
                  line,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: line == 'Black Lodge'
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              )
              .toList(),
        ),
        pw.Container(
          width: 100,
          height: 60,
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.amber700, width: 2),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'BLACK\nLODGE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bearbeiter & Auftraggeber ─────────────────────────────────────────────

  static pw.Widget _buildEditorAndClient(OfferData offer, bool isEn) {
    final dateStr =
        '${offer.eventDate.day.toString().padLeft(2, '0')}.${offer.eventDate.month.toString().padLeft(2, '0')}.${offer.eventDate.year}';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isEn ? 'Editor' : 'Bearbeiter',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Name: ${offer.editorName}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                '${isEn ? 'Date' : 'Datum'}: $dateStr',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (offer.eventTime.isNotEmpty)
                pw.Text(
                  '${isEn ? 'Time' : 'Uhrzeit'}: ${offer.eventTime} Uhr',
                  style: const pw.TextStyle(fontSize: 10),
                ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isEn ? 'Client' : 'Auftraggeber',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Name: ${offer.clientName}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                '${isEn ? 'Contact' : 'Kontakt'}: ${offer.clientContact}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Anlass ────────────────────────────────────────────────────────────────

  static pw.Widget _buildAnlass(OfferData offer, bool isEn) {
    final options = [
      (
        EventType.birthday,
        isEn ? 'Birthday Party' : 'Geburtstagsfeier',
      ),
      (
        EventType.wedding,
        isEn ? 'Wedding Party' : 'Hochzeitsfeier',
      ),
      (
        EventType.company,
        isEn ? 'Company Event' : 'Firmenanlass',
      ),
      (
        EventType.babyshower,
        isEn ? 'Babyshower' : 'Babyshower',
      ),
      (
        EventType.other,
        isEn ? 'Other' : 'Sonstiges',
      ),
    ];

    // Split into two rows of up to 3 columns each
    final row1 = options.take(3).toList();
    final row2 = options.skip(3).toList();

    pw.Widget checkboxItem((EventType, String) opt) {
      final checked = offer.eventTypes.contains(opt.$1);
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 10,
            height: 10,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: checked
                ? pw.Center(
                    child: pw.Text('✗',
                        style: const pw.TextStyle(fontSize: 8)),
                  )
                : null,
          ),
          pw.SizedBox(width: 4),
          pw.Text(opt.$2, style: const pw.TextStyle(fontSize: 10)),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          isEn ? 'Event Type' : 'Anlass',
          style:
              pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: row1
              .map((opt) => pw.Expanded(child: checkboxItem(opt)))
              .toList(),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            ...row2.map((opt) => pw.Expanded(child: checkboxItem(opt))),
            // Fill remaining columns
            ...List.generate(
              3 - row2.length,
              (_) => const pw.Expanded(child: pw.SizedBox()),
            ),
          ],
        ),
      ],
    );
  }

  // ── Guests, cocktails, bar, shots ─────────────────────────────────────────

  static pw.Widget _buildGuestAndServices(OfferData offer, bool isEn) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: isEn ? 'Guest count: ' : 'Gästeanzahl: ',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.TextSpan(
                text: '${offer.guestCount} ${isEn ? 'Guests' : 'Gäste'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        if (offer.cocktails.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Cocktails: ',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(
                  text: offer.cocktails.join(', '),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
        if (offer.barDescription.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Bar: ',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(
                  text: offer.barDescription,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
        if (offer.shots.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Shots: ',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(
                  text: offer.shots.join(', '),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Positions table ───────────────────────────────────────────────────────

  static pw.Widget _buildPositionsTable(
      OfferData offer, Currency curr, bool isEn) {
    final dateStr =
        '${offer.eventDate.day.toString().padLeft(2, '0')}.${offer.eventDate.month.toString().padLeft(2, '0')}.${offer.eventDate.year}';

    pw.Widget headerCell(String text) => pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            text,
            style:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        );

    pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 9),
            textAlign: align,
          ),
        );

    pw.Widget boldCell(String text,
            {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: align,
          ),
        );

    final travelTotal = offer.travelCostTotal;
    final columnWidths = {
      0: const pw.FlexColumnWidth(1.2), // Datum
      1: const pw.FlexColumnWidth(2.0), // Paket
      2: const pw.FlexColumnWidth(1.0), // Anzahl
      3: const pw.FlexColumnWidth(1.2), // Preis
      4: const pw.FlexColumnWidth(1.2), // Gesamtpreis
      5: const pw.FlexColumnWidth(2.5), // Bemerkung
    };

    final rows = <pw.TableRow>[
      // Header
      pw.TableRow(
        children: [
          headerCell(isEn ? 'Date' : 'Datum'),
          headerCell(isEn ? 'Package' : 'Paket'),
          headerCell(isEn ? 'Qty' : 'Anzahl'),
          headerCell(isEn ? 'Price' : 'Preis'),
          headerCell(isEn ? 'Total' : 'Gesamtpreis'),
          headerCell(isEn ? 'Note' : 'Bemerkung'),
        ],
      ),
      // Cocktail & Barservice
      pw.TableRow(
        children: [
          cell(dateStr),
          cell(isEn ? 'Cocktail & Bar Service' : 'Cocktail & Barservice'),
          cell('1', align: pw.TextAlign.center),
          cell(curr.format(offer.barServiceCost), align: pw.TextAlign.right),
          cell(curr.format(offer.barServiceCost), align: pw.TextAlign.right),
          cell(
            isEn
                ? '- 3 Barkeeper\n- Max. 5h Cocktail & Bar Service\n- Unlimited Cocktails\n- served in 0.3L hard plastic cups'
                : '- 3 Barkeeper\n- Max. 5h Cocktail & Barservice\n- Unlimitiert Cocktails (s. oben welche Cocktails)\n- ausgeschenkt in 0.3L Hartplastikbechern',
          ),
        ],
      ),
      // Travel cost (only if distance > 0)
      if (offer.distanceKm > 0)
        pw.TableRow(
          children: [
            cell(dateStr),
            cell(isEn ? 'Travel Costs' : 'Reisekosten'),
            cell('${offer.distanceKm * 2} km', align: pw.TextAlign.center),
            cell(curr.format(offer.travelCostPerKm), align: pw.TextAlign.right),
            cell(curr.format(travelTotal), align: pw.TextAlign.right),
            cell(
              isEn
                  ? 'Return trip from Allschwil, CH to venue'
                  : 'An & Rückfahrt von Allschwil, CH nach ${offer.orderName}',
            ),
          ],
        ),
      // Extra staff note row
      pw.TableRow(
        children: [
          cell(dateStr),
          cell(isEn ? 'Extra hours' : 'Extrastunden'),
          cell('X', align: pw.TextAlign.center),
          cell(curr.format(100), align: pw.TextAlign.right),
          cell('tbd'),
          cell(
            isEn
                ? 'Price is determined as follows:\n50 ${offer.currency} per extra Barkeeper per hour'
                : 'Der Preis setzt sich, wie folgt zusammen:\n50 ${offer.currency} a Barkeeper pro Stunde',
          ),
        ],
      ),
      // Bar/Theke (only if cost > 0)
      if (offer.barCost > 0)
        pw.TableRow(
          children: [
            cell(dateStr),
            cell(isEn ? 'Bar Counter' : 'Theke'),
            cell('1', align: pw.TextAlign.center),
            cell(curr.format(offer.barCost), align: pw.TextAlign.right),
            cell(curr.format(offer.barCost), align: pw.TextAlign.right),
            cell(
              isEn
                  ? 'Mobile bar counter will be set up and provided'
                  : 'Mobile Theke wird aufgebaut und zur Verfügung gestellt',
            ),
          ],
        ),
      // Discount row (only if > 0)
      if (offer.discount > 0)
        pw.TableRow(
          children: [
            cell(''),
            cell(isEn ? 'Discount' : 'Rabatt'),
            cell('', align: pw.TextAlign.center),
            cell('', align: pw.TextAlign.right),
            cell('-${curr.format(offer.discount)}', align: pw.TextAlign.right),
            cell(isEn ? 'Family/Friend discount' : 'Familie/Freunde Rabatt'),
          ],
        ),
      // Total row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          cell(''),
          boldCell(''),
          boldCell(''),
          boldCell(
            isEn ? 'Total:' : 'Gesamtkosten:',
            align: pw.TextAlign.right,
          ),
          boldCell(
            curr.format(offer.grandTotal),
            align: pw.TextAlign.right,
          ),
          cell(''),
        ],
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  // ── Additional info ───────────────────────────────────────────────────────

  static pw.Widget _buildAdditionalInfo(OfferData offer, bool isEn) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          isEn ? 'Additional Information:' : 'Zusatzinformationen:',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          offer.additionalInfo,
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context context, bool isEn) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            isEn ? 'Generated on $dateStr' : 'Erstellt am $dateStr',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            '${isEn ? 'Page' : 'Seite'} ${context.pageNumber} ${isEn ? 'of' : 'von'} ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }
}
