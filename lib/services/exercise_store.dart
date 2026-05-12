import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/exercise_entry.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';
import '../models/exercise_model.dart';

class ExerciseStore {
  ExerciseStore({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance {
    _ready = _initializePrefs();
  }

  static const String _favoritesKeyBase = 'favorite_exercises';
  static const String _exerciseHistoryKeyBase = 'exercise_history_v2';
  final FirebaseAuth _auth;
  late SharedPreferences _prefs;
  late final Future<void> _ready;
  List<ExerciseModel> exercises = [];
  List<String> _favoriteIds = [];
  String? _loadedScopeKey;

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadedScopeKey = _scopeKey;
    _loadFavorites();
    await _loadFromIsar();
  }

  Future<void> ensureReady() => _ready;

  String get _scopeKey => _auth.currentUser?.uid ?? 'guest';

  String get _favoritesKey => '${_favoritesKeyBase}_$_scopeKey';
  String get _exerciseHistoryKey => '${_exerciseHistoryKeyBase}_$_scopeKey';

  void _ensureCurrentScopeLoaded() {
    if (_loadedScopeKey == _scopeKey) return;
    _loadedScopeKey = _scopeKey;
    _loadFavorites();
  }

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
    _ensureCurrentScopeLoaded();
    return _favoriteIds.contains(exerciseId);
  }

  /// Get all favorite exercises
  List<ExerciseModel> getFavoriteExercises() {
    _ensureCurrentScopeLoaded();
    return exercises
        .where((exercise) => _favoriteIds.contains(exercise.id))
        .toList();
  }

  /// Get favorite count
  int getFavoriteCount() {
    _ensureCurrentScopeLoaded();
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
    _ensureCurrentScopeLoaded();
    return List.from(_favoriteIds);
  }

