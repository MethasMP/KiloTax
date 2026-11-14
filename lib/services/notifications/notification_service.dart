import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/vehicle.dart';
import '../engine/evidence_review_service.dart';
import '../tax/ato_tax_period_engine.dart';

/// Type of Notification Event
enum KiloTaxNotificationType {
  tripDetected,
  dailySummary,
  logbookReminder,
  complianceAlert,
  eofyAlert,
}

/// Statutory EOFY (30 June) reminder milestones for annual odometer snapshotting (ITAA 1997 s 28-125).
enum EofyAlertMilestone {
  june15(
      day: 15,
      daysRemaining: 15,
      title: '📅 EOFY Closing Odometer: 15 Days Left'),
  june28(
      day: 28,
      daysRemaining: 2,
      title: '⚠️ EOFY Urgent: 2 Days to Record Closing Odometer'),
  june30(
      day: 30,
      daysRemaining: 0,
      title: '🚨 EOFY Final Day: Record 30 June Closing Odometer');

  final int day;
  final int daysRemaining;
  final String title;

  const EofyAlertMilestone({
    required this.day,
    required this.daysRemaining,
    required this.title,
  });

  static EofyAlertMilestone? forDate(DateTime date) {
    if (date.month != 6) return null;
    for (final m in values) {
      if (m.day == date.day) return m;
    }
    return null;
  }
}

/// In-App & Local Notification Payload
class KiloTaxNotification {
  final String id;
  final String title;
  final String body;
  final KiloTaxNotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? deepLinkRoute;
  final Map<String, dynamic>? data;

  const KiloTaxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.deepLinkRoute,
    this.data,
  });

  KiloTaxNotification copyWith({bool? isRead}) {
    return KiloTaxNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      deepLinkRoute: deepLinkRoute,
      data: data,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'deepLinkRoute': deepLinkRoute,
        'data': data,
      };

  factory KiloTaxNotification.fromJson(Map<String, dynamic> json) {
    return KiloTaxNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: KiloTaxNotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => KiloTaxNotificationType.complianceAlert,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      deepLinkRoute: json['deepLinkRoute'] as String?,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }
}

/// Service managing device local notifications and in-app activity queue
class NotificationService {
  static const String _storageKey = 'kilotax_notifications_v1';
  static NotificationService? _instance;

  final SharedPreferences? _prefs;
  final List<KiloTaxNotification> _notifications = [];

  NotificationService._(this._prefs) {
    _loadFromStorage();
  }

