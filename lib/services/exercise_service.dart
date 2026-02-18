import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_model.dart';

class ExerciseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<ExerciseModel>> fetchExercises() async {
    final snapshot = await _db.collection('exercises').get();

    return snapshot.docs
      .map((doc) => ExerciseModel.fromJson(doc.data()))
      .toList();
  }
}