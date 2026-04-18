import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
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

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isRefreshing = false;
  String? _loadedScopeKey;
  final Set<String> _viewedDigests = <String>{};
  List<_StoredSuggestion> _unread = const <_StoredSuggestion>[];

  bool get isReady => _isInitialized;
  bool get isRefreshing => _isRefreshing;
  int get unreadCount => _unread.length;

  List<DailySuggestion> get unreadSuggestions =>
      _unread.map((item) => item.toDailySuggestion()).toList(growable: false);

  String get _scopeKey => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String get _viewedDigestsKey => '${_viewedDigestsKeyBase}_$_scopeKey';
  String get _unreadSuggestionsKey => '${_unreadSuggestionsKeyBase}_$_scopeKey';

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
          return;
        }
      } catch (_) {
        // Fall through to empty state.
      }
    }

    _unread = const <_StoredSuggestion>[];
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

      final nextUnread = currentSuggestions
          .where((item) => !_viewedDigests.contains(item.digest))
          .toList(growable: false);

      if (_sameDigests(_unread, nextUnread)) {
        return;
      }

      _unread = nextUnread;
      await _persistUnread();
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

    await _persistViewedDigests();
    await _persistUnread();
    notifyListeners();
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
