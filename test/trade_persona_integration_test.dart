import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/data/models/trade_persona.dart';
import 'package:kilotax/data/models/user_profile.dart';
import 'package:kilotax/services/engine/purpose_synthesizer_service.dart';
import 'package:kilotax/services/tracking/trade_poi_resolver.dart';

void main() {
  group('Trade Persona & Purpose Synthesizer Integration Tests', () {
    test('Sparky persona prioritizes Middys and enables bulky tools deduction', () {
      const persona = TradePersona.sparky;
      expect(persona.defaultBulkyToolsCarried, isTrue);
      expect(persona.priorityMerchants, contains("middy's"));

      final poi = TradePoiResolver.resolve("Middy's Electrical Richmond", persona: persona);
      expect(poi, isNotNull);
      expect(poi!.merchantName, "Middy's Electrical");
      expect(poi.suggestedPurpose, contains('Sparky'));

      final purpose = PurposeSynthesizerService.synthesize(
        selectedPurpose: 'Supplies Run',
        destination: "Middy's Electrical",
        persona: persona,
      );

      // Must cite ITAA 1997 s 8-1 and mention trade
      expect(purpose, contains('ITAA 1997 s 8-1'));
      expect(purpose, contains('Sparky'));
    });

    test('Plumber persona prioritizes Reece Plumbing', () {
      const persona = TradePersona.plumber;
      final poi = TradePoiResolver.resolve('Reece Plumbing Brookvale', persona: persona);
      expect(poi, isNotNull);
      expect(poi!.merchantName, 'Reece Plumbing');
      expect(poi.suggestedPurpose, contains('Plumber'));
    });

    test('UserProfile serializes and deserializes TradePersona cleanly', () {
      const profile = UserProfile(
        taxpayerName: 'Dave Sparks',
        abn: '12 345 678 901',
        tradePersona: TradePersona.sparky,
      );

      final json = profile.toJson();
      expect(json['tradePersona'], 'sparky');

      final reconstructed = UserProfile.fromJson(json);
      expect(reconstructed.tradePersona, TradePersona.sparky);
      expect(reconstructed.taxpayerName, 'Dave Sparks');
    });
  });
}
