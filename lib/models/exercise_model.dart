class ExerciseModel {
  const ExerciseModel({
    required this.name,
    required this.type,
    required this.muscle,
    required this.difficulty,
  });

  final String name;
  final String type;
  final String muscle;
  final String difficulty;

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      name: json['name'],
      type: json['type'],
      muscle: json['muscle'],
      difficulty: json['difficulty'],
    );
  }
}