import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

/// Runs MobileBERT emotion classification on-device via ONNX Runtime.
///
/// Model inputs:  input_ids      [1, 128] int64
///                attention_mask [1, 128] int64
/// Model output:  logits         [1, 6]   float32
class MobileBertService {
  static const int _seqLen = 128;

  OrtSession? _session;
  bool _isLoaded = false;
  String? _assetPath;

  bool get isLoaded => _isLoaded;

  /// Load the ONNX model from a Flutter asset path.
  Future<void> load(String assetPath) async {
    _assetPath = assetPath;
    OrtEnv.instance.init();
    final rawAssetFile = await rootBundle.load(assetPath);
    final bytes       = rawAssetFile.buffer.asUint8List();
    final opts        = OrtSessionOptions();
    _session          = OrtSession.fromBuffer(bytes, opts);
    _isLoaded         = true;
  }

  /// Reload the model from the last-used asset path.
  Future<void> reload() async {
    if (_assetPath == null) throw StateError('MobileBertService: reload() called before load()');
    await load(_assetPath!);
  }

  /// Run inference on a single [text] string.
  ///
  /// [tokenize] returns `{ 'input_ids': List<int>, 'attention_mask': List<int> }`
  /// both of length [_seqLen].
  ///
  /// Returns softmax probabilities as `List<double>` of length 6.
  Future<List<double>> classify(
    String text,
    Map<String, List<int>> Function(String text, int maxLen) tokenize,
  ) async {
    if (!_isLoaded) throw StateError('MobileBertService not loaded. Call load() first.');

    final tokens = tokenize(text, _seqLen);
    final ids    = tokens['input_ids']!;
    final mask   = tokens['attention_mask']!;

    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(ids),
      [1, _seqLen],
    );
    final maskTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(mask),
      [1, _seqLen],
    );

    final inputs     = {'input_ids': inputIdsTensor, 'attention_mask': maskTensor};
    final runOptions = OrtRunOptions();
    final outputs    = await _session!.runAsync(runOptions, inputs);

    // outputs[0] = logits [1, 6]
    final logits = (outputs![0]!.value as List<List<double>>)[0];

    inputIdsTensor.release();
    maskTensor.release();
    runOptions.release();
    for (final e in outputs) { e?.release(); }

    return _softmax(logits);
  }

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce((a, b) => a > b ? a : b);
    final exps   = logits.map((v) => _dartExp(v - maxVal)).toList();
    final sum    = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  // Taylor series approximation of e^x (avoids dart:math import)
  double _dartExp(double x) {
    double result = 1.0, term = 1.0;
    for (var i = 1; i <= 20; i++) {
      term   *= x / i;
      result += term;
    }
    return result;
  }

  void dispose() {
    _session?.release();
    _isLoaded = false;
  }
}
