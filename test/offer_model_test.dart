import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/models/offer.dart';

void main() {
  group('OfferData.toJson / fromJson round-trip', () {
    test('fromJson(offer.toJson()) reproduces every field', () {
      final original = OfferData(
        orderName: 'Test Event',
        eventDate: DateTime(2026, 10, 31),
        eventTime: '18:00',
        currency: 'CHF',
        guestCount: 100,
        editorName: 'Inthusan',
        clientName: 'Jane Doe',
        clientContact: '+41 79 000 00 00',
        eventTypes: {EventType.wedding},
        cocktails: const ['Mojito'],
        shots: const ['Tequila'],
        barDescription: 'Whiskey Bar',
        orderTotal: 1500.0,
        distanceKm: 260,
        travelCostPerKm: 0.7,
        barCost: 100.0,
        discount: 50.0,
        discountRemark: 'Stammkunde',
        discountPercent: 10.0,
        additionalInfo: 'Some info',
        language: 'de',
        serviceType: 'cocktail_barservice',
        servicePositionText: 'Cocktail- & Barservice',
        servicePositionRemark: 'Inkl. 3x Barkeeper',
        eventLocation: 'Dortmund',
        extraPositions: const [
          ExtraPosition(name: 'Reisekosten', price: 0.7, quantity: 260),
        ],
        offerPositions: const [
          ExtraPosition(name: 'Barservice', price: 1500.0, quantity: 1, remark: 'Inkl. 3x Barkeeper', date: '21.08.2026'),
        ],
        assignedEmployees: const ['Mario'],
        supervisorItems: const [
          {'name': 'Barkeeper (5h)', 'category': 'supervisor', 'price': 250, 'quantity': 3, 'total': 750},
        ],
        barDrinks: const ['Bier'],
        alcoholPurchase: const ['Wodka'],
        additionalServices: const ['photobooth'],
        remarks: 'Welcomedrinks',
      );

      final rebuilt = OfferData.fromJson(original.toJson());

      expect(rebuilt.orderName, original.orderName);
      expect(rebuilt.eventDate, original.eventDate);
      expect(rebuilt.eventTime, original.eventTime);
      expect(rebuilt.currency, original.currency);
      expect(rebuilt.guestCount, original.guestCount);
      expect(rebuilt.editorName, original.editorName);
      expect(rebuilt.clientName, original.clientName);
      expect(rebuilt.clientContact, original.clientContact);
      expect(rebuilt.eventTypes, original.eventTypes);
      expect(rebuilt.cocktails, original.cocktails);
      expect(rebuilt.shots, original.shots);
      expect(rebuilt.barDescription, original.barDescription);
      expect(rebuilt.orderTotal, original.orderTotal);
      expect(rebuilt.distanceKm, original.distanceKm);
      expect(rebuilt.travelCostPerKm, original.travelCostPerKm);
      expect(rebuilt.barCost, original.barCost);
      expect(rebuilt.discount, original.discount);
      expect(rebuilt.discountRemark, original.discountRemark);
      expect(rebuilt.discountPercent, original.discountPercent);
      expect(rebuilt.additionalInfo, original.additionalInfo);
      expect(rebuilt.language, original.language);
      expect(rebuilt.serviceType, original.serviceType);
      expect(rebuilt.servicePositionText, original.servicePositionText);
      expect(rebuilt.servicePositionRemark, original.servicePositionRemark);
      expect(rebuilt.eventLocation, original.eventLocation);
      expect(rebuilt.extraPositions.map((p) => p.toJson()),
          original.extraPositions.map((p) => p.toJson()));
      expect(rebuilt.offerPositions.map((p) => p.toJson()),
          original.offerPositions.map((p) => p.toJson()));
      expect(rebuilt.assignedEmployees, original.assignedEmployees);
      expect(rebuilt.supervisorItems, original.supervisorItems);
      expect(rebuilt.barDrinks, original.barDrinks);
      expect(rebuilt.alcoholPurchase, original.alcoholPurchase);
      expect(rebuilt.additionalServices, original.additionalServices);
      expect(rebuilt.remarks, original.remarks);
    });
  });

  group('resolveDiscountAmount', () {
    test('applies a percentage to the subtotal, rounded to cents', () {
      expect(resolveDiscountAmount(subtotal: 1234.56, percent: 10), 123.46);
    });

    test('percentage takes precedence over a fixed amount', () {
      expect(
        resolveDiscountAmount(subtotal: 1000, percent: 5, amount: 300),
        50,
      );
    });

    test('uses the fixed amount when no percentage is set', () {
      expect(resolveDiscountAmount(subtotal: 1000, amount: 150), 150);
    });

    test('never exceeds the subtotal or goes negative', () {
      expect(resolveDiscountAmount(subtotal: 100, amount: 250), 100);
      expect(resolveDiscountAmount(subtotal: 100, amount: -20), 0);
      expect(resolveDiscountAmount(subtotal: 0, percent: 10), 0);
    });
  });

  group('discount helpers', () {
    test('formatDiscountPercent drops trailing zeros', () {
      expect(formatDiscountPercent(10), '10');
      expect(formatDiscountPercent(7.5), '7.5');
      expect(formatDiscountPercent(12.25), '12.25');
    });

    test('discountLabel includes the percentage when set', () {
      expect(discountLabel(isEnglish: false), 'Rabatt');
      expect(discountLabel(isEnglish: false, percent: 10), 'Rabatt (10%)');
      expect(discountLabel(isEnglish: true, percent: 7.5), 'Discount (7.5%)');
    });

    test('isLegacyDiscountPosition only matches negative Rabatt rows', () {
      expect(
        isLegacyDiscountPosition(const ExtraPosition(name: 'Rabatt', price: -50)),
        isTrue,
      );
      expect(
        isLegacyDiscountPosition(const ExtraPosition(name: ' Discount ', price: -5)),
        isTrue,
      );
      expect(
        isLegacyDiscountPosition(const ExtraPosition(name: 'Rabatt', price: 50)),
        isFalse,
      );
      expect(
        isLegacyDiscountPosition(const ExtraPosition(name: 'Theke', price: -50)),
        isFalse,
      );
    });

    test('grandTotal subtracts the discount from offer positions', () {
      final offer = OfferData.fromJson({
        'eventDate': '2026-10-31T00:00:00.000',
        'discount': 100.0,
        'discountPercent': 10.0,
        'offerPositions': [
          {'name': 'Barservice', 'price': 1000.0, 'quantity': 1},
        ],
      });
      expect(offer.grandTotal, 900);
    });
  });
}
