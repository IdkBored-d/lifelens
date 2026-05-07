import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBindingObserver;

import 'mobilebert_service.dart';
import 'disembed_service.dart';
import 'fitness_mlp_service.dart';
import 'minigen_service.dart';
import 'minigen_downloader.dart';

/// Identifies each on-device AI model.
enum ModelType { mobileBert, disEmbed, fitnessMlp, miniGen }

/// Dynamic model lifecycle manager with lazy loading and auto-unloading.
///
/// Policy:
///   - Models are loaded on-demand via [ensureLoaded].
///   - MobileBERT and DisEmbed are automatically unloaded after 15 seconds
///     of inactivity (triggered by UI lifecycle events).
///   - FitnessMLP is persistent (per user requirement).
///   - MiniGen is loaded on-demand.
class ModelLifecycleService with WidgetsBindingObserver {
  ModelLifecycleService._();
  static final ModelLifecycleService instance = ModelLifecycleService._();

  // ── Memory estimates (MB) ────────────────────────────────────────────────────
  static const Map<ModelType, int> _kEstimatedMB = {
    ModelType.mobileBert: 35,
    ModelType.disEmbed:   55,
    ModelType.fitnessMlp: 8,
    ModelType.miniGen:    96,
  };

  // ── Service references ───────────────────────────────────────────────────────
  late MobileBertService _mobileBert;
  late DisEmbedService   _disEmbed;
  late FitnessMlpService _fitnessMlp;
  late MiniGenService    _miniGen;

  late String _mobileBertAssetPath;
  late String _disEmbedAssetPath;

  bool _initialised = false;

  /// Last time each model was accessed via [ensureLoaded].
  final Map<ModelType, DateTime> _lastUsed = {};

  /// Active unload timers.
  final Map<ModelType, Timer> _unloadTimers = {};

  // ── Initialisation ───────────────────────────────────────────────────────────

  void init({
    required MobileBertService mobileBert,
    required DisEmbedService   disEmbed,
    required FitnessMlpService fitnessMlp,
    required MiniGenService    miniGen,
    String mobileBertAssetPath = 'assets/models/mobile_bert_emotion.onnx',
    String disEmbedAssetPath   = 'assets/models/disembed_fp16.onnx',
  }) {
    _mobileBert  = mobileBert;
    _disEmbed    = disEmbed;
    _fitnessMlp  = fitnessMlp;
    _miniGen     = miniGen;
    _mobileBertAssetPath = mobileBertAssetPath;
    _disEmbedAssetPath   = disEmbedAssetPath;
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
      cancelUnload(type); // Cancel any pending unload if the user returns.
      
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

  /// Explicitly load a model.
  Future<void> loadModel(ModelType type) async {
    _assertInitialised();
    switch (type) {
      case ModelType.mobileBert:
        await _mobileBert.load(_mobileBertAssetPath);
      case ModelType.disEmbed:
        await _disEmbed.load(_disEmbedAssetPath);
      case ModelType.fitnessMlp:
        await _fitnessMlp.reload(); // FitnessMLP is loaded at init, so reload is safe.
      case ModelType.miniGen:
        final path = await MiniGenDownloader.ensureModel();
        await _miniGen.reload(path);
        _lastUsed[ModelType.miniGen] = DateTime.now();
    }
  }

  /// Unload a model explicitly and free its memory.
  Future<void> unloadModel(ModelType type) async {
    _assertInitialised();
    
    // Per user request: DO NOT TOUCH THE FITNESS MLP
    if (type == ModelType.fitnessMlp) return;

    if (!isLoaded(type)) return;

    debugPrint('[ModelLifecycle] Unloading $type to free memory...');
    switch (type) {
      case ModelType.mobileBert:
        _mobileBert.dispose();
      case ModelType.disEmbed:
        _disEmbed.dispose();
      case ModelType.miniGen:
        await _miniGen.dispose();
      case ModelType.fitnessMlp:
        // Already handled above, but for completeness.
        break;
    }
  }

  /// Schedule a model to be unloaded after a delay (e.g. when leaving a screen).
  void scheduleUnload(ModelType type, {Duration delay = const Duration(seconds: 15)}) {
    _assertInitialised();
    if (type == ModelType.fitnessMlp) return;

    cancelUnload(type);
    
    debugPrint('[ModelLifecycle] Scheduling unload for $type in ${delay.inSeconds}s');
    _unloadTimers[type] = Timer(delay, () {
      unloadModel(type);
      _unloadTimers.remove(type);
    });
  }

  /// Cancel a pending unload timer.
  void cancelUnload(ModelType type) {
    _unloadTimers[type]?.cancel();
    _unloadTimers.remove(type);
  }

  // ── Memory pressure ──────────────────────────────────────────────────────────

  @override
  void didHaveMemoryPressure() {
    debugPrint('[ModelLifecycle] Memory pressure received. '
        'Current usage: ${getMemoryUsageMB()} MB.');
    
    // On memory pressure, unload any model that isn't currently active.
    // (excluding fitnessMlp per requirement).
    for (final type in ModelType.values) {
      if (type != ModelType.fitnessMlp && isLoaded(type)) {
        unloadModel(type);
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _assertInitialised() {
    if (!_initialised) {
      throw StateError('ModelLifecycleService not initialised. Call init() first.');
    }
  }
}
