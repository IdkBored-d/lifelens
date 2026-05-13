import 'package:isar_community/isar.dart';

part 'exercise_entry.g.dart';

@Collection()
class ExerciseEntry {
  Id id = Isar.autoIncrement;

  @Index()
  late String date;

  late String exerciseId;
  late String exerciseName;
  late String mood;
  late int durationMinutes;
  late int sets;
  late int reps;
  late bool noExercise;
  late String workoutItemsJson;
  late int workoutCount;

  @Index()
  late DateTime timestamp;
}
