import '../../data/models/job_site.dart';
import '../../data/models/trip.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_expense.dart';
import '../tracking/trade_poi_resolver.dart';
import '../tracking/wgs84_geodesic_engine.dart';

enum ConfidenceTier {
  /// Evidence-backed work travel eligible for 1-tap user sign-off.
  highConfidenceWork,

  /// Trips requiring explicit individual confirmation of purpose and business use.
  requiresUserDecision,
}

enum ClassificationSignal {
  receiptBacked,
  jobSiteToJobSite,
  jobSiteToTradeSupplier,
  bulkyToolsHomeException,
  vehicleBluetoothMatched,
  homeCommuteGate,
  personalPoiDetected,
}

/// Optional domain context linking a trip to the user's Evidence Graph
/// (saved job sites, receipts, registered bulky tools, and paired vehicle).
class TripClassificationContext {
  final UserProfile? userProfile;
  final Vehicle? vehicle;
  final List<JobSite> jobSites;
  final List<VehicleExpense> expenses;
  final bool isVehicleBluetoothMatched;

  const TripClassificationContext({
    this.userProfile,
    this.vehicle,
    this.jobSites = const [],
    this.expenses = const [],
    this.isVehicleBluetoothMatched = false,
  });

  bool get hasRegisteredBulkyTools =>
      vehicle?.tradeToolsRegisteredAt != null ||
      (vehicle?.tradeToolsDescription?.trim().isNotEmpty ?? false);
}

class ClassifiedTripAssessment {
  final Trip trip;
  final ConfidenceTier tier;
  final String suggestedPurpose;
  final bool suggestedBulkyTools;
  final String decisionReason;
  final List<ClassificationSignal> evidenceSignals;

  const ClassifiedTripAssessment({
    required this.trip,
    required this.tier,
    required this.suggestedPurpose,
    required this.suggestedBulkyTools,
    required this.decisionReason,
    this.evidenceSignals = const [],
  });

  bool get isHighConfidence => tier == ConfidenceTier.highConfidenceWork;
}

/// Pure Evidence-Graph Trip Classifier (ATO TR 2021/1 & ITAA 1997 s 8-1 aligned).
///
/// Bare `assess(trip)` without [context] never auto-promotes unresolved trips
/// from place names or timestamps alone. Supplying [TripClassificationContext]
/// unlocks `highConfidenceWork` for 1-tap batch sign-off strictly when backed
/// by verifiable evidence (linked receipt, saved JobSite-to-JobSite run,
/// JobSite-to-Trade-Supplier run, or registered bulky-tools vehicle evidence).
class TripConfidenceClassifier {
  static const List<String> _personalPoiKeywords = [
    'school',
    'childcare',
    'kindergarten',
    'gym',
    'fitness',
    'woolworths',
    'coles',
    'aldi',
    'iga',
    'supermarket',
    'cinema',
    'westfield',
    'bws',
    'dan murphy',
  ];

  static ClassifiedTripAssessment assess(
    Trip trip, {
    TripClassificationContext? context,
  }) {
    final destination = trip.destinationAddress ?? '';
    final origin = trip.originAddress ?? '';
    final poi = TradePoiResolver.resolve(
      destination,
      persona: context?.userProfile?.tradePersona,
    );
    final originPoi = TradePoiResolver.resolve(
      origin,
      persona: context?.userProfile?.tradePersona,
    );
    final destinationLower = destination.toLowerCase();
    final originLower = origin.toLowerCase();
    final isSiteName = destinationLower.contains('site') ||
        destinationLower.contains('job') ||
        destinationLower.contains('client');

    final touchesHome = _touchesHome(
      trip: trip,
      originLower: originLower,
      destinationLower: destinationLower,
      profile: context?.userProfile,
    );

    if (trip.classification == TripClassification.personal) {
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.requiresUserDecision,
        suggestedPurpose: 'Personal',
        suggestedBulkyTools: false,
        decisionReason:
            'Marked personal. Keep private travel out of business claims.',
      );
    }

