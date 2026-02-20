import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/offer.dart';
import '../models/order.dart';
import '../utils/currency.dart';

/// Generates an invoice/confirmation PDF (Auftragsbestätigung) from a [SavedOrder].
class InvoicePdfGenerator {
  static const _blackLodgeAddress = [
    'Black Lodge',
    'Mario Kantharoobarajah',
    'Birkenstrasse 3',
    'CH-4123 Allschwil',
    'Telefon: +41 79 778 48 61',
    'E-Mail: the.blacklodge@outlook.com',
  ];

  static const _bankIban = 'CH86 0020 8208 1176 8440 B';
  static const _twintNumber = '+41 79 778 48 61';

  /// Generates and shares an invoice PDF from an accepted order.
  /// [language] overrides order.offerLanguage if provided ('de' or 'en').
  static Future<void> generateAndDownload(SavedOrder order, {String? language}) async {
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
    final isEn = (language ?? order.offerLanguage) == 'en';

    // Load logo image
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      // Logo not available, will use text fallback
    }

    // Calculate totals
    final travelCostPerKm = 0.70;
    final travelTotal = order.distanceKm * 2 * travelCostPerKm;
    final barServiceCost = order.total - travelTotal - order.thekeCost;
    final grandTotal = order.total - order.offerDiscount;
    // Payment split: ~2/3 deposit, ~1/3 on-site (rounded UP to nearest 100)
    final oneThird = grandTotal / 3;
    final remainingAmount = ((oneThird / 100).ceil()) * 100.0; // Round up to nearest 100
    final depositAmount = grandTotal - remainingAmount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _buildCompanyHeader(logoImage),
          pw.SizedBox(height: 20),
          pw.Text(
            isEn ? 'Order Confirmation' : 'Auftragsbestätigung',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 14),
          _buildEditorAndClient(order, isEn),
          pw.SizedBox(height: 12),
          _buildAnlass(order, isEn),
          pw.SizedBox(height: 10),
          _buildGuestAndServices(order, isEn),
          pw.SizedBox(height: 14),
          _buildPositionsTable(order, curr, isEn, barServiceCost, travelTotal),
          pw.SizedBox(height: 14),
          _buildAdditionalInfo(
            order,
            curr,
            isEn,
            depositAmount: depositAmount,
            remainingAmount: remainingAmount,
          ),
        ],
        footer: (context) => _buildFooter(context, isEn),
      ),
    );

    final dateTag =
        '${order.date.year}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
    final safeName = order.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'auftragsbestaetigung_${safeName}_$dateTag.pdf',
    );
  }

  // ── Company header ────────────────────────────────────────────────────────

  static pw.Widget _buildCompanyHeader(pw.ImageProvider? logoImage) {
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
                    fontSize: 9,
                    fontWeight:
                        line == 'Black Lodge' ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              )
              .toList(),
        ),
        if (logoImage != null)
          pw.Container(
            width: 65,
            height: 65,
            child: pw.Image(logoImage),
          )
        else
          pw.Container(
            width: 100,
            height: 60,
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  static pw.Widget _buildEditorAndClient(SavedOrder order, bool isEn) {
    final createdDateStr =
        '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';
    final eventDateStr =
        '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}.${order.date.year}';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isEn ? 'Editor' : 'Bearbeiter',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 3),
              pw.Text('Name: Mario Kantharoobarajah', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                '${isEn ? 'Date' : 'Datum'}: $createdDateStr',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                '${isEn ? 'Event Date' : 'Eventdatum'}: $eventDateStr',
                style: const pw.TextStyle(fontSize: 9),
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
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Name: ${order.offerClientName.isNotEmpty ? order.offerClientName : order.name}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                '${isEn ? 'Contact' : 'Kontakt'}: ${order.offerClientContact}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (order.offerEventTime.isNotEmpty)
                pw.Text(
                  '${isEn ? 'Time' : 'Uhrzeit'}: ${order.offerEventTime} ${isEn ? '' : 'Uhr'}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Anlass ────────────────────────────────────────────────────────────────

  static pw.Widget _buildAnlass(SavedOrder order, bool isEn) {
    final options = [
      (EventType.birthday, isEn ? 'Birthday Party' : 'Geburtstagsfeier'),
      (EventType.wedding, isEn ? 'Wedding Party' : 'Hochzeitsfeier'),
      (EventType.company, isEn ? 'Company Event' : 'Firmenanlass'),
      (EventType.babyshower, isEn ? 'Babyshower' : 'Babyshower'),
      (EventType.other, isEn ? 'Other' : 'Sonstiges'),
    ];

    final row1 = options.take(3).toList();
    final row2 = options.skip(3).toList();

    // Convert string list to EventType set
    final eventTypes = order.offerEventTypes
        .map((s) => EventType.values.where((e) => e.name == s).firstOrNull)
        .whereType<EventType>()
        .toSet();

    pw.Widget checkboxItem((EventType, String) opt) {
      final checked = eventTypes.contains(opt.$1);
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
                    child: pw.Text('X',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  )
                : null,
          ),
          pw.SizedBox(width: 4),
          pw.Text(opt.$2, style: const pw.TextStyle(fontSize: 9)),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          isEn ? 'Event Type' : 'Anlass',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: row1.map((opt) => pw.Expanded(child: checkboxItem(opt))).toList(),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            ...row2.map((opt) => pw.Expanded(child: checkboxItem(opt))),
            ...List.generate(3 - row2.length, (_) => pw.Expanded(child: pw.SizedBox())),
          ],
        ),
      ],
    );
  }

  // ── Guests, cocktails, bar, shots ─────────────────────────────────────────

  static pw.Widget _buildGuestAndServices(SavedOrder order, bool isEn) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: isEn ? 'Guest count: ' : 'Gästeanzahl: ',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.TextSpan(
                text: '${order.personCount} ${isEn ? 'Guests' : 'Personen'}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        if (order.cocktails.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Cocktails: ',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(
                  text: order.cocktails.join(', '),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
        if (order.bar.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Bar: ',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(
                  text: order.bar,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
        if (order.shots.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Shots: ',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(
                  text: order.shots.join(', '),
                  style: const pw.TextStyle(fontSize: 9),
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
    SavedOrder order,
    Currency curr,
    bool isEn,
    double barServiceCost,
    double travelTotal,
  ) {
    final dateStr =
        '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}.${order.date.year}';
    final grandTotal = order.total - order.offerDiscount;

    pw.Widget headerCell(String text) => pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        );

    pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: align,
          ),
        );

    pw.Widget boldCell(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: align,
          ),
        );

    final columnWidths = {
      0: const pw.FlexColumnWidth(1.1), // Datum
      1: const pw.FlexColumnWidth(1.8), // Paket
      2: const pw.FlexColumnWidth(0.8), // Anzahl
      3: const pw.FlexColumnWidth(1.0), // Preis
      4: const pw.FlexColumnWidth(1.1), // Gesamtpreis
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
          cell(curr.format(barServiceCost), align: pw.TextAlign.right),
          cell(curr.format(barServiceCost), align: pw.TextAlign.right),
          cell(
            isEn
                ? '- 4 Barkeeper\n- Max. 5h Cocktail & Barservice\n- Unlimitiert Cocktails (s. oben welche Cocktails)\n- ausgeschenkt in 0.3L Hartplastikbechern'
                : '- 4 Barkeeper\n- Max. 5h Cocktail & Barservice\n- Unlimitiert Cocktails (s. oben welche Cocktails)\n- ausgeschenkt in 0.3L Hartplastikbechern',
          ),
        ],
      ),
      // Shots (if present)
      if (order.shots.isNotEmpty)
        pw.TableRow(
          children: [
            cell(dateStr),
            cell('Shots'),
            cell('${order.personCount ~/ 5}', align: pw.TextAlign.center), // Estimate
            cell(curr.format(1.50), align: pw.TextAlign.right),
            cell(curr.format((order.personCount ~/ 5) * 1.50), align: pw.TextAlign.right),
            cell(
              isEn
                  ? 'Shots – ${order.shots.join(", ")}\nServed in 0.4 CL shot glasses'
                  : 'Shots – ${order.shots.join(", ")}\nAusgeschenkt in 0.4 CL Shotbechern',
            ),
          ],
        ),
      // Travel cost (if distance > 0)
      if (order.distanceKm > 0)
        pw.TableRow(
          children: [
            cell(dateStr),
            cell(isEn ? 'Travel Costs' : 'Reisekosten'),
            cell('${order.distanceKm * 2} km', align: pw.TextAlign.center),
            cell(curr.format(0.70), align: pw.TextAlign.right),
            cell(curr.format(travelTotal), align: pw.TextAlign.right),
            cell(
              isEn
                  ? 'Return trip from Allschwil, CH to ${order.name}'
                  : 'An & Rückfahrt von Allschwil, CH nach ${order.name}',
            ),
          ],
        ),
      // Extra hours row
      pw.TableRow(
        children: [
          cell(dateStr),
          cell(isEn ? 'Extra hours' : 'Extrastunden'),
          cell('X', align: pw.TextAlign.center),
          cell(curr.format(200), align: pw.TextAlign.right),
          cell('tbd'),
          cell(
            isEn
                ? 'Price is determined as follows:\n50 ${order.currency} per Barkeeper per hour'
                : 'Der Preis setzt sich, wie folgt zusammen:\n50 ${order.currency} a Barkeeper pro Stunde',
          ),
        ],
      ),
      // Theke (if cost > 0)
      if (order.thekeCost > 0)
        pw.TableRow(
          children: [
            cell(dateStr),
            cell(isEn ? 'Bar Counter' : 'Theke'),
            cell('1', align: pw.TextAlign.center),
            cell(curr.format(order.thekeCost), align: pw.TextAlign.right),
            cell(curr.format(order.thekeCost), align: pw.TextAlign.right),
            cell(
              isEn
                  ? 'Mobile bar counter will be set up and provided'
                  : 'Mobile Theke wird aufgebaut und zur Verfügung gestellt',
            ),
          ],
        ),
      // Discount row (if > 0)
      if (order.offerDiscount > 0)
        pw.TableRow(
          children: [
            cell(dateStr),
            cell(isEn ? 'Discount' : 'Rabatt'),
            cell('1', align: pw.TextAlign.center),
            cell(curr.format(order.offerDiscount), align: pw.TextAlign.right),
            cell('-${curr.format(order.offerDiscount)}', align: pw.TextAlign.right),
            cell(
              order.offerDiscount >= order.total * 0.1
                  ? (isEn ? 'Discount: 15% Friends' : 'Rabatt: 15% Friends')
                  : (isEn ? 'Family/Friend discount' : 'Familie/Freunde Rabatt'),
            ),
          ],
        ),
      // Total row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          cell(''),
          cell(''),
          cell(''),
          boldCell(isEn ? 'Total:' : 'Gesamtkosten:', align: pw.TextAlign.right),
          boldCell(curr.format(grandTotal), align: pw.TextAlign.right),
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

  // ── Additional info with payment terms ────────────────────────────────────

  static pw.Widget _buildAdditionalInfo(
    SavedOrder order,
    Currency curr,
    bool isEn, {
    required double depositAmount,
    required double remainingAmount,
  }) {
    final eventDateStr =
        '${order.date.day.toString().padLeft(2, '0')}.${order.date.month.toString().padLeft(2, '0')}.${order.date.year}';

    final additionalTextDe = '''
"Black Lodge" ist für den Einkauf und Zubereitung der Cocktails verantwortlich. Dies betrifft auch die Hartplastikbecher, Süssigkeiten, Strohhalme, Früchte und den dazugehörigen Alkohol. Eine "Bartheke" kann von uns zur Verfügung gestellt werden gegen Aufpreis (s. oben).
Empfehlung: Am Anfang würden wir nur die Cocktails ohne "Barservice" für 2 Stunden anbieten und anschliessend sowohl Cocktails & Barservice für den restlichen Abend. Jedoch richten wir uns hier nach Kundenwunsch.

Die Zeit für die Anfahrt, Abfahrt und Aufbau gehören nicht zu den "5h Cocktail & Barservice", werden dem Kunden dennoch nicht verrechnet. Unser Team wird mindestens 1 Stunde vor Auftragsbeginn am Standort erscheinen und den Aufbau beginnen, aber auch hier richten wir uns gern nach Kundenwunsch.

Wir bitten den Auftraggeber eine Anzahlung in Höhe von ${curr.format(depositAmount)} binnen 14 Tage zu tätigen. Andernfalls wird der Auftrag automatisch storniert. Die restlichen ${curr.format(remainingAmount)} werden am $eventDateStr nach Auftragsende vom Kunden bar oder per TWINT bezahlt.

Name: Mario Kantharoobarajah        IBAN: $_bankIban        TWINT: $_twintNumber

Wird der Auftrag seitens, Auftraggeber nach Anzahlung storniert, hat er keinen Anspruch auf die Anzahlung! Sollte es von seitens Auftragnehmer storniert werden, wird die Anzahlung unverzüglich wieder zurückerstattet!''';

    final additionalTextEn = '''
"BlackLodge" is responsible for purchasing and preparing the cocktails. This includes hard plastic cups, sweets, straws, fruits, and the associated alcohol. A "bar counter" can be provided by us for an additional charge (see above).
Recommendation: At the beginning we would only offer cocktails without "bar service" for 2 hours and then both cocktails & bar service for the rest of the evening. However, we follow the customer's wishes.

The time for arrival, departure and setup is not included in the "5h Cocktail & Bar Service", but will not be charged to the client. Our team will arrive at the venue at least 1 hour before the start of the assignment and begin setup.

We ask the client to make a deposit of ${curr.format(depositAmount)} within 14 days. Otherwise the order will be automatically cancelled. The remaining ${curr.format(remainingAmount)} will be paid in cash or via TWINT on $eventDateStr after the order is completed.

Name: Mario Kantharoobarajah        IBAN: $_bankIban        TWINT: $_twintNumber

If the order is cancelled by the client after the deposit has been made, they are not entitled to a refund! If the order is cancelled by the contractor, the deposit will be refunded immediately!''';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          isEn ? 'Additional Information:' : 'Zusatzinformationen:',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          isEn ? additionalTextEn : additionalTextDe,
          style: const pw.TextStyle(fontSize: 8),
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
      padding: const pw.EdgeInsets.only(top: 6),
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
