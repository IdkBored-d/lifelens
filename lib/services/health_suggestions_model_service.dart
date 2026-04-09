import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

/// Output from [HealthSuggestionsModelService.predict].
class SuggestionsModelOutput {
  /// 384-dim context vector used to rank the suggestion bank.
  final List<double> contextVector;

  /// Relevance gate (sigmoid output, 0–1). Below [HealthSuggestionsModelService.minGateThreshold],
  /// callers should return a generic "keep logging" fallback instead of ML suggestions.
  final double relevanceGate;

  const SuggestionsModelOutput({
    required this.contextVector,
    required this.relevanceGate,
  });
}

/// Extended feature vector for the suggestions model.
///
/// Combines the 25 base health features from [HealthFeatureComputer] with
/// 9 derived decision-support features, totalling [numNumericalFeatures] = 34.
///
/// Derived features (indices 25–33):
///   [25] risk_score        — normalised to [0, 1] from the 0–100 raw score
///   [26] tier_high         — 1.0 if intervention tier is "high"
///   [27] tier_medium       — 1.0 if intervention tier is "medium"
///   [28] tier_low          — 1.0 if intervention tier is "low"
///   [29] phase_acute_risk  — 1.0 if user phase is "acute-risk"
///   [30] phase_recovering  — 1.0 if user phase is "recovering"
///   [31] phase_declining   — 1.0 if user phase is "declining"
///   [32] phase_stable      — 1.0 if user phase is "stable"
///   [33] symptom_count     — current number of active symptoms
class SuggestionsFeatureVector {
  final List<double> baseFeatures;   // length 25 from HealthFeatureComputer
  final double       riskScore;      // 0–100
  final String       interventionTier; // "high" | "medium" | "low"
  final String       userPhase;        // "acute-risk" | "recovering" | "declining" | "stable"
  final int          symptomCount;

  const SuggestionsFeatureVector({
    required this.baseFeatures,
    required this.riskScore,
    required this.interventionTier,
    required this.userPhase,
    required this.symptomCount,
  });

  /// Compute the full 34-dim flat float vector consumed by the ONNX model.
  List<double> toList() {
    final tierHigh   = interventionTier == 'high'   ? 1.0 : 0.0;
    final tierMedium = interventionTier == 'medium' ? 1.0 : 0.0;
    final tierLow    = interventionTier == 'low'    ? 1.0 : 0.0;

    final phaseAcute     = userPhase == 'acute-risk'  ? 1.0 : 0.0;
    final phaseRecovering = userPhase == 'recovering' ? 1.0 : 0.0;
    final parseDeclining  = userPhase == 'declining'  ? 1.0 : 0.0;
    final phaseStable     = userPhase == 'stable'     ? 1.0 : 0.0;

    return [
      ...baseFeatures,
      riskScore / 100.0, // normalised
      tierHigh,
      tierMedium,
      tierLow,
      phaseAcute,
      phaseRecovering,
      parseDeclining,
      phaseStable,
      symptomCount.toDouble(),
    ];
  }
}

/// Runs the HealthSuggestionsModel on-device to produce a context vector for
/// ranking the suggestion bank, replacing [LocalHeuristicSuggestionsClient].
///
/// Architecture (MLP ranker):
///   Input:  numerical_features [1, 34] float32 — from [SuggestionsFeatureVector]
///           text_embedding      [1, 384] float32 — DisEmbed of active symptoms
///   Hidden: Linear(418→256)→LayerNorm→ReLU, Linear(256→128)→LayerNorm→ReLU
///   Output: context_vector  [1, 384] float32 — L2-normalised
///           relevance_gate  [1, 1]   float32 — sigmoid confidence (0–1)
///
/// Model asset: assets/models/health_suggestions_model.onnx
/// (Placeholder path — drop in trained model when available)
///
/// See docs/training_plan.md for architecture and training details.
class HealthSuggestionsModelService {
  /// Total numerical features (25 base + 9 derived). Must match training.
  static const int numNumericalFeatures = 34;

  /// DisEmbed embedding dimension. Must match training.
  static const int embeddingDim = 384;

  /// Gate threshold below which ML suggestions are not trusted.
  /// Falls back to [DailySuggestionsService] heuristic client.
  static const double minGateThreshold = 0.30;

  OrtSession? _session;
  bool        _isLoaded = false;
  String?     _assetPath;

  bool get isLoaded => _isLoaded;

  /// Load the ONNX model from a Flutter asset path.
  Future<void> load(String assetPath) async {
    _assetPath = assetPath;
    OrtEnv.instance.init();
    final rawAssetFile = await rootBundle.load(assetPath);
    final bytes        = rawAssetFile.buffer.asUint8List();
    final opts         = OrtSessionOptions();
    _session           = OrtSession.fromBuffer(bytes, opts);
    _isLoaded          = true;
  }

  /// Reload the model from the last-used asset path.
  Future<void> reload() async {
    if (_assetPath == null) {
      throw StateError('HealthSuggestionsModelService: reload() called before load()');
    }
    await load(_assetPath!);
  }

  /// Run inference and return a [SuggestionsModelOutput].
  ///
  /// Throws [StateError] if not loaded.
  Future<SuggestionsModelOutput> predict({
    required List<double> numericalFeatures,
    required List<double> textEmbedding,
  }) async {
    if (!_isLoaded) {
      throw StateError('HealthSuggestionsModelService not loaded. Call load() first.');
    }

    assert(
      numericalFeatures.length == numNumericalFeatures,
      'Expected $numNumericalFeatures features, got ${numericalFeatures.length}',
    );
    assert(
      textEmbedding.length == embeddingDim,
      'Expected embedding dim $embeddingDim, got ${textEmbedding.length}',
    );

    final numTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(numericalFeatures),
      [1, numNumericalFeatures],
    );
    final embTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(textEmbedding),
      [1, embeddingDim],
    );

    final inputs     = {'numerical_features': numTensor, 'text_embedding': embTensor};
    final runOptions = OrtRunOptions();
    final outputs    = await _session!.runAsync(runOptions, inputs);

    // Output[0]: context_vector [1, 384] → List<List<double>>
    // Output[1]: relevance_gate [1, 1]   → List<List<double>>
    final contextRaw = outputs![0]!.value as List<List<double>>;
    final gateRaw    = outputs[1]!.value  as List<List<double>>;

    numTensor.release();
    embTensor.release();
    runOptions.release();
    for (final e in outputs) { e?.release(); }

    return SuggestionsModelOutput(
      contextVector:  List<double>.from(contextRaw[0]),
      relevanceGate:  gateRaw[0][0],
    );
  }

  void dispose() {
    _session?.release();
    _isLoaded = false;
  }
}
