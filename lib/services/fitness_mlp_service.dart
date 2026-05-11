import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

import '../models/fitness_result.dart';

/// Runs the Fitness MLP (sklearn Pipeline: StandardScaler + MLP) on-device.
///
/// Model:   fitness_model_v9.onnx (exported via skl2onnx; FP32 for MVP)
/// Input:   float_input [1, 8] float32
///          features: [age, bmi, heart_rate, sleep_hours, smokes,
///                     nutrition_quality, activity_index, gender_M]
/// Outputs: label           [1]    int64
///          probabilities   [1, 2] float32  ← what we use
///
/// The sklearn pipeline bakes StandardScaler into the ONNX graph,
/// so raw feature values are passed directly — no manual scaling needed.
class FitnessMlpService {
  static const int _numFeatures = 8;

  OrtSession? _session;
  bool _isLoaded = false;
  String? _assetPath;

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
    if (_assetPath == null) throw StateError('FitnessMlpService: reload() called before load()');
    await load(_assetPath!);
  }

  /// Run inference on [features].
  /// Returns [List<double>] of length 2: [P(is_fit=0), P(is_fit=1)]
  Future<List<double>> predict(FitnessFeatures features) async {
    assert(_isLoaded, 'FitnessMlpService not loaded. Call load() first.');

    final featureList = features.toList();
    assert(featureList.length == _numFeatures,
        'Expected $_numFeatures features, got ${featureList.length}');

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(featureList.map((e) => e.toDouble()).toList()),
      [1, _numFeatures],
    );

    final inputs     = {'float_input': inputTensor};
    final runOptions = OrtRunOptions();
    final outputs    = await _session!.runAsync(runOptions, inputs);

    // The fixed model outputs probabilities as a raw tensor [1, 2] instead of a Map
    final probaRaw = outputs![1]!.value as List<List<double>>;
    final proba    = probaRaw[0];

    inputTensor.release();
    runOptions.release();
    for (final e in outputs) { e?.release(); }

    return [
      proba[0],  // P(is_fit = 0)
      proba[1],  // P(is_fit = 1)
    ];
  }

  void dispose() {
    _session?.release();
    _isLoaded = false;
  }
}
