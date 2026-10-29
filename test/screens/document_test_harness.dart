// Shared fakes for the offer/invoice tests (document_logic_test.dart,
// document_flow_test.dart). Everything the screens write goes through
// these fakes, so no Firebase is involved.
import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/data/share_link_repository.dart';
import 'package:cocktail_planer/models/offer.dart';
import 'package:cocktail_planer/models/order.dart';

/// Records the arguments of every offer/invoice write.
class FakeDocumentRepository extends OrderRepository {
  final List<Map<String, dynamic>> offerDataCalls = [];
  final List<Map<String, dynamic>> totalsCalls = [];
  final List<Map<String, dynamic>> cocktailsCalls = [];
  bool offerResult = true;
  bool secondResult = true;

  @override
  Future<bool> updateOfferData({
    required String orderId,
    required String clientName,
    required String clientContact,
    required String eventTime,
    required List<String> eventTypes,
    required double discount,
    required String language,
    required DateTime eventDate,
    String discountRemark = '',
    double discountPercent = 0,
    List<Map<String, dynamic>> extraPositions = const [],
    List<Map<String, dynamic>> offerPositions = const [],
    int shotsCount = 0,
    double shotsPricePerPiece = 1.50,
    String shotsRemark = '',
    int extraHours = 0,
    double extraHourRate = 50.0,
    List<String> assignedEmployees = const [],
    String? serviceType,
    String? firstPositionText,
    String? firstPositionRemark,
    int distanceKm = 0,
    double travelCostPerKm = 0.70,
    double barCost = 0,
    String location = '',
    String? currency,
  }) async {
    offerDataCalls.add({
      'orderId': orderId,
      'clientName': clientName,
      'clientContact': clientContact,
      'eventTime': eventTime,
      'eventTypes': eventTypes,
      'discount': discount,
      'language': language,
      'eventDate': eventDate,
      'discountRemark': discountRemark,
      'discountPercent': discountPercent,
      'extraPositions': extraPositions,
      'offerPositions': offerPositions,
      'shotsCount': shotsCount,
      'shotsPricePerPiece': shotsPricePerPiece,
      'shotsRemark': shotsRemark,
      'extraHours': extraHours,
      'extraHourRate': extraHourRate,
      'assignedEmployees': assignedEmployees,
      'serviceType': serviceType,
      'firstPositionText': firstPositionText,
      'firstPositionRemark': firstPositionRemark,
      'distanceKm': distanceKm,
      'travelCostPerKm': travelCostPerKm,
      'barCost': barCost,
      'location': location,
      'currency': currency,
    });
    return offerResult;
  }

  @override
  Future<bool> updateOrderTotals({
    required String orderId,
    required double total,
    required int distanceKm,
    required double thekeCost,
    List<String>? cocktails,
    List<String>? shots,
    String? bar,
  }) async {
    totalsCalls.add({
      'orderId': orderId,
      'total': total,
      'distanceKm': distanceKm,
      'thekeCost': thekeCost,
      'cocktails': cocktails,
      'shots': shots,
      'bar': bar,
    });
    return secondResult;
  }

  @override
  Future<bool> updateOrderCocktailsAndBar({
    required String orderId,
    List<String>? cocktails,
    List<String>? shots,
    String? bar,
  }) async {
    cocktailsCalls.add({
      'orderId': orderId,
      'cocktails': cocktails,
      'shots': shots,
      'bar': bar,
    });
    return secondResult;
  }
}

class FakeShareLinks extends ShareLinkRepository {
  final List<(OfferData, String, List<String>)> offerLinks = [];
  final List<SavedOrder> invoiceLinks = [];

  @override
  Future<String> createOfferShareLink(
    OfferData offer, {
    required String orderId,
    required List<String> bullets,
  }) async {
    offerLinks.add((offer, orderId, bullets));
    return 'ABC123';
  }

  @override
  Future<String> createInvoiceShareLink(SavedOrder order) async {
    invoiceLinks.add(order);
    return 'INV123';
  }
}

/// The offer test order: total 1000, 50 km, theke 150, two employees.
SavedOrder offerOrder({
  double total = 1000,
  int distanceKm = 50,
  double thekeCost = 150,
  String serviceType = '',
  double discountPercent = 0,
  double discount = 0,
  String discountRemark = '',
  List<Map<String, dynamic>> offerPositions = const [],
  List<Map<String, dynamic>> offerExtraPositions = const [],
  List<String> shots = const [],
  List<ShotSelection> shotSelections = const [],
  List<String> offerEventTypes = const [],
  String eventType = '',
  String offerLanguage = 'de',
  List<String> cocktails = const ['Mojito', 'Hugo'],
  List<String> assignedEmployees = const ['Ana', 'Ben'],
  List<Map<String, dynamic>> items = const [],
  String name = 'Fest',
}) => SavedOrder(
  id: 'o1',
  name: name,
  date: DateTime(2027, 5, 1),
  items: items,
  total: total,
  personCount: 40,
  drinkerType: 'normal',
  currency: 'CHF',
  status: OrderStatus.quote,
  phone: '079 111 22 33',
  location: 'Basel',
  eventTime: '18:00',
  eventType: eventType,
  serviceType: serviceType,
  distanceKm: distanceKm,
  thekeCost: thekeCost,
  cocktails: cocktails,
  shots: shots,
  shotSelections: shotSelections,
  bar: 'Theke links',
  assignedEmployees: assignedEmployees,
  offerEventTypes: offerEventTypes,
  offerDiscount: discount,
  offerDiscountPercent: discountPercent,
  offerDiscountRemark: discountRemark,
  offerPositions: offerPositions,
  offerExtraPositions: offerExtraPositions,
  offerLanguage: offerLanguage,
);

/// The invoice test order (fields mode unless [offerPositions] is given).
SavedOrder invoiceOrder({
  List<Map<String, dynamic>> offerPositions = const [],
  List<String> assignedEmployees = const ['Ana', 'Ben'],
  double discountPercent = 5,
  double discount = 0,
  String offerLanguage = 'de',
}) => SavedOrder(
  id: 'o2',
  name: 'Hochzeit',
  date: DateTime(2027, 6, 12),
  items: const [],
  total: 1000,
  personCount: 40,
  drinkerType: 'normal',
  currency: 'CHF',
  status: OrderStatus.accepted,
  location: 'Bern',
  distanceKm: 50,
  thekeCost: 100,
  cocktails: const ['Mojito'],
  shots: const ['Tequila'],
  bar: 'Mobile Bar',
  assignedEmployees: assignedEmployees,
  offerClientName: 'Anna Muster',
  offerClientContact: 'anna@x.ch',
  offerEventTime: '17:30',
  offerEventTypes: const ['wedding'],
  offerDiscountPercent: discountPercent,
  offerDiscount: discount,
  offerExtraHours: 2,
  offerExtraHourRate: 50,
  offerExtraPositions: const [
    {'name': 'Deko', 'price': 30.0, 'quantity': 2, 'remark': '', 'date': ''},
  ],
  offerPositions: offerPositions,
  offerLanguage: offerLanguage,
);
