/// High-precision Australian Trade Merchant & POI Classification Engine.
/// Detects prominent Australian hardware, plumbing, electrical, and tool suppliers
/// from OpenStreetMap tags or reverse-geocoded place names.
class TradePoiResolver {
  static const Map<String, String> _knownTradeMerchants = {
    // Hardware & Building
    'bunnings': 'Bunnings Warehouse',
    'mitre 10': 'Mitre 10',
    'bowens': 'Bowens Timber & Hardware',
    'home timber': 'Home Timber & Hardware',
    'stratco': 'Stratco',
    // Plumbing & Gas & HVAC
    'reece': 'Reece Plumbing',
    'tradelink': 'Tradelink',
    'actrol': 'Actrol HVAC',
    'plumbtec': 'Plumbtec',
    'metalflex': 'Metalflex',
    // Electrical & Data
    "middy's": "Middy's Electrical",
    'middys': "Middy's Electrical",
    'lawrence & hanson': 'Lawrence & Hanson (L&H)',
    'l&h': 'Lawrence & Hanson (L&H)',
    'rexel': 'Rexel Electrical',
    'awm': 'AWM Electrical',
    'haymans': 'Haymans Electrical',
    'turrk': 'Turrk Electrical',
    // Tools & Equipment
    'total tools': 'Total Tools',
    'sydney tools': 'Sydney Tools',
    'tradetools': 'TradeTools',
    'gasweld': 'Gasweld Tools',
    'jaycar': 'Jaycar Electronics',
    // Paint & Finishes
    'dulux': 'Dulux Trade Centre',
    'taubmans': 'Taubmans Trade Centre',
    'bristol': 'Bristol Paints',
    'wattyl': 'Wattyl Paint Centre',
  };

  /// Evaluates an address, place name, or POI tag to determine if it is an Australian Trade Merchant.
  /// Returns a [TradePoiMatch] if recognized, or null if it appears to be a general location.
  static TradePoiMatch? resolve(String? placeNameOrAddress) {
    if (placeNameOrAddress == null || placeNameOrAddress.trim().isEmpty) {
      return null;
    }

    final lower = placeNameOrAddress.toLowerCase();

    for (final entry in _knownTradeMerchants.entries) {
      if (lower.contains(entry.key)) {
        return TradePoiMatch(
          merchantName: entry.value,
          keywordMatched: entry.key,
          suggestedPurpose: 'Supplies Run',
          auditCategory: 'Trade Supplies / Materials Run',
        );
      }
    }

    return null;
  }
}

class TradePoiMatch {
  final String merchantName;
  final String keywordMatched;
  final String suggestedPurpose;
  final String auditCategory;

  const TradePoiMatch({
    required this.merchantName,
    required this.keywordMatched,
    required this.suggestedPurpose,
    required this.auditCategory,
  });
}
