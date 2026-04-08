import 'escalation_level.dart';

/// Raw output from DisEmbed inference.
class DisEmbedResult {
  final double cosineScore;
  final String prediction; // "similar" or "dissimilar"
  final bool confidenceOk;
  final String confidenceLevel; // "high", "medium", "uncertain"
  final EscalationLevel escalation;
  final String reason;

  const DisEmbedResult({
    required this.cosineScore,
    required this.prediction,
    required this.confidenceOk,
    required this.confidenceLevel,
    required this.escalation,
    required this.reason,
  });
}

/// A single disease prediction entry from Gemma2b or Gemini.
class DiagnosisEntry {
  final String diseaseName;
  final String reasoning;

  /// Concise next steps. Longer for the top result, shorter for alternatives.
  final String nextSteps;

  /// True if this condition warrants urgent medical attention.
  final bool isUrgent;

  const DiagnosisEntry({
    required this.diseaseName,
    required this.reasoning,
    required this.nextSteps,
    this.isUrgent = false,
  });
}

/// Full result returned from the symptom pipeline to the UI layer.
class SymptomPipelineResult {
  /// User's original symptom input text.
  final String userSymptoms;

  /// DisEmbed's initial fast prediction (top-1 disease name).
  /// May be null if DisEmbed was skipped due to low confidence.
  final String? disEmbedPrediction;

  /// Top 5 triage decisions from Gemma2b / Gemini.
  /// Index 0 = most likely, index 4 = least likely.
  final List<DiagnosisEntry> diagnoses;

  /// Whether Weaviate RAG was used to ground the Gemma2b/Gemini response.
  final bool ragUsed;

  /// Whether the response was generated offline (no RAG grounding).
  final bool isOffline;

  /// Which model ultimately resolved the triage decision.
  final EscalationLevel resolvedBy;

  /// Raw DisEmbed result, null if skipped.
  final DisEmbedResult? disEmbedResult;

  final DateTime timestamp;

  const SymptomPipelineResult({
    required this.userSymptoms,
    required this.diagnoses,
    required this.ragUsed,
    required this.isOffline,
    required this.resolvedBy,
    required this.timestamp,
    this.disEmbedPrediction,
    this.disEmbedResult,
  });

  /// Convenience getter for the top triage decision.
  DiagnosisEntry? get topDiagnosis =>
      diagnoses.isNotEmpty ? diagnoses.first : null;
}
