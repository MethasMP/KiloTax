import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

/// Autonomous ATO Tax Rate Crawler & Gazette Parser
/// Dynamically queries government register without search engines or hardcoded IDs
Future<void> main(List<String> args) async {
  final targetYear = args.isNotEmpty ? int.tryParse(args[0]) : null;

  print('======================================================');
  print('🏛️  [ATO Sentinel] Connecting to Federal Register of Legislation...');
  print('======================================================');

  final now = DateTime.now();
  final currentStartYear = now.month >= 7 ? now.year : now.year - 1;
  final inspectYear = targetYear ?? currentStartYear;

  print('🎯 Target Inspection Year: $inspectYear');
  print('🔎 Querying Australian Legislation OData API for year $inspectYear...');

  final match = await findGazetteIdByYear(inspectYear);
  if (match == null) {
    print('❌ No statutory determination found on Government register for year $inspectYear.');
    exit(1);
  }

  final registerId = match['id'] as String;
  final titleName = match['name'] as String;
  print('🎯 Auto-Discovered Register ID: $registerId');
  print('   Title: $titleName');

  final detected = await extractStatutoryDetermination(inspectYear, registerId);
  if (detected != null) {
    print('\n✅ SUCCESS: Successfully fetched & decoded from Official Gazette!');
    print('   - Register ID: $registerId');
    print('   - Legislative Title: ${detected.title}');
    print('   - Statutory Year: ${detected.year}');
    print('   - Statutory Rate: ${(detected.rate * 100).toInt()} cents per kilometre');
    print('   - Authority: ITAA 1997 s.28-25');
  } else {
    print('❌ Failed to extract rate from Government Gazette.');
    exit(1);
  }
}

Future<Map<String, dynamic>?> findGazetteIdByYear(int year) async {
  try {
    final searchUri = Uri.parse(
        'https://api.prod.legislation.gov.au/v1/titles?\$filter=contains(name,\'Cents%20per%20Kilometre\')%20and%20contains(name,\'$year\')&\$select=id,name,makingDate');
    final response = await http.get(searchUri);
    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> items = json['value'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        return items.first as Map<String, dynamic>;
      }
    }
  } catch (e) {
    print('⚠️ Search error for year $year: $e');
  }
  return null;
}

class DetectedStatutoryRule {
  final String title;
  final int year;
  final double rate;

  DetectedStatutoryRule({
    required this.title,
    required this.year,
    required this.rate,
  });
}

Future<DetectedStatutoryRule?> extractStatutoryDetermination(int targetYear, String registerId) async {
  try {
    final metadataUri = Uri.parse('https://api.prod.legislation.gov.au/v1/titles(\'$registerId\')');
    final metaRes = await http.get(metadataUri);
    if (metaRes.statusCode != 200) {
      print('❌ Metadata response failed: ${metaRes.statusCode}');
      return null;
    }

    final metaJson = jsonDecode(metaRes.body) as Map<String, dynamic>;
    final titleName = metaJson['name'] as String? ?? 'Determination $targetYear';
    final regDateRaw = metaJson['asMadeRegisteredAt'] as String? ?? '2024-06-17';
    final startDate = regDateRaw.split('T').first;

    // Download official primary document dynamically using discovered registration date
    final docUri = Uri.parse(
        'https://api.prod.legislation.gov.au/v1/documents(titleid=\'$registerId\',start=$startDate,retrospectivestart=$startDate,rectificationversionnumber=0,type=\'Primary\',uniqueTypeNumber=0,volumeNumber=0,format=\'Word\')');

    print('📥 Downloading official Gazette legal package directly from Government Vault ($registerId)...');
    final docRes = await http.get(docUri);
    if (docRes.statusCode != 200 || docRes.bodyBytes.isEmpty) {
      print('❌ Document download failed: ${docRes.statusCode}');
      return null;
    }

    final archive = ZipDecoder().decodeBytes(docRes.bodyBytes);
    final documentXmlFile = archive.findFile('word/document.xml');
    if (documentXmlFile == null) {
      print('❌ word/document.xml not found in gazette archive');
      return null;
    }

    final xmlContent = utf8.decode(documentXmlFile.content as List<int>);
    final rawText = xmlContent.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ');

    final rateMatch = RegExp(r'is\s+(\d{2})\s+cents\s+per\s+kilometre', caseSensitive: false).firstMatch(rawText);
    if (rateMatch != null) {
      final centsInt = int.parse(rateMatch.group(1)!);
      return DetectedStatutoryRule(
        title: titleName,
        year: targetYear,
        rate: centsInt / 100.0,
      );
    }
  } catch (e, stack) {
    print('❌ Error during gazette processing: $e\n$stack');
  }
  return null;
}
