import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/mood_entry.dart';

class MoodCheckIn {
  MoodCheckIn({
    required this.moodLabel,
    required this.emoji,
    required this.intensity,
    required this.tags,
    required this.notes,
    required this.createdAt,
  });
  final String moodLabel;
  final String emoji;
  final int intensity;
  final List<String> tags;
  final String notes;
  final DateTime createdAt;
}

class MoodLogStore extends ChangeNotifier {
  MoodLogStore() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleAuthChanged(user);
    });
    refreshFromPersistence();
  }

  final List<MoodCheckIn> _items = [];
  late final StreamSubscription<User?> _authSub;
  String _loadedScopeKey = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  int _loadRequestId = 0;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<MoodCheckIn> get items => List.unmodifiable(_items);

  void _handleAuthChanged(User? user) {
    final nextScopeKey = user?.uid ?? 'guest';
    if (_loadedScopeKey != nextScopeKey) {
      _loadedScopeKey = nextScopeKey;
      _items.clear();
      _isLoading = true;
      notifyListeners();
    }
    refreshFromPersistence();
  }

  void add(MoodCheckIn item) {
    _items.insert(0, item);
    notifyListeners();
  }

  Future<void> refreshFromPersistence() async {
    final requestId = ++_loadRequestId;
    final scopeKey = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    if (_loadedScopeKey != scopeKey) {
      _loadedScopeKey = scopeKey;
      _items.clear();
    }
    _isLoading = true;
    notifyListeners();

    try {
      await AppServices.isar.init();
      if (requestId != _loadRequestId || _loadedScopeKey != scopeKey) return;
      final entries = await AppServices.isar.getRecentMoodEntries(
        days: 365,
      );
      if (requestId != _loadRequestId || _loadedScopeKey != scopeKey) return;
      final persisted =
          entries
              .map(_fromMoodEntry)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _items
        ..clear()
        ..addAll(persisted);
    } catch (_) {
      // Keep the in-memory items if persistence is unavailable.
    } finally {
      if (requestId == _loadRequestId && _loadedScopeKey == scopeKey) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  // Optionally, add methods to set loading state
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  MoodCheckIn _fromMoodEntry(MoodEntry entry) {
    return MoodCheckIn(
      moodLabel: entry.resolvedMood,
      emoji: _emojiForMood(entry.resolvedMood),
      intensity: _intensityFromMoodEntry(entry),
      tags: const [],
      notes: _stripInternalContextMetadata(entry.rawLog),
      createdAt: entry.timestamp,
    );
  }

  String _stripInternalContextMetadata(String value) {
    return value
        .replaceAll(
          RegExp(r'\s*\[context:\s*[^\]]+\]\s*', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _emojiForMood(String moodLabel) {
    final normalized = moodLabel.trim().toLowerCase();

    switch (normalized) {
      case 'neutral':
      case 'content':
        return '😐';
      case 'angry':
      case 'anger':
        return '😠';
      case 'scared':
      case 'fear':
      case 'anxious':
        return '😨';
      case 'happy':
      case 'joy':
        return '😊';
      case 'affectionate':
      case 'love':
        return '🥰';
      case 'sad':
      case 'sadness':
        return '😔';
      case 'surprised':
      case 'surprise':
        return '😲';
      default:
        return '🙂';
    }
  }

  int _intensityFromMoodEntry(MoodEntry entry) {
    final match = RegExp(r'([1-5])\/5').firstMatch(entry.condensedLog);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 3;
    }
    return 3;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
