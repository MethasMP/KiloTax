import '../../data/models/vehicle_expense.dart';
import 'australian_tax_validator.dart';
import 'receipt_ocr_engine.dart';
import 'spatial_receipt_parser.dart';

class ReceiptOcrResult {
  final String? currency;
  final String? invoiceNumber;
  final DateTime? parsedDate;
  final bool hasMixedItems;
  final List<Map<String, dynamic>> lineObservations;
  final String merchant;
  final double amount;
  final double? gstAmount;
  final String? abn;
  final DateTime date;
  final bool dateNeedsReview;
  final ExpenseCategory category;
  final double confidence;
  final List<String> evidence;
  final String rawText;

  const ReceiptOcrResult({
    this.currency,
    this.invoiceNumber,
    this.parsedDate,
    this.hasMixedItems = false,
    this.lineObservations = const [],
    required this.merchant,
    required this.amount,
    required this.date,
    this.dateNeedsReview = false,
    required this.category,
    required this.confidence,
    required this.evidence,
    required this.rawText,
    this.gstAmount,
    this.abn,
  });

  bool get isHighConfidence =>
      confidence >= 0.78 &&
      currency == 'AUD' &&
      !hasMixedItems &&
      !dateNeedsReview &&
      amount > 0 &&
      merchant.isNotEmpty;
}

class ReceiptIntelligenceService {
  const ReceiptIntelligenceService();

  static final _personalItemPattern = RegExp(
    r'\b(ice break|coke|coca cola|snack|chips|chocolate|drink|coffee|confectionery|sandwich|pie|energy drink|red bull)\b',
    caseSensitive: false,
  );

  /// Checks if an item description likely represents a personal/convenience purchase.
  bool isLikelyPersonalItem(String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return false;
    return _personalItemPattern.hasMatch(trimmed);
  }

