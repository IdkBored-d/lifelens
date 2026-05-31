import 'package:isar_community/isar.dart';

part 'symptom_entry.g.dart';

/// ISAR collection for symptom/illness entries.
/// Never truncated — all historical ailment data is kept for future reference.
@Collection()
class SymptomEntry {
  Id id = Isar.autoIncrement;

  /// ISO 8601 date string of when the symptom was first reported.
  @Index()
  late String date;

  /// Raw symptom text as submitted by the user.
  late String rawSymptoms;

  /// Parsed list of individual symptom strings.
  late List<String> symptomList;

  /// Top predicted ailment (disease name).
  late String predictedAilment;

  /// DisEmbed's raw cosine similarity score for the top prediction.
  /// Null if DisEmbed was escalated or skipped.
  double? disEmbedScore;

  /// Full JSON string of all 5 diagnoses from MiniGen / Gemini.
  /// NOTE: logic may be incorrect -- this is replacing our old version.
  /// Stored as JSON string for ISAR compatibility.
  /// Schema per entry:
  ///   {"disease": "...", "reasoning": "...", "treatment": "...", "next_steps": "...", "is_urgent": false}
  late String diagnosesJson;

  /// Which model resolved the final diagnosis.
  /// Values: "base" (DisEmbed→MiniGen), "gemma2b" (legacy/MiniGen), "gemini"
  late String resolvedBy;

  /// Whether Weaviate RAG was used to ground the response.
  late bool ragUsed;

  /// Whether the device was offline when this entry was created.
  late bool wasOffline;

  /// Current status of this ailment.
  /// Values: "active", "resolved", "monitoring"
  @Index()
  late String status;

  /// Date when status was last updated (e.g. marked resolved).
  String? statusUpdatedDate;

  /// Full UTC timestamp of when this entry was created.
  @Index()
  late DateTime timestamp;

  /// Last time this entry was updated (e.g. status change).
  late DateTime updatedAt;
}