    // Without Evidence Graph context, never promote unresolved trips from names/time alone.
    if (context == null) {
      final String reason;
      if (touchesHome) {
        reason =
            'Travel involving home needs review. Confirm the business reason '
            'and any applicable exception before claiming.';
      } else if (poi != null) {
        reason = 'Possible supplies stop at ${poi.merchantName}. Confirm what '
            'this journey was for; a merchant location alone does not establish business use.';
      } else if (isSiteName) {
        reason =
            'Possible job site visit. Confirm the job and business reason; '
            'a place name alone does not establish business use.';
      } else {
        reason =
            'Confirm whether this journey was business, personal, or mixed.';
      }

      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.requiresUserDecision,
        suggestedPurpose: poi != null
            ? 'Supplies Run'
            : isSiteName
                ? 'Client Site'
                : '',
        suggestedBulkyTools: false,
        decisionReason: reason,
      );
    }

    // Evidence Graph Evaluation (with verified context)
    final signals = <ClassificationSignal>[];

    final isPersonalPoi = _personalPoiKeywords
        .any((kw) => destinationLower.contains(kw));
    if (isPersonalPoi) {
      signals.add(ClassificationSignal.personalPoiDetected);
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.requiresUserDecision,
        suggestedPurpose: 'Personal',
        suggestedBulkyTools: false,
        decisionReason:
            'Destination matches a personal location. Confirm before claiming.',
        evidenceSignals: List.unmodifiable(signals),
      );
    }

    final btMatched = context.isVehicleBluetoothMatched ||
        trip.review['vehicleBluetoothMatched'] == true ||
        trip.evidenceSource == 'native_bluetooth_auto';
    if (btMatched) {
      signals.add(ClassificationSignal.vehicleBluetoothMatched);
    }

    final originSite = _matchJobSite(
      lat: trip.startLat,
      lng: trip.startLng,
      jobId: null,
      sites: context.jobSites,
    );
    final destSite = _matchJobSite(
      lat: trip.endLat,
      lng: trip.endLng,
      jobId: trip.jobId,
      sites: context.jobSites,
    );

    final matchedReceipt = _findMatchingReceipt(trip, context.expenses);
    final hasReceiptEvidence =
        trip.linkedExpenseIds.isNotEmpty || matchedReceipt != null;

    // ATO TR 2021/1 Home Commute Gate
    if (touchesHome) {
      signals.add(ClassificationSignal.homeCommuteGate);
      final targetSite = destSite ?? originSite;
      if (context.hasRegisteredBulkyTools && targetSite != null) {
        signals.add(ClassificationSignal.bulkyToolsHomeException);
        return ClassifiedTripAssessment(
          trip: trip,
          tier: ConfidenceTier.highConfidenceWork,
          suggestedPurpose: 'Site Work (${targetSite.name}) · Bulky Tools',
          suggestedBulkyTools: true,
          decisionReason:
              'Registered bulky tools carried to saved job site "${targetSite.name}" (TR 2021/1). Tap once to confirm.',
          evidenceSignals: List.unmodifiable(signals),
        );
      }

      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.requiresUserDecision,
        suggestedPurpose: targetSite != null
            ? 'Site Work (${targetSite.name})'
            : (poi != null ? 'Supplies Run' : ''),
        suggestedBulkyTools: false,
        decisionReason:
            'Travel involving home needs review. Confirm the business reason '
            'and any applicable exception before claiming.',
        evidenceSignals: List.unmodifiable(signals),
      );
    }

    // Rule 1: Receipt-Backed Non-Home Trip (Strongest ATO Evidence)
    if (hasReceiptEvidence) {
      signals.add(ClassificationSignal.receiptBacked);
      final merchantLabel = matchedReceipt?.supplier ??
          matchedReceipt?.receiptAudit?.ocrMerchant ??
          poi?.merchantName;
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.highConfidenceWork,
        suggestedPurpose: merchantLabel != null
            ? 'Supplies Run ($merchantLabel)'
            : (destSite != null ? 'Site Work (${destSite.name})' : 'Work Supplies'),
        suggestedBulkyTools: false,
        decisionReason: merchantLabel != null
            ? 'Matched receipt from $merchantLabel substantiates this drive. Ready for 1-tap sign-off.'
            : 'Linked receipt substantiates this drive. Ready for 1-tap sign-off.',
        evidenceSignals: List.unmodifiable(signals),
      );
    }

    // Rule 2: Saved JobSite -> Saved JobSite (Workplace-to-Workplace, 100% ATO Deductible)
    if (originSite != null && destSite != null && originSite.id != destSite.id) {
      signals.add(ClassificationSignal.jobSiteToJobSite);
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.highConfidenceWork,
        suggestedPurpose: 'Site Transfer (${originSite.name} → ${destSite.name})',
        suggestedBulkyTools: false,
        decisionReason:
            'Direct travel between saved job sites "${originSite.name}" and "${destSite.name}". Ready for 1-tap sign-off.',
        evidenceSignals: List.unmodifiable(signals),
      );
    }

    // Rule 3: Saved JobSite <-> Trade Supplier (Non-Home)
    if ((originSite != null && poi != null) ||
        (destSite != null && originPoi != null)) {
      signals.add(ClassificationSignal.jobSiteToTradeSupplier);
      final siteName = (originSite ?? destSite)!.name;
      final supplierName = (poi ?? originPoi)!.merchantName;
      return ClassifiedTripAssessment(
        trip: trip,
        tier: ConfidenceTier.highConfidenceWork,
        suggestedPurpose: 'Supplies Run ($supplierName · $siteName)',
        suggestedBulkyTools: false,
        decisionReason:
            'Trade supplies run between "$siteName" and $supplierName. Ready for 1-tap sign-off.',
        evidenceSignals: List.unmodifiable(signals),
      );
    }

    // Fallback: Insufficient non-circumstantial evidence -> Individual Review
    return ClassifiedTripAssessment(
      trip: trip,
      tier: ConfidenceTier.requiresUserDecision,
      suggestedPurpose: destSite != null
          ? 'Site Work (${destSite.name})'
          : (poi != null
              ? 'Supplies Run'
              : (isSiteName ? 'Client Site' : '')),
      suggestedBulkyTools: false,
      decisionReason: poi != null
          ? 'Possible supplies stop at ${poi.merchantName}. Confirm purpose before claiming.'
          : (destSite != null
              ? 'Arrived at saved job site "${destSite.name}". Confirm departure context before claiming.'
              : (isSiteName
                  ? 'Possible job site visit. Confirm the job and business reason; '
                      'a place name alone does not establish business use.'
                  : 'Confirm whether this journey was business, personal, or mixed.')),
      evidenceSignals: List.unmodifiable(signals),
    );
  }

  static bool _touchesHome({
    required Trip trip,
    required String originLower,
    required String destinationLower,
    required UserProfile? profile,
  }) {
    if (profile != null && profile.hasHomeCoordinates) {
      if (trip.startLat != null && trip.startLng != null) {
        final d = Wgs84GeodesicEngine.calculateDistanceMeters(
          lat1: trip.startLat!,
          lon1: trip.startLng!,
          lat2: profile.homeLatitude!,
          lon2: profile.homeLongitude!,
        );
        if (d <= profile.homeRadiusMeters) return true;
      }
      if (trip.endLat != null && trip.endLng != null) {
        final d = Wgs84GeodesicEngine.calculateDistanceMeters(
          lat1: trip.endLat!,
          lon1: trip.endLng!,
          lat2: profile.homeLatitude!,
          lon2: profile.homeLongitude!,
        );
        if (d <= profile.homeRadiusMeters) return true;
      }
    }
    return originLower.contains('home') ||
        originLower.contains('residence') ||
        destinationLower.contains('home') ||
        destinationLower.contains('residence');
  }

  static JobSite? _matchJobSite({
    required double? lat,
    required double? lng,
    required String? jobId,
    required List<JobSite> sites,
  }) {
    if (jobId != null && jobId.isNotEmpty) {
      for (final site in sites) {
        if (site.isActive && site.id == jobId) return site;
      }
    }
    if (lat == null || lng == null) return null;
    for (final site in sites) {
      if (site.isActive && site.containsCoordinate(lat: lat, lng: lng)) {
        return site;
      }
    }
    return null;
  }

  static VehicleExpense? _findMatchingReceipt(
    Trip trip,
    List<VehicleExpense> expenses,
  ) {
    final anchorTime = trip.stoppedAt ?? trip.date;
    for (final expense in expenses) {
      if (expense.isDeleted) continue;
      if (expense.linkedTripId == trip.id) return expense;
      if (expense.vehicleId != trip.vehicleId) continue;

      final minutesDiff = expense.date.difference(anchorTime).inMinutes.abs();
      if (minutesDiff <= 30) {
        return expense;
      }
    }
    return null;
  }
}
