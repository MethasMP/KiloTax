import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Trade Persona classification under Australian Tax & Industry Standards.
/// Influences default vehicle suggestions, trade merchant prioritization in POI resolution,
/// default bulky tool deduction applicability, and quick-purpose presets.
enum TradePersona {
  sparky, // Electrician / Data Cabler
  plumber, // Plumber / Gasfitter / HVAC
  builder, // Carpenter / Builder / Concreter
  painter, // Painter / Finishes / Plasterer
  landscaper, // Landscaper / Arborist / Earthmoving
  otherSoleTrader, // Other Sole Trader / Mobile Professional
}

extension TradePersonaMetadata on TradePersona {
  String get id {
    switch (this) {
      case TradePersona.sparky:
        return 'sparky';
      case TradePersona.plumber:
        return 'plumber';
      case TradePersona.builder:
        return 'builder';
      case TradePersona.painter:
        return 'painter';
      case TradePersona.landscaper:
        return 'landscaper';
      case TradePersona.otherSoleTrader:
        return 'other_sole_trader';
    }
  }

  String get title {
    switch (this) {
      case TradePersona.sparky:
        return 'Sparky';
      case TradePersona.plumber:
        return 'Plumber / Gas / HVAC';
      case TradePersona.builder:
        return 'Chipper / Builder';
      case TradePersona.painter:
        return 'Painter / Finishes';
      case TradePersona.landscaper:
        return 'Landscaper / Earthmoving';
      case TradePersona.otherSoleTrader:
        return 'Other Sole Trader';
    }
  }

  String get subtitle {
    switch (this) {
      case TradePersona.sparky:
        return 'Electrical, Solar, Data';
      case TradePersona.plumber:
        return 'Plumbing, Drainage, Aircon';
      case TradePersona.builder:
        return 'Carpentry, Framing, Roofing';
      case TradePersona.painter:
        return 'Painting, Plastering, Tiling';
      case TradePersona.landscaper:
        return 'Gardening, Fencing, Paving';
      case TradePersona.otherSoleTrader:
        return 'Tradie, Subbie, Field Tech';
    }
  }

  IconData get icon {
    switch (this) {
      case TradePersona.sparky:
        return LucideIcons.zap;
      case TradePersona.plumber:
        return LucideIcons.wrench;
      case TradePersona.builder:
        return LucideIcons.hammer;
      case TradePersona.painter:
        return LucideIcons.paintbrush;
      case TradePersona.landscaper:
        return LucideIcons.shovel;
      case TradePersona.otherSoleTrader:
        return LucideIcons.briefcase;
    }
  }

  /// True if trade typically involves transport of heavy/bulky tools (>20kg)
  /// establishing ITAA 1997 s 8-1 home-to-work travel substantiation.
  bool get defaultBulkyToolsCarried {
    switch (this) {
      case TradePersona.sparky:
      case TradePersona.plumber:
      case TradePersona.builder:
      case TradePersona.landscaper:
        return true;
      case TradePersona.painter:
      case TradePersona.otherSoleTrader:
        return false;
    }
  }

  /// Primary trade merchants prioritized in POI resolution and suggestions.
  List<String> get priorityMerchants {
    switch (this) {
      case TradePersona.sparky:
        return ["middy's", 'lawrence & hanson', 'l&h', 'rexel', 'awm', 'haymans', 'bunnings'];
      case TradePersona.plumber:
        return ['reece', 'tradelink', 'actrol', 'plumbtec', 'metalflex', 'bunnings'];
      case TradePersona.builder:
        return ['bowens', 'bunnings', 'mitre 10', 'stratco', 'total tools', 'sydney tools'];
      case TradePersona.painter:
        return ['dulux', 'taubmans', 'bristol', 'wattyl', 'bunnings'];
      case TradePersona.landscaper:
        return ['bunnings', 'mitre 10', 'stratco', 'total tools'];
      case TradePersona.otherSoleTrader:
        return ['bunnings', 'total tools', 'sydney tools', 'mitre 10'];
    }
  }

  static TradePersona fromId(String? id) {
    if (id == null) return TradePersona.otherSoleTrader;
    for (final persona in TradePersona.values) {
      if (persona.id == id || persona.name == id) {
        return persona;
      }
    }
    return TradePersona.otherSoleTrader;
  }
}
