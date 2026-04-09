import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBindingObserver;

import 'mobilebert_service.dart';
import 'disembed_service.dart';
import 'fitness_mlp_service.dart';
import 'health_summary_model_service.dart';
import 'health_suggestions_model_service.dart';

/// Identifies each on-device AI model.
enum ModelType { mobileBert, disEmbed, fitnessMlp, healthSummary, healthSuggestions }

/// Conservative model lifecycle manager.
///
/// Policy:
///   - ONNX models are loaded at app startup and **never unloaded** automatically.
///   - healthSummary (~2 MB) and healthSuggestions (~1 MB) are loaded only when
///     their ONNX asset files exist; missing files are silently skipped.
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
    ModelType.mobileBert:         35,
    ModelType.disEmbed:           55,
    ModelType.fitnessMlp:          8,
    ModelType.healthSummary:       2,
    ModelType.healthSuggestions:   1,
  };

  // ── Service references ───────────────────────────────────────────────────────
  late MobileBertService            _mobileBert;
  late DisEmbedService              _disEmbed;
  late FitnessMlpService            _fitnessMlp;
  late HealthSummaryModelService    _healthSummary;
  late HealthSuggestionsModelService _healthSuggestions;

  bool _initialised = false;

  /// Last time each model was accessed via [ensureLoaded].
  final Map<ModelType, DateTime> _lastUsed = {};

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Wire up service references. Must be called once from AppServices.init().
  void init({
    required MobileBertService             mobileBert,
    required DisEmbedService               disEmbed,
    required FitnessMlpService             fitnessMlp,
    required HealthSummaryModelService     healthSummary,
    required HealthSuggestionsModelService healthSuggestions,
  }) {
    _mobileBert        = mobileBert;
    _disEmbed          = disEmbed;
    _fitnessMlp        = fitnessMlp;
    _healthSummary     = healthSummary;
    _healthSuggestions = healthSuggestions;
    _initialised       = true;
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  bool get isInitialised => _initialised;

  bool isLoaded(ModelType type) {
    _assertInitialised();
    return switch (type) {
      ModelType.mobileBert         => _mobileBert.isLoaded,
      ModelType.disEmbed           => _disEmbed.isLoaded,
      ModelType.fitnessMlp         => _fitnessMlp.isLoaded,
      ModelType.healthSummary      => _healthSummary.isLoaded,
      ModelType.healthSuggestions  => _healthSuggestions.isLoaded,
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
  Future<void> loadModel(ModelType type) async {
    _assertInitialised();
    switch (type) {
      case ModelType.mobileBert:
        await _mobileBert.reload();
      case ModelType.disEmbed:
        await _disEmbed.reload();
      case ModelType.fitnessMlp:
        await _fitnessMlp.reload();
      case ModelType.healthSummary:
        await _healthSummary.reload();
      case ModelType.healthSuggestions:
        await _healthSuggestions.reload();
    }
  }

  /// Explicitly unload a model.
  /// For ONNX models this is a no-op in the conservative policy — they are
  /// kept loaded at all times.
  Future<void> unloadModel(ModelType type) async {
    _assertInitialised();
    // Conservative policy: ONNX models are never auto-evicted.
    debugPrint('[ModelLifecycle] unloadModel($type) skipped — ONNX models stay loaded.');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _assertInitialised() {
    if (!_initialised) {
      throw StateError('ModelLifecycleService not initialised. Call init() first.');
    }
  }
}
