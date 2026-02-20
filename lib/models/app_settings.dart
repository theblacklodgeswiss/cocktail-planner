/// App settings loaded from Firebase.
class AppSettings {
  const AppSettings({
    this.longDistanceThresholdKm = 400,
  });

  /// Distance threshold in km for long distance pricing.
  final int longDistanceThresholdKm;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      longDistanceThresholdKm: (json['longDistanceThresholdKm'] as num?)?.toInt() ?? 400,
    );
  }

  Map<String, dynamic> toJson() => {
        'longDistanceThresholdKm': longDistanceThresholdKm,
      };

  AppSettings copyWith({int? longDistanceThresholdKm}) {
    return AppSettings(
      longDistanceThresholdKm: longDistanceThresholdKm ?? this.longDistanceThresholdKm,
    );
  }
}
