/// Event type for an offer
enum EventType {
  birthday,
  wedding,
  company,
  babyshower,
  other,
}

/// Extra position (custom line item) for offers and invoices
class ExtraPosition {
  const ExtraPosition({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.remark = '',
  });

  final String name;
  final double price;
  final int quantity;
  final String remark;

  /// Total price = price × quantity
  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'quantity': quantity,
        'remark': remark,
      };

  factory ExtraPosition.fromJson(Map<String, dynamic> json) {
    return ExtraPosition(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      remark: json['remark'] as String? ?? '',
    );
  }

  ExtraPosition copyWith({
    String? name,
    double? price,
    int? quantity,
    String? remark,
  }) {
    return ExtraPosition(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      remark: remark ?? this.remark,
    );
  }
}

/// Data class holding all fields needed to generate an offer document (Angebot)
class OfferData {
  const OfferData({
    required this.orderName,
    required this.eventDate,
    required this.eventTime,
    required this.currency,
    required this.guestCount,
    required this.editorName,
    required this.clientName,
    required this.clientContact,
    required this.eventTypes,
    required this.cocktails,
    required this.shots,
    required this.barDescription,
    required this.orderTotal,
    required this.distanceKm,
    required this.travelCostPerKm,
    required this.barCost,
    required this.discount,
    required this.additionalInfo,
    required this.language,
    this.extraPositions = const [],
    this.assignedEmployees = const [],
  });

  /// Event / order name (from SavedOrder.name)
  final String orderName;

  /// Date of the event (from SavedOrder.date)
  final DateTime eventDate;

  /// Start time of the event (e.g. "17:30")
  final String eventTime;

  /// Currency code, e.g. "EUR" or "CHF"
  final String currency;

  /// Number of guests (from SavedOrder.personCount)
  final int guestCount;

  /// Name of the person handling the offer (Bearbeiter)
  final String editorName;

  /// Name of the client (Auftraggeber)
  final String clientName;

  /// Contact info of the client
  final String clientContact;

  /// Selected event types (one or more)
  final Set<EventType> eventTypes;

  /// List of cocktail names to show on offer
  final List<String> cocktails;

  /// List of shot names (empty = not included)
  final List<String> shots;

  /// Bar description (empty = not included)
  final String barDescription;

  /// Total from the order (already includes travel & theke costs)
  final double orderTotal;

  /// One-way distance to venue in km (used for travel cost)
  final int distanceKm;

  /// Price per km for travel (return trip = 2 × distanceKm × travelCostPerKm)
  final double travelCostPerKm;

  /// Cost of mobile bar/Theke (0 = not included)
  final double barCost;

  /// Family/friend discount amount (0 = none)
  final double discount;

  /// Editable additional information block (Zusatzinformation)
  final String additionalInfo;

  /// Output language: 'de' or 'en'
  final String language;

  /// Extra custom positions (line items)
  final List<ExtraPosition> extraPositions;
  /// Assigned employee names for this offer (used to show number of barkeepers)
  final List<String> assignedEmployees;

  double get travelCostTotal => distanceKm * 2 * travelCostPerKm;

  /// Sum of all extra positions
  double get extraPositionsTotal =>
      extraPositions.fold(0.0, (sum, pos) => sum + pos.price);

  /// Cocktail & Barservice cost (orderTotal minus travel and theke)
  double get barServiceCost => orderTotal - travelCostTotal - barCost;

  /// Grand total = orderTotal + extraPositions - discount
  double get grandTotal => orderTotal + extraPositionsTotal - discount;

  /// Default Zusatzinformation text in German
  static const String defaultAdditionalInfoDe =
      '"BlackLodge" ist für den Einkauf und Zubereitung der Cocktails verantwortlich. '
      'Dies betrifft auch die Hartplastikbecher, Süssigkeiten, Strohhalme, Früchte und den dazugehörigen Alkohol.\n'
      'Eine "Bartheke" kann von uns zur Verfügung gestellt werden gegen Aufpreis (s. oben).\n\n'
      'Die Zeit für die Anfahrt, Abfahrt und Aufbau gehören nicht zu den "5h Cocktail & Barservice", '
      'werden dem Kunden dennoch nicht verrechnet. Unser Team wird mindestens 1 Stunde vor Auftragsbeginn '
      'am Standort erscheinen und den Aufbau beginnen, aber auch hier richten wir uns gern nach Kundenwunsch.\n\n'
      'Dieses Angebot ist 14 Tage gültig, sollte das Angebot erst zu einem späteren Zeitpunkt angenommen werden, '
      'kann sich der Preis ändern oder der Auftrag sogar vom Auftragnehmer abgelehnt werden!\n'
      'Nach Angebot Annahme wird ein Auftragsdokument mit Anzahlungsanweisung an den Auftraggeber gesandt.';

  /// Default Zusatzinformation text in English
  static const String defaultAdditionalInfoEn =
      '"BlackLodge" is responsible for purchasing and preparing the cocktails. '
      'This includes hard plastic cups, sweets, straws, fruits, and the associated alcohol.\n'
      'A "bar counter" can be provided by us for an additional charge (see above).\n\n'
      'The time for arrival, departure and setup is not included in the "5h Cocktail & Bar Service", '
      'but will not be charged to the client. Our team will arrive at the venue at least 1 hour before '
      'the start of the assignment and begin setup, but we are also happy to accommodate the client\'s wishes.\n\n'
      'This offer is valid for 14 days; should the offer be accepted at a later point in time, '
      'the price may change or the assignment may even be declined by the contractor!\n'
      'After the offer is accepted, a contract document with deposit instructions will be sent to the client.';
}
