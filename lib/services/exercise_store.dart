import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';
import '../models/exercise_model.dart';

class ExerciseStore {
  ExerciseStore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _ready = _initializePrefs();
  }

  static const String _favoritesKeyBase = 'favorite_exercises';
  static const String _exerciseHistoryKeyBase = 'exercise_history_v2';
  static const String _pendingExerciseSyncKeyBase = 'pending_exercise_sync_v1';
  final FirebaseFirestore _firestore;
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
    await _flushPendingCloudSync();
    await _loadCloudHistory();
  }

  Future<void> ensureReady() => _ready;

  String get _scopeKey => _auth.currentUser?.uid ?? 'guest';

  String get _favoritesKey => '${_favoritesKeyBase}_$_scopeKey';
  String get _exerciseHistoryKey => '${_exerciseHistoryKeyBase}_$_scopeKey';
  String get _pendingExerciseSyncKey =>
      '${_pendingExerciseSyncKeyBase}_$_scopeKey';

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
  Future<String?> logExercise(
    String exerciseId, {
    String mood = '',
    String exerciseName = '',
    int durationMinutes = 0,
    int sets = 0,
    int reps = 0,
    bool noExercise = false,
  }) async {
    await _ready;
    final timestamp = DateTime.now();
    final record = <String, String>{
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'mood': mood,
      'durationMinutes': durationMinutes.toString(),
      'sets': sets.toString(),
      'reps': reps.toString(),
      'noExercise': noExercise.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
    final history = List<Map<String, String>>.from(_loadExerciseHistory());
    history.insert(0, record);
    await _prefs.setStringList(
      _exerciseHistoryKey,
      history.map(_encodeHistoryRecord).toList(growable: false),
    );
    await _enqueuePendingSync(record);
    await TrackingReminderService.instance.handleLogRecorded();

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return 'Saved on this device. Sign in to sync exercise logs.';
    }

    final synced = await _syncRecordToCloud(record, timestamp: timestamp);
    if (synced) {
      await _removePendingSync(record);
      return null;
    }

    return 'Saved on this device. Cloud sync will retry automatically.';
  }

  Future<void> refreshFromCloud() async {
    await _ready;
    await _flushPendingCloudSync();
    await _loadCloudHistory();
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

  Future<void> _loadCloudHistory() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .orderBy('timestamp', descending: true)
          .limit(120)
          .get();

      if (snapshot.docs.isEmpty) return;

      final history = snapshot.docs
          .map(_fromFirestore)
          .where((record) => record['exerciseId']?.isNotEmpty ?? false)
          .toList(growable: false);

      await _prefs.setStringList(
        _exerciseHistoryKey,
        history.map(_encodeHistoryRecord).toList(growable: false),
      );
    } on FirebaseException {
      // Keep the local history when cloud sync is unavailable.
    }
  }

  Future<void> _enqueuePendingSync(Map<String, String> record) async {
    final pending = List<Map<String, String>>.from(_loadPendingSyncRecords());
    final recordId = _cloudLogIdFor(record);
    final exists = pending.any((item) => _cloudLogIdFor(item) == recordId);
    if (exists) return;

    pending.add(record);
    await _prefs.setStringList(
      _pendingExerciseSyncKey,
      pending.map(_encodeHistoryRecord).toList(growable: false),
    );
  }

  Future<void> _removePendingSync(Map<String, String> record) async {
    final recordId = _cloudLogIdFor(record);
    final pending = _loadPendingSyncRecords()
        .where((item) => _cloudLogIdFor(item) != recordId)
        .toList(growable: false);
    await _prefs.setStringList(
      _pendingExerciseSyncKey,
      pending.map(_encodeHistoryRecord).toList(growable: false),
    );
  }

  List<Map<String, String>> _loadPendingSyncRecords() {
    _ensureCurrentScopeLoaded();
    final raw =
        _prefs.getStringList(_pendingExerciseSyncKey) ?? const <String>[];
    return raw
        .map(_decodeHistoryRecord)
        .where((record) => record['exerciseId']?.isNotEmpty ?? false)
        .where((record) => record['timestamp']?.isNotEmpty ?? false)
        .toList(growable: true);
  }

  Future<void> _flushPendingCloudSync() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final pending = _loadPendingSyncRecords();
    if (pending.isEmpty) return;

    final remaining = <Map<String, String>>[];
    for (final record in pending) {
      final timestamp = DateTime.tryParse(record['timestamp'] ?? '');
      final synced = await _syncRecordToCloud(record, timestamp: timestamp);
      if (!synced) {
        remaining.add(record);
      }
    }

    await _prefs.setStringList(
      _pendingExerciseSyncKey,
      remaining.map(_encodeHistoryRecord).toList(growable: false),
    );
  }

  Future<bool> _syncRecordToCloud(
    Map<String, String> record, {
    DateTime? timestamp,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final effectiveTimestamp =
        timestamp ?? DateTime.tryParse(record['timestamp'] ?? '');
    if (effectiveTimestamp == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .doc(_cloudLogIdFor(record))
          .set(
            _toFirestore(record, effectiveTimestamp),
            SetOptions(merge: true),
          );
      return true;
    } on FirebaseException {
      return false;
    }
  }

  String _cloudLogIdFor(Map<String, String> record) {
    final exerciseId = (record['exerciseId'] ?? '').trim();
    final timestamp = (record['timestamp'] ?? '').trim();
    final safeExerciseId = exerciseId.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final safeTimestamp = timestamp.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${safeExerciseId}_$safeTimestamp';
  }

  Map<String, dynamic> _toFirestore(
    Map<String, String> record,
    DateTime timestamp,
  ) {
    return {
      'exerciseId': record['exerciseId'],
      'exerciseName': record['exerciseName'],
      'mood': record['mood'],
      'durationMinutes': int.tryParse(record['durationMinutes'] ?? '') ?? 0,
      'sets': int.tryParse(record['sets'] ?? '') ?? 0,
      'reps': int.tryParse(record['reps'] ?? '') ?? 0,
      'noExercise': (record['noExercise'] ?? '').trim() == 'true',
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, String> _fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['timestamp'];

    return {
      'exerciseId': (data['exerciseId'] ?? '').toString(),
      'exerciseName': (data['exerciseName'] ?? '').toString(),
      'mood': (data['mood'] ?? '').toString(),
      'durationMinutes': (data['durationMinutes'] ?? '').toString(),
      'sets': (data['sets'] ?? '').toString(),
      'reps': (data['reps'] ?? '').toString(),
      'noExercise': (data['noExercise'] ?? false).toString(),
      'timestamp': switch (timestamp) {
        Timestamp value => value.toDate().toIso8601String(),
        DateTime value => value.toIso8601String(),
        String value => value,
        _ => '',
      },
    };
  }
}
