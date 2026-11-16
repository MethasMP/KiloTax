import '../../data/models/trade_persona.dart';
import '../tracking/trade_poi_resolver.dart';

/// Synthesizes dynamic, non-repetitive, and ATO audit-proof Purpose descriptions.
/// Keeps UI descriptions clean & human (Apple standard) while generating rigorous,
/// context-rich legal narratives for accountants and tax auditors (ITAA 1997).
class PurposeSynthesizerService {
  /// Words or phrases rejected as vague or non-compliant under ATO audit standards
  /// unless sufficiently contextualized.
  static const Set<String> _vaguePurposes = {
    'work',
    'business',
    'job',
    'client',
    'meeting',
    'drive',
    'site visit',
    'errand',
  };

  /// Anti-vagueness validator: checks whether a purpose string meets ATO audit specificity.
  /// Rejects strings that are shorter than 5 characters or match vague keywords.
  static bool isValidBusinessPurpose(String purpose) {
    final trimmed = purpose.trim();
    if (trimmed.length < 5) {
      return false;
    }

    final lower = trimmed.toLowerCase();
    if (_vaguePurposes.contains(lower)) {
      return false;
    }

    return true;
  }

  /// Converts a front-end choice and destination into a legally substantiated ATO purpose description.
  /// Automatically connects to [TradePoiResolver] if a merchant (Bunnings, Reece, Middy's, Mitre 10, etc.)
  /// is matched either in the destination or purpose input.
  static String synthesize({
    required String selectedPurpose,
    required String? destination,
    bool bulkyToolsCarried = false,
    String? jobReference,
    TradePersona? persona,
  }) {
    final dest = (destination != null && destination.trim().isNotEmpty)
        ? destination.trim()
        : 'Jobsite';

    final jobSuffix = (jobReference != null && jobReference.trim().isNotEmpty)
        ? ' [Ref: ${jobReference.trim()}]'
        : '';

    // Auto-resolve merchant from destination or purpose input, taking persona priorities into account
    final poiMatch = TradePoiResolver.resolve(dest, persona: persona) ??
        TradePoiResolver.resolve(selectedPurpose, persona: persona);

    // Normalize purpose selection
    final normalized = selectedPurpose.toLowerCase();

    // If persona defaults to bulky tools or explicitly flagged
    final hasBulkyTools = bulkyToolsCarried ||
        (persona != null && persona.defaultBulkyToolsCarried);

    if (hasBulkyTools ||
        normalized.contains('tool') ||
        normalized.contains('heavy') ||
        normalized.contains('bulky')) {
      final tradeTag = persona != null ? ' (${persona.title})' : '';
      return 'Transit with essential heavy trade equipment (>20kg) to $dest per ITAA 1997 s 8-1$tradeTag$jobSuffix';
    }

    if (normalized.contains('suppl') ||
        normalized.contains('bunning') ||
        normalized.contains('material') ||
        poiMatch != null) {
      if (poiMatch != null) {
        return 'Trade consumables & parts procurement at ${poiMatch.merchantName} ($dest)$jobSuffix';
      }
      return 'Procurement of trade materials and consumables for $dest$jobSuffix';
    }

    if (normalized.contains('client') ||
        normalized.contains('job') ||
        normalized.contains('site') ||
        normalized.contains('work')) {
      return 'Client site visit & contract trade works at $dest (TR 95/34)$jobSuffix';
    }

    if (normalized.contains('personal') || normalized.contains('private')) {
      return 'Personal journey';
    }

    // Fallback: Preserve original text with destination anchor
    return '$selectedPurpose - $dest$jobSuffix';
  }

  /// Returns a clean, human-friendly 2-word label for the UI (Apple Human Interface Guidelines)
  static String getHumanLabel(String rawPurpose) {
    final lower = rawPurpose.toLowerCase();
    if (lower.contains('tool') ||
        lower.contains('heavy') ||
        lower.contains('bulky')) {
      return 'Tool Transport';
    }
    if (lower.contains('suppl') ||
        lower.contains('bunning') ||
        lower.contains('material')) {
      return 'Supplies Run';
    }
    if (lower.contains('personal') || lower.contains('private')) {
      return 'Personal';
    }
    return 'Client Site';
  }
}
