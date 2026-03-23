import 'dart:math' as math;
import '../models/mood_result.dart';
import '../models/symptom_result.dart';
import '../models/fitness_result.dart';
import '../models/escalation_level.dart';

// ─────────────────────────────────────────────
// PER-MODEL THRESHOLD CONFIGURATION
// ─────────────────────────────────────────────

/// MobileBERT per-class softmax thresholds.
/// Derived from test set F1 scores (training notebook):
///   sadness=0.95, joy=0.94, anger=0.92, fear=0.88, love=0.84, surprise=0.73
/// Formula: threshold = max(0.62, 1.0 - (f1 * 0.4))
const Map<String, double> kMobileBertClassThresholds = {
  'sadness':  0.62,
  'joy':      0.62,
  'anger':    0.63,
  'fear':     0.65,
  'love':     0.67,
  'surprise': 0.71,
};

/// If top-class prob is below this, skip per-class check entirely.
const double kMobileBertGlobalFloor = 0.50;

/// If top-2 class margin is below this, prediction is ambiguous.
const double kMobileBertAmbiguityMargin = 0.15;

/// DisEmbed cosine similarity threshold calibrated from testing.
/// recall=100%, precision=83.3% on medical domain pairs.
const double kDisEmbedThreshold = 0.3846;

/// Scores within ±margin of the threshold are treated as uncertain.
const double kDisEmbedMargin = 0.05;

/// Above this = strong similar (high confidence).
const double kDisEmbedStrongSimilar = 0.55;

/// Below this = strong dissimilar (high confidence).
const double kDisEmbedStrongDissimilar = 0.20;

/// Fitness MLP predict_proba confidence threshold.
/// NOTE: Set conservatively — update once test evaluation metrics are available.
const double kFitnessConfidenceThreshold = 0.70;

// ─────────────────────────────────────────────
// CONFIDENCE MANAGER
// ─────────────────────────────────────────────

class ConfidenceManager {
  final Map<String, double> mbThresholds;
  final double mbGlobalFloor;
  final double mbAmbiguityMargin;
  final double deThreshold;
  final double deMargin;
  final double fitThreshold;

  const ConfidenceManager({
    this.mbThresholds      = kMobileBertClassThresholds,
    this.mbGlobalFloor     = kMobileBertGlobalFloor,
    this.mbAmbiguityMargin = kMobileBertAmbiguityMargin,
    this.deThreshold       = kDisEmbedThreshold,
    this.deMargin          = kDisEmbedMargin,
    this.fitThreshold      = kFitnessConfidenceThreshold,
  });

  // ── MobileBERT ─────────────────────────────────────────────────────────────