  static Future<NotificationService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = NotificationService._(prefs);
    }
    return _instance!;
  }

  /// Create instance directly with existing SharedPreferences (for tests / DI)
  factory NotificationService.withPrefs(SharedPreferences? prefs) {
    final instance = NotificationService._(prefs);
    _instance = instance;
    return instance;
  }

  List<KiloTaxNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _loadFromStorage() {
    if (_prefs == null) return;
    final jsonList = _prefs.getStringList(_storageKey);
    if (jsonList != null) {
      _notifications.clear();
      for (final raw in jsonList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _notifications.add(KiloTaxNotification.fromJson(map));
        } catch (e, stack) {
          debugPrint(
              '[NotificationService] Warning decoding notification payload: $e\n$stack');
        }
      }
    }
  }

  Future<void> _persist() async {
    if (_prefs == null) return;
    final encoded = _notifications.map((n) => jsonEncode(n.toJson())).toList();
    await _prefs.setStringList(_storageKey, encoded);
  }

  /// Trigger a Trip Detected Notification (e.g. at destination)
  Future<KiloTaxNotification> notifyTripDetected({
    required double distanceKm,
    required double estimatedDeduction,
    String? tripId,
  }) async {
    final notification = KiloTaxNotification(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      title: '🚗 Trip detected: ${distanceKm.toStringAsFixed(1)} km',
      body:
          'Review the purpose and choose business or personal before claiming.',
      type: KiloTaxNotificationType.tripDetected,
      timestamp: DateTime.now(),
      deepLinkRoute: '/trips',
      data: {'tripId': tripId, 'distanceKm': distanceKm},
    );
    await addNotification(notification);
    return notification;
  }

  /// Trigger 5 PM Daily Wrap-up for tradies
  Future<KiloTaxNotification> notifyDailyWrapUp({
    required int unclassifiedTripsCount,
    required double potentialTaxClaim,
  }) async {
    final notification = KiloTaxNotification(
      id: 'daily_${DateTime.now().millisecondsSinceEpoch}',
      title: '📋 5 PM Daily Tax Wrap',
      body:
          'You have $unclassifiedTripsCount unlogged trips today (\$$potentialTaxClaim deduction). Clear before smoko!',
      type: KiloTaxNotificationType.dailySummary,
      timestamp: DateTime.now(),
      deepLinkRoute: '/compliance',
      data: {'count': unclassifiedTripsCount},
    );
    await addNotification(notification);
    return notification;
  }

  /// Trigger Logbook Weekly milestone
  Future<KiloTaxNotification> notifyLogbookProgress({
    required int currentWeek,
    required double progressPercent,
  }) async {
    final notification = KiloTaxNotification(
      id: 'logbook_w${currentWeek}_${DateTime.now().millisecondsSinceEpoch}',
      title: '📅 Week $currentWeek of 12 Logbook Completed',
      body:
          'Logbook is ${(progressPercent * 100).toStringAsFixed(0)}% valid for ATO 5-year lock.',
      type: KiloTaxNotificationType.logbookReminder,
      timestamp: DateTime.now(),
      deepLinkRoute: '/logbook',
      data: {'week': currentWeek},
    );
    await addNotification(notification);
    return notification;
  }

  /// Trigger statutory EOFY (June 15, June 28, June 30) odometer snapshot reminder
  Future<KiloTaxNotification?> notifyEofyOdometerReminder({
    required Vehicle vehicle,
    required String financialYearLabel,
    required EofyAlertMilestone milestone,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final notifId =
        'eofy_${vehicle.id}_${financialYearLabel}_day${milestone.day}';

    // Idempotency: prevent duplicate notification for the same milestone in this FY
    if (_notifications.any((n) => n.id == notifId)) {
      return null;
    }

    String body;
    switch (milestone) {
      case EofyAlertMilestone.june15:
        body =
            'Only 15 days left in $financialYearLabel. Snapshot your ${vehicle.displayName} closing odometer to preserve your 5-year logbook tax deduction.';
        break;
      case EofyAlertMilestone.june28:
        body =
            '2 days until 30 June! ATO ITAA 1997 s 28-125 requires your closing odometer reading to maintain your audit-proof business claim.';
        break;
      case EofyAlertMilestone.june30:
        body =
            'Today is 30 June (EOFY). Record your closing odometer reading today to lock in your 5-year logbook exemption.';
        break;
    }

    final notification = KiloTaxNotification(
      id: notifId,
      title: milestone.title,
      body: body,
      type: KiloTaxNotificationType.eofyAlert,
      timestamp: now,
      deepLinkRoute: '/odometer-closing',
      data: {
        'vehicleId': vehicle.id,
        'financialYear': financialYearLabel,
        'milestoneDay': milestone.day,
      },
    );

    await addNotification(notification);
    return notification;
  }

  /// Automated pipeline: Evaluates vehicles in Years 1-5 of a 12-week logbook
  /// and automatically triggers alerts on June 15, June 28, and June 30 if closing odometer is missing.
  Future<List<KiloTaxNotification>> evaluateEofyAlertPipeline({
    required List<Vehicle> vehicles,
    required bool Function(String vehicleId, String fyLabel)
        isMissingClosingOdometer,
    DateTime? currentDate,
  }) async {
    final date = currentDate ?? DateTime.now();
    final milestone = EofyAlertMilestone.forDate(date);
    if (milestone == null) return [];

    final fyEngine = const AtoTaxPeriodEngine();
    final fyLabel = fyEngine.forDate(date).shortLabel;
    final generated = <KiloTaxNotification>[];

    for (final vehicle in vehicles) {
      // 1. Must be active (not deleted) and logbook method
      if (vehicle.deletedAt != null || vehicle.taxMethod != TaxMethod.logbook) {
        continue;
      }
      // 2. Must have active logbook start date
      if (vehicle.logbookStartDate == null) {
        continue;
      }
      // 3. Must be within Years 1 to 5 of logbook window
      final yearsSinceStart =
          date.difference(vehicle.logbookStartDate!).inDays / 365.25;
      if (yearsSinceStart < 0 || yearsSinceStart > 5.0) {
        continue;
      }
      // 4. Must be missing closing odometer for this FY
      if (!isMissingClosingOdometer(vehicle.id, fyLabel)) {
        continue;
      }

      final notif = await notifyEofyOdometerReminder(
        vehicle: vehicle,
        financialYearLabel: fyLabel,
        milestone: milestone,
        timestamp: date,
      );
      if (notif != null) {
        generated.add(notif);
      }
    }

    return generated;
  }

  /// Add notification to stack
  Future<KiloTaxNotification?> notifyWeeklyEvidenceReview({
    required EvidenceReviewReport report,
    required DateTime now,
  }) async {
    if (!report.canExport) return null;
    final week = EvidenceReviewReport.weekStart(now);
    final cutoff = now.weekday == DateTime.sunday
        ? DateTime(week.year, week.month, week.day + 7)
        : week;
    final count = report.itemsBetween(null, cutoff).length;
    if (count == 0) return null;
    final key = 'weekly_evidence_review_${report.vehicle!.id}';
    final stamp = week.toIso8601String();
    final id = '${key}_$stamp';
    if (_prefs?.getString(key) == stamp ||
        _notifications.any((item) => item.id == id)) {
      return null;
    }
    final notice = KiloTaxNotification(
      id: id,
      title: 'Weekly evidence review',
      body:
          '$count ${count == 1 ? "record needs" : "records need"} review from completed weeks. Open your pending evidence.',
      type: KiloTaxNotificationType.complianceAlert,
      timestamp: now,
      deepLinkRoute: '/evidence-review',
      data: {
        'vehicleId': report.vehicle!.id,
        'financialYear': report.financialYear
      },
    );
    await addNotification(notice);
    await _prefs?.setString(key, stamp);
    return notice;
  }

  Future<void> addNotification(KiloTaxNotification item) async {
    _notifications.insert(0, item);
    // Keep max 50 recent notifications
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
    await _persist();
  }

  /// Mark specific notification as read
  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      await _persist();
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _persist();
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _persist();
  }
}
