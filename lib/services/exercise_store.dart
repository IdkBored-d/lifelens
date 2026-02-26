import '../models/exercise_model.dart';
import '../models/user_exercise_log.dart';

class ExerciseStore {
  List<ExerciseModel> exercises = [];
  List<UserExerciseLog> logs = [];

  void saveExercise(String exerciseId, String mood) {
    final log = UserExerciseLog(
      exerciseId: exerciseId,
      timestamp: DateTime.now(),
      mood: mood,
    );
    logs.add(log);

    final exercise = exercises.firstWhere((e) => e.id == exerciseId);
    exercise.timesChosen += 1;
  }

  void favoriteExercise(String exerciseId) {
    final exercise = exercises.firstWhere((e) => e.id == exerciseId);
    exercise.isFavorite = true;
  }

  List<ExerciseModel> getRecommendedExercises(String mood) {
    return exercises.where((e) =>
      e.isFavorite || logs.any((log) => log.exerciseId == e.id && log.mood == mood)
    ).toList();
  }
}