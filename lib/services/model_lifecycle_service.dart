import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBindingObserver;
import 'dart:io' show Platform;

import 'mobilebert_service.dart';
import 'disembed_service.dart';
import 'fitness_mlp_service.dart';
import 'minigen_service.dart';
import 'minigen_downloader.dart';

/// Identifies each on-device AI model.
enum ModelType { mobileBert, disEmbed, fitnessMlp, miniGen }

/// Conservative model lifecycle manager.
///
/// Policy:
///   - Models (MobileBERT ~35 MB, DisEmbed ~55 MB, FitnessMLP ~8 MB,
///     MiniGen ~96 MB) are loaded at app startup and never unloaded
///     automatically. MiniGen's memory is managed by llama.cpp internally.
///
/// NOTE: logic may be incorrect -- this is replacing our old version.
///
/// Call [init] once from AppServices after all model services are constructed.
/// Register the singleton as a [WidgetsBindingObserver] at the same time.
class ModelLifecycleService with WidgetsBindingObserver {
  ModelLifecycleService._();
  static final ModelLifecycleService instance = ModelLifecycleService._();

  // ── Memory estimates (MB) ────────────────────────────────────────────────────
  static const Map<ModelType, int> _kEstimatedMB = {
    ModelType.mobileBert: 35,
    ModelType.disEmbed:   55,
    ModelType.fitnessMlp: 8,
    ModelType.miniGen:    96,  // F16 GGUF; actual runtime memory managed by llama.cpp
  };

  // ── Service references ───────────────────────────────────────────────────────
  late MobileBertService _mobileBert;
  late DisEmbedService   _disEmbed;
  late FitnessMlpService _fitnessMlp;
  late MiniGenService    _miniGen;

  bool _initialised = false;

  /// Last time each model was accessed via [ensureLoaded].
  final Map<ModelType, DateTime> _lastUsed = {};

  // ── Initialisation ───────────────────────────────────────────────────────────

  void init({
    required MobileBertService mobileBert,
    required DisEmbedService   disEmbed,
    required FitnessMlpService fitnessMlp,
    required MiniGenService    miniGen,
  }) {
    _mobileBert  = mobileBert;
    _disEmbed    = disEmbed;
    _fitnessMlp  = fitnessMlp;
    _miniGen     = miniGen;
    _initialised = true;
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  bool get isInitialised => _initialised;

  bool isLoaded(ModelType type) {
    _assertInitialised();
    return switch (type) {
      ModelType.mobileBert => _mobileBert.isLoaded,
      ModelType.disEmbed   => _disEmbed.isLoaded,
      ModelType.fitnessMlp => _fitnessMlp.isLoaded,
      ModelType.miniGen    => _miniGen.isLoaded,
    };
  }

  /// Ensure all [types] are loaded before a pipeline call.
  Future<void> ensureLoaded(List<ModelType> types) async {
    _assertInitialised();
    for (final type in types) {
      if (!isLoaded(type)) {
        debugPrint('[ModelLifecycle] Loading $type on demand...');
        await loadModel(type);
      }
      _lastUsed[type] = DateTime.now();
    }
  }

  /// Estimated total memory used by currently-loaded models (MB).
  int getMemoryUsageMB() {
    return ModelType.values
        .where(isLoaded)
        .fold(0, (sum, t) => sum + _kEstimatedMB[t]!);
  }

  /// Explicitly load a model. All models call [reload] on their cached asset
  /// path (Rule #9 — never pass the asset path again after initial load).
  Future<void> loadModel(ModelType type) async {
    _assertInitialised();
    switch (type) {
      case ModelType.mobileBert:
        await _mobileBert.reload();
      case ModelType.disEmbed:
        await _disEmbed.reload();
      case ModelType.fitnessMlp:
        await _fitnessMlp.reload();
      case ModelType.miniGen:
        // iOS simulator/framework packaging can fail for llamadart.
        // Keep app stable and allow backend fallback when unavailable.
        if (Platform.isIOS) {
          debugPrint('[ModelLifecycle] MiniGen load skipped on iOS; using backend fallback.');
          return;
        }
        try {
          final path = await MiniGenDownloader.ensureModel();
          await _miniGen.reload(path);
          _lastUsed[ModelType.miniGen] = DateTime.now();
        } catch (e) {
          debugPrint('[ModelLifecycle] MiniGen reload failed (non-fatal): $e');
        }
    }
  }

  /// Unload a model explicitly. Conservative policy: ONNX models are kept
  /// loaded at all times — this is a no-op for all current model types.
  Future<void> unloadModel(ModelType type) async {
    _assertInitialised();
    debugPrint('[ModelLifecycle] unloadModel($type) — conservative policy, skipped.');
  }

  // ── Memory pressure ──────────────────────────────────────────────────────────

  /// MiniGen at 96 MB (F16 GGUF) does not warrant eviction under memory pressure.
  /// Override present for future policy changes.
  @override
  void didHaveMemoryPressure() {
    debugPrint('[ModelLifecycle] Memory pressure received. '
        'Current usage: ${getMemoryUsageMB()} MB. No models evicted (all under threshold).');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _assertInitialised() {
    if (!_initialised) {
      throw StateError('ModelLifecycleService not initialised. Call init() first.');
    }
  }
}
