import 'receipt_ocr_engine.dart';

class SpatialParsedReceipt {
  final String? total;
  final double? totalAmount;
  final String? gst;
  final double? gstAmount;
  final String? abn;
  final String? date;
  final String? invoiceNumber;

  const SpatialParsedReceipt({
    this.total,
    this.totalAmount,
    this.gst,
    this.gstAmount,
    this.abn,
    this.date,
    this.invoiceNumber,
  });
}

class SpatialReceiptParser {
  final double maxHorizontalGap;
  final double verticalToleranceFactor;

  const SpatialReceiptParser({
    this.maxHorizontalGap = 800.0,
    this.verticalToleranceFactor = 0.5,
  });

  static final RegExp _amountRegex =
      RegExp(r'\$?\s*([0-9]+(?:[.,][0-9]{2}))');
  static final RegExp _abnRegex = RegExp(r'(?:\d\s*){11}');
  static final RegExp _dateRegex = RegExp(
      r'\b(\d{1,2}[./-]\d{1,2}[./-]\d{2,4}|\d{4}[./-]\d{1,2}[./-]\d{1,2})\b');
  static final RegExp _invoiceRegex =
      RegExp(r'(?:#|no\.?|num\.?)?\s*([A-Za-z0-9][A-Za-z0-9\-_/]{2,})');

  SpatialParsedReceipt parse(List<ReceiptOcrBlock> blocks) {
    if (blocks.isEmpty) {
      return const SpatialParsedReceipt();
    }

    String? totalStr;
    double? totalAmt;
    String? gstStr;
    double? gstAmt;
    String? abnStr;
    String? dateStr;
    String? invoiceStr;

    // First check single blocks that may already have both anchor and value
    for (final block in blocks) {
      final upper = block.text.toUpperCase();

      if (totalStr == null && _isTotalAnchor(upper)) {
        final val = _extractEmbeddedAmount(block.text);
        if (val != null) {
          totalStr = val.$1;
          totalAmt = val.$2;
        }
      }

      if (gstStr == null && _isGstAnchor(upper)) {
        final val = _extractEmbeddedAmount(block.text);
        if (val != null) {
          gstStr = val.$1;
          gstAmt = val.$2;
        }
      }

      if (abnStr == null && _isAbnAnchor(upper)) {
        final val = _extractEmbeddedAbn(block.text);
        if (val != null) {
          abnStr = val;
        }
      }

      if (dateStr == null && _isDateAnchor(upper)) {
        final val = _extractEmbeddedDate(block.text);
        if (val != null) {
          dateStr = val;
        }
      }

      if (invoiceStr == null && _isInvoiceAnchor(upper)) {
        final val = _extractEmbeddedInvoice(block.text);
        if (val != null) {
          invoiceStr = val;
        }
      }
    }

    // Now perform spatial horizontal pairing for any missing fields
    for (final anchor in blocks) {
      final upper = anchor.text.toUpperCase();
      final anchorPage = anchor.page;
      final anchorTop = anchor.bounds[1];
      final anchorRight = anchor.bounds[2];
      final anchorBottom = anchor.bounds[3];
      final anchorHeight = (anchorBottom - anchorTop).abs();

      // Find candidates to the right on the same visual line and page
      final rightCandidates = blocks.where((candidate) {
        if (identical(candidate, anchor)) return false;
        if (candidate.page != anchorPage) return false;

        final candLeft = candidate.bounds[0];
        final candTop = candidate.bounds[1];
        final candBottom = candidate.bounds[3];

        // Must be to the right of the anchor
        if (candLeft < anchorRight - 5.0) return false;

        // Must be within max horizontal gap
        final gap = candLeft - anchorRight;
        if (gap > maxHorizontalGap) return false;

        // Visual row alignment check:
        // Candidate vertical bounds must overlap or be within tolerance:
        // [anchorTop - factor * height, anchorBottom + factor * height]
        final vTol = anchorHeight * verticalToleranceFactor;
        final vMin = anchorTop - vTol;
        final vMax = anchorBottom + vTol;

        // Check vertical overlap/intersection
        return candBottom >= vMin && candTop <= vMax;
      }).toList();

      // Sort by horizontal proximity to the anchor
      rightCandidates.sort((a, b) => a.bounds[0].compareTo(b.bounds[0]));

      if (totalStr == null && _isTotalAnchor(upper)) {
        for (final cand in rightCandidates) {
          final amt = _parseAmount(cand.text);
          if (amt != null) {
            totalStr = amt.$1;
            totalAmt = amt.$2;
            break;
          }
        }
      }

      if (gstStr == null && _isGstAnchor(upper)) {
        for (final cand in rightCandidates) {
          final amt = _parseAmount(cand.text);
          if (amt != null) {
            gstStr = amt.$1;
            gstAmt = amt.$2;
            break;
          }
        }
      }

      if (abnStr == null && _isAbnAnchor(upper)) {
        for (final cand in rightCandidates) {
          final abn = _parseAbn(cand.text);
          if (abn != null) {
            abnStr = abn;
            break;
          }
        }
      }

      if (dateStr == null && _isDateAnchor(upper)) {
        for (final cand in rightCandidates) {
          final date = _parseDate(cand.text);
          if (date != null) {
            dateStr = date;
            break;
          }
        }
      }

      if (invoiceStr == null && _isInvoiceAnchor(upper)) {
        for (final cand in rightCandidates) {
          final inv = _parseInvoice(cand.text);
          if (inv != null) {
            invoiceStr = inv;
            break;
          }
        }
      }
    }

    return SpatialParsedReceipt(
      total: totalStr,
      totalAmount: totalAmt,
      gst: gstStr,
      gstAmount: gstAmt,
      abn: abnStr,
      date: dateStr,
      invoiceNumber: invoiceStr,
    );
  }

