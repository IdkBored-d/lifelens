import 'package:flutter/foundation.dart';
import 'package:lifelens/database/isar_service.dart';
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
    refreshFromPersistence();
  }

  final List<MoodCheckIn> _items = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<MoodCheckIn> get items => List.unmodifiable(_items);

  void add(MoodCheckIn item) {
    _items.insert(0, item);
    notifyListeners();
  }

  Future<void> refreshFromPersistence() async {
    _isLoading = true;
    notifyListeners();

    try {
      await IsarService.instance.init();
      final entries = await IsarService.instance.getRecentMoodEntries(
        days: 365,
      );
      final persisted =
          entries
              .where((entry) => entry.resolvedBy != 'minime')
              .map(_fromMoodEntry)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _items
        ..clear()
        ..addAll(persisted);
    } catch (_) {
      // Keep the in-memory items if persistence is unavailable.
    } finally {
      _isLoading = false;
      notifyListeners();
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
      notes: entry.rawLog,
      createdAt: entry.timestamp,
    );
  }

  String _emojiForMood(String moodLabel) {
    switch (moodLabel) {
      case 'Happy':
        return '😊';
      case 'Calm':
        return '😌';
      case 'Anxious':
        return '😟';
      case 'Sad':
        return '😔';
      case 'Neutral':
        return '😐';
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
}
