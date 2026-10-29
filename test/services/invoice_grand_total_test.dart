import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/services/invoice_pdf_generator.dart';
import 'package:flutter_test/flutter_test.dart';

SavedOrder order({
  double total = 0,
  List<Map<String, dynamic>> positions = const [],
  double discount = 0,
  int shots = 0,
  double shotPrice = 0,
  int extraHours = 0,
  List<String> employees = const [],
  List<Map<String, dynamic>> extras = const [],
}) => SavedOrder(
  id: 'o',
  name: 'Fest',
  date: DateTime(2026, 9, 1),
  items: const [],
  total: total,
  personCount: 10,
  drinkerType: 'normal',
  currency: 'CHF',
  status: OrderStatus.quote,
  offerPositions: positions,
  offerDiscount: discount,
  offerShotsCount: shots,
  offerShotsPricePerPiece: shotPrice,
  offerExtraHours: extraHours,
  offerExtraHourRate: 50,
  assignedEmployees: employees,
  offerExtraPositions: extras,
);

void main() {
  // The formula is byte-for-byte the one that was inline in the generator at
  // eb3980d (verified by diff); these cases are computed by hand.
  group('InvoicePdfGenerator.grandTotalOf', () {
    final positions = [
      {'name': 'Service', 'price': 150.0, 'quantity': 2}, // 300
      {'name': 'Anfahrt', 'price': 80.0, 'quantity': 1}, // 80
    ];

    test('offerPositions branch without discount: 300 + 80 = 380', () {
      expect(
        InvoicePdfGenerator.grandTotalOf(order(positions: positions)),
        380,
      );
    });

    test('offerPositions branch with discount: 380 - 30 = 350', () {
      expect(
        InvoicePdfGenerator.grandTotalOf(
          order(positions: positions, discount: 30),
        ),
        350,
      );
    });

    test('offerPositions branch ignores legacy fields', () {
      // total/shots/hours are not added once positions exist.
      expect(
        InvoicePdfGenerator.grandTotalOf(
          order(
            positions: positions,
            total: 9999,
            shots: 5,
            shotPrice: 4,
            extraHours: 2,
            employees: ['a'],
          ),
        ),
        380,
      );
    });

    test('legacy branch: 1000 + 35 + 240 + 300 - 75 = 1500', () {
      // shots: 10 * 3.5 = 35
      // extra positions: 120 * 2 = 240
      // extra hours: 2 employees * 3 h * 50 = 300
      expect(
        InvoicePdfGenerator.grandTotalOf(
          order(
            total: 1000,
            shots: 10,
            shotPrice: 3.5,
            extras: [
              {'name': 'Deko', 'price': 120.0, 'quantity': 2},
            ],
            extraHours: 3,
            employees: ['a', 'b'],
            discount: 75,
          ),
        ),
        1500,
      );
    });

    test('legacy branch with nothing extra is just the order total', () {
      expect(InvoicePdfGenerator.grandTotalOf(order(total: 640)), 640);
    });
  });
}