  ReceiptOcrResult analyseText(
    String rawText, {
    DateTime? fallbackDate,
    List<ReceiptOcrBlock>? blocks,
    SpatialParsedReceipt? spatialParsed,
  }) {
    final sanitizedRaw =
        rawText.replaceAll('¥', '%').replaceAll('PREMOBA', 'PREM98');
    final normalized = _normalize(sanitizedRaw);

    // If blocks are provided and spatialParsed is not, run SpatialReceiptParser
    final spatialHints = spatialParsed ??
        (blocks != null && blocks.isNotEmpty
            ? const SpatialReceiptParser().parse(blocks)
            : null);

    final categoryMatch = classify(normalized);
    final rawGstCandidate = _extractGstAmount(normalized);
    final gstCandidate = rawGstCandidate ?? spatialHints?.gstAmount;
    final discountCandidate = _extractDiscountAmount(normalized);
    final rawAbnCandidate = _extractAbn(sanitizedRaw);
    final abnCandidate = rawAbnCandidate ??
        (spatialHints?.abn != null ? _formatAbn(spatialHints!.abn!) : null);

    final consensus = _extractConsensusSettlement(
      rawText: sanitizedRaw,
      normalized: normalized,
      gst: gstCandidate,
      discount: discountCandidate,
      spatialTotal: spatialHints?.totalAmount,
    );

    final currencyCodes = RegExp(r'\b(AUD|USD|NZD|CAD|EUR|GBP|THB|JPY|SGD)\b',
            caseSensitive: false)
        .allMatches(rawText)
        .map((m) => m.group(1)!.toUpperCase())
        .toSet();
    final currency = currencyCodes.length == 1 ? currencyCodes.single : null;
    final invoice = RegExp(
            r'(?:invoice|receipt)\s*(?:number|no\.?|#)\s*[:#]?\s*([A-Z0-9][A-Z0-9-]*)',
            caseSensitive: false)
        .firstMatch(rawText)
        ?.group(1) ??
        spatialHints?.invoiceNumber;
    final mixed = RegExp(
            r'\b(chocolate|grocery|groceries|milk|bread|coffee|sandwich|snack|chips|drink|cigarettes|tobacco|confectionery)\b',
            caseSensitive: false)
        .hasMatch(rawText);
    final amount = consensus.amount;
    final merchant = _extractMerchant(sanitizedRaw, normalized);
    final parsedDate = _extractDateTime(normalized, sanitizedRaw) ??
        (spatialHints?.date != null
            ? _extractDateTime(_normalize(spatialHints!.date!), spatialHints.date!)
            : null);
    final now = DateTime.now();
    DateTime date;
    if (parsedDate != null) {
      if (parsedDate.isAfter(now.add(const Duration(minutes: 5))) ||
          parsedDate
              .isBefore(now.subtract(const Duration(days: 365 * 5 + 30)))) {
        date = fallbackDate ?? now;
      } else {
        date = parsedDate;
      }
    } else {
      date = fallbackDate ?? now;
    }

    // ABN Mod-89 Validation
    String? validAbn;
    String? rejectedAbnDigits;
    if (abnCandidate != null && abnCandidate.isNotEmpty) {
      if (AustralianTaxValidator.isValidAbn(abnCandidate)) {
        validAbn = abnCandidate;
      } else {
        rejectedAbnDigits = abnCandidate.replaceAll(RegExp(r'\D'), '');
      }
    }

    final isGstClean = amount > 0 &&
        gstCandidate != null &&
        gstCandidate > 0 &&
        AustralianTaxValidator.isGstConsistent(amount, gstCandidate);

    final evidence = <String>[
      if (mixed) 'mixed_items',
      if (currency == null) 'currency_unknown',
      if (parsedDate == null) 'purchase_date_missing',
      if (parsedDate != null && date != parsedDate)
        'purchase_date_rejected:${parsedDate.toIso8601String()}',
      ...categoryMatch.evidence,
      ...consensus.evidence,
      if (amount > 0) 'total:${amount.toStringAsFixed(2)}',
      if (merchant.isNotEmpty) 'merchant:$merchant',
      if (gstCandidate != null && gstCandidate > 0)
        'gst:${gstCandidate.toStringAsFixed(2)}',
      if (validAbn != null) ...[
        'abn:$validAbn',
        'abn_mod89_valid',
      ],
      if (rejectedAbnDigits != null) 'abn_mod89_rejected:$rejectedAbnDigits',
    ];

    double calculatedConfidence;
    if (isGstClean && validAbn != null) {
      // Both GST math invariant and ABN checksum validate cleanly
      calculatedConfidence = 0.95;
    } else {
      calculatedConfidence = _bounded(
        categoryMatch.confidence +
            (amount > 0 ? 0.24 : 0) +
            (merchant.isNotEmpty ? 0.16 : 0) +
            (evidence.length >= 3 ? 0.08 : 0) +
            (consensus.isCrossValidated ? 0.12 : 0) +
            (validAbn != null ? 0.06 : 0),
      );
    }

    final auditedConfidence = categoryMatch.hasConflictingEvidence
        ? calculatedConfidence.clamp(0.0, 0.76).toDouble()
        : calculatedConfidence;

    return ReceiptOcrResult(
      currency: currency,
      invoiceNumber: invoice,
      parsedDate: parsedDate,
      hasMixedItems: mixed,
      lineObservations: rawText
          .split(RegExp(r'\r?\n'))
          .map((line) => <String, dynamic>{'text': line})
          .toList(),
      merchant: merchant,
      amount: amount,
      gstAmount: gstCandidate,
      abn: validAbn,
      date: date,
      dateNeedsReview: parsedDate == null || date != parsedDate,
      category: categoryMatch.category,
      confidence: auditedConfidence,
      evidence: evidence,
      rawText: rawText,
    );
  }

  ReceiptCategoryMatch classify(String text) {
    final normalized = _normalize(text);
    final maintenanceSignals = _signals(normalized, _maintenanceSignals);
    final fuelSignals = _signals(normalized, _fuelSignals);
    final evSignals = _signals(normalized, _evSignals);
    final gasSignals = _signals(normalized, _gasSignals);

    final maintenanceScore = _weightedScore(maintenanceSignals);
    final runningSignals = [...fuelSignals, ...evSignals, ...gasSignals];
    final runningScore = _weightedScore(runningSignals);
    final conflictPenalty =
        maintenanceScore > 0 && runningScore > 0 ? 0.18 : 0.0;
    final scoreGap = (maintenanceScore - runningScore).abs();

    if (maintenanceScore >= runningScore && maintenanceScore > 0) {
      return ReceiptCategoryMatch(
        category: ExpenseCategory.maintenanceTyres,
        confidence:
            _categoryConfidence(maintenanceScore, scoreGap) - conflictPenalty,
        evidence: maintenanceSignals
            .map((signal) => signal.label)
            .toList(growable: false),
        hasConflictingEvidence: runningScore > 0,
      );
    }

    if (runningScore > 0) {
      return ReceiptCategoryMatch(
        category: ExpenseCategory.fuel,
        confidence:
            _categoryConfidence(runningScore, scoreGap) - conflictPenalty,
        evidence: runningSignals
            .map((signal) => signal.label)
            .toList(growable: false),
        hasConflictingEvidence: maintenanceScore > 0,
      );
    }

    return const ReceiptCategoryMatch(
      category: ExpenseCategory.toolsMaterials,
      confidence: 0.18,
      evidence: [],
      hasConflictingEvidence: false,
    );
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u2018\u2019]'), "'")
        .replaceAll(RegExp(r'[^a-z0-9$%.\-/:\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatAbn(String digitsOnly) {
    final clean = digitsOnly.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 11) {
      return '${clean.substring(0, 2)} ${clean.substring(2, 5)} ${clean.substring(5, 8)} ${clean.substring(8, 11)}';
    }
    return digitsOnly;
  }