  bool _isTotalAnchor(String text) {
    // Avoid false positives like SUB TOTAL or TOTAL GST
    if (text.contains('SUBTOTAL') || text.contains('SUB TOTAL')) return false;
    if (text.contains('TOTAL GST') || text.contains('GST TOTAL')) return false;
    return RegExp(r'\b(TOTAL|BALANCE DUE|AMOUNT DUE|TOTAL DUE|TOTAL AUD|AUD TOTAL)\b')
        .hasMatch(text);
  }

  bool _isGstAnchor(String text) {
    return RegExp(r'\b(GST|INCLUDES GST|INC GST|GST INCLUDED|TAX)\b')
        .hasMatch(text);
  }

  bool _isAbnAnchor(String text) {
    return RegExp(r'\b(ABN|A\.B\.N\.)\b').hasMatch(text);
  }

  bool _isDateAnchor(String text) {
    return RegExp(r'\b(DATE|TAX INVOICE DATE|DATED)\b').hasMatch(text);
  }

  bool _isInvoiceAnchor(String text) {
    return RegExp(r'\b(INVOICE|TAX INVOICE|INV|RECEIPT NO|RECEIPT #)\b')
        .hasMatch(text);
  }

  (String, double)? _extractEmbeddedAmount(String text) {
    final match = _amountRegex.firstMatch(text);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(raw);
      if (val != null) {
        return (raw, val);
      }
    }
    return null;
  }

  (String, double)? _parseAmount(String text) {
    final match = _amountRegex.firstMatch(text);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(raw);
      if (val != null) {
        return (raw, val);
      }
    }
    return null;
  }

  String? _extractEmbeddedAbn(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 11) {
      return digits.substring(0, 11);
    }
    return null;
  }

  String? _parseAbn(String text) {
    final match = _abnRegex.firstMatch(text);
    if (match != null) {
      final clean = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
      if (clean.length == 11) {
        return clean;
      }
    }
    return null;
  }

  String? _extractEmbeddedDate(String text) {
    final match = _dateRegex.firstMatch(text);
    return match?.group(1);
  }

  String? _parseDate(String text) {
    final match = _dateRegex.firstMatch(text);
    return match?.group(1);
  }

  String? _extractEmbeddedInvoice(String text) {
    // If text is like "TAX INVOICE NO: INV-123", extract the value part after the anchor
    final match = RegExp(
            r'(?:invoice|receipt)\s*(?:number|no\.?|#)?\s*[:#]?\s*([A-Za-z0-9][A-Za-z0-9\-_/]{2,})',
            caseSensitive: false)
        .firstMatch(text);
    return match?.group(1);
  }

  String? _parseInvoice(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final match = _invoiceRegex.firstMatch(trimmed);
    return match?.group(1) ?? trimmed;
  }
}
