import 'package:flutter_test/flutter_test.dart';
import 'package:kilotax/services/tracking/trade_poi_resolver.dart';
import 'package:kilotax/services/engine/purpose_synthesizer_service.dart';

void main() {
  group('TradePoiResolver Tests (Monozukuri Validation)', () {
    test('Correctly identifies Bunnings Warehouse across variations', () {
      final match1 = TradePoiResolver.resolve('Bunnings Box Hill, VIC');
      expect(match1, isNotNull);
      expect(match1!.merchantName, 'Bunnings Warehouse');
      expect(match1.suggestedPurpose, 'Supplies Run');

      final match2 = TradePoiResolver.resolve('123 Victoria St, Bunnings Warehouse');
      expect(match2, isNotNull);
      expect(match2!.merchantName, 'Bunnings Warehouse');
    });

    test('Correctly identifies Reece Plumbing and trade suppliers', () {
      final reece = TradePoiResolver.resolve('Reece Plumbing Richmond');
      expect(reece, isNotNull);
      expect(reece!.merchantName, 'Reece Plumbing');

      final middys = TradePoiResolver.resolve("Middy's Electrical Collingwood");
      expect(middys, isNotNull);
      expect(middys!.merchantName, "Middy's Electrical");

      final totalTools = TradePoiResolver.resolve('Total Tools Moorabbin');
      expect(totalTools, isNotNull);
      expect(totalTools!.merchantName, 'Total Tools');

      final sydneyTools = TradePoiResolver.resolve('Sydney Tools Alexandria');
      expect(sydneyTools, isNotNull);
      expect(sydneyTools!.merchantName, 'Sydney Tools');
    });

    test('Gracefully returns null for generic residential addresses', () {
      final residential = TradePoiResolver.resolve('42 Wallaby Way, Sydney NSW');
      expect(residential, isNull);

      final empty = TradePoiResolver.resolve('');
      expect(empty, isNull);

      final nullAddress = TradePoiResolver.resolve(null);
      expect(nullAddress, isNull);
    });
  });

  group('PurposeSynthesizerService Dual-Layer Tests', () {
    test('Synthesizes dynamic non-repetitive client visit purpose', () {
      final text = PurposeSynthesizerService.synthesize(
        selectedPurpose: 'Client Site',
        destination: '14 Smith St, Richmond VIC',
      );
      expect(text, contains('Client site visit & contract trade works'));
      expect(text, contains('14 Smith St, Richmond VIC'));
      expect(text, contains('TR 95/34'));
    });

    test('Synthesizes specific trade supplies procurement when POI is matched', () {
      final text = PurposeSynthesizerService.synthesize(
        selectedPurpose: 'Supplies Run',
        destination: 'Bunnings Warehouse, Box Hill VIC',
      );
      expect(text, contains('Bunnings Warehouse'));
      expect(text, contains('Trade consumables & parts procurement'));
    });

    test('Synthesizes Bulky Tools exemption (s 8-1) when flag is enabled', () {
      final text = PurposeSynthesizerService.synthesize(
        selectedPurpose: 'Tool Transport',
        destination: 'Commercial Site, Parramatta',
        bulkyToolsCarried: true,
      );
      expect(text, contains('Transit with essential heavy trade equipment (>20kg)'));
      expect(text, contains('Commercial Site, Parramatta'));
      expect(text, contains('ITAA 1997 s 8-1'));
    });

    test('Maps human UI labels cleanly according to Apple design principles', () {
      expect(PurposeSynthesizerService.getHumanLabel('Client / Job Site Visit'), 'Client Site');
      expect(PurposeSynthesizerService.getHumanLabel('Trade Supplies / Bunnings Run'), 'Supplies Run');
      expect(PurposeSynthesizerService.getHumanLabel('Work Site (Bulky Tools Carried)'), 'Tool Transport');
      expect(PurposeSynthesizerService.getHumanLabel('Personal Drive'), 'Personal');
    });
  });
}
