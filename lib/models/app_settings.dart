/// App settings loaded from Firebase.
class AppSettings {
  const AppSettings({
    this.longDistanceThresholdKm = 400,
    this.microsoftClientId,
    this.microsoftTenantId = 'common',
    // Company info
    this.companyName = 'Black Lodge',
    this.companyOwner = 'Mario Kantharoobarajah',
    this.companyStreet = 'Birkenstrasse 3',
    this.companyCity = 'CH-4123 Allschwil',
    this.companyPhone = '+41 79 778 48 61',
    this.companyEmail = 'the.blacklodge@outlook.com',
    this.bankIban = 'CH86 0020 8208 1176 8440 B',
    this.twintNumber = '+41 79 778 48 61',
    this.geminiApiKey,
  });

  /// Distance threshold in km for long distance pricing.
  final int longDistanceThresholdKm;

  /// Microsoft Azure App Client ID for Graph API.
  final String? microsoftClientId;

  /// Microsoft Azure Tenant ID (default: 'common' for any account).
  final String microsoftTenantId;

  // Company info fields
  final String companyName;
  final String companyOwner;
  final String companyStreet;
  final String companyCity;
  final String companyPhone;
  final String companyEmail;
  final String bankIban;
  final String twintNumber;

  /// Gemini API key for AI-powered shopping list generation.
  final String? geminiApiKey;

  /// Returns the full company address as a list of lines (for PDF).
  List<String> get addressLines => [
        companyName,
        companyOwner,
        companyStreet,
        companyCity,
        'Telefon: $companyPhone',
        'E-Mail: $companyEmail',
      ];

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      longDistanceThresholdKm: (json['longDistanceThresholdKm'] as num?)?.toInt() ?? 400,
      microsoftClientId: json['microsoftClientId'] as String?,
      microsoftTenantId: json['microsoftTenantId'] as String? ?? 'common',
      companyName: json['companyName'] as String? ?? 'Black Lodge',
      companyOwner: json['companyOwner'] as String? ?? 'Mario Kantharoobarajah',
      companyStreet: json['companyStreet'] as String? ?? 'Birkenstrasse 3',
      companyCity: json['companyCity'] as String? ?? 'CH-4123 Allschwil',
      companyPhone: json['companyPhone'] as String? ?? '+41 79 778 48 61',
      companyEmail: json['companyEmail'] as String? ?? 'the.blacklodge@outlook.com',
      bankIban: json['bankIban'] as String? ?? 'CH86 0020 8208 1176 8440 B',
      twintNumber: json['twintNumber'] as String? ?? '+41 79 778 48 61',
      geminiApiKey: json['geminiApiKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'longDistanceThresholdKm': longDistanceThresholdKm,
        if (microsoftClientId != null) 'microsoftClientId': microsoftClientId,
        'microsoftTenantId': microsoftTenantId,
        'companyName': companyName,
        'companyOwner': companyOwner,
        'companyStreet': companyStreet,
        'companyCity': companyCity,
        'companyPhone': companyPhone,
        'companyEmail': companyEmail,
        'bankIban': bankIban,
        'twintNumber': twintNumber,
        if (geminiApiKey != null) 'geminiApiKey': geminiApiKey,
      };

  AppSettings copyWith({
    int? longDistanceThresholdKm,
    String? microsoftClientId,
    String? microsoftTenantId,
    String? companyName,
    String? companyOwner,
    String? companyStreet,
    String? companyCity,
    String? companyPhone,
    String? companyEmail,
    String? bankIban,
    String? twintNumber,
    String? geminiApiKey,
  }) {
    return AppSettings(
      longDistanceThresholdKm: longDistanceThresholdKm ?? this.longDistanceThresholdKm,
      microsoftClientId: microsoftClientId ?? this.microsoftClientId,
      microsoftTenantId: microsoftTenantId ?? this.microsoftTenantId,
      companyName: companyName ?? this.companyName,
      companyOwner: companyOwner ?? this.companyOwner,
      companyStreet: companyStreet ?? this.companyStreet,
      companyCity: companyCity ?? this.companyCity,
      companyPhone: companyPhone ?? this.companyPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      bankIban: bankIban ?? this.bankIban,
      twintNumber: twintNumber ?? this.twintNumber,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}