  /// Extracts statutory 11-digit Australian Business Number (ABN)
  /// e.g. "ABN: 12 345 678 901", "A.B.N 53004085616"
  String? _extractAbn(String text) {
    final abnPattern = RegExp(
      r'(?:a\.?b\.?n\.?|aust(?:ralian)?\s+bus(?:iness)?\s+no\.?)\s*[:# ]*\s*(\d{2}[\s.-]?\d{3}[\s.-]?\d{3}[\s.-]?\d{3})\b',
      caseSensitive: false,
    );

    final match = abnPattern.firstMatch(text);
    if (match != null) {
      final digits = match.group(1)!.replaceAll(RegExp(r'[\s.-]'), '');
      if (digits.length == 11) {
        return _formatAbn(digits);
      }
    }
    return null;
  }

  /// Extracts Australian GST with variations (e.g. "includes gst $14.25", "10% gst a $4.95")
  double? _extractGstAmount(String text) {
    final gstPatterns = [
      RegExp(
          r'\bgst\s+(?:included|inclusive|incl)\s*[:$ ]+\s*\$?\s*(\d{1,4}(?:\.\d{2}))'),
      RegExp(
          r'(?<!includes\s+)\bgst(?:\s+[a-z])?\s*[:$ ]+\s*\$?\s*(\d{1,4}(?:\.\d{2}))'),
      RegExp(
          r'(?:gst\s+amount|tax\s+amount)\s*[:$ ]+\s*\$?\s*(\d{1,4}(?:\.\d{2}))'),
      RegExp(
          r'(?<!total\s+)includes?\s+gst(?:\s+10%)?\s*[:$ ]+\s*\$?\s*(\d{1,4}(?:\.\d{2}))'),
      RegExp(
          r'\bincl(?:udes?)?\s+gst(?:\s+10%)?\s*[:$ ]+\s*\$?\s*(\d{1,4}(?:\.\d{2}))'),
      RegExp(r'\b10%\s+tax\s*[:$ ]+\s*\$?\s*(\d{1,4}(?:\.\d{2}))'),
    ];

    for (final pattern in gstPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        if (val != null && val >= 0) return val;
      }
    }
    return null;
  }

  /// Extracts fuel supermarket discounts (e.g. "discount -$3.20", "4c discount $3.20")
  double? _extractDiscountAmount(String text) {
    final discPatterns = [
      RegExp(
          r'(?:discount|fuel\s+discount|savings?|voucher)\s*[:$ ]+\s*-?\$?\s*(\d{1,3}(?:\.\d{2}))'),
      RegExp(r'-\s*\$\s*(\d{1,3}(?:\.\d{2}))'),
    ];

    for (final pattern in discPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  /// Multi-strategy Consensus Settlement Engine:
  /// Evaluates candidates with Bottom-up scanning, Levenshtein Fuzzy matching,
  /// Discount Reconciliation, and GST Invariant validation.
  _ConsensusResult _extractConsensusSettlement({
    required String rawText,
    required String normalized,
    required double? gst,
    required double? discount,
    double? spatialTotal,
  }) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);

    final candidates = <_AmountCandidate>[];
    final evidence = <String>[];

    // If spatial parsing found an explicit horizontal total, add it with high priority
    if (spatialTotal != null && spatialTotal > 0) {
      candidates.add(_AmountCandidate(spatialTotal, 7.0));
      evidence.add('spatial_consensus_match');
    }

    final reversedLines = lines.reversed.toList(growable: false);
    for (int i = 0; i < reversedLines.length; i++) {
      final line = reversedLines[i];
      final normLine = _normalize(line);

      // Check for fuzzy match against settlement keywords
      final isSettlementLine = _isFuzzySettlementLine(normLine);
      final match =
          RegExp(r'\$?\s*(\d{1,4}(?:,\d{3})*(?:\.\d{2}))').firstMatch(line);

      if (match != null) {
        final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (amount != null && amount > 0) {
          double score = 1.0;
          score += (reversedLines.length - i) / reversedLines.length * 2.0;

          if (isSettlementLine) {
            score += 5.0;
          }

          if (line.contains(RegExp(r'\b(abn|acn|tel|phone|qty|litres|ltrs)\b',
              caseSensitive: false))) {
            score -= 4.0;
          }

          candidates.add(_AmountCandidate(amount, score));
        }
      }
    }

    final totalPatterns = [
      RegExp(
          r'(?:grand\s+total|amount\s+paid|total\s+paid|total\s+aud|total|balance\s+due)\s*[:$ ]+\s*\$?\s*(\d{1,4}(?:,\d{3})*(?:\.\d{2})?)'),
      RegExp(r'\$\s*(\d{1,4}(?:,\d{3})*(?:\.\d{2})?)'),
    ];

    for (final pattern in totalPatterns) {
      for (final match in pattern.allMatches(normalized)) {
        final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (amount == null || amount <= 0) continue;
        final labelBoost = match.group(0)!.contains('total') ||
                match.group(0)!.contains('paid')
            ? 3.0
            : 0.5;
        candidates.add(_AmountCandidate(amount, labelBoost));
      }
    }

    bool gstCrossValidated = false;
    if (gst != null && gst > 0) {
      final expectedTotal = gst * 11.0;
      for (final c in candidates) {
        if ((c.amount - expectedTotal).abs() <= 0.60) {
          c.score += 8.0;
          gstCrossValidated = true;
          if (!evidence.contains('gst_invariant_match')) {
            evidence.add('gst_invariant_match');
          }
          break;
        }
      }
    }

    if (discount != null && discount > 0) {
      evidence.add('discount_detected:${discount.toStringAsFixed(2)}');
      for (final lower in candidates) {
        for (final higher in candidates) {
          if ((higher.amount - lower.amount - discount).abs() <= 0.05 &&
              higher.amount > lower.amount) {
            lower.score += 6.0;
            evidence.add('discount_reconciled');
            break;
          }
        }
      }
    }

    // Auto-repair Total if GST is crisp and candidates are missing, 0, or mathematically inconsistent
    // Only repair if no strong settlement line matched an explicit total
    if (gst != null && gst > 0 && !gstCrossValidated) {
      final deducedTotal = AustralianTaxValidator.deduceTotalFromGst(gst);
      if (deducedTotal != null) {
        // If there are no candidates, or no candidate has strong settlement evidence
        final hasStrongSettlementCandidate = candidates.any((c) => c.score >= 5.0);
        final hasConsistentCandidate = candidates.any(
            (c) => (c.amount - deducedTotal).abs() <= 0.60);
        if (!hasConsistentCandidate && !hasStrongSettlementCandidate) {
          // Add deduced total as high-scoring candidate
          candidates.add(_AmountCandidate(deducedTotal, 12.0));
          evidence.add('total_repaired_from_gst:${deducedTotal.toStringAsFixed(2)}');
          gstCrossValidated = true;
          if (!evidence.contains('gst_invariant_match')) {
            evidence.add('gst_invariant_match');
          }
        }
      }
    }

    if (candidates.isEmpty) {
      return const _ConsensusResult(
          amount: 0.0, isCrossValidated: false, evidence: []);
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final bestAmount = candidates.first.amount;

    return _ConsensusResult(
      amount: bestAmount,
      isCrossValidated:
          gstCrossValidated || evidence.contains('discount_reconciled'),
      evidence: evidence,
    );
  }

  bool _isFuzzySettlementLine(String normLine) {
    const settlementWords = [
      'total',
      'total aud',
      'amount paid',
      'balance due',
      'eftpos',
      'eft',
      'visa',
      'mastercard',
      'amex',
      'settlement',
      'paid',
    ];

    for (final word in settlementWords) {
      if (normLine.contains(word)) return true;
    }

    final tokens = normLine.split(' ');
    for (final token in tokens) {
      if (token.length >= 4) {
        if (_levenshtein(token, 'total') <= 1 ||
            _levenshtein(token, 'eftpos') <= 1 ||
            _levenshtein(token, 'paid') <= 1) {
          return true;
        }
      }
    }
    return false;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  /// Proposes a merchant from header lines; this heuristic does not establish identity.
  String _extractMerchant(String rawText, String normalized) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    for (final line in lines) {
      final norm = line.toLowerCase();
      // Skip pure statutory labels, date/time timestamps, or pure numeric lines
      if (RegExp(
              r'^(?:\d+[\s/:-]+\d+|tax\s+invoice|tax\s+receipt|customer\s+tax|receipt|a\.?b\.?n\.?|a\.?c\.?n\.?|ph:|tel:|welcome\s+to)',
              caseSensitive: false)
          .hasMatch(norm)) {
        continue;
      }
      // If line is just a pure number or amount, skip
      if (RegExp(r'^\$?\d+(?:\.\d+)?$').hasMatch(norm)) {
        continue;
      }
      if (line.length >= 2) {
        return _cleanMerchantName(line);
      }
    }

    return '';
  }

  /// Cleans legal corporate designations (e.g. "Pty Ltd", "P/L", "Trading As") into clean trading names.
  String _cleanMerchantName(String raw) {
    var cleaned = raw
        .replaceAll(
            RegExp(r'\s+(?:pty\.?\s+ltd\.?|pty\s+limited|p/l|ltd\.?|limited)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'^(?:welcome\s+to\s+)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\*#_]+'), '')
        .trim();

    if (cleaned.length <= 3) {
      cleaned = cleaned.toUpperCase();
    } else {
      cleaned = _titleCase(cleaned);
    }
    return cleaned;
  }

  DateTime? _extractDateTime(String normalized, String rawText) {
    final date = _extractDate(normalized);
    if (date == null) return null;

    final time = _extractTime(rawText) ?? _extractTime(normalized);
    if (time == null) return date;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
  }

  ({int hour, int minute, int second})? _extractTime(String text) {
    // 1. Matches 12-hour format with AM/PM (e.g., "10:42 AM", "2:15pm", "08:30:15 PM")
    final amPmPattern = RegExp(
      r'\b([01]?\d):([0-5]\d)(?::([0-5]\d))?\s*([ap]\.?m\.?)\b',
      caseSensitive: false,
    );
    final amPmMatch = amPmPattern.firstMatch(text);
    if (amPmMatch != null) {
      var hour = int.parse(amPmMatch.group(1)!);
      final minute = int.parse(amPmMatch.group(2)!);
      final second =
          amPmMatch.group(3) != null ? int.parse(amPmMatch.group(3)!) : 0;
      final modifier = amPmMatch.group(4)!.toLowerCase().replaceAll('.', '');

      if (modifier == 'pm' && hour < 12) {
        hour += 12;
      } else if (modifier == 'am' && hour == 12) {
        hour = 0;
      }
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return (hour: hour, minute: minute, second: second);
      }
    }

    // 2. Matches 24-hour military/POS format (e.g., "TIME 14:42", "14:42:10", "AT 09:15")
    final pos24Pattern = RegExp(
      r'(?:time|at|\s)\s*([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?\b',
      caseSensitive: false,
    );
    final posMatch = pos24Pattern.firstMatch(text);
    if (posMatch != null) {
      final hour = int.parse(posMatch.group(1)!);
      final minute = int.parse(posMatch.group(2)!);
      final second =
          posMatch.group(3) != null ? int.parse(posMatch.group(3)!) : 0;
      return (hour: hour, minute: minute, second: second);
    }

    return null;
  }

  DateTime? _extractDate(String text) {
    final textMonthPattern = RegExp(
      r'\b(\d{1,2})[\s\.-]+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*[\s\.-]+(\d{2,4})\b',
      caseSensitive: false,
    );
    final textMatch = textMonthPattern.firstMatch(text);
    if (textMatch != null) {
      final day = int.tryParse(textMatch.group(1)!);
      final monthStr = textMatch.group(2)!.toLowerCase();
      var year = int.tryParse(textMatch.group(3)!);
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'sept': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12
      };
      final month = months[monthStr];
      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        return _validDate(year, month, day);
      }
    }

    final isoPattern = RegExp(r'\b(20\d{2})[/-](\d{1,2})[/-](\d{1,2})\b');
    final isoMatch = isoPattern.firstMatch(text);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      if (year != null && month != null && day != null) {
        return _validDate(year, month, day);
      }
    }

    final slash =
        RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b').firstMatch(text);
    if (slash == null) return null;
    final day = int.tryParse(slash.group(1)!);
    final month = int.tryParse(slash.group(2)!);
    var year = int.tryParse(slash.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    return _validDate(year, month, day);
  }

  DateTime? _validDate(int year, int month, int day) {
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  List<_ReceiptSignal> _signals(String text, List<_ReceiptSignal> signals) {
    return signals
        .where((signal) => signal.pattern.hasMatch(text))
        .toList(growable: false);
  }

  double _weightedScore(List<_ReceiptSignal> signals) {
    return signals.fold(0.0, (total, signal) => total + signal.weight);
  }

  double _categoryConfidence(double score, double scoreGap) {
    return _bounded(0.30 + (score * 0.10) + (scoreGap >= 2.0 ? 0.10 : 0));
  }

  double _bounded(double value) => value.clamp(0.0, 0.98).toDouble();

  String _titleCase(String value) {
    return value.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.contains('-')) {
        return word
            .split('-')
            .map((sub) => sub.isEmpty
                ? sub
                : '${sub[0].toUpperCase()}${sub.substring(1).toLowerCase()}')
            .join('-');
      }
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}

