import '../tracking/trade_poi_resolver.dart';

/// Synthesizes dynamic, non-repetitive, and ATO audit-proof Purpose descriptions.
/// Keeps UI descriptions clean & human (Apple standard) while generating rigorous,
/// context-rich legal narratives for accountants and tax auditors (ITAA 1997).
class PurposeSynthesizerService {
  /// Converts a front-end choice and destination into a legally substantiated ATO purpose description.
  static String synthesize({
    required String selectedPurpose,
    required String? destination,
    bool bulkyToolsCarried = false,
    String? jobReference,
  }) {
    final dest = (destination != null && destination.trim().isNotEmpty)
        ? destination.trim()
        : 'Jobsite';

    final jobSuffix = (jobReference != null && jobReference.trim().isNotEmpty)
        ? ' [Ref: ${jobReference.trim()}]'
        : '';

    // 1. Check for Australian Trade Merchant POI match
    final poiMatch = TradePoiResolver.resolve(dest);

    // Normalize purpose selection
    final normalized = selectedPurpose.toLowerCase();

    // 2. Heavy Tools & Equipment (ITAA 1997 s 8-1 Exemption)
    if (bulkyToolsCarried ||
        normalized.contains('tool') ||
        normalized.contains('heavy') ||
        normalized.contains('bulky')) {
      return 'Transit with essential heavy trade equipment (>20kg) to $dest per ITAA 1997 s 8-1$jobSuffix';
    }

    // 3. Trade Supplies & Consumables Run
    if (normalized.contains('suppl') ||
        normalized.contains('bunning') ||
        normalized.contains('material') ||
        poiMatch != null) {
      if (poiMatch != null) {
        return 'Trade consumables & parts procurement at ${poiMatch.merchantName} ($dest)$jobSuffix';
      }
      return 'Procurement of trade materials and consumables for $dest$jobSuffix';
    }

    // 4. Client / Job Site Visit (TR 95/34 Itinerant Schedule)
    if (normalized.contains('client') ||
        normalized.contains('job') ||
        normalized.contains('site') ||
        normalized.contains('work')) {
      return 'Client site visit & contract trade works at $dest (TR 95/34)$jobSuffix';
    }

    // 5. Personal Drive
    if (normalized.contains('personal') || normalized.contains('private')) {
      return 'Personal journey';
    }

    // Fallback: Preserve original text with destination anchor
    return '$selectedPurpose - $dest$jobSuffix';
  }

  /// Returns a clean, human-friendly 2-word label for the UI (Apple Human Interface Guidelines)
  static String getHumanLabel(String rawPurpose) {
    final lower = rawPurpose.toLowerCase();
    if (lower.contains('tool') || lower.contains('heavy') || lower.contains('bulky')) {
      return 'Tool Transport';
    }
    if (lower.contains('suppl') || lower.contains('bunning') || lower.contains('material')) {
      return 'Supplies Run';
    }
    if (lower.contains('personal') || lower.contains('private')) {
      return 'Personal';
    }
    return 'Client Site';
  }
}
