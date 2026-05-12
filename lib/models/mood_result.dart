import 'escalation_level.dart';

// TODO(ML): Expand to ~28 emotion classes when the model is retrained.
// Current model is fine-tuned on 6 GoEmotions-derived classes (sadness, joy,
// love, anger, fear, surprise). The architecture targets ~28 classes from
// the full GoEmotions taxonomy (Demszky et al. 2020).
// When retraining:
//   1. Update kMobileBertLabels with all 28 labels in the model's output order.
//   2. Update ConfidenceManager.evaluateMobileBert() — per-class thresholds
//      will need re-calibration against the new class distribution.
//   3. Update dev_test_screen _testConfidenceManager and _testMobileBert —
//      test vectors currently use 6 probabilities; expand to 28.
//   4. Update the architecture doc (says 28 classes already — doc is ahead of code).

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

