import 'package:isar/isar.dart';

part 'mood_entry.g.dart';

/// ISAR collection for mood log entries. Source of truth for all mood data.
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
  /// Values: "base" (MobileBERT), "gemma2b" (legacy/MiniGen), "gemini"
  late String resolvedBy;

  /// MobileBERT's raw top prediction — advisory only, never overrides user pick.
  String? mobileBertPrediction;

  /// MobileBERT's softmax probability for its top prediction.
  double? mobileBertTopProb;

  /// Text shown to the user (or "I am feeling [intensity] [mood]" if no notes).
  late String responseText;

  /// Fitness score snapshot at the time of this log entry.
  late double fitnessScoreSnapshot;

  /// Full UTC timestamp of when this entry was created.
  @Index()
  late DateTime timestamp;
}