class ReceiptCategoryMatch {
  final ExpenseCategory category;
  final double confidence;
  final List<String> evidence;
  final bool hasConflictingEvidence;

  const ReceiptCategoryMatch({
    required this.category,
    required this.confidence,
    required this.evidence,
    required this.hasConflictingEvidence,
  });
}

class _ConsensusResult {
  final double amount;
  final bool isCrossValidated;
  final List<String> evidence;

  const _ConsensusResult({
    required this.amount,
    required this.isCrossValidated,
    required this.evidence,
  });
}

class _AmountCandidate {
  final double amount;
  double score;

  _AmountCandidate(this.amount, this.score);
}

class _ReceiptSignal {
  final String label;
  final RegExp pattern;
  final double weight;

  _ReceiptSignal(this.label, String pattern, this.weight)
      : pattern = RegExp(pattern);
}

/// Keyword evidence used to propose an expense category.
final _fuelSignals = [
  _ReceiptSignal(
      'fuel product',
      r'\b(fuel|petrol|diesel|unleaded|ulp|e10|u91|u95|u98|prem98|prem95)\b',
      2.0),
  _ReceiptSignal(
      'premium fuel',
      r'\b(premium 95|premium 98|prem 98|prem 95|v-power|vortex|ultimate)\b',
      1.6),
  _ReceiptSignal('pump/bowser', r'\b(pump|bowser)\b', 1.4),
  _ReceiptSignal('litres',
      r'\b(\d+(?:\.\d+)?\s*(?:l|litres|liters|ltrs|ltr|qty l))\b', 1.2),
];

