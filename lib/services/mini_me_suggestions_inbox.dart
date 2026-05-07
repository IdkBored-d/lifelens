import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MiniMeSuggestionsInbox extends ChangeNotifier {
  MiniMeSuggestionsInbox() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleAuthChanged(user);
    });
    _init();
  }

  static const String _viewedDigestsKeyBase =
      'miniMeSuggestionsInbox.viewedDigests';
  static const String _unreadSuggestionsKeyBase =
      'miniMeSuggestionsInbox.unreadSuggestions';
  static const String _deliveryStateKeyBase =
      'miniMeSuggestionsInbox.deliveryState';

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  bool _refreshQueuedFromLog = false;
  String? _loadedScopeKey;
  late final StreamSubscription<User?> _authSub;
  final Set<String> _viewedDigests = <String>{};
  List<_StoredSuggestion> _unread = const <_StoredSuggestion>[];
  _SuggestionDeliveryState _deliveryState = const _SuggestionDeliveryState();

  bool get isReady => _isInitialized;
  bool get isRefreshing => _isRefreshing;
  int get unreadCount => _unread.length;

  List<DailySuggestion> get unreadSuggestions =>
      _unread.map((item) => item.toDailySuggestion()).toList(growable: false);

  Future<void> ensureReady() async {
    await _ensureCurrentScopeLoaded();
  }

  String get _scopeKey => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String get _viewedDigestsKey => '${_viewedDigestsKeyBase}_$_scopeKey';
  String get _unreadSuggestionsKey => '${_unreadSuggestionsKeyBase}_$_scopeKey';
  String get _deliveryStateKey => '${_deliveryStateKeyBase}_$_scopeKey';

  void _clearInMemoryStateForScope(String scopeKey) {
    _loadedScopeKey = scopeKey;
    _viewedDigests.clear();
    _unread = const <_StoredSuggestion>[];
    _deliveryState = const _SuggestionDeliveryState();
    _refreshQueued = false;
    _refreshQueuedFromLog = false;
  }

  void _handleAuthChanged(User? user) {
    final nextScopeKey = user?.uid ?? 'guest';
    if (_loadedScopeKey == nextScopeKey) return;
    _clearInMemoryStateForScope(nextScopeKey);
    notifyListeners();
    if (_isInitialized) {
      unawaited(_loadScopedState().then((_) => notifyListeners()));
    }
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadScopedState();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadScopedState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    _loadedScopeKey = _scopeKey;
    _viewedDigests
      ..clear()
      ..addAll(prefs.getStringList(_viewedDigestsKey) ?? const []);
    _unread = const <_StoredSuggestion>[];
    _deliveryState = const _SuggestionDeliveryState();

    final rawUnread = prefs.getString(_unreadSuggestionsKey);
    if (rawUnread != null && rawUnread.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUnread);
        if (decoded is List) {
          _unread = decoded
              .whereType<Map>()
              .map(
                (item) =>
                    _StoredSuggestion.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false);
        }
      } catch (_) {
        // Fall through to empty state.
      }
    }

    final rawDeliveryState = prefs.getString(_deliveryStateKey);
    if (rawDeliveryState != null && rawDeliveryState.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDeliveryState);
        if (decoded is Map) {
          _deliveryState = _SuggestionDeliveryState.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          return;
        }
      } catch (_) {
        // Fall through to empty state.
      }
    }

    _deliveryState = const _SuggestionDeliveryState();
  }

  Future<void> _ensureCurrentScopeLoaded() async {
    await _init();
    if (_loadedScopeKey == _scopeKey) return;
    await _loadScopedState();
    notifyListeners();
  }

  Future<void> refresh({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    bool fromLog = false,
  }) async {
    await _ensureCurrentScopeLoaded();
    if (_isRefreshing) {
      _refreshQueued = true;
      _refreshQueuedFromLog = _refreshQueuedFromLog || fromLog;
      return;
    }

    _isRefreshing = true;
    try {
      var currentFromLog = fromLog;
      do {
        _refreshQueued = false;
        final nextFromLog = currentFromLog || _refreshQueuedFromLog;
        _refreshQueuedFromLog = false;
        await _refreshOnce(
          moodStore: moodStore,
          sleepStore: sleepStore,
          fromLog: nextFromLog,
        );
        currentFromLog = false;
      } while (_refreshQueued);
    } finally {
      _isRefreshing = false;
      _refreshQueuedFromLog = false;
    }
  }

  Future<void> _refreshOnce({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required bool fromLog,
  }) async {
    if (!fromLog) {
      return;
    }

    final cadenceDecision = await _evaluateCadenceDecision(
      moodStore: moodStore,
      sleepStore: sleepStore,
      fromLog: fromLog,
    );
    if (!cadenceDecision.shouldRequest) {
      return;
    }

    final forceSurface =
        cadenceDecision.eventOverride || cadenceDecision.window == 'log_update';
    final avoidedSuggestions = _recentSuggestionActionsForAvoidance();
    if (forceSurface && _unread.isNotEmpty) {
      _unread = const <_StoredSuggestion>[];
      await _persistUnread();
      notifyListeners();
    }

    final snapshot = await DailySuggestionsService.instance.buildSnapshot(
      moodStore: moodStore,
      sleepStore: sleepStore,
      recentSuggestionActions: avoidedSuggestions,
      suggestionWindow: cadenceDecision.window,
      triggerReason: cadenceDecision.triggerReason,
      eventOverride: cadenceDecision.eventOverride,
    );

    final currentSuggestions = snapshot.suggestions
        .where((item) => item.action.trim().isNotEmpty)
        .take(1)
        .map(_StoredSuggestion.fromDailySuggestion)
        .toList(growable: false);

    var nextUnread = forceSurface
        ? currentSuggestions
        : currentSuggestions
              .where((item) => !_viewedDigests.contains(item.digest))
              .toList(growable: false);

    if (!forceSurface && nextUnread.isNotEmpty) {
      final merged = <_StoredSuggestion>[...nextUnread];
      for (final item in _unread) {
        if (merged.any((existing) => existing.digest == item.digest)) {
          continue;
        }
        merged.add(item);
        if (merged.length >= 12) break;
      }
      nextUnread = merged;
    }

    if (currentSuggestions.isNotEmpty) {
      _recordDeliveryIfRequested(
        cadenceDecision,
        deliveredSuggestions: currentSuggestions,
      );
    }

    if (_sameDigests(_unread, nextUnread)) {
      await _persistDeliveryState();
      return;
    }

    _unread = nextUnread;
    await _persistUnread();
    await _persistDeliveryState();
    notifyListeners();
  }

  Future<void> markSuggestionsViewed(
    Iterable<DailySuggestion> suggestions,
  ) async {
    await _ensureCurrentScopeLoaded();

    final digests = suggestions
        .map(_StoredSuggestion.fromDailySuggestion)
        .map((item) => item.digest)
        .toSet();

    if (digests.isEmpty) return;

    var changed = false;
    for (final digest in digests) {
      if (_viewedDigests.add(digest)) {
        changed = true;
      }
    }

    final nextUnread = _unread
        .where((item) => !digests.contains(item.digest))
        .toList(growable: false);
    if (!_sameDigests(_unread, nextUnread)) {
      _unread = nextUnread;
      changed = true;
    }

    if (!changed) return;

    await _persistViewedDigests();
    await _persistUnread();
    notifyListeners();
  }

  Future<void> clearUnreadSuggestions({bool markAsViewed = true}) async {
    await _ensureCurrentScopeLoaded();

    if (_unread.isEmpty) return;

    if (markAsViewed) {
      _viewedDigests.addAll(_unread.map((item) => item.digest));
    }
    _unread = const <_StoredSuggestion>[];

    if (markAsViewed) {
      await _persistViewedDigests();
    }
    await _persistUnread();
    notifyListeners();
  }

  Future<void> enqueueSymptomInsight({
    required List<String> topConditions,
    required List<String> symptoms,
  }) async {
    await _ensureCurrentScopeLoaded();

    final cleanedConditions = topConditions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList(growable: false);
    if (cleanedConditions.isEmpty) return;

    final action =
        'Here are your possible conditions: ${cleanedConditions.join(', ')}.';
    final reason = 'This is just a quick guide, not a diagnosis.';

    final suggestion = DailySuggestion(
      title: 'Symptom analysis ready',
      action: action,
      reason: reason,
      category: 'Symptoms',
      priority: 5,
      icon: Icons.health_and_safety_rounded,
    );

    final stored = _StoredSuggestion.fromDailySuggestion(suggestion);
    final nextUnread = <_StoredSuggestion>[stored];

    if (_sameDigests(_unread, nextUnread)) return;

    _unread = nextUnread;
    await _persistUnread();
    notifyListeners();
  }

  Future<_SuggestionCadenceDecision> _evaluateCadenceDecision({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required bool fromLog,
  }) async {
    if (!fromLog) {
      return _SuggestionCadenceDecision.skip();
    }

    final now = DateTime.now();
    final activeSymptomsCount = await _activeSymptomsCount();
    final latestMood = moodStore.items.isEmpty ? null : moodStore.items.first;
    final previousMood = moodStore.items.length < 2 ? null : moodStore.items[1];
    final latestSleep = sleepStore.items.isEmpty
        ? null
        : sleepStore.items.first;
    final latestExerciseTimestamp = await _latestExerciseTimestamp();
    final latestSymptomTimestamp = await _latestSymptomTimestamp();
    final latestLogTimestamp = _maxTimestamp(<DateTime?>[
      latestMood?.createdAt,
      latestSleep?.wakeTime,
      latestSleep?.date,
      latestExerciseTimestamp,
      latestSymptomTimestamp,
    ]);
    final contextSignature = _buildContextSignature(
      latestMood: latestMood,
      latestSleep: latestSleep,
      latestExerciseTimestamp: latestExerciseTimestamp,
      latestSymptomTimestamp: latestSymptomTimestamp,
      activeSymptomsCount: activeSymptomsCount,
    );

    final lastDeliveredAt = _deliveryState.lastDeliveredAt;
    final hasNewLogSinceLast =
        latestLogTimestamp != null &&
        (lastDeliveredAt == null ||
            latestLogTimestamp.isAfter(lastDeliveredAt));
    final contextChanged =
        contextSignature.isNotEmpty &&
        contextSignature != _deliveryState.lastDeliveredContextSignature;

    final strongStateShift = _hasStrongStateShift(latestMood, previousMood);
    final majorDrop = _hasMajorDrop(latestMood, previousMood);
    final highDistress = _isHighDistress(
      latestMoodLabel: latestMood?.moodLabel,
      latestMoodIntensity: latestMood?.intensity ?? 0,
      activeSymptomsCount: activeSymptomsCount,
    );
    final eventOverride = highDistress || majorDrop;

    if (eventOverride && _canSendEventOverride(now)) {
      return _SuggestionCadenceDecision(
        shouldRequest: true,
        window: 'event_override',
        triggerReason: highDistress
            ? 'high distress or symptom escalation detected'
            : 'major negative mood shift detected',
        eventOverride: true,
        now: now,
        contextSignature: contextSignature,
      );
    }

    // Always request after new logs so each update can surface a fresh
    // suggestion; for context-only changes keep a cooldown.
    if (hasNewLogSinceLast) {
      return _SuggestionCadenceDecision(
        shouldRequest: true,
        window: 'log_update',
        triggerReason:
            'new logs were added since the last delivered suggestion',
        eventOverride: false,
        now: now,
        contextSignature: contextSignature,
      );
    }

    if (contextChanged && _passesUpdateCooldown(now)) {
      return _SuggestionCadenceDecision(
        shouldRequest: true,
        window: 'log_update',
        triggerReason:
            'context changed enough to justify a refreshed suggestion',
        eventOverride: false,
        now: now,
        contextSignature: contextSignature,
      );
    }

    final window = _currentWindow(now);
    if (window == null) {
      return _SuggestionCadenceDecision.skip();
    }

    final windowStamp = '${_dayStamp(now)}:$window';
    if (_deliveryState.deliveredWindowStamps.contains(windowStamp)) {
      return _SuggestionCadenceDecision.skip();
    }

    if (window == 'midday_checkin' &&
        !hasNewLogSinceLast &&
        !strongStateShift) {
      return _SuggestionCadenceDecision.skip();
    }

    // Prevent repeating suggestions for effectively unchanged logs.
    if (!contextChanged) {
      return _SuggestionCadenceDecision.skip();
    }

    final triggerReason = switch (window) {
      'morning_anchor' =>
        'first morning suggestion using overnight sleep and recent mood trend',
      'midday_checkin' =>
        hasNewLogSinceLast
            ? 'new logs detected since last suggestion'
            : 'strong state shift detected since last suggestion',
      'evening_reflection' =>
        'evening wrap-up with review and next-day preparation context',
      _ => 'scheduled refresh',
    };

    return _SuggestionCadenceDecision(
      shouldRequest: true,
      window: window,
      triggerReason: triggerReason,
      eventOverride: false,
      now: now,
      contextSignature: contextSignature,
    );
  }

  Future<int> _activeSymptomsCount() async {
    try {
      await AppServices.isar.init();
      final symptoms = await AppServices.isar.getActiveSymptomEntries();
      return symptoms.length;
    } catch (_) {
      return 0;
    }
  }

  Future<DateTime?> _latestExerciseTimestamp() async {
    try {
      final exerciseStore = ExerciseStore();
      await exerciseStore.ensureReady();
      final latest = exerciseStore.getRecentExerciseHistory(limit: 1);
      if (latest.isEmpty) return null;
      return DateTime.tryParse(latest.first['timestamp'] ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> _latestSymptomTimestamp() async {
    try {
      await AppServices.isar.init();
      final latest = await AppServices.isar.getRecentSymptomEntries(days: 45);
      if (latest.isEmpty) return null;
      return latest.first.timestamp;
    } catch (_) {
      return null;
    }
  }

  DateTime? _maxTimestamp(List<DateTime?> values) {
    DateTime? maxValue;
    for (final value in values) {
      if (value == null) continue;
      if (maxValue == null || value.isAfter(maxValue)) {
        maxValue = value;
      }
    }
    return maxValue;
  }

  bool _hasStrongStateShift(MoodCheckIn? latest, MoodCheckIn? previous) {
    if (latest == null || previous == null) return false;
    final intensityShift = (latest.intensity - previous.intensity).abs() >= 2;
    final valenceShift =
        _moodValence(latest.moodLabel) != _moodValence(previous.moodLabel);
    return intensityShift || valenceShift;
  }

  bool _hasMajorDrop(MoodCheckIn? latest, MoodCheckIn? previous) {
    if (latest == null || previous == null) return false;
    return _moodValence(previous.moodLabel) > 0 &&
        _moodValence(latest.moodLabel) < 0;
  }

  bool _isHighDistress({
    required String? latestMoodLabel,
    required int latestMoodIntensity,
    required int activeSymptomsCount,
  }) {
    final mood = (latestMoodLabel ?? '').trim().toLowerCase();
    final distressMood = const {
      'sad',
      'sadness',
      'scared',
      'fear',
      'anxious',
      'angry',
      'anger',
      'frustrated',
    }.contains(mood);
    return (distressMood && latestMoodIntensity >= 4) ||
        activeSymptomsCount >= 3;
  }

  int _moodValence(String moodLabel) {
    final mood = moodLabel.trim().toLowerCase();
    if (const {'happy', 'joy', 'love', 'affectionate'}.contains(mood)) {
      return 1;
    }
    if (const {
      'sad',
      'sadness',
      'angry',
      'anger',
      'scared',
      'fear',
      'anxious',
      'frustrated',
    }.contains(mood)) {
      return -1;
    }
    return 0;
  }

  bool _canSendEventOverride(DateTime now) {
    final lastEventOverrideAt = _deliveryState.lastEventOverrideAt;
    if (lastEventOverrideAt == null) return true;
    return now.difference(lastEventOverrideAt) >= const Duration(minutes: 90);
  }

  bool _passesUpdateCooldown(DateTime now) {
    final lastDeliveredAt = _deliveryState.lastDeliveredAt;
    if (lastDeliveredAt == null) return true;
    return now.difference(lastDeliveredAt) >= const Duration(minutes: 10);
  }

  String _buildContextSignature({
    required MoodCheckIn? latestMood,
    required Sleep? latestSleep,
    required DateTime? latestExerciseTimestamp,
    required DateTime? latestSymptomTimestamp,
    required int activeSymptomsCount,
  }) {
    final moodStamp = latestMood == null
        ? 'mood:none'
        : 'mood:${latestMood.createdAt.microsecondsSinceEpoch}:${latestMood.moodLabel}:${latestMood.intensity}';
    final sleepStamp = latestSleep == null
        ? 'sleep:none'
        : 'sleep:${latestSleep.wakeTime.microsecondsSinceEpoch}:${latestSleep.duration.inMinutes}:${latestSleep.quality.label}';
    final exerciseStamp = latestExerciseTimestamp == null
        ? 'exercise:none'
        : 'exercise:${latestExerciseTimestamp.microsecondsSinceEpoch}';
    final symptomStamp = latestSymptomTimestamp == null
        ? 'symptoms:$activeSymptomsCount:none'
        : 'symptoms:$activeSymptomsCount:${latestSymptomTimestamp.microsecondsSinceEpoch}';
    return [moodStamp, sleepStamp, exerciseStamp, symptomStamp].join('|');
  }

  String? _currentWindow(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 11) return 'morning_anchor';
    if (hour >= 11 && hour < 17) return 'midday_checkin';
    if (hour >= 17 && hour < 23) return 'evening_reflection';
    return null;
  }

  String _dayStamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  List<String> _recentSuggestionActionsForAvoidance() {
    final values = <String>[
      ..._deliveryState.recentDeliveredSuggestionActions,
      ..._unread.map((item) => item.action),
    ];
    final deduped = <String>[];
    for (final value in values.reversed) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (deduped.any((item) => item.toLowerCase() == trimmed.toLowerCase())) {
        continue;
      }
      deduped.add(trimmed);
      if (deduped.length >= 10) break;
    }
    return deduped.toList(growable: false);
  }

  void _recordDeliveryIfRequested(
    _SuggestionCadenceDecision decision, {
    required List<_StoredSuggestion> deliveredSuggestions,
  }) {
    if (!decision.shouldRequest ||
        decision.window == null ||
        decision.now == null) {
      return;
    }

    final now = decision.now!;
    final nextWindows = List<String>.from(_deliveryState.deliveredWindowStamps);
    nextWindows.add('${_dayStamp(now)}:${decision.window!}');
    if (nextWindows.length > 40) {
      nextWindows.removeRange(0, nextWindows.length - 40);
    }
    final nextRecentSuggestions = <String>[
      ..._deliveryState.recentDeliveredSuggestionActions,
      ...deliveredSuggestions.map((item) => item.action.trim()),
    ].where((item) => item.isNotEmpty).toList(growable: true);
    if (nextRecentSuggestions.length > 20) {
      nextRecentSuggestions.removeRange(0, nextRecentSuggestions.length - 20);
    }

    _deliveryState = _deliveryState.copyWith(
      lastDeliveredAtIso: now.toIso8601String(),
      deliveredWindowStamps: nextWindows,
      recentDeliveredSuggestionActions: nextRecentSuggestions,
      lastEventOverrideAtIso: decision.eventOverride
          ? now.toIso8601String()
          : _deliveryState.lastEventOverrideAtIso,
      lastDeliveredContextSignature:
          decision.contextSignature ??
          _deliveryState.lastDeliveredContextSignature,
    );
  }

  bool _sameDigests(
    List<_StoredSuggestion> left,
    List<_StoredSuggestion> right,
  ) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].digest != right[i].digest) {
        return false;
      }
    }
    return true;
  }

  Future<void> _persistViewedDigests() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final values = _viewedDigests.toList(growable: true);
    if (values.length > 120) {
      values.removeRange(0, values.length - 120);
    }
    await prefs.setStringList(_viewedDigestsKey, values);
  }

  Future<void> _persistUnread() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final payload = jsonEncode(
      _unread.map((item) => item.toJson()).toList(growable: false),
    );
    await prefs.setString(_unreadSuggestionsKey, payload);
  }

  Future<void> _persistDeliveryState() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _deliveryStateKey,
      jsonEncode(_deliveryState.toJson()),
    );
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}

