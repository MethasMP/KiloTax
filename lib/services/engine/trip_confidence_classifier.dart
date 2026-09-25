import '../../data/models/trip.dart';
import '../tracking/trade_poi_resolver.dart';

enum ConfidenceTier {
  /// Trips during normal trade hours to trade POIs or client sites
  highConfidenceWork,

  /// Trips on weekends, late nights, or ambiguous routes requiring explicit user sign-off
  requiresUserDecision,
}

class ClassifiedTripAssessment {
  final Trip trip;
  final ConfidenceTier tier;
  final String suggestedPurpose;
  final bool suggestedBulkyTools;
  final String decisionReason;

  const ClassifiedTripAssessment({
    required this.trip,
    required this.tier,
    required this.suggestedPurpose,
    required this.suggestedBulkyTools,
    required this.decisionReason,
  });

  bool get isHighConfidence => tier == ConfidenceTier.highConfidenceWork;
}

/// Sentinel Risk Gatekeeper & Trip Confidence Classifier
/// Distinguishes safe-to-bundle routine trade travel from high-audit-risk drives (ITAA 1997 s 28-25 / TR 97/11).
class TripConfidenceClassifier {
  static ClassifiedTripAssessment assess(Trip trip) {
    final tripDate = trip.date;
    final isWeekend = tripDate.weekday == DateTime.saturday || tripDate.weekday == DateTime.sunday;
    final hour = tripDate.hour;
    final isAfterHours = hour < 6 || hour >= 19; // Typical Australian tradie hours 6:00 AM - 7:00 PM

    final dest = trip.destinationAddress ?? '';
    final orig = trip.originAddress ?? '';
    final destLower = dest.toLowerCase();
    final origLower = orig.toLowerCase();

    final poiMatch = TradePoiResolver.resolve(dest);
    final isTradeMerchant = poiMatch != null;
    final isSiteVisit = destLower.contains('site') || destLower.contains('job') || destLower.contains('client');
    final isHomeDeparture = origLower.contains('home') || origLower.contains('residence');

    // 1. Weekend Travel Sentinel Guard
    if (isWeekend) {
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.requiresUserDecision,
        suggestedPurpose: isTradeMerchant ? 'Supplies Run' : 'Client Site',
        suggestedBulkyTools: true,
        decisionReason: 'Weekend drive requires explicit trade confirmation to avoid ATO audit penalties.',
      );
    }

    // 2. Late Night Travel Guard
    if (isAfterHours && !isTradeMerchant) {
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.requiresUserDecision,
        suggestedPurpose: 'Emergency Trade Callout',
        suggestedBulkyTools: true,
        decisionReason: 'After-hours drive. Please confirm if this was an emergency job or personal journey.',
      );
    }

    // 3. Trade Merchant Run (High Confidence: Mon-Fri 6AM-7PM)
    if (isTradeMerchant) {
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.highConfidenceWork,
        suggestedPurpose: 'Supplies Run',
        suggestedBulkyTools: false,
        decisionReason: 'Trade supplies procurement at ${poiMatch.merchantName}.',
      );
    }

    // 4. Jobsite / Client Site (High Confidence)
    if (isSiteVisit) {
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.highConfidenceWork,
        suggestedPurpose: isHomeDeparture ? 'Tool Transport' : 'Client Site',
        suggestedBulkyTools: isHomeDeparture,
        decisionReason: isHomeDeparture
            ? 'Home-to-work transit with trade gear.'
            : 'Contract trade works at client site.',
      );
    }

    // 5. Default ambiguous travel
    return ClassifiedTripAssessment(
      trip: trip,
      tier: ConfidenceTier.requiresUserDecision,
      suggestedPurpose: 'Client Site',
      suggestedBulkyTools: isHomeDeparture,
      decisionReason: 'Destination not yet cataloged. Quick tap to confirm work vs private.',
    );
  }
}
