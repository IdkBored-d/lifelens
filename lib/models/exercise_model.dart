import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseModel {
  ExerciseModel({
    required this.id,
    required this.name,
    required this.type,
    required this.muscle,
    required this.difficulty,
    this.description,
    this.instructions,
    this.equipment = const [],
    this.benefits = const [],
    this.instructionUrl,
    this.videoUrl,
    this.isFavorite = false,
    this.timesChosen = 0,
    this.timesSearched = 0,
  });
  final String id;
  final String name;
  final String type;
  final String muscle;
  final String difficulty;
  final String? description;
  final String? instructions;
  final List<String> equipment;
  final List<String> benefits;
  final String? instructionUrl;
  final String? videoUrl;
  bool isFavorite;
  int timesChosen;
  int timesSearched;

  factory ExerciseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExerciseModel(
      id: doc.id,
      name: data['name'],
      type: data['type'],
      muscle: data['muscle'],
      difficulty: data['difficulty'],
      description: (data['description'] as String?)?.trim(),
      instructions: (data['instructions'] as String?)?.trim(),
      equipment: _stringListFrom(data['equipment']),
      benefits: _stringListFrom(data['benefits']),
      instructionUrl: (data['instructionUrl'] as String?)?.trim(),
      videoUrl: (data['videoUrl'] as String?)?.trim(),
      isFavorite: data['isFavorite'] ?? false,
      timesChosen: data['timesChosen'] ?? 0,
      timesSearched: data['timesSearched'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'muscle': muscle,
      'difficulty': difficulty,
      'description': description,
      'instructions': instructions,
      'equipment': equipment,
      'benefits': benefits,
      'instructionUrl': instructionUrl,
      'videoUrl': videoUrl,
      'isFavorite': isFavorite,
      'timesChosen': timesChosen,
      'timesSearched': timesSearched,
    };
  }

  static List<String> _stringListFrom(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