  /// Evaluate MobileBERT softmax probabilities.
  ///
  /// [probs] must be a list of 6 doubles in label order:
  ///   [sadness, joy, love, anger, fear, surprise]
  MobileBertResult evaluateMobileBert(List<double> probs) {
    assert(probs.length == 6, 'Expected 6 class probs, got ${probs.length}');

    // Build label → prob map
    final allProbs = <String, double>{
      for (var i = 0; i < kMobileBertLabels.length; i++)
        kMobileBertLabels[i]: probs[i],
    };

    // Find top class
    int topId = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[topId]) topId = i;
    }
    final topLabel = kMobileBertLabels[topId];
    final topProb  = probs[topId];

    // 1. Global floor
    if (topProb < mbGlobalFloor) {
      return MobileBertResult(
        topLabel: topLabel, topLabelId: topId,
        topProb: topProb, allProbs: allProbs,
        confidenceOk: false,
        thresholdUsed: mbGlobalFloor,
        escalation: EscalationLevel.gemma,
        reason: 'Top prob ${_pct(topProb)} is below global floor '
                '${_pct(mbGlobalFloor)}. Model is uncertain.',
      );
    }

    // 2. Per-class threshold
    final classThreshold = mbThresholds[topLabel] ?? 0.65;
    if (topProb < classThreshold) {
      return MobileBertResult(
        topLabel: topLabel, topLabelId: topId,
        topProb: topProb, allProbs: allProbs,
        confidenceOk: false,
        thresholdUsed: classThreshold,
        escalation: EscalationLevel.gemma,
        reason: '"$topLabel" predicted at ${_pct(topProb)}, below its '
                'class threshold of ${_pct(classThreshold)} (F1-adjusted).',
      );
    }

    // 3. Ambiguity check — top two classes too close
    final sorted = allProbs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final secondLabel = sorted[1].key;
    final secondProb  = sorted[1].value;
    final margin      = topProb - secondProb;

    if (margin < mbAmbiguityMargin) {
      return MobileBertResult(
        topLabel: topLabel, topLabelId: topId,
        topProb: topProb, allProbs: allProbs,
        confidenceOk: false,
        thresholdUsed: classThreshold,
        escalation: EscalationLevel.gemma,
        reason: '"$topLabel" (${_pct(topProb)}) vs "$secondLabel" '
                '(${_pct(secondProb)}) — margin ${_pct(margin)} '
                'is below ${_pct(mbAmbiguityMargin)}. Ambiguous.',
      );
    }

    // Passed all checks
    return MobileBertResult(
      topLabel: topLabel, topLabelId: topId,
      topProb: topProb, allProbs: allProbs,
      confidenceOk: true,
      thresholdUsed: classThreshold,
      escalation: EscalationLevel.base,
      reason: '"$topLabel" at ${_pct(topProb)} passes class threshold.',
    );
  }

  // ── DisEmbed ────────────────────────────────────────────────────────────────

  /// Evaluate DisEmbed cosine similarity score.
  DisEmbedResult evaluateDisEmbed(double cosineScore) {
    final lo         = deThreshold - deMargin;   // 0.3346
    final hi         = deThreshold + deMargin;   // 0.4346
    final prediction = cosineScore >= deThreshold ? 'similar' : 'dissimilar';

    // Uncertain zone
    if (cosineScore >= lo && cosineScore <= hi) {
      return DisEmbedResult(
        cosineScore: cosineScore,
        prediction: prediction,
        confidenceOk: false,
        confidenceLevel: 'uncertain',
        escalation: EscalationLevel.gemma,
        reason: 'Score ${cosineScore.toStringAsFixed(4)} is within '
                '±$deMargin of threshold $deThreshold. Too close to call.',
      );
    }

    // Strong similar
    if (cosineScore > kDisEmbedStrongSimilar) {
      return DisEmbedResult(
        cosineScore: cosineScore,
        prediction: 'similar',
        confidenceOk: true,
        confidenceLevel: 'high',
        escalation: EscalationLevel.base,
        reason: 'Score ${cosineScore.toStringAsFixed(4)} — strong match.',
      );
    }

    // Strong dissimilar
    if (cosineScore < kDisEmbedStrongDissimilar) {
      return DisEmbedResult(
        cosineScore: cosineScore,
        prediction: 'dissimilar',
        confidenceOk: true,
        confidenceLevel: 'high',
        escalation: EscalationLevel.base,
        reason: 'Score ${cosineScore.toStringAsFixed(4)} — strong non-match.',
      );
    }

    // Medium confidence
    return DisEmbedResult(
      cosineScore: cosineScore,
      prediction: prediction,
      confidenceOk: true,
      confidenceLevel: 'medium',
      escalation: EscalationLevel.base,
      reason: 'Score ${cosineScore.toStringAsFixed(4)} — medium confidence "$prediction".',
    );
  }

  // ── Fitness MLP ─────────────────────────────────────────────────────────────

  /// Evaluate Fitness MLP predict_proba output.
  ///
  /// [proba] = [P(is_fit=0), P(is_fit=1)]
  ///
  /// Note: Low fitness confidence does NOT escalate to Gemma2b/Gemini.
  /// Gemma2b cannot improve a numerical fitness score.
  /// Low confidence instead flags a data freshness issue to the user.
  FitnessMlpResult evaluateFitness(List<double> proba) {
    assert(proba.length == 2, 'Expected 2 class probs, got ${proba.length}');

    final fitProb = proba[1];
    final isFit   = fitProb >= 0.5;
    final maxConf = math.max(proba[0], proba[1]);

    if (maxConf < fitThreshold) {
      return FitnessMlpResult(
        isFit: isFit,
        fitProbability: fitProb,
        confidenceOk: false,
        // GEMMA here signals "flag to user + suggest data refresh"
        // not actual Gemma2b LLM escalation
        escalation: EscalationLevel.gemma,
        reason: 'Max confidence ${_pct(maxConf)} is below threshold '
                '${_pct(fitThreshold)}. Health data may be stale.',
      );
    }

    return FitnessMlpResult(
      isFit: isFit,
      fitProbability: fitProb,
      confidenceOk: true,
      escalation: EscalationLevel.base,
      reason: 'Fitness confidence ${_pct(maxConf)} passes threshold.',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool shouldEscalate(dynamic result) =>
      result.escalation != EscalationLevel.base;

  bool needsOnline(dynamic result) =>
      result.escalation == EscalationLevel.gemini;

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}