class _StoredSuggestion {
  const _StoredSuggestion({
    required this.digest,
    required this.title,
    required this.reason,
    required this.action,
    required this.category,
    required this.priority,
    required this.iconCodePoint,
    required this.iconFontFamily,
  });

  final String digest;
  final String title;
  final String reason;
  final String action;
  final String category;
  final int priority;
  final int iconCodePoint;
  final String? iconFontFamily;

  factory _StoredSuggestion.fromDailySuggestion(DailySuggestion suggestion) {
    return _StoredSuggestion(
      digest: _digestForSuggestion(suggestion),
      title: suggestion.title,
      reason: suggestion.reason,
      action: suggestion.action,
      category: suggestion.category,
      priority: suggestion.priority,
      iconCodePoint: suggestion.icon.codePoint,
      iconFontFamily: suggestion.icon.fontFamily,
    );
  }

  factory _StoredSuggestion.fromJson(Map<String, dynamic> json) {
    return _StoredSuggestion(
      digest: (json['digest'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      category: (json['category'] ?? 'Suggestion').toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      iconCodePoint:
          (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.tips_and_updates_rounded.codePoint,
      iconFontFamily: json['iconFontFamily']?.toString(),
    );
  }

  DailySuggestion toDailySuggestion() {
    return DailySuggestion(
      title: title,
      reason: reason,
      action: action,
      category: category,
      priority: priority,
      icon: IconData(
        iconCodePoint,
        fontFamily: iconFontFamily ?? 'MaterialIcons',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'digest': digest,
      'title': title,
      'reason': reason,
      'action': action,
      'category': category,
      'priority': priority,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
    };
  }

  static String _digestForSuggestion(DailySuggestion suggestion) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    return [
      normalize(suggestion.title),
      normalize(suggestion.action),
      normalize(suggestion.reason),
    ].join('|');
  }
}

class _SuggestionDeliveryState {
  const _SuggestionDeliveryState({
    this.lastDeliveredAtIso = '',
    this.lastEventOverrideAtIso = '',
    this.lastDeliveredContextSignature = '',
    this.deliveredWindowStamps = const <String>[],
    this.recentDeliveredSuggestionActions = const <String>[],
  });

  final String lastDeliveredAtIso;
  final String lastEventOverrideAtIso;
  final String lastDeliveredContextSignature;
  final List<String> deliveredWindowStamps;
  final List<String> recentDeliveredSuggestionActions;

  DateTime? get lastDeliveredAt => DateTime.tryParse(lastDeliveredAtIso);
  DateTime? get lastEventOverrideAt =>
      DateTime.tryParse(lastEventOverrideAtIso);

  factory _SuggestionDeliveryState.fromJson(Map<String, dynamic> json) {
    final rawWindows = json['deliveredWindowStamps'];
    final rawRecentSuggestions = json['recentDeliveredSuggestionActions'];
    return _SuggestionDeliveryState(
      lastDeliveredAtIso: (json['lastDeliveredAtIso'] ?? '').toString(),
      lastEventOverrideAtIso: (json['lastEventOverrideAtIso'] ?? '').toString(),
      lastDeliveredContextSignature:
          (json['lastDeliveredContextSignature'] ?? '').toString(),
      deliveredWindowStamps: rawWindows is List
          ? rawWindows.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      recentDeliveredSuggestionActions: rawRecentSuggestions is List
          ? rawRecentSuggestions
                .map((item) => item.toString())
                .where((item) => item.trim().isNotEmpty)
                .take(20)
                .toList(growable: false)
          : const <String>[],
    );
  }

  _SuggestionDeliveryState copyWith({
    String? lastDeliveredAtIso,
    String? lastEventOverrideAtIso,
    String? lastDeliveredContextSignature,
    List<String>? deliveredWindowStamps,
    List<String>? recentDeliveredSuggestionActions,
  }) {
    return _SuggestionDeliveryState(
      lastDeliveredAtIso: lastDeliveredAtIso ?? this.lastDeliveredAtIso,
      lastEventOverrideAtIso:
          lastEventOverrideAtIso ?? this.lastEventOverrideAtIso,
      lastDeliveredContextSignature:
          lastDeliveredContextSignature ?? this.lastDeliveredContextSignature,
      deliveredWindowStamps:
          deliveredWindowStamps ?? this.deliveredWindowStamps,
      recentDeliveredSuggestionActions:
          recentDeliveredSuggestionActions ??
          this.recentDeliveredSuggestionActions,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lastDeliveredAtIso': lastDeliveredAtIso,
      'lastEventOverrideAtIso': lastEventOverrideAtIso,
      'lastDeliveredContextSignature': lastDeliveredContextSignature,
      'deliveredWindowStamps': deliveredWindowStamps,
      'recentDeliveredSuggestionActions': recentDeliveredSuggestionActions,
    };
  }
}

class _SuggestionCadenceDecision {
  const _SuggestionCadenceDecision({
    required this.shouldRequest,
    this.window,
    this.triggerReason,
    this.eventOverride = false,
    this.now,
    this.contextSignature,
  });

  factory _SuggestionCadenceDecision.skip() {
    return const _SuggestionCadenceDecision(shouldRequest: false);
  }

  final bool shouldRequest;
  final String? window;
  final String? triggerReason;
  final bool eventOverride;
  final DateTime? now;
  final String? contextSignature;
}