  /// Get recommended exercises based on current mood
  List<ExerciseModel> getRecommendedExercises(String currentMood) {
    final moodExerciseMap = {
      'happy': ['cardio', 'dance', 'running'],
      'sad': ['yoga', 'meditation', 'walking'],
      'anxious': ['yoga', 'meditation', 'pilates'],
      'stressed': ['stretching', 'yoga', 'pilates'],
      'calm': ['any'],
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
  Future<String?> logExercise(
    String exerciseId, {
    String mood = '',
    String exerciseName = '',
    int durationMinutes = 0,
    int sets = 0,
    int reps = 0,
    bool noExercise = false,
    List<Map<String, String>> workoutItems = const <Map<String, String>>[],
  }) async {
    await _ready;
    final timestamp = DateTime.now();
    final normalizedWorkoutItems = workoutItems
        .map(
          (item) => <String, String>{
            'exerciseId': (item['exerciseId'] ?? '').trim(),
            'exerciseName': (item['exerciseName'] ?? '').trim(),
            'sets': (item['sets'] ?? '').trim(),
            'reps': (item['reps'] ?? '').trim(),
            'durationMinutes': (item['durationMinutes'] ?? '').trim(),
          },
        )
        .where((item) => (item['exerciseId'] ?? '').isNotEmpty)
        .toList(growable: false);

    final hasWorkoutItems = normalizedWorkoutItems.isNotEmpty;
    final primaryItem = hasWorkoutItems ? normalizedWorkoutItems.first : null;
    final multiExerciseId = hasWorkoutItems
        ? (normalizedWorkoutItems.length > 1
              ? 'multi_exercise'
              : (primaryItem!['exerciseId'] ?? ''))
        : exerciseId;
    final multiExerciseName = hasWorkoutItems
        ? _workoutSummaryLabel(normalizedWorkoutItems)
        : exerciseName;
    final record = <String, String>{
      'exerciseId': multiExerciseId,
      'exerciseName': multiExerciseName,
      'mood': mood,
      'durationMinutes': hasWorkoutItems
          ? (primaryItem!['durationMinutes'] ?? '')
          : durationMinutes.toString(),
      'sets': hasWorkoutItems ? (primaryItem!['sets'] ?? '') : sets.toString(),
      'reps': hasWorkoutItems ? (primaryItem!['reps'] ?? '') : reps.toString(),
      'noExercise': noExercise.toString(),
      if (hasWorkoutItems)
        'workoutItemsJson': jsonEncode(normalizedWorkoutItems),
      if (hasWorkoutItems)
        'workoutCount': normalizedWorkoutItems.length.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
    final history = List<Map<String, String>>.from(_loadExerciseHistory());
    history.insert(0, record);
    await _prefs.setStringList(
      _exerciseHistoryKey,
      history.map(_encodeHistoryRecord).toList(growable: false),
    );
    await _writeToIsar(record, timestamp: timestamp);
    await TrackingReminderService.instance.handleLogRecorded();
    return null;
  }

  Future<void> refreshFromCloud() => _loadFromIsar();

  /// Return recent exercise activity as daily counts for the last [days] days.
  /// Index 0 is today.
  List<int> getRecentExerciseActivity({
    int days = 7,
    bool includeNoExercise = true,
  }) {
    final history = _loadExerciseHistory();
    final buckets = List<int>.filled(days, 0);
    final now = DateTime.now();

    for (final record in history) {
      if (!includeNoExercise && (record['noExercise'] ?? '').trim() == 'true') {
        continue;
      }
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
    _ensureCurrentScopeLoaded();
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
        'exerciseName': '',
        'mood': parts.length > 1 ? parts[1] : '',
        'durationMinutes': '',
        'sets': '',
        'reps': '',
        'noExercise': 'false',
        'timestamp': parts.length > 2 ? parts[2] : '',
      };
    }

    return const {
      'exerciseId': '',
      'exerciseName': '',
      'mood': '',
      'durationMinutes': '',
      'sets': '',
      'reps': '',
      'noExercise': 'false',
      'timestamp': '',
    };
  }

  Future<void> _loadFromIsar() async {
    try {
      final entries = await AppServices.isar.getRecentExerciseEntries(
        days: 120,
      );
      if (entries.isEmpty) return;
      final history = entries
          .map(
            (e) => <String, String>{
              'exerciseId': e.exerciseId,
              'exerciseName': e.exerciseName,
              'mood': e.mood,
              'durationMinutes': e.durationMinutes.toString(),
              'sets': e.sets.toString(),
              'reps': e.reps.toString(),
              'noExercise': e.noExercise.toString(),
              'workoutItemsJson': e.workoutItemsJson,
              'workoutCount': e.workoutCount.toString(),
              'timestamp': e.timestamp.toIso8601String(),
            },
          )
          .toList(growable: false);
      await _prefs.setStringList(
        _exerciseHistoryKey,
        history.map(_encodeHistoryRecord).toList(growable: false),
      );
    } catch (_) {
      // Keep the local history when ISAR is unavailable.
    }
  }

  Future<void> _writeToIsar(
    Map<String, String> record, {
    DateTime? timestamp,
  }) async {
    final effectiveTimestamp =
        timestamp ?? DateTime.tryParse(record['timestamp'] ?? '');
    if (effectiveTimestamp == null) return;
    final entry = ExerciseEntry()
      ..date = effectiveTimestamp.toIso8601String().substring(0, 10)
      ..exerciseId = record['exerciseId'] ?? ''
      ..exerciseName = record['exerciseName'] ?? ''
      ..mood = record['mood'] ?? ''
      ..durationMinutes = int.tryParse(record['durationMinutes'] ?? '') ?? 0
      ..sets = int.tryParse(record['sets'] ?? '') ?? 0
      ..reps = int.tryParse(record['reps'] ?? '') ?? 0
      ..noExercise = (record['noExercise'] ?? '').trim() == 'true'
      ..workoutItemsJson = record['workoutItemsJson'] ?? ''
      ..workoutCount = int.tryParse(record['workoutCount'] ?? '') ?? 0
      ..timestamp = effectiveTimestamp;
    await AppServices.isar.writeExerciseEntry(entry);
  }

  String _workoutSummaryLabel(List<Map<String, String>> items) {
    if (items.isEmpty) return '';
    final names = items
        .map((item) => (item['exerciseName'] ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return 'Workout';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} + ${names[1]}';
    return '${names[0]} + ${names.length - 1} more';
  }
}
