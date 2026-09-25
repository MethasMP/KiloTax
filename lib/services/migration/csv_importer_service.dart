import 'dart:convert';
import '../../data/models/trip.dart';

class MigrationImportResult {
  final int totalParsed;
  final int autoMatched;
  final int needsAttention;
  final List<Trip> importedTrips;
  final List<String> issues;

  MigrationImportResult({
    required this.totalParsed,
    required this.autoMatched,
    required this.needsAttention,
    required this.importedTrips,
    required this.issues,
  });

  double get matchRate => totalParsed > 0 ? (autoMatched / totalParsed) * 100 : 100.0;
}

/// Spec #19: Migration Engine (Driversnote, Xero, Generic CSV)
/// Parses standard mileage exports, automatically classifies trips,
/// and flags trips needing attention for seamless onboarding.
class CsvImporterService {
  static MigrationImportResult parseMileageCsv({
    required String csvContent,
    required String defaultVehicleId,
  }) {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.isEmpty) {
      return MigrationImportResult(
        totalParsed: 0,
        autoMatched: 0,
        needsAttention: 0,
        importedTrips: [],
        issues: ['Empty CSV content'],
      );
    }

    final List<Trip> trips = [];
    final List<String> issues = [];
    int autoMatched = 0;
    int needsAttention = 0;

    // Detect header index
    final header = lines.first.toLowerCase();
    final hasHeader = header.contains('date') || header.contains('distance') || header.contains('km');
    final startIndex = hasHeader ? 1 : 0;

    double runningOdometer = 10000.0;

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvLine(line);
      if (cols.length < 2) continue;

      try {
        DateTime date = DateTime.now();
        double distance = 0.0;
        String purpose = '';
        TripClassification classification = TripClassification.business;
        String? origin;
        String? destination;

        // Try parsing columns flexibly: Date, Distance, Purpose/Notes, Type, From, To
        if (cols.isNotEmpty) {
          date = DateTime.tryParse(cols[0].trim()) ?? DateTime.now();
        }
        if (cols.length > 1) {
          distance = double.tryParse(cols[1].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        }
        if (cols.length > 2) {
          purpose = cols[2].trim();
        }
        if (cols.length > 3) {
          final type = cols[3].toLowerCase();
          if (type.contains('personal') || type.contains('private')) {
            classification = TripClassification.personal;
          }
        }
        if (cols.length > 4) origin = cols[4].trim();
        if (cols.length > 5) destination = cols[5].trim();

        final startOdo = runningOdometer;
        final endOdo = runningOdometer + distance;
        runningOdometer = endOdo;

        final isUnclear = purpose.isEmpty || purpose.contains('?') || purpose.toLowerCase() == 'unknown';
        if (isUnclear) {
          needsAttention++;
          purpose = 'Needs Attention (Imported)';
        } else {
          autoMatched++;
        }

        final trip = Trip(
          id: 'imported_${DateTime.now().microsecondsSinceEpoch}_$i',
          vehicleId: defaultVehicleId,
          distanceKm: distance,
          date: date,
          purpose: purpose,
          startOdometer: startOdo,
          endOdometer: endOdo,
          classification: classification,
          originAddress: origin,
          destinationAddress: destination,
        );

        trips.add(trip);
      } catch (e) {
        issues.add('Line ${i + 1}: Could not parse ($e)');
      }
    }

    return MigrationImportResult(
      totalParsed: trips.length,
      autoMatched: autoMatched,
      needsAttention: needsAttention,
      importedTrips: trips,
      issues: issues,
    );
  }

  static List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }
}
