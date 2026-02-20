/// App settings loaded from Firebase.
class AppSettings {
  const AppSettings({
    this.longDistanceThresholdKm = 400,
    this.microsoftClientId,
    this.microsoftTenantId = 'common',
  });

  /// Distance threshold in km for long distance pricing.
  final int longDistanceThresholdKm;

  /// Microsoft Azure App Client ID for Graph API.
  final String? microsoftClientId;

  /// Microsoft Azure Tenant ID (default: 'common' for any account).
  final String microsoftTenantId;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      longDistanceThresholdKm: (json['longDistanceThresholdKm'] as num?)?.toInt() ?? 400,
      microsoftClientId: json['microsoftClientId'] as String?,
      microsoftTenantId: json['microsoftTenantId'] as String? ?? 'common',
    );
  }

  Map<String, dynamic> toJson() => {
        'longDistanceThresholdKm': longDistanceThresholdKm,
        if (microsoftClientId != null) 'microsoftClientId': microsoftClientId,
        'microsoftTenantId': microsoftTenantId,
      };

  AppSettings copyWith({
    int? longDistanceThresholdKm,
    String? microsoftClientId,
    String? microsoftTenantId,
  }) {
    return AppSettings(
      longDistanceThresholdKm: longDistanceThresholdKm ?? this.longDistanceThresholdKm,
      microsoftClientId: microsoftClientId ?? this.microsoftClientId,
      microsoftTenantId: microsoftTenantId ?? this.microsoftTenantId,
    );
  }
}
