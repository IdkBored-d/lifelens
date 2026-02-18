import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exercise_model.dart';

class ExerciseService {
  static const String _apiKey = 'wBQmajIP2iKSdQOKyhcifBD5D7NETa79ZOWfO2IX';

  Future<List<ExerciseModel>> fetchExercises({
    String muscle = 'chest',
  })
  async {
    final url = Uri.parse('https://api.api-ninjas.com/v1/exercises?muscle=$muscle');

    final response = await http.get(
      url,
      headers: {'X-Api-Key': _apiKey},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ExerciseModel.fromJson(e)).toList();
    }
    else {
      throw Exception('Failed to load exercises');
    }
  }
}