import 'dart:convert';

class UserExerciseLog {
  final String exerciseId;
  final DateTime timestamp;
  final String mood;

  UserExerciseLog({
    required this.exerciseId,
    required this.timestamp,
    required this.mood,
  });

  factory UserExerciseLog.fromJson(Map<String, dynamic> json) {
    return UserExerciseLog(
      exerciseId: json['exerciseId'],
      timestamp: DateTime.parse(json['timestamp']),
      mood: json['mood'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'timestamp': timestamp.toIso8601String(),
      'mood': mood,
    };
  }
}