// Characterization tests for the offer and invoice screens (Task 17).
//
// The old screens import the dart:js_interop Microsoft code and cannot be
// pumped in the VM, so their logic was moved verbatim into OfferFormState /
// InvoiceFormState first; these tests pin that logic with hand-computed
// expectations (prices, totals, discount, extra hours, defaults, validation
// and the exact arguments written to the repository).
import 'package:cocktail_planer/models/offer.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/invoice/invoice_form_state.dart';
import 'package:cocktail_planer/screens/offer/offer_form_state.dart';
import 'package:cocktail_planer/services/invoice_pdf_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'document_test_harness.dart';

const _remarkDe2 =
    '- 2 Barkeeper\n- Max. 5h Cocktail- & Barservice\n'
    '- Unlimitiert Cocktails (s. oben)\n'
    '- ausgeschenkt in 0.3L Hartplastikbechern';

void main() {
  group('OfferFormState: generated positions and totals', () {
    test('new offer: service, travel, extra hours, theke', () {
      final s = OfferFormState(offerOrder(), displayName: 'Ida');
      addTearDown(s.dispose);
      final p = s.offerPositions;
      expect(p.map((e) => e.name).toList(), [
        'Cocktail- & Barservice',
        'Reisekosten',
        'Extrastunden',
        'Theke',
      ]);
      // 1000 - 50 km x 0.70 - 150 theke = 815
      expect(p[0].price, closeTo(815, 1e-9));
      expect(p[0].remark, _remarkDe2);
      expect(p[0].date, '01.05.2027');
      expect(p[1].price, 0.70);
      expect(p[1].quantity, 50);
      expect(p[1].remark, 'Reisekosten von Allschwil CH nach Basel');
      expect(p[2].quantity, 0); // "tbd"
      expect(p[2].remark, '50 CHF/Barkeeper/Std. extra');
      expect(p[3].price, 150);
      // 815 + 35 + 0 + 150
      expect(s.positionsSubtotal, closeTo(1000, 1e-9));
      expect(s.discountAmount, 0);
      expect(s.grandTotal, closeTo(1000, 1e-9));
      expect(s.editorNameCtrl.text, 'Ida');
      expect(s.clientNameCtrl.text, 'Fest'); // falls back to order name
      expect(s.clientContactCtrl.text, '079 111 22 33');
      expect(s.eventTimeCtrl.text, '18:00');
      expect(s.barCostCtrl.text, '150.00');
      expect(s.travelCostPerKmCtrl.text, '0.70');
      expect(s.cocktailsCtrl.text, 'Mojito, Hugo');
    });

    test('default editor name when nobody is signed in', () {
      final s = OfferFormState(offerOrder());
      addTearDown(s.dispose);
      expect(s.editorNameCtrl.text, 'Inthusan Gunasiri');
    });

    test('percent discount 10% of 1000 = 100, total 900', () {
      final s = OfferFormState(offerOrder(discountPercent: 10));
      addTearDown(s.dispose);
      expect(s.discountIsPercent, isTrue);
      expect(s.discountValueCtrl.text, '10');
      expect(s.discountAmount, 100);
      expect(s.storedDiscountPercent, 10);
      expect(s.grandTotal, closeTo(900, 1e-9));
      final data = s.buildOfferData();
      expect(data.discount, 100);
      expect(data.discountPercent, 10);
      expect(data.grandTotal, closeTo(900, 1e-9));
    });

    test('fixed discount is capped at the subtotal', () {
      final s = OfferFormState(offerOrder(discount: 1200));
      addTearDown(s.dispose);
      expect(s.discountIsPercent, isFalse);
      expect(s.discountValueCtrl.text, '1200.00');
      expect(s.discountAmount, closeTo(1000, 1e-9));
      expect(s.storedDiscountPercent, 0);
      expect(s.grandTotal, closeTo(0, 1e-9));
    });

    test('legacy negative "Rabatt" position becomes the discount', () {
      final s = OfferFormState(
        offerOrder(
          offerPositions: const [
            {'name': 'Service', 'price': 500.0, 'quantity': 1},
            {'name': 'Rabatt', 'price': -50.0, 'quantity': 1, 'remark': 'Treue'},
          ],
        ),
      );
      addTearDown(s.dispose);
      expect(s.offerPositions.map((e) => e.name), ['Service']);
      expect(s.discountIsPercent, isFalse);
      expect(s.discountValueCtrl.text, '50.00');
      expect(s.discountRemarkCtrl.text, 'Treue');
      expect(s.grandTotal, closeTo(450, 1e-9));
    });

    test('requested shots add a Shots position (4 x 1.50)', () {
      final s = OfferFormState(
        offerOrder(
          shots: const ['Tequila'],
          shotSelections: const [ShotSelection(name: 'Tequila', quantity: 4)],
        ),
      );
      addTearDown(s.dispose);
      final shots = s.offerPositions.last;
      expect(shots.name, 'Shots');
      expect(shots.quantity, 4);
      expect(shots.price, 1.50);
      expect(shots.remark, 'Tequila 4');
      expect(s.positionsSubtotal, closeTo(1006, 1e-9));
    });

    test('event type falls back to the customer occasion', () {
      final s = OfferFormState(offerOrder(eventType: 'birthday'));
      addTearDown(s.dispose);
      expect(s.eventTypes, {EventType.birthday});
      final saved = OfferFormState(
        offerOrder(eventType: 'birthday', offerEventTypes: const ['wedding']),
      );
      addTearDown(saved.dispose);
      expect(saved.eventTypes, {EventType.wedding});
    });

    test('language switch translates untouched defaults', () {
      final s = OfferFormState(offerOrder());
      addTearDown(s.dispose);
      s.changeLanguage('en');
      expect(s.language, 'en');
      expect(s.offerPositions.first.name, 'Cocktail & Bar Service');
      expect(s.firstPositionTextCtrl.text, 'Cocktail & Bar Service');
      expect(s.offerPositions.first.remark, contains('2 Barkeepers'));
      expect(s.additionalInfoCtrl.text, OfferData.defaultAdditionalInfoEn);
    });

    test('service type switch renames the untouched first position', () {
      final s = OfferFormState(offerOrder());
      addTearDown(s.dispose);
      s.changeServiceType('bar_service');
      expect(s.offerPositions.first.name, 'Nur Barservice');
      expect(s.requiresCocktails, isFalse);
      // A custom first position name is kept.
      s.putPosition(
        s.offerPositions.first.copyWith(name: 'Spezial'),
        index: 0,
      );
      s.changeServiceType('cocktail_service');
      expect(s.offerPositions.first.name, 'Spezial');
    });

    test('regenerate keeps custom positions', () {
      final s = OfferFormState(offerOrder());
      addTearDown(s.dispose);
      s.putPosition(const ExtraPosition(name: 'Deko', price: 40));
      s.distanceKmCtrl.text = '10';
      s.regeneratePositions();
      expect(s.offerPositions.map((e) => e.name), [
        'Cocktail- & Barservice',
        'Reisekosten',
        'Extrastunden',
        'Theke',
        'Deko',
      ]);
      // 1000 - 10 x 0.70 - 150
      expect(s.offerPositions.first.price, closeTo(843, 1e-9));
      s.removePosition(4);
      expect(s.offerPositions.length, 4);
    });

    test('validation rules', () {
      expect(OfferFormState.guestCountErrorKey(''), 'offer.field_required');
      expect(OfferFormState.guestCountErrorKey('0'), 'offer.invalid_number');
      expect(OfferFormState.guestCountErrorKey('x'), 'offer.invalid_number');
      expect(OfferFormState.guestCountErrorKey('12'), isNull);
      final s = OfferFormState(offerOrder());
      addTearDown(s.dispose);
      expect(s.cocktailsErrorKey(' , '), 'offer.cocktails_required');
      expect(s.cocktailsErrorKey('Mojito'), isNull);
      s.changeServiceType('bar_service');
      expect(s.cocktailsErrorKey(''), isNull);
      expect(s.eventTypeErrorKey, isNull); // hints only after an attempt
      s.showValidationErrors = true;
      expect(s.eventTypeErrorKey, 'offer.event_type_required');
      s.offerPositions.clear();
      expect(s.positionsErrorKey, 'offer.positions_required');
    });

    test('save writes exactly these arguments', () async {
      final s = OfferFormState(offerOrder(discountPercent: 10));
      addTearDown(s.dispose);
      s.clientNameCtrl.text = ' Anna ';
      s.shotsCtrl.text = 'Tequila, , B52';
      s.setEventTypes({EventType.wedding});
      final repo = FakeDocumentRepository();
      expect(await s.save(repo), isTrue);
      final a = repo.offerDataCalls.single;
      expect(a['orderId'], 'o1');
      expect(a['clientName'], 'Anna');
      expect(a['clientContact'], '079 111 22 33');
      expect(a['eventTime'], '18:00');
      expect(a['eventTypes'], ['wedding']);
      expect(a['discount'], 100);
      expect(a['discountRemark'], '');
      expect(a['discountPercent'], 10);
      expect(a['language'], 'de');
      expect(a['eventDate'], DateTime(2027, 5, 1));
      expect(a['offerPositions'], s.offerPositions.map((e) => e.toJson()));
      expect(a['extraPositions'], a['offerPositions']);
      expect(a['assignedEmployees'], ['Ana', 'Ben']);
      expect(a['serviceType'], 'cocktail_barservice');
      expect(a['firstPositionText'], 'Cocktail- & Barservice');
      expect(a['firstPositionRemark'], _remarkDe2);
      expect(a['distanceKm'], 50);
      expect(a['travelCostPerKm'], 0.70);
      expect(a['barCost'], 150);
      expect(a['location'], 'Basel');
      expect(a['currency'], 'CHF');
      // Invoice-only fields keep the repository defaults.
      expect(a['shotsCount'], 0);
      expect(a['extraHours'], 0);
      expect(repo.cocktailsCalls.single, {
        'orderId': 'o1',
        'cocktails': ['Mojito', 'Hugo'],
        'shots': ['Tequila', 'B52'],
        'bar': 'Theke links',
      });
    });

    test('a failed first write skips the second', () async {
      final s = OfferFormState(offerOrder());
      addTearDown(s.dispose);
      final repo = FakeDocumentRepository()..offerResult = false;
      expect(await s.save(repo), isFalse);
      expect(repo.cocktailsCalls, isEmpty);
    });
  });

  group('InvoiceFormState: fields mode', () {
    test('initial values and sums', () {
      final s = InvoiceFormState(invoiceOrder(), displayName: null);
      addTearDown(s.dispose);
      expect(s.usePositionsMode, isFalse);
      expect(s.editorNameCtrl.text, 'Mario Kantharoobarajah');
      // 1000 - 50 x 2 x 0.70 - 100 = 830
      expect(s.barServiceCostCtrl.text, '830.00');
      expect(s.travelCostTotal, closeTo(70, 1e-9));
      expect(s.thekeCost, 100);
      // 40 guests / 5 = 8 shots x 1.50
      expect(s.shotsCount, 8);
      expect(s.shotsCostTotal, 12);
      expect(
        s.shotsRemarkCtrl.text,
        'Shots – Tequila\nAusgeschenkt in 0.4 CL Shotbechern',
      );
      // 2 employees x 2 h x 50
      expect(s.extraHoursTotal, 200);
      expect(s.extraPositionsTotal, 60);
      expect(s.positionsSum, closeTo(1272, 1e-9));
      // 5% of 1272 = 63.60
      expect(s.discount, closeTo(63.6, 1e-9));
      expect(s.grandTotal, closeTo(1208.4, 1e-9));
      expect(s.savedTotal, closeTo(1000, 1e-9));
    });

    test('the PDF generator computes the same grand total', () {
      final s = InvoiceFormState(invoiceOrder());
      addTearDown(s.dispose);
      expect(
        InvoicePdfGenerator.grandTotalOf(s.buildUpdatedOrder()),
        closeTo(s.grandTotal, 1e-9),
      );
    });

    test('validation: employees and negative total', () {
      final s = InvoiceFormState(invoiceOrder(assignedEmployees: const []));
      addTearDown(s.dispose);
      expect(s.validateAll(), isFalse);
      expect(s.validationErrorKey, 'invoice.employees_required');
      s.toggleEmployee('Ana', true);
      s.barServiceCostCtrl.text = '-2000';
      expect(s.validateAll(), isFalse);
      expect(s.validationErrorKey, 'invoice.total_cannot_be_negative');
      s.barServiceCostCtrl.text = '830';
      expect(s.validateAll(), isTrue);
      expect(s.validationErrorKey, isNull);
    });

    test('save writes exactly these arguments', () async {
      final s = InvoiceFormState(invoiceOrder());
      addTearDown(s.dispose);
      final repo = FakeDocumentRepository();
      expect(await s.save(repo), isTrue);
      final a = repo.offerDataCalls.single;
      expect(a['orderId'], 'o2');
      expect(a['clientName'], 'Anna Muster');
      expect(a['clientContact'], 'anna@x.ch');
      expect(a['eventTime'], '17:30');
      expect(a['eventTypes'], ['wedding']);
      expect(a['discount'], closeTo(63.6, 1e-9));
      expect(a['discountPercent'], 5);
      expect(a['extraPositions'], [
        {'name': 'Deko', 'price': 30.0, 'quantity': 2, 'remark': '', 'date': ''},
      ]);
      expect(a['offerPositions'], isEmpty);
      expect(a['shotsCount'], 8);
      expect(a['shotsPricePerPiece'], 1.5);
      expect(a['shotsRemark'], 'Shots – Tequila\nAusgeschenkt in 0.4 CL Shotbechern');
      expect(a['extraHours'], 2);
      expect(a['extraHourRate'], 50);
      expect(a['assignedEmployees'], ['Ana', 'Ben']);
      expect(a['serviceType'], 'cocktail_barservice');
      // Offer-only fields keep the repository defaults.
      expect(a['firstPositionText'], isNull);
      expect(a['location'], '');
      expect(a['currency'], isNull);
      expect(repo.totalsCalls.single, {
        'orderId': 'o2',
        'total': closeTo(1000, 1e-9),
        'distanceKm': 50,
        'thekeCost': 100,
        'cocktails': ['Mojito'],
        'shots': ['Tequila'],
        'bar': 'Mobile Bar',
      });
    });

    test('calendar text and start', () {
      final s = InvoiceFormState(invoiceOrder());
      addTearDown(s.dispose);
      final built = s.buildUpdatedOrder();
      expect(InvoiceFormState.calendarStart(built), DateTime(2027, 6, 12, 17, 30));
      final lines = s.calendarBodyLines(built, documentUrl: 'u1');
      expect(lines.first, 'Auftrag: Anna Muster');
      expect(lines, contains('Adresse: Bern'));
      expect(lines, contains('Mitarbeiter: Ana, Ben'));
      expect(lines.any((l) => l.startsWith('Gesamtbetrag: ') && l.contains('1')), isTrue);
      expect(lines.last, 'Auftragsbestätigung: u1');
      expect(
        s.shareMessage('https://x/s/1'),
        'Hallo, hier ist deine Auftragsbestätigung für Hochzeit: https://x/s/1',
      );
    });
  });

  group('InvoiceFormState: positions mode', () {
    final positions = [
      {'name': 'Service', 'price': 300.0, 'quantity': 2},
      {'name': 'Anfahrt', 'price': 80.0, 'quantity': 1},
      {'name': 'Extrastunden', 'price': 50.0, 'quantity': 0},
    ];

    test('sum, fixed discount, PDF parity and save', () async {
      final s = InvoiceFormState(
        invoiceOrder(offerPositions: positions, discountPercent: 0, discount: 80),
      );
      addTearDown(s.dispose);
      expect(s.usePositionsMode, isTrue);
      expect(s.offerPositionsSum, 680);
      expect(s.discount, 80);
      expect(s.grandTotal, 600);
      expect(s.savedTotal, 680);
      expect(InvoicePdfGenerator.grandTotalOf(s.buildUpdatedOrder()), 600);
      final repo = FakeDocumentRepository();
      await s.save(repo);
      final a = repo.offerDataCalls.single;
      expect(a['extraPositions'], isEmpty);
      expect((a['offerPositions'] as List).length, 3);
      expect(a['shotsCount'], 0);
      expect(a['shotsPricePerPiece'], 0);
      expect(a['extraHours'], 0);
      expect(a['extraHourRate'], 0);
      expect(repo.totalsCalls.single['total'], 680);
      expect(repo.totalsCalls.single['distanceKm'], 0);
      expect(repo.totalsCalls.single['thekeCost'], 0);
    });

    test('language switch translates standard positions only', () {
      final s = InvoiceFormState(invoiceOrder(offerPositions: positions));
      addTearDown(s.dispose);
      s.changeLanguage('en');
      expect(s.offerPositions.map((e) => e.name), [
        'Service',
        'Anfahrt',
        'Extra hours',
      ]);
      expect(
        s.shareMessage('u'),
        'Hello, here is your order confirmation for Hochzeit: u',
      );
    });
  });

  test('splitCommaList and formatDocumentDate', () {
    expect(splitCommaList(' a, ,b ,'), ['a', 'b']);
    expect(formatDocumentDate(DateTime(2027, 1, 5)), '05.01.2027');
    expect(OrderStatus.values, isNotEmpty);
  });
}