final _gasSignals = [
  _ReceiptSignal('lpg/autogas', r'\b(lpg|autogas|cng)\b', 2.0),
  _ReceiptSignal('gas with fuel context',
      r'\bgas\b.*\b(pump|litres|fuel)\b|\b(pump|litres|fuel)\b.*\bgas\b', 1.4),
];

final _evSignals = [
  _ReceiptSignal(
      'ev charging', r'\b(ev charging|charge session|charging session)\b', 2.2),
  _ReceiptSignal('energy kwh', r'\b(kwh|kw h)\b', 1.8),
  _ReceiptSignal('charger network',
      r'\b(charge session|supercharger|fast charger|ev charging)\b', 1.6),
];

final _maintenanceSignals = [
  _ReceiptSignal(
      'service invoice',
      r'\b(service(?! station)|servicing|logbook service|mechanic|labour|labor|repair)\b',
      2.0),
  _ReceiptSignal('engine oil context',
      r'\b(engine oil|motor oil|oil filter|oil change)\b', 2.6),
  _ReceiptSignal('tyres',
      r'\b(tyre|tyres|tire|tires|puncture|wheel alignment|alignment)\b', 2.2),
  _ReceiptSignal(
      'parts', r'\b(brake|battery|coolant|wiper|roadworthy|pink slip)\b', 1.8),
];
