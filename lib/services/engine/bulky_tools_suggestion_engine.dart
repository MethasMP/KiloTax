import '../../data/models/trip.dart';
import '../tracking/trade_poi_resolver.dart';

/// Suggestion assessment for Bulky Tools exemption (ITAA 1997 s 8-1).
class BulkyToolsSuggestion {
  final bool isSuggested;
  final bool isSupplierStop;
  final String? matchedKeyword;
  final String? matchedLocation;
  final String badgeText;
  final String reason;

  const BulkyToolsSuggestion({
    required this.isSuggested,
    this.isSupplierStop = false,
    this.matchedKeyword,
    this.matchedLocation,
    this.badgeText = 'Stopped at trade supplier',
    this.reason = 'Stopped at trade supplier',
  });

  static const none = BulkyToolsSuggestion(
    isSuggested: false,
    badgeText: '',
    reason: '',
  );
}

/// Zero-Friction Heuristic Engine for Bulky Tools Travel Exemption.
/// Detects trade suppliers, hardware stores, and construction/client sites.
class BulkyToolsSuggestionEngine {
  static const List<String> _tradeSupplierKeywords = [
    'bunnings',
    'middy',
    'rexel',
    'trade',
    'electrical wholesaler',
    'hardware',
    'timber',
    'reece',
    'tradelink',
    'actrol',
    'plumbtec',
    'metalflex',
    'lawrence & hanson',
    'l&h',
    'awm',
    'haymans',
    'turrk',
    'total tools',
    'sydney tools',
    'gasweld',
    'jaycar',
    'dulux',
    'taubmans',
    'bristol',
    'wattyl',
  ];

  static const List<String> _constructionSiteKeywords = [
    'site',
    'job',
    'construction',
    'works',
    'workshop',
    'depot',
    'build',
  ];

  /// Evaluates a [Trip] for Bulky Tools eligibility suggestion.
  static BulkyToolsSuggestion evaluate(Trip trip) {
    return evaluateLocations(
      origin: trip.originAddress,
      destination: trip.destinationAddress,
      purpose: trip.purpose,
      jobReference: trip.jobReference,
    );
  }

  /// Convenience boolean check.
  static bool isSuggested(Trip trip) => evaluate(trip).isSuggested;

  /// Evaluates raw location and contextual strings.
  static BulkyToolsSuggestion evaluateLocations({
    String? origin,
    String? destination,
    String? purpose,
    String? jobReference,
  }) {
    final orig = origin ?? '';
    final dest = destination ?? '';
    final origLower = orig.toLowerCase();
    final destLower = dest.toLowerCase();

    // 1. Trade POI lookup from catalog
    final poiDest = TradePoiResolver.resolve(dest);
    if (poiDest != null) {
      return BulkyToolsSuggestion(
        isSuggested: true,
        isSupplierStop: true,
        matchedKeyword: poiDest.keywordMatched,
        matchedLocation: dest,
        badgeText: 'Stopped at trade supplier',
        reason: 'Stopped at trade supplier (${poiDest.merchantName})',
      );
    }

    final poiOrig = TradePoiResolver.resolve(orig);
    if (poiOrig != null) {
      return BulkyToolsSuggestion(
        isSuggested: true,
        isSupplierStop: true,
        matchedKeyword: poiOrig.keywordMatched,
        matchedLocation: orig,
        badgeText: 'Stopped at trade supplier',
        reason: 'Stopped at trade supplier (${poiOrig.merchantName})',
      );
    }

    // 2. Trade supplier keywords check
    for (final kw in _tradeSupplierKeywords) {
      if (origLower.contains(kw)) {
        return BulkyToolsSuggestion(
          isSuggested: true,
          isSupplierStop: true,
          matchedKeyword: kw,
          matchedLocation: orig,
          badgeText: 'Stopped at trade supplier',
          reason: 'Stopped at trade supplier',
        );
      }
      if (destLower.contains(kw)) {
        return BulkyToolsSuggestion(
          isSuggested: true,
          isSupplierStop: true,
          matchedKeyword: kw,
          matchedLocation: dest,
          badgeText: 'Stopped at trade supplier',
          reason: 'Stopped at trade supplier',
        );
      }
    }

    // 3. Construction site / Job keywords check
    for (final kw in _constructionSiteKeywords) {
      if (origLower.contains(kw)) {
        return BulkyToolsSuggestion(
          isSuggested: true,
          isSupplierStop: false,
          matchedKeyword: kw,
          matchedLocation: orig,
          badgeText: 'Job site trip',
          reason: 'Job site trip',
        );
      }
      if (destLower.contains(kw)) {
        return BulkyToolsSuggestion(
          isSuggested: true,
          isSupplierStop: false,
          matchedKeyword: kw,
          matchedLocation: dest,
          badgeText: 'Job site trip',
          reason: 'Job site trip',
        );
      }
    }

    // 4. Job reference context
    if (jobReference != null && jobReference.trim().isNotEmpty) {
      final jobLower = jobReference.toLowerCase();
      for (final kw in _tradeSupplierKeywords) {
        if (jobLower.contains(kw)) {
          return BulkyToolsSuggestion(
            isSuggested: true,
            isSupplierStop: true,
            matchedKeyword: kw,
            matchedLocation: jobReference,
            badgeText: 'Stopped at trade supplier',
            reason: 'Stopped at trade supplier',
          );
        }
      }
      for (final kw in _constructionSiteKeywords) {
        if (jobLower.contains(kw)) {
          return BulkyToolsSuggestion(
            isSuggested: true,
            isSupplierStop: false,
            matchedKeyword: kw,
            matchedLocation: jobReference,
            badgeText: 'Job site trip',
            reason: 'Job site trip',
          );
        }
      }
    }

    // 5. Purpose keywords fallback
    if (purpose != null && purpose.trim().isNotEmpty) {
      final purpLower = purpose.toLowerCase();
      if (purpLower.contains('bunning') ||
          purpLower.contains('supplier') ||
          purpLower.contains('material')) {
        return const BulkyToolsSuggestion(
          isSuggested: true,
          isSupplierStop: true,
          matchedKeyword: 'supplier',
          badgeText: 'Stopped at trade supplier',
          reason: 'Stopped at trade supplier',
        );
      }
      if (purpLower.contains('site') || purpLower.contains('job')) {
        return const BulkyToolsSuggestion(
          isSuggested: true,
          isSupplierStop: false,
          matchedKeyword: 'site',
          badgeText: 'Job site trip',
          reason: 'Job site trip',
        );
      }
    }

    return BulkyToolsSuggestion.none;
  }
}
