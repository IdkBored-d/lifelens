import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise_model.dart';

class ExerciseStore {
  static const String _favoritesKey = 'favorite_exercises';
  late SharedPreferences _prefs;
  List<ExerciseModel> exercises = [];
  List<String> _favoriteIds = [];

  ExerciseStore() {
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavorites();
  }

  /// Load favorite exercise IDs from local storage
  void _loadFavorites() {
    final favorites = _prefs.getStringList(_favoritesKey) ?? [];
    _favoriteIds = favorites;
  }

  /// Mark an exercise as favorite
  Future<void> favoriteExercise(String exerciseId) async {
    if (!_favoriteIds.contains(exerciseId)) {
      _favoriteIds.add(exerciseId);
      await _prefs.setStringList(_favoritesKey, _favoriteIds);
    }
  }

  /// Remove an exercise from favorites
  Future<void> unfavoriteExercise(String exerciseId) async {
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
    return exercises.where((exercise) => _favoriteIds.contains(exercise.id)).toList();
  }

  /// Get favorite count
  int getFavoriteCount() {
    return _favoriteIds.length;
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
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

    final recommendedTypes = moodExerciseMap[currentMood.toLowerCase()] ?? ['any'];
    
    return exercises.where((exercise) {
      if (recommendedTypes.contains('any')) return true;
      return recommendedTypes.contains(exercise.type.toLowerCase());
    }).toList();
  }

  /// Save exercise with associated mood
  Future<void> saveExercise(String exerciseId, String currentMood) async {
    // Track the exercise with mood association
    final key = 'exercise_mood_${exerciseId}_$currentMood';
    final count = _prefs.getInt(key) ?? 0;
    await _prefs.setInt(key, count + 1);
  }
}
