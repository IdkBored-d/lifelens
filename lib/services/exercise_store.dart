import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise_model.dart';

class ExerciseStore {
  static const String _favoritesKey = 'favorite_exercises';
  static const String _exerciseHistoryKey = 'exercise_history_v2';
  late SharedPreferences _prefs;
  late final Future<void> _ready;
  List<ExerciseModel> exercises = [];
  List<String> _favoriteIds = [];

  ExerciseStore() {
    _ready = _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavorites();
  }

  Future<void> ensureReady() => _ready;

  /// Load favorite exercise IDs from local storage
  void _loadFavorites() {
    final favorites = _prefs.getStringList(_favoritesKey) ?? [];
    _favoriteIds = favorites;
  }

  /// Mark an exercise as favorite
  Future<void> favoriteExercise(String exerciseId) async {
    await _ready;
    if (!_favoriteIds.contains(exerciseId)) {
      _favoriteIds.add(exerciseId);
      await _prefs.setStringList(_favoritesKey, _favoriteIds);
    }
  }

  /// Remove an exercise from favorites
  Future<void> unfavoriteExercise(String exerciseId) async {
    await _ready;
    if (_favoriteIds.contains(exerciseId)) {
      _favoriteIds.remove(exerciseId);
      await _prefs.setStringList(_favoritesKey, _favoriteIds);
    }
  }

  /// Check if an exercise is favorited
  bool isFavorite(String exerciseId) {
    return _favoriteIds.contains(exerciseId);
  }

  /// Get all favorite exercises
  List<ExerciseModel> getFavoriteExercises() {
    return exercises
        .where((exercise) => _favoriteIds.contains(exercise.id))
        .toList();
  }

  /// Get favorite count
  int getFavoriteCount() {
    return _favoriteIds.length;
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    await _ready;
    _favoriteIds.clear();
    await _prefs.remove(_favoritesKey);
  }

  /// Get favorite IDs
  List<String> getFavoriteIds() {
    return List.from(_favoriteIds);
  }

  /// Get recommended exercises based on current mood
  List<ExerciseModel> getRecommendedExercises(String currentMood) {
    // Filter exercises based on mood recommendations
    final moodExerciseMap = {
      'happy': ['cardio', 'dance', 'running'],
      'sad': ['yoga', 'meditation', 'walking'],
      'anxious': ['yoga', 'meditation', 'pilates'],
      'stressed': ['stretching', 'yoga', 'pilates'],
      'calm': ['any'], // Any exercise works when calm
    };

    final recommendedTypes =
        moodExerciseMap[currentMood.toLowerCase()] ?? ['any'];

    return exercises.where((exercise) {
      if (recommendedTypes.contains('any')) return true;
      return recommendedTypes.contains(exercise.type.toLowerCase());
    }).toList();
  }

  /// Save exercise with associated mood
  Future<void> saveExercise(String exerciseId, String currentMood) async {
    await logExercise(exerciseId, mood: currentMood);
  }

  /// Record an exercise completion in the local timeline.
  Future<void> logExercise(
    String exerciseId, {
    String mood = '',
  }) async {
    await _ready;
    final history = _loadExerciseHistory();
    history.insert(0, {
      'exerciseId': exerciseId,
      'mood': mood,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _prefs.setStringList(
      _exerciseHistoryKey,
      history.map(_encodeHistoryRecord).toList(growable: false),
    );
  }

  /// Return recent exercise activity as daily counts for the last [days] days.
  /// Index 0 is today.
  List<int> getRecentExerciseActivity({int days = 7}) {
    final history = _loadExerciseHistory();
    final buckets = List<int>.filled(days, 0);
    final now = DateTime.now();

    for (final record in history) {
      final timestamp = DateTime.tryParse(record['timestamp'] ?? '');
      if (timestamp == null) continue;
      final diffDays = now.difference(timestamp).inDays;
      if (diffDays < 0 || diffDays >= days) continue;
      buckets[diffDays] += 1;
    }

    return buckets;
  }

  /// Expose the latest exercise history for summaries and debugging.
  List<Map<String, String>> getRecentExerciseHistory({int limit = 30}) {
    final history = _loadExerciseHistory();
    return history.take(limit).toList(growable: false);
  }

  List<Map<String, String>> _loadExerciseHistory() {
    final raw = _prefs.getStringList(_exerciseHistoryKey) ?? const <String>[];
    return raw
        .map(_decodeHistoryRecord)
        .where((record) => record['exerciseId']?.isNotEmpty ?? false)
        .where((record) => record['timestamp']?.isNotEmpty ?? false)
        .toList(growable: false);
  }

  String _encodeHistoryRecord(Map<String, String> record) {
    return jsonEncode(record);
  }

  Map<String, String> _decodeHistoryRecord(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      }
    } catch (_) {
      // Backward compatibility for older pipe-delimited records.
      final parts = encoded.split('|');
      return {
        'exerciseId': parts.isNotEmpty ? parts[0] : '',
        'mood': parts.length > 1 ? parts[1] : '',
        'timestamp': parts.length > 2 ? parts[2] : '',
      };
    }

    return const {'exerciseId': '', 'mood': '', 'timestamp': ''};
  }
}
