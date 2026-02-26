import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseModel {
  ExerciseModel({
    required this.id,
    required this.name,
    required this.type,
    required this.muscle,
    required this.difficulty,
    this.isFavorite = false,
    this.timesChosen = 0,
    this.timesSearched = 0,
  });
  final String id;
  final String name;
  final String type;
  final String muscle;
  final String difficulty;
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
      'isFavorite': isFavorite,
      'timesChosen': timesChosen,
      'timesSearched': timesSearched,
    };
  }
}
