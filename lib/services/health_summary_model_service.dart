import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

/// Runs the HealthSummaryModel on-device to generate context vectors for
/// sentence bank selection, replacing [TemplateSummaryInsightService] and
/// the narrative generation in [EodCorrelationEngine].
///
/// Architecture (MLP projector):
///   Input:  numerical_features [1, 25] float32 — from [HealthFeatureComputer]
///           text_embedding      [1, 384] float32 — DisEmbed of recent mood logs
///   Hidden: Linear(409→256)→LayerNorm→ReLU×2
///   Output: context_vectors [1, 3, 384] float32 — L2-normalised
///           One 384-dim context vector per sentence slot:
///             [0] mood_status sentence
///             [1] health_context sentence
///             [2] actionable_closing sentence
///
/// Model asset: assets/models/health_summary_model.onnx
/// (Placeholder path — drop in trained model when available)
///
/// See docs/training_plan.md for architecture and training details.
class HealthSummaryModelService {
  /// Number of base numerical health features. Must match training.
  static const int numNumericalFeatures = 25;

  /// DisEmbed embedding dimension. Must match training.
  static const int embeddingDim = 384;

  /// Number of output sentence heads (mood_status / health_context / actionable).
  static const int numHeads = 3;

  /// Minimum cosine similarity for a sentence selection to be considered
  /// confident. Below this threshold, callers should fall back to templates.
  static const double minConfidenceThreshold = 0.30;

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
      throw StateError('HealthSummaryModelService: reload() called before load()');
    }
    await load(_assetPath!);
  }

  /// Run inference and return 3 context vectors (one per sentence slot).
  ///
  /// Returns a [List] of 3 elements, each a 384-dim [List<double>]:
  ///   result[0] = context vector for mood_status sentence
  ///   result[1] = context vector for health_context sentence
  ///   result[2] = context vector for actionable_closing sentence
  ///
  /// Throws [StateError] if not loaded.
  Future<List<List<double>>> predict({
    required List<double> numericalFeatures,
    required List<double> textEmbedding,
  }) async {
    if (!_isLoaded) {
      throw StateError('HealthSummaryModelService not loaded. Call load() first.');
    }

    assert(
      numericalFeatures.length == numNumericalFeatures,
      'Expected $numNumericalFeatures numerical features, got ${numericalFeatures.length}',
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

    // Output: context_vectors [1, 3, 384] → List<List<List<double>>>
    final raw = outputs![0]!.value as List<List<List<double>>>;

    numTensor.release();
    embTensor.release();
    runOptions.release();
    for (final e in outputs) { e?.release(); }

    // raw[0] has shape [3][384]
    final batch0 = raw[0];
    return [
      List<double>.from(batch0[0]), // mood_status
      List<double>.from(batch0[1]), // health_context
      List<double>.from(batch0[2]), // actionable_closing
    ];
  }

  void dispose() {
    _session?.release();
    _isLoaded = false;
  }
}
