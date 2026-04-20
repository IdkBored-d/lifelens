import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MiniMeSuggestionsInbox extends ChangeNotifier {
  MiniMeSuggestionsInbox() {
    _init();
  }

  static const String _viewedDigestsKeyBase =
      'miniMeSuggestionsInbox.viewedDigests';
  static const String _unreadSuggestionsKeyBase =
      'miniMeSuggestionsInbox.unreadSuggestions';
    static const String _pendingFollowUpsKeyBase =
      'miniMeSuggestionsInbox.pendingFollowUps';

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isRefreshing = false;
  String? _loadedScopeKey;
  final Set<String> _viewedDigests = <String>{};
  List<_StoredSuggestion> _unread = const <_StoredSuggestion>[];
  List<_PendingFollowUp> _pendingFollowUps = const <_PendingFollowUp>[];

  bool get isReady => _isInitialized;
  bool get isRefreshing => _isRefreshing;
  int get unreadCount => _unread.length;

  List<DailySuggestion> get unreadSuggestions =>
      _unread.map((item) => item.toDailySuggestion()).toList(growable: false);

  String get _scopeKey => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String get _viewedDigestsKey => '${_viewedDigestsKeyBase}_$_scopeKey';
  String get _unreadSuggestionsKey => '${_unreadSuggestionsKeyBase}_$_scopeKey';
  String get _pendingFollowUpsKey => '${_pendingFollowUpsKeyBase}_$_scopeKey';

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

    _unread = const <_StoredSuggestion>[];

    final rawPending = prefs.getString(_pendingFollowUpsKey);
    if (rawPending != null && rawPending.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPending);
        if (decoded is List) {
          _pendingFollowUps = decoded
              .whereType<Map>()
              .map(
                (item) =>
                    _PendingFollowUp.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false);
          return;
        }
      } catch (_) {
        // Fall through to empty state.
      }
    }

    _pendingFollowUps = const <_PendingFollowUp>[];
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
  }) async {
    await _ensureCurrentScopeLoaded();
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      final snapshot = await DailySuggestionsService.instance.buildSnapshot(
        moodStore: moodStore,
        sleepStore: sleepStore,
      );

      final currentSuggestions = snapshot.suggestions
          .where((item) => item.action.trim().isNotEmpty)
          .map(_StoredSuggestion.fromDailySuggestion)
          .toList(growable: false);

      var nextUnread = currentSuggestions
          .where((item) => !_viewedDigests.contains(item.digest))
          .toList(growable: false);

      final followUpSuggestions = await _buildFollowUpSuggestions(
        moodStore: moodStore,
        sleepStore: sleepStore,
      );
      if (followUpSuggestions.isNotEmpty) {
        final existingDigests = nextUnread.map((item) => item.digest).toSet();
        final merged = <_StoredSuggestion>[...nextUnread];
        for (final followUp in followUpSuggestions) {
          if (_viewedDigests.contains(followUp.digest)) continue;
          if (existingDigests.add(followUp.digest)) {
            merged.add(followUp);
          }
        }
        nextUnread = merged;
      }

      if (_sameDigests(_unread, nextUnread)) {
        return;
      }

      _unread = nextUnread;
      await _persistUnread();
      await _persistPendingFollowUps();
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
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

    final viewedStored = suggestions
        .map(_StoredSuggestion.fromDailySuggestion)
        .where((item) => item.action.trim().isNotEmpty)
        .where((item) => item.category.toLowerCase() != 'follow-up')
        .toList(growable: false);
    if (viewedStored.isNotEmpty) {
      final now = DateTime.now();
      var pendingChanged = false;
      final nextPending = List<_PendingFollowUp>.from(_pendingFollowUps);
      for (final item in viewedStored) {
        final alreadyTracked = nextPending.any(
          (pending) => pending.originDigest == item.digest,
        );
        if (alreadyTracked) continue;
        nextPending.add(
          _PendingFollowUp(
            originDigest: item.digest,
            action: item.action,
            reason: item.reason,
            viewedAtIso: now.toIso8601String(),
            sentCount: 0,
            lastSentAtIso: '',
          ),
        );
        pendingChanged = true;
      }
      if (pendingChanged) {
        _pendingFollowUps = nextPending;
      }
    }

    await _persistViewedDigests();
    await _persistUnread();
    await _persistPendingFollowUps();
    notifyListeners();
  }

  Future<List<_StoredSuggestion>> _buildFollowUpSuggestions({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
  }) async {
    if (_pendingFollowUps.isEmpty) return const <_StoredSuggestion>[];

    final now = DateTime.now();
    final followUps = <_StoredSuggestion>[];
    final nextPending = <_PendingFollowUp>[];
    final exerciseStore = ExerciseStore();
    await exerciseStore.ensureReady();

    for (final pending in _pendingFollowUps) {
      final viewedAt = DateTime.tryParse(pending.viewedAtIso);
      if (viewedAt == null) {
        continue;
      }

      // Stop retrying stale follow-ups.
      if (now.difference(viewedAt) > const Duration(days: 3)) {
        continue;
      }

      // Cap retries so reminders do not become repetitive.
      if (pending.sentCount >= 2) {
        continue;
      }

      final hoursSinceViewed = now.difference(viewedAt).inHours;
      if (hoursSinceViewed < 3) {
        nextPending.add(pending);
        continue;
      }

      final lastSentAt = DateTime.tryParse(pending.lastSentAtIso);
      if (lastSentAt != null && _isSameDay(lastSentAt, now)) {
        nextPending.add(pending);
        continue;
      }

      final hasMoodAfter = moodStore.items.any(
        (item) => item.createdAt.isAfter(viewedAt),
      );
      final hasSleepAfter = sleepStore.items.any(
        (item) =>
            item.date.isAfter(viewedAt) || item.wakeTime.isAfter(viewedAt),
      );
      final hasExerciseAfter = exerciseStore
          .getRecentExerciseHistory(limit: 60)
          .map((entry) => DateTime.tryParse(entry['timestamp'] ?? ''))
          .whereType<DateTime>()
          .any((timestamp) => timestamp.isAfter(viewedAt));

      final anyProgressAfterViewed =
          hasMoodAfter || hasSleepAfter || hasExerciseAfter;

      final shortAction = _shortAction(pending.action);
      final followUpDigest =
          'followup|${pending.originDigest}|${now.year}-${now.month}-${now.day}|${pending.sentCount + 1}';

      if (anyProgressAfterViewed) {
        followUps.add(
          _StoredSuggestion(
            digest: followUpDigest,
            title: 'Mini-Me follow-up',
            reason:
                'Nice consistency. A quick reflection helps Mini-Me adapt your next suggestions.',
            action:
                'If you tried "$shortAction", tell Mini-Me how it went so your next plan fits you better.',
            category: 'Follow-up',
            priority: 110,
            iconCodePoint: Icons.follow_the_signs_rounded.codePoint,
            iconFontFamily: Icons.follow_the_signs_rounded.fontFamily,
          ),
        );
      } else {
        followUps.add(
          _StoredSuggestion(
            digest: followUpDigest,
            title: 'Mini-Me follow-up',
            reason:
                'A tiny follow-through now is better than waiting for a perfect moment.',
            action: 'Quick reminder: try "$shortAction" now and check back in after 10-20 minutes.',
            category: 'Follow-up',
            priority: 110,
            iconCodePoint: Icons.notifications_active_rounded.codePoint,
            iconFontFamily: Icons.notifications_active_rounded.fontFamily,
          ),
        );
      }

      nextPending.add(
        pending.copyWith(
          sentCount: pending.sentCount + 1,
          lastSentAtIso: now.toIso8601String(),
        ),
      );
    }

    _pendingFollowUps = nextPending;
    return followUps;
  }

  String _shortAction(String action) {
    final normalized = action.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 90) return normalized;
    return '${normalized.substring(0, 87).trimRight()}...';
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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
    final values = _viewedDigests.toList(growable: false);
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

  Future<void> _persistPendingFollowUps() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final payload = jsonEncode(
      _pendingFollowUps.map((item) => item.toJson()).toList(growable: false),
    );
    await prefs.setString(_pendingFollowUpsKey, payload);
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

