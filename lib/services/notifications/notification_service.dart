import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Type of Notification Event
enum KiloTaxNotificationType {
  tripDetected,
  dailySummary,
  logbookReminder,
  complianceAlert,
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
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
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

  List<KiloTaxNotification> get notifications => List.unmodifiable(_notifications);

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
        } catch (_) {}
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
      body: 'Claim \$${estimatedDeduction.toStringAsFixed(2)} tax deduction with 1 tap.',
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
      body: 'You have $unclassifiedTripsCount unlogged trips today (\$$potentialTaxClaim deduction). Clear before smoko!',
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
      body: 'Logbook is ${(progressPercent * 100).toStringAsFixed(0)}% valid for ATO 5-year lock.',
      type: KiloTaxNotificationType.logbookReminder,
      timestamp: DateTime.now(),
      deepLinkRoute: '/logbook',
      data: {'week': currentWeek},
    );
    await addNotification(notification);
    return notification;
  }

  /// Add notification to stack
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
