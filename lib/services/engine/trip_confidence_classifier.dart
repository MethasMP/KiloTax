import '../../data/models/trip.dart';
import '../tracking/trade_poi_resolver.dart';

enum ConfidenceTier {
  /// Reserved for a future evidence-backed, user-authorized review rule.
  highConfidenceWork,

  /// Trips requiring explicit confirmation of purpose and business use.
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

/// Suggests review context, never tax eligibility from a place name or time.
/// The current Trip model has no confirmed commute/exception evidence, so
/// unresolved trips must stay in individual review rather than preselected batches.
class TripConfidenceClassifier {
  static ClassifiedTripAssessment assess(Trip trip) {
    final destination = trip.destinationAddress ?? '';
    final poi = TradePoiResolver.resolve(destination);
    final destinationLower = destination.toLowerCase();
    final isSite = destinationLower.contains('site') ||
        destinationLower.contains('job') ||
        destinationLower.contains('client');
    final originLower = (trip.originAddress ?? '').toLowerCase();
    final touchesHome = originLower.contains('home') ||
        originLower.contains('residence') ||
        destinationLower.contains('home') ||
        destinationLower.contains('residence');

    final String reason;
    if (trip.classification == TripClassification.personal) {
      reason = 'Marked personal. Keep private travel out of business claims.';
    } else if (touchesHome) {
      reason =
          'Travel involving home needs review. Confirm the business reason '
          'and any applicable exception before claiming.';
    } else if (poi != null) {
      reason = 'Possible supplies stop at ${poi.merchantName}. Confirm what '
          'this journey was for; a merchant location alone does not establish business use.';
    } else if (isSite) {
      reason = 'Possible job site visit. Confirm the job and business reason; '
          'a place name alone does not establish business use.';
    } else {
      reason = 'Confirm whether this journey was business, personal, or mixed.';
    }

    return ClassifiedTripAssessment(
      trip: trip,
      tier: ConfidenceTier.requiresUserDecision,
      suggestedPurpose: trip.classification == TripClassification.personal
          ? 'Personal'
          : poi != null
              ? 'Supplies Run'
              : isSite
                  ? 'Client Site'
                  : '',
      suggestedBulkyTools: false,
      decisionReason: reason,
    );
  }
}
