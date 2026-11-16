import 'trade_persona.dart';

/// Immutable model representing the user's home base and tax profile settings.
/// Used for Home Base Geofencing (TR 2021/1) to deterministically classify
/// commute origins and destinations via precise coordinates rather than brittle strings.
class UserProfile {
  final String? taxpayerName;
  final String? abn;
  final String? homeAddress;
  final double? homeLatitude;
  final double? homeLongitude;
  final double homeRadiusMeters;
  final TradePersona tradePersona;

  const UserProfile({
    this.taxpayerName,
    this.abn,
    this.homeAddress,
    this.homeLatitude,
    this.homeLongitude,
    this.homeRadiusMeters = 200.0,
    this.tradePersona = TradePersona.otherSoleTrader,
  });

  bool get hasHomeCoordinates => homeLatitude != null && homeLongitude != null;

  UserProfile copyWith({
    String? taxpayerName,
    String? abn,
    String? homeAddress,
    double? homeLatitude,
    double? homeLongitude,
    double? homeRadiusMeters,
    TradePersona? tradePersona,
  }) {
    return UserProfile(
      taxpayerName: taxpayerName ?? this.taxpayerName,
      abn: abn ?? this.abn,
      homeAddress: homeAddress ?? this.homeAddress,
      homeLatitude: homeLatitude ?? this.homeLatitude,
      homeLongitude: homeLongitude ?? this.homeLongitude,
      homeRadiusMeters: homeRadiusMeters ?? this.homeRadiusMeters,
      tradePersona: tradePersona ?? this.tradePersona,
    );
  }

  Map<String, dynamic> toJson() => {
        if (taxpayerName != null) 'taxpayerName': taxpayerName,
        if (abn != null) 'abn': abn,
        if (homeAddress != null) 'homeAddress': homeAddress,
        if (homeLatitude != null) 'homeLatitude': homeLatitude,
        if (homeLongitude != null) 'homeLongitude': homeLongitude,
        'homeRadiusMeters': homeRadiusMeters,
        'tradePersona': tradePersona.id,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      taxpayerName:
          json['taxpayerName'] as String? ?? json['taxpayer_name'] as String?,
      abn: json['abn'] as String?,
      homeAddress:
          json['homeAddress'] as String? ?? json['home_address'] as String?,
      homeLatitude: (json['homeLatitude'] ?? json['home_latitude']) != null
          ? (json['homeLatitude'] ?? json['home_latitude'] as num).toDouble()
          : null,
      homeLongitude: (json['homeLongitude'] ?? json['home_longitude']) != null
          ? (json['homeLongitude'] ?? json['home_longitude'] as num).toDouble()
          : null,
      homeRadiusMeters:
          (json['homeRadiusMeters'] ?? json['home_radius_meters'] as num?)
                  ?.toDouble() ??
              200.0,
      tradePersona: TradePersonaMetadata.fromId(
          (json['tradePersona'] ?? json['trade_persona']) as String?),
    );
  }
}
