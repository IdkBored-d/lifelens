import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

/// Runs DisEmbed-v1 (FP16 ONNX) on-device to produce sentence embeddings.
///
/// Model:  SalmanFaroz/DisEmbed-v1 (FP16)
/// Input:  input_ids [1, 512] int64, attention_mask [1, 512] int64
/// Output: token embeddings [1, 512, 384] float32
///         → mean-pooled + L2-normalised → 384-dim embedding
class DisEmbedService {
  static const int _maxSeqLen = 512;
  static const int _hiddenDim = 384;

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
    // We cannot use Isolate.run here because OrtSession attaches a NativeFinalizer
    // which cannot be sent across isolates. Lazy-loading alone fixes the startup ANR.
    // To fully offload, this entire service must be rewritten as a persistent isolate worker.
    final opts = OrtSessionOptions();
    _session   = OrtSession.fromBuffer(bytes, opts);
    
    _isLoaded  = true;
  }

  /// Reload the model from the last-used asset path.
  Future<void> reload() async {
    if (_assetPath == null) throw StateError('DisEmbedService: reload() called before load()');
    await load(_assetPath!);
  }

  /// Embed [text] and return a 384-dim L2-normalised vector.
  ///
  /// [tokenize] returns `{ 'input_ids': List<int>, 'attention_mask': List<int> }`
  /// both padded/truncated to [_maxSeqLen].
  Future<List<double>> embed(
    String text,
    Map<String, List<int>> Function(String text, int maxLen) tokenize,
  ) async {
    if (!_isLoaded) throw StateError('DisEmbedService not loaded. Call load() first.');

    final tokens = tokenize(text, _maxSeqLen);
    final ids    = tokens['input_ids']!;
    final mask   = tokens['attention_mask']!;

    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(ids),
      [1, _maxSeqLen],
    );
    final maskTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(mask),
      [1, _maxSeqLen],
    );

    final inputs     = {'input_ids': inputIdsTensor, 'attention_mask': maskTensor};
    final runOptions = OrtRunOptions();
    final outputs    = await _session!.runAsync(runOptions, inputs);

    // outputs[0] = token embeddings [1, seq_len, 384]
    final rawEmbeddings = outputs![0]!.value as List<List<List<double>>>;

    inputIdsTensor.release();
    maskTensor.release();
    runOptions.release();
    for (final e in outputs) { e?.release(); }

    final tokenEmbeddings = rawEmbeddings[0]; // [seq_len, 384]
    final pooled          = _meanPool(tokenEmbeddings, mask);
    return _l2Normalize(pooled);
  }

  /// Cosine similarity between two 384-dim embeddings.
  double cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Embedding dimension mismatch');
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot   += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  List<double> _meanPool(List<List<double>> tokenEmbs, List<int> mask) {
    final pooled   = List<double>.filled(_hiddenDim, 0.0);
    int realCount  = 0;
    for (var t = 0; t < tokenEmbs.length; t++) {
      if (mask[t] == 1) {
        for (var d = 0; d < _hiddenDim; d++) {
          pooled[d] += tokenEmbs[t][d];
        }
        realCount++;
      }
    }
    if (realCount > 0) {
      for (var d = 0; d < _hiddenDim; d++) {
        pooled[d] /= realCount;
      }
    }
    return pooled;
  }

  List<double> _l2Normalize(List<double> v) {
    final norm = math.sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    if (norm < 1e-9) return v;
    return v.map((x) => x / norm).toList();
  }

  void dispose() {
    _session?.release();
    _isLoaded = false;
  }
}
