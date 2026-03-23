import 'escalation_level.dart';

/// Labels matching training notebook ID2LABEL order.
/// Index must match the ONNX model's output logit positions.
const List<String> kMobileBertLabels = [
  'sadness',   // 0
  'joy',       // 1
  'love',      // 2
  'anger',     // 3
  'fear',      // 4
  'surprise',  // 5
];

/// Raw output from MobileBERT inference.
class MobileBertResult {
  final String topLabel;
  final int topLabelId;
  final double topProb;

  /// Softmax probabilities for all 6 classes, keyed by label name.
  final Map<String, double> allProbs;

  final bool confidenceOk;
  final double thresholdUsed;
  final EscalationLevel escalation;
  final String reason;

  const MobileBertResult({
    required this.topLabel,
    required this.topLabelId,
    required this.topProb,
    required this.allProbs,
    required this.confidenceOk,
    required this.thresholdUsed,
    required this.escalation,
    required this.reason,
  });

  /// Second most likely emotion and its probability.
  MapEntry<String, double> get secondPlace {
    final sorted = allProbs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.length > 1 ? sorted[1] : sorted[0];
  }

  /// Margin between top and second-place class.
  double get ambiguityMargin => topProb - secondPlace.value;
}

/// Full result returned from the mood pipeline to the UI layer.
class MoodPipelineResult {
  /// Final resolved mood label (may differ from MobileBERT's raw output
  /// if Gemma2b or Gemini resolved the prediction).
  final String resolvedMood;

  /// Gemma2b / Gemini response text shown to the user.
  final String responseText;

  /// Which model ultimately resolved the mood.
  final EscalationLevel resolvedBy;

  /// Raw MobileBERT output, null if MobileBERT was skipped.
  final MobileBertResult? mobileBertResult;

  /// Whether the user confirmed the mood prediction.
  /// Null = user skipped the confirmation step.
  final bool? userConfirmed;

  final DateTime timestamp;

  const MoodPipelineResult({
    required this.resolvedMood,
    required this.responseText,
    required this.resolvedBy,
    required this.timestamp,
    this.mobileBertResult,
    this.userConfirmed,
  });
}
