import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_services.dart';
import 'exercise_store.dart';

enum TrackingReminderTrigger { largeGap, inconsistency }

class TrackingReminderService {
  TrackingReminderService._();

  static final TrackingReminderService instance = TrackingReminderService._();

  static const String _notificationsEnabledKey = 'notifications_enabled_local';
  static const String _lastNotificationDateKey =
      'tracking_reminder_last_notification_date';
  static const String _lastNotificationTypeKey =
      'tracking_reminder_last_notification_type';
  static const String _recentLogDaysKey = 'tracking_reminder_recent_log_days';
  static const int _reminderNotificationId = 7101;
  static const String _channelId = 'tracking_reminders_v2';
  static const String _channelName = 'Tracking Reminders';
  static const String _channelDescription =
      'Gentle reminders when logging has been inconsistent or paused for a while.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> requestPermissionsIfEnabled() async {
    await init();
    if (!notificationsEnabled) {
      return;
    }

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await androidImplementation
        ?.requestNotificationsPermission();

    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macGranted = await macImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      '[TrackingReminderService] notification permission request results: '
      'android=$androidGranted iOS=$iosGranted macOS=$macGranted',
    );
  }

  Future<String> debugPermissionStatus() async {
    await init();

    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosPermissions = await iosImplementation?.checkPermissions();

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidEnabled = await androidImplementation
        ?.areNotificationsEnabled();

    final macImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macPermissions = await macImplementation?.checkPermissions();

    String formatOptions(NotificationsEnabledOptions? options) {
      if (options == null) {
        return 'unavailable';
      }
      return 'enabled=${options.isEnabled} alert=${options.isAlertEnabled} sound=${options.isSoundEnabled} badge=${options.isBadgeEnabled} provisional=${options.isProvisionalEnabled}';
    }

    return 'notificationsEnabledToggle=$notificationsEnabled\n'
        'androidNotificationsEnabled=${androidEnabled?.toString() ?? 'unavailable'}\n'
        'androidChannel=$_channelId importance=high\n'
        'iosPermissions=${formatOptions(iosPermissions)}\n'
        'macPermissions=${formatOptions(macPermissions)}';
  }

  bool get notificationsEnabled =>
      _prefs?.getBool(_notificationsEnabledKey) ?? true;

  Future<void> setNotificationsEnabled(bool value) async {
    await init();
    await _prefs!.setBool(_notificationsEnabledKey, value);
    if (!value) {
      await cancelReminder();
      return;
    }
    await requestPermissionsIfEnabled();
  }

  Future<void> handleLogRecorded() async {
    await init();
    final today = _dateKey(DateTime.now());
    final recentDays =
        (_prefs!.getStringList(_recentLogDaysKey) ?? const <String>[])
            .where((item) => item.trim().isNotEmpty)
            .toSet()
            .toList(growable: true);
    recentDays.remove(today);
    recentDays.insert(0, today);
    if (recentDays.length > 30) {
      recentDays.removeRange(30, recentDays.length);
    }
    await _prefs!.setStringList(_recentLogDaysKey, recentDays);
    await cancelReminder();
  }

  Future<void> refreshReminderState() async {
    await init();
    if (!notificationsEnabled) {
      await cancelReminder();
      return;
    }

    final trigger = await _detectTrigger();
    if (trigger == null) {
      await cancelReminder();
    }
  }

  Future<void> evaluateAndNotifyIfNeeded() async {
    await init();
    if (!notificationsEnabled) {
      await cancelReminder();
      return;
    }

    final trigger = await _detectTrigger();
    if (trigger == null) {
      await cancelReminder();
      return;
    }

    final today = _dateKey(DateTime.now());
    final lastDate = _prefs!.getString(_lastNotificationDateKey) ?? '';
    final lastType = _prefs!.getString(_lastNotificationTypeKey) ?? '';
    final triggerKey = trigger.name;

    if (lastDate == today && lastType == triggerKey) {
      return;
    }

    final message = _messageForTrigger(trigger);
    await _plugin.show(
      _reminderNotificationId,
      message.title,
      message.body,
      _notificationDetails(),
    );

    await _prefs!.setString(_lastNotificationDateKey, today);
    await _prefs!.setString(_lastNotificationTypeKey, triggerKey);
  }

  Future<String> debugStatus() async {
    await init();
    final timeline = await _collectTimeline();
    timeline.sort((a, b) => b.compareTo(a));
    final trigger = await _detectTrigger();
    final today = DateTime.now();
    final latest = timeline.isEmpty ? null : timeline.first;
    final loggedToday = timeline.any((day) => _isSameDay(day, today));
    final gapDays = latest == null
        ? null
        : DateTime(
            today.year,
            today.month,
            today.day,
          ).difference(DateTime(latest.year, latest.month, latest.day)).inDays;
    final recentSeven = timeline
        .where((day) => today.difference(day).inDays < 7)
        .map(_dateKey)
        .toSet();

    return 'notificationsEnabled=$notificationsEnabled\n'
        'loggedToday=$loggedToday\n'
        'latestLogDay=${latest == null ? 'none' : _dateKey(latest)}\n'
        'gapDays=${gapDays?.toString() ?? 'none'}\n'
        'recentUniqueDaysLast7=${recentSeven.length}\n'
        'timeline=${timeline.take(7).map(_dateKey).join(', ')}\n'
        'detectedTrigger=${trigger?.name ?? 'none'}';
  }

  Future<void> debugForceNotification({
    TrackingReminderTrigger trigger = TrackingReminderTrigger.largeGap,
  }) async {
    await init();
    final message = _messageForTrigger(trigger);
    final debugNotificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1 << 31,
    );
    await _plugin.show(
      debugNotificationId,
      message.title,
      message.body,
      _notificationDetails(),
    );
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
    );
  }

  Future<void> cancelReminder() async {
    await init();
    await _plugin.cancel(_reminderNotificationId);
  }

  Future<TrackingReminderTrigger?> _detectTrigger() async {
    final timeline = await _collectTimeline();
    if (timeline.isEmpty) {
      return null;
    }

    final today = DateTime.now();
    final loggedToday = timeline.any((day) => _isSameDay(day, today));
    if (loggedToday) {
      return null;
    }

    timeline.sort((a, b) => b.compareTo(a));
    final lastLog = timeline.first;
    final gapDays = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(lastLog.year, lastLog.month, lastLog.day)).inDays;

    if (gapDays >= 3) {
      return TrackingReminderTrigger.largeGap;
    }

    final recentSeven = timeline
        .where((day) => today.difference(day).inDays < 7)
        .map(_dateKey)
        .toSet();

    if (recentSeven.length <= 2 && gapDays >= 1) {
      return TrackingReminderTrigger.inconsistency;
    }

    return null;
  }

  Future<List<DateTime>> _collectTimeline() async {
    await AppServices.isar.init();

    final points = <DateTime>[];

    final moodEntries = await AppServices.isar.getRecentMoodEntries(days: 30);
    points.addAll(moodEntries.map((entry) => entry.timestamp.toLocal()));

    final symptomEntries = await AppServices.isar.getRecentSymptomEntries(
      days: 30,
    );
    points.addAll(symptomEntries.map((entry) => entry.timestamp.toLocal()));

    final exerciseStore = ExerciseStore();
    await exerciseStore.ensureReady();
    final exerciseHistory = exerciseStore.getRecentExerciseHistory(limit: 40);
    points.addAll(
      exerciseHistory
          .map((item) => DateTime.tryParse(item['timestamp'] ?? ''))
          .whereType<DateTime>()
          .map((item) => item.toLocal()),
    );

    final distinctDays = points
        .map((point) {
          return DateTime(point.year, point.month, point.day);
        })
        .toSet()
        .toList(growable: true);

    final persistedDays =
        _prefs!.getStringList(_recentLogDaysKey) ?? const <String>[];
    for (final day in persistedDays) {
      final parsed = DateTime.tryParse(day);
      if (parsed != null) {
        distinctDays.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }

    return distinctDays;
  }

  _ReminderMessage _messageForTrigger(TrackingReminderTrigger trigger) {
    switch (trigger) {
      case TrackingReminderTrigger.largeGap:
        return const _ReminderMessage(
          title: 'A gentle check-in',
          body:
              'It has been a little while since your last log. If today feels okay for it, one small check-in can help you reconnect with your patterns.',
        );
      case TrackingReminderTrigger.inconsistency:
        return const _ReminderMessage(
          title: 'A small reminder',
          body:
              'Your recent logging has been a bit uneven. Even a quick check-in today can make your patterns easier to understand.',
        );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateKey(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.toIso8601String().split('T').first;
  }
}

class _ReminderMessage {
  const _ReminderMessage({required this.title, required this.body});

  final String title;
  final String body;
}
