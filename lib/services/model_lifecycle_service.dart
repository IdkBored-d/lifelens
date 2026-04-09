import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBindingObserver;
import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;

import 'mobilebert_service.dart';
import 'disembed_service.dart';
import 'fitness_mlp_service.dart';
import 'gemma_service.dart';
import 'gemma_model_manager.dart';

/// Identifies each on-device AI model.
enum ModelType { mobileBert, disEmbed, fitnessMlp, gemma }

/// Conservative model lifecycle manager.
///
/// Policy:
///   - ONNX models (MobileBERT ~35 MB, DisEmbed ~55 MB, FitnessMLP ~8 MB)
///     are loaded at app startup and **never unloaded** automatically.
///     Their combined footprint (~98 MB) is negligible on modern devices.
///
///   - Gemma (~1.4 GB) **is** unloaded under OS memory pressure via
///     [WidgetsBindingObserver.didHaveMemoryPressure].
///     A 60-second keep-alive prevents thrashing if the user just used MiniMe
///     and immediately triggered a memory warning.
///
/// Call [init] once from AppServices after all model services are constructed.
/// Register the singleton as a [WidgetsBindingObserver] at the same time:
///
/// ```dart
/// ModelLifecycleService.instance.init(...);
/// WidgetsBinding.instance.addObserver(ModelLifecycleService.instance);
/// ```
class ModelLifecycleService with WidgetsBindingObserver {
  ModelLifecycleService._();
  static final ModelLifecycleService instance = ModelLifecycleService._();

  // ── Memory estimates (MB) ────────────────────────────────────────────────────
  static const Map<ModelType, int> _kEstimatedMB = {
    ModelType.mobileBert: 35,
    ModelType.disEmbed:   55,
    ModelType.fitnessMlp: 8,
    ModelType.gemma:      1400,
  };

  /// Minimum time Gemma must be idle before it can be evicted under pressure.
  static const Duration _kGemmaKeepAlive = Duration(seconds: 60);

  // ── Service references ───────────────────────────────────────────────────────
  late MobileBertService _mobileBert;
  late DisEmbedService   _disEmbed;
  late FitnessMlpService _fitnessMlp;
  late GemmaService      _gemma;

  bool _initialised = false;

  /// Last time each model was accessed via [ensureLoaded].
  final Map<ModelType, DateTime> _lastUsed = {};

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Wire up service references. Must be called once from AppServices.init().
  void init({
    required MobileBertService mobileBert,
    required DisEmbedService   disEmbed,
    required FitnessMlpService fitnessMlp,
    required GemmaService      gemma,
  }) {
    _mobileBert  = mobileBert;
    _disEmbed    = disEmbed;
    _fitnessMlp  = fitnessMlp;
    _gemma       = gemma;
    _initialised = true;
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  bool get isInitialised => _initialised;

  /// The backend (GPU or CPU) that Gemma was loaded on. Null when not loaded.
  PreferredBackend? get gemmaBackend => _initialised ? _gemma.activeBackend : null;

  bool isLoaded(ModelType type) {
    _assertInitialised();
    return switch (type) {
      ModelType.mobileBert => _mobileBert.isLoaded,
      ModelType.disEmbed   => _disEmbed.isLoaded,
      ModelType.fitnessMlp => _fitnessMlp.isLoaded,
      ModelType.gemma      => _gemma.isLoaded,
    };
  }

  /// Ensure all [types] are loaded before a pipeline call.
  /// Updates [_lastUsed] so the keep-alive window resets on each use.
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

  /// Explicitly load a model. ONNX models reload from cached asset path.
  /// Gemma reloads from the path saved in [GemmaModelManager].
  Future<void> loadModel(ModelType type) async {
    _assertInitialised();
    switch (type) {
      case ModelType.mobileBert:
        await _mobileBert.reload();
      case ModelType.disEmbed:
        await _disEmbed.reload();
      case ModelType.fitnessMlp:
        await _fitnessMlp.reload();
      case ModelType.gemma:
        final path = await GemmaModelManager.getSavedPath();
        if (path.isNotEmpty) {
          await _gemma.load(path);
          _lastUsed[ModelType.gemma] = DateTime.now();
        } else {
          debugPrint('[ModelLifecycle] Gemma reload skipped — no saved path.');
        }
    }
  }

  /// Explicitly unload a model.
  /// For ONNX models this is a no-op in the conservative policy — they are
  /// kept loaded at all times. Gemma can be unloaded freely.
  Future<void> unloadModel(ModelType type) async {
    _assertInitialised();
    switch (type) {
      case ModelType.mobileBert:
      case ModelType.disEmbed:
      case ModelType.fitnessMlp:
        // Conservative policy: ONNX models are never auto-evicted.
        debugPrint('[ModelLifecycle] unloadModel($type) skipped — ONNX models stay loaded.');
      case ModelType.gemma:
        if (_gemma.isLoaded) {
          await _gemma.unload();
          debugPrint('[ModelLifecycle] Gemma unloaded.');
        }
    }
  }

  // ── Memory pressure ──────────────────────────────────────────────────────────

  /// Called automatically by [WidgetsBindingObserver] when the OS signals low
  /// memory. Only evicts Gemma, and only if it has been idle for the keep-alive
  /// window (default 60 s).
  @override
  void didHaveMemoryPressure() {
    debugPrint('[ModelLifecycle] Memory pressure received. '
        'Current usage: ${getMemoryUsageMB()} MB.');
    _evictGemmaIfIdle();
  }

  void _evictGemmaIfIdle() {
    if (!_gemma.isLoaded) return;
    final lastUsed = _lastUsed[ModelType.gemma];
    final idleLong = lastUsed == null ||
        DateTime.now().difference(lastUsed) > _kGemmaKeepAlive;
    if (idleLong) {
      // Fire-and-forget — we're in a synchronous observer callback.
      _gemma.unload().then((_) {
        debugPrint('[ModelLifecycle] Gemma evicted under memory pressure.');
      }).catchError((Object e) {
        debugPrint('[ModelLifecycle] Gemma eviction failed: $e');
      });
    } else {
      debugPrint('[ModelLifecycle] Gemma recently used — skipping eviction.');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _assertInitialised() {
    if (!_initialised) {
      throw StateError('ModelLifecycleService not initialised. Call init() first.');
    }
  }
}