class _PendingFollowUp {
  const _PendingFollowUp({
    required this.originDigest,
    required this.action,
    required this.reason,
    required this.viewedAtIso,
    required this.sentCount,
    required this.lastSentAtIso,
  });

  final String originDigest;
  final String action;
  final String reason;
  final String viewedAtIso;
  final int sentCount;
  final String lastSentAtIso;

  factory _PendingFollowUp.fromJson(Map<String, dynamic> json) {
    return _PendingFollowUp(
      originDigest: (json['originDigest'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      viewedAtIso: (json['viewedAtIso'] ?? '').toString(),
      sentCount: (json['sentCount'] as num?)?.toInt() ?? 0,
      lastSentAtIso: (json['lastSentAtIso'] ?? '').toString(),
    );
  }

  _PendingFollowUp copyWith({
    int? sentCount,
    String? lastSentAtIso,
  }) {
    return _PendingFollowUp(
      originDigest: originDigest,
      action: action,
      reason: reason,
      viewedAtIso: viewedAtIso,
      sentCount: sentCount ?? this.sentCount,
      lastSentAtIso: lastSentAtIso ?? this.lastSentAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'originDigest': originDigest,
      'action': action,
      'reason': reason,
      'viewedAtIso': viewedAtIso,
      'sentCount': sentCount,
      'lastSentAtIso': lastSentAtIso,
    };
  }
}
