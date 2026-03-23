import 'package:isar/isar.dart';

part 'mood_entry.g.dart';

/// ISAR collection for mood log entries.
/// Written by MoodPipelineService BEFORE the quick-tracking file is updated.
/// This is the source of truth for all mood data.
@Collection()
class MoodEntry {
  /// ISAR auto-incremented ID
  Id id = Isar.autoIncrement;

  /// ISO 8601 date string (e.g. "2026-03-21")
  /// Indexed for fast date-range queries and EOD consistency checks.
  @Index()
  late String date;

  /// Full raw log text as submitted by the user.
  late String rawLog;

  /// Condensed version stored in the quick-tracking file.
  late String condensedLog;

  /// Final resolved mood label.
  /// e.g. "sadness", "joy", "love", "anger", "fear", "surprise",
  ///      "anxious", "content", "neutral"
  late String resolvedMood;

  /// Which model resolved the mood.
  /// Values: "base" (MobileBERT), "gemma2b", "gemini"
  late String resolvedBy;

  /// MobileBERT's raw top prediction before any user interaction.
  /// Null if MobileBERT was skipped due to low confidence.
  String? mobileBertPrediction;

  /// MobileBERT's softmax probability for its top prediction.
  double? mobileBertTopProb;

  /// Whether the user confirmed the mood prediction.
  /// Null = user skipped the confirmation step.
  bool? userConfirmed;

  /// Gemma2b / Gemini response text shown to the user.
  late String responseText;

  /// Fitness score snapshot at the time of this log entry.
  late double fitnessScoreSnapshot;

  /// Full UTC timestamp of when this entry was created.
  @Index()
  late DateTime timestamp;
}
