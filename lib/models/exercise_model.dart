class ExerciseModel {
  const ExerciseModel({
    required this.name,
    required this.type,
    required this.muscle,
    required this.difficulty,
    required this.instructions,
  });

  final String name;
  final String type;
  final String muscle;
  final String difficulty;
  final String instructions;

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      name: json['name'],
      type: json['type'],
      muscle: json['muscle'],
      difficulty: json['difficulty'],
      instructions: json['instructions'],
    );
  }
}