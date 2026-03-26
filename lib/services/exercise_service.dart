import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_model.dart';

class ExerciseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all exercises from Firestore
  Future<List<ExerciseModel>> fetchExercises() async {
    try {
      final snapshot = await _firestore.collection('exercises').get();
      return snapshot.docs.map((doc) => ExerciseModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch exercises: $e');
    }
  }

  /// Fetch exercises by muscle group
  Future<List<ExerciseModel>> fetchExercisesByMuscle(String muscle) async {
    try {
      final snapshot = await _firestore
          .collection('exercises')
          .where('muscle', isEqualTo: muscle)
          .get();
      return snapshot.docs.map((doc) => ExerciseModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch exercises for muscle: $e');
    }
  }

  /// Fetch exercises by type
  Future<List<ExerciseModel>> fetchExercisesByType(String type) async {
    try {
      final snapshot = await _firestore
          .collection('exercises')
          .where('type', isEqualTo: type)
          .get();
      return snapshot.docs.map((doc) => ExerciseModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch exercises by type: $e');
    }
  }

  /// Fetch exercises by difficulty
  Future<List<ExerciseModel>> fetchExercisesByDifficulty(String difficulty) async {
    try {
      final snapshot = await _firestore
          .collection('exercises')
          .where('difficulty', isEqualTo: difficulty)
          .get();
      return snapshot.docs.map((doc) => ExerciseModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch exercises by difficulty: $e');
    }
  }

  /// Search exercises by name
  Future<List<ExerciseModel>> searchExercises(String query) async {
    try {
      final snapshot = await _firestore.collection('exercises').get();
      return snapshot.docs
          .map((doc) => ExerciseModel.fromFirestore(doc))
          .where((exercise) => exercise.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search exercises: $e');
    }
  }

  /// Get exercise by ID
  Future<ExerciseModel?> getExerciseById(String id) async {
    try {
      final doc = await _firestore.collection('exercises').doc(id).get();
      if (doc.exists) {
        return ExerciseModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get exercise: $e');
    }
  }

  /// Update exercise times chosen
  Future<void> updateTimesChosen(String exerciseId) async {
    try {
      await _firestore.collection('exercises').doc(exerciseId).update({
        'timesChosen': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to update times chosen: $e');
    }
  }

  /// Update exercise times searched
  Future<void> updateTimesSearched(String exerciseId) async {
    try {
      await _firestore.collection('exercises').doc(exerciseId).update({
        'timesSearched': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to update times searched: $e');
    }
  }

  /// Get unique muscle groups
  Future<List<String>> getMuscleGroups() async {
    try {
      final snapshot = await _firestore.collection('exercises').get();
      final muscles = <String>{};
      for (final doc in snapshot.docs) {
        final exercise = ExerciseModel.fromFirestore(doc);
        muscles.add(exercise.muscle);
      }
      return muscles.toList();
    } catch (e) {
      throw Exception('Failed to get muscle groups: $e');
    }
  }

  /// Get unique exercise types
  Future<List<String>> getExerciseTypes() async {
    try {
      final snapshot = await _firestore.collection('exercises').get();
      final types = <String>{};
      for (final doc in snapshot.docs) {
        final exercise = ExerciseModel.fromFirestore(doc);
        types.add(exercise.type);
      }
      return types.toList();
    } catch (e) {
      throw Exception('Failed to get exercise types: $e');
    }
  }

  /// Get unique difficulty levels
  Future<List<String>> getDifficultyLevels() async {
    try {
      final snapshot = await _firestore.collection('exercises').get();
      final difficulties = <String>{};
      for (final doc in snapshot.docs) {
        final exercise = ExerciseModel.fromFirestore(doc);
        difficulties.add(exercise.difficulty);
      }
      return difficulties.toList();
    } catch (e) {
      throw Exception('Failed to get difficulty levels: $e');
    }
  }
}
