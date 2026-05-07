import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:llamadart/llamadart.dart';

/// Low-level wrapper around [LlamaEngine] for MiniGen GGUF inference.
///
/// Handles model loading, generation parameters, and lifecycle.
/// For chat-level logic (crisis detection, history, prompt building),
/// see [MiniGenChat].
///
/// NOTE: logic may be incorrect -- this is replacing our old version.
class MiniGenService {
  LlamaEngine? _engine;
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;

  /// Load the MiniGen GGUF model from the given filesystem path.
  Future<void> load(String modelPath) async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;

    final nThreads = math.max(1, Platform.numberOfProcessors ~/ 2);
    debugPrint(
      '[MiniGenService] loading model: $modelPath (threads=$nThreads)',
    );

    try {
      _engine = LlamaEngine(LlamaBackend());
      // Add a timeout to prevent infinite hang if the native isolate crashes
      await _engine!.loadModel(
        modelPath,
        modelParams: ModelParams(
          gpuLayers: 0, // CPU-only on mobile
          contextSize: 2048,
          numberOfThreads: nThreads,
        ),
      ).timeout(const Duration(seconds: 90));

      // Guard: dispose() may have been called while the native load was awaited.
      if (_engine == null) return;

      _isLoaded = true;
      debugPrint('[MiniGenService] model loaded successfully');
    } catch (e) {
      debugPrint('[MiniGenService] load failed or timed out: $e');
      _engine = null; // Clean up so dispose doesn't hang
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Reload the model (dispose then load again).
  Future<void> reload(String modelPath) async {
    await dispose();
    await load(modelPath);
  }

  /// Stream raw token output for the given prompt.
  ///
  /// The caller is responsible for prompt formatting and crisis detection.
  Stream<String> generate(
    String prompt, {
    int maxTokens = 512,
    double temperature = 0.25,
    int topK = 50,
    double repetitionPenalty = 1.1,
  }) async* {
    if (!_isLoaded || _engine == null) {
      throw StateError('MiniGenService not loaded. Call load() first.');
    }

    await for (final token in _engine!.generate(
      prompt,
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: temperature,
        topK: topK,
        penalty: repetitionPenalty,
      ),
    )) {
      yield token;
    }
  }

  /// Non-streaming generation — collects all tokens and returns the result.
  Future<String> generateFull(
    String prompt, {
    int maxTokens = 512,
    double temperature = 0.25,
    int topK = 50,
    double repetitionPenalty = 1.1,
  }) async {
    final buffer = StringBuffer();
    await for (final token in generate(
      prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topK: topK,
      repetitionPenalty: repetitionPenalty,
    )) {
      buffer.write(token);
    }
    return buffer.toString().trim();
  }

  /// Dispose the engine and free native resources.
  Future<void> dispose() async {
    if (_engine != null) {
      try {
        await _engine!.dispose().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('[MiniGenService] dispose failed or timed out: $e');
      }
      _engine = null;
    }
    _isLoaded = false;
    _isLoading = false;
    debugPrint('[MiniGenService] disposed');
  }
}
