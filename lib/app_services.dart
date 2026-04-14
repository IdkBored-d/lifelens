import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_wordpiece/dart_wordpiece.dart';

import 'database/isar_service.dart';
import 'services/confidence_manager.dart';
import 'services/quick_track_service.dart';
import 'services/weaviate_service.dart';
import 'services/mobilebert_service.dart';
import 'services/disembed_service.dart';
import 'services/fitness_mlp_service.dart';
import 'services/gemma_service.dart';
import 'services/gemini_service.dart';
import 'services/mood_pipeline_service.dart';
import 'services/symptom_pipeline_service.dart';
import 'services/fitness_pipeline_service.dart';
import 'services/eod_pipeline_service.dart';
import 'services/chat_session_service.dart';
import 'services/model_lifecycle_service.dart';

/// Central service locator for LifeLens.
/// Initialised once at app startup — all pipelines accessible as singletons.
///
/// Usage:
///   await AppServices.init(gemmaPath: path);
///   AppServices.moodPipeline.analyze(...)
///
/// TOKENIZER NOTE:
///   MobileBERT and DisEmbed share the same BERT WordPiece vocab
///   (google/mobilebert-uncased, 30,522 tokens).
///   Two tokenizer instances are created — one per maxLength:
///     _mbTokenizer  → maxLen = 128  (MobileBERT)
///     _deTokenizer  → maxLen = 512  (DisEmbed)
class AppServices {
  AppServices._();

  // Add this for health data platform channel
  static const MethodChannel _healthChannel = MethodChannel('lifelens/health');

  // ── Singletons ──────────────────────────────────────────────────────────────
  static late final IsarService isar;
  static late final ConfidenceManager confidence;
  static late final QuickTrackService quickTrack;
  static late final WeaviateService weaviate;
  static late final MobileBertService mobileBert;
  static late final DisEmbedService disEmbed;
  static late final FitnessMlpService fitnessMlp;
  static late final GemmaService gemma;
  static late final GeminiService gemini;
  static late final MoodPipelineService moodPipeline;
  static late final SymptomPipelineService symptomPipeline;
  static late final FitnessPipelineService fitnessPipeline;
  static late final EodPipelineService eodPipeline;

  // Two tokenizer instances — same vocab, different maxLength
  static late final WordPieceTokenizer
  _mbTokenizer; // maxLen=128 for MobileBERT
  static late final WordPieceTokenizer _deTokenizer; // maxLen=512 for DisEmbed

  // ── Configuration ────────────────────────────────────────────────────────────
  // Keys are injected at build time via --dart-define-from-file=config.json.
  // config.json is gitignored — never commit real keys.
  //
  // TODO(prod): Move key retrieval to a server-side call before release.
  //   The client should fetch a short-lived token from the backend at login
  //   rather than bundling API keys in the binary.

  static const String _weaviateHost = 'https://your-cluster.weaviate.network';
  static const String _weaviateApiKey = 'YOUR_WEAVIATE_API_KEY';
  static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY';

  // Asset paths
  static const String _mobileBertAsset =
      'assets/models/mobile_bert_emotion.onnx';
  static const String _disEmbedAsset = 'assets/models/disembed_fp16.onnx';
  //static const String _fitnessAsset    = 'assets/models/fitness_model.onnx';
  static const String _fitnessAsset =
      'assets/models/for MVP/fitness_model_v9.onnx';
  static const String _vocabAsset = 'assets/models/vocab.txt';

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Initialise all services. Call once in main() before runApp().
  ///
  /// [gemmaPath] is the on-device path to the Gemma 2 2B IT model file.
  /// Pass an empty string if not yet downloaded — the app will run without
  /// on-device LLM and escalate to Gemini when online.
  static Future<void> init({required String gemmaPath}) async {
    WidgetsFlutterBinding.ensureInitialized();
    final sw = Stopwatch()..start();
    debugPrint('[AppServices] init: start');

    // ── 1. Database ──────────────────────────────────────────────────────────
    isar = IsarService.instance;
    final dbStart = sw.elapsedMilliseconds;
    try {
      await isar.init();
      debugPrint(
        '[AppServices] init: Isar initialised in ${sw.elapsedMilliseconds - dbStart}ms (total ${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      debugPrint('[AppServices] init: Isar init failed (non-fatal): $e');
    }

    // ── 2. Shared BERT tokenizers ────────────────────────────────────────────
    // Same vocab file works for both models.
    // Two instances needed because maxLength is set at construction time.
    final vocabRaw = await rootBundle.loadString(_vocabAsset);
    final vocab = VocabLoader.fromString(vocabRaw);

    _mbTokenizer = WordPieceTokenizer(
      vocab: vocab,
      config: TokenizerConfig(maxLength: 128, normalizeText: true),
    );
    _deTokenizer = WordPieceTokenizer(
      vocab: vocab,
      config: TokenizerConfig(maxLength: 512, normalizeText: true),
    );

    // ── 3. Stateless services ────────────────────────────────────────────────
    final statelessStart = sw.elapsedMilliseconds;
    confidence = const ConfidenceManager();
    quickTrack = QuickTrackService();
    debugPrint(
      '[AppServices] init: Stateless services in ${sw.elapsedMilliseconds - statelessStart}ms',
    );

    // ── 4. External services ─────────────────────────────────────────────────
    weaviate = WeaviateService(host: _weaviateHost, apiKey: _weaviateApiKey);
    gemini = GeminiService(apiKey: _geminiApiKey);

    // ── 5. ONNX model services (load in parallel) ────────────────────────────
    final modelsStart = sw.elapsedMilliseconds;
    mobileBert = MobileBertService();
    disEmbed = DisEmbedService();
    fitnessMlp = FitnessMlpService();

    var loadedCount = 0;

    Future<void> loadModel(String name, Future<void> Function() loader) async {
      try {
        await loader();
        loadedCount += 1;
        debugPrint('[AppServices] init: $name loaded');
      } catch (e) {
        debugPrint('[AppServices] init: $name load failed: $e');
      }
    }

    await Future.wait([
      loadModel('MobileBERT', () => mobileBert.load(_mobileBertAsset)),
      loadModel('DisEmbed', () => disEmbed.load(_disEmbedAsset)),
      loadModel('FitnessMLP', () => fitnessMlp.load(_fitnessAsset)),
    ]);

    debugPrint(
      '[AppServices] init: ONNX models ready $loadedCount/3 in ${sw.elapsedMilliseconds - modelsStart}ms',
    );

    // ── 6. Gemma 2 2B IT (skip gracefully if not yet downloaded) ────────────
    final gemmaStart = sw.elapsedMilliseconds;
    gemma = GemmaService();
    if (gemmaPath.isNotEmpty) {
      try {
        await gemma.load(gemmaPath);
        debugPrint(
          '[AppServices] init: Gemma loaded in ${sw.elapsedMilliseconds - gemmaStart}ms',
        );
      } catch (e) {
        debugPrint('[AppServices] init: Gemma load failed: $e');
      }
    } else {
      debugPrint('[AppServices] init: Gemma skipped (no path provided)');
    }

    // ── 7. Lifecycle + startup repair ───────────────────────────────────────
    ModelLifecycleService.instance.init(
      mobileBert: mobileBert,
      disEmbed: disEmbed,
      fitnessMlp: fitnessMlp,
      gemma: gemma,
    );
    WidgetsBinding.instance.addObserver(ModelLifecycleService.instance);

    final repairStart = sw.elapsedMilliseconds;
    try {
      final chatSessions = ChatSessionService(quickTrack, gemma);
      await chatSessions.repairIncompleteSessions();
      debugPrint(
        '[AppServices] init: Startup repair in ${sw.elapsedMilliseconds - repairStart}ms',
      );
    } catch (e) {
      debugPrint('[AppServices] startup repair failed (non-fatal): $e');
    }

    // ── 8. Pipeline services ─────────────────────────────────────────────────
    moodPipeline = MoodPipelineService(
      mobileBert: mobileBert,
      gemma: gemma,
      gemini: gemini,
      confidence: confidence,
      quickTrack: quickTrack,
      tokenize: _mobileBertTokenize,
    );

    symptomPipeline = SymptomPipelineService(
      disEmbed: disEmbed,
      gemma: gemma,
      gemini: gemini,
      weaviate: weaviate,
      confidence: confidence,
      quickTrack: quickTrack,
      tokenize: _disEmbedTokenize,
    );

    fitnessPipeline = FitnessPipelineService(
      mlp: fitnessMlp,
      confidence: confidence,
      fetchHealthData: _fetchHealthData,
    );

    eodPipeline = EodPipelineService(
      gemma: gemma,
      gemini: gemini,
      weaviate: weaviate,
      quickTrack: quickTrack,
      fitness: fitnessPipeline,
      disEmbed: disEmbed,
      tokenize: _disEmbedTokenize,
    );

    debugPrint('[AppServices] init: completed in ${sw.elapsedMilliseconds}ms');
  }

  // ── Tokenizer functions ───────────────────────────────────────────────────────

  /// MobileBERT tokenizer — enforces maxLen slice
  static Map<String, List<int>> _mobileBertTokenize(String text, int maxLen) {
    final output = _mbTokenizer.encode(text);
    return {
      'input_ids': output.inputIds.take(maxLen).toList(),
      'attention_mask': output.attentionMask.take(maxLen).toList(),
    };
  }

  /// DisEmbed tokenizer — enforces maxLen slice
  static Map<String, List<int>> _disEmbedTokenize(String text, int maxLen) {
    final output = _deTokenizer.encode(text);
    return {
      'input_ids': output.inputIds.take(maxLen).toList(),
      'attention_mask': output.attentionMask.take(maxLen).toList(),
    };
  }

  // ── Public tokenizer accessors ────────────────────────────────────────────────
  // These expose the private tokenizer functions so that dev_test_screen and
  // any other callers outside this class can pass them as callbacks.

  /// Public accessor for MobileBERT tokenizer (maxLen=128).
  static Map<String, List<int>> mobileBertTokenize(String text, int maxLen) =>
      _mobileBertTokenize(text, maxLen);

  /// Public accessor for DisEmbed tokenizer (maxLen=512).
  static Map<String, List<int>> disEmbedTokenize(String text, int maxLen) =>
      _disEmbedTokenize(text, maxLen);

  // ── Health data fetcher ───────────────────────────────────────────────────────

  static Future<RawHealthData?> _fetchHealthData() async {
    try {
      final Map<dynamic, dynamic>? raw = await _healthChannel.invokeMethod(
        'getDailyHealthMetrics',
      );

      if (raw == null) return null;

      return RawHealthData(
        age: (raw['age'] as num?)?.toDouble() ?? 0,
        weightKg: (raw['weightKg'] as num?)?.toDouble() ?? 0,
        heightCm: (raw['heightCm'] as num?)?.toDouble() ?? 0,
        restingHeartRate: (raw['restingHeartRate'] as num?)?.toDouble() ?? 0,
        sleepHours: (raw['sleepHours'] as num?)?.toDouble() ?? 0,
        smokes: raw['smokes'] as bool? ?? false,
        nutritionQuality: (raw['nutritionQuality'] as num?)?.toDouble() ?? 0,
        activityIndex: (raw['activityIndex'] as num?)?.toDouble() ?? 0,
        isMale: raw['isMale'] as bool? ?? false,
        timestamp:
            DateTime.tryParse(raw['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (e) {
      debugPrint('Health channel error: $e');
      return null;
    }
  }
  // ── Runtime helpers ───────────────────────────────────────────────────────────

  /// Load Gemma after OTA download completes — no app restart needed.
  static Future<void> loadGemmaModel(String path) async {
    if (gemma.isLoaded) return;
    await gemma.load(path);
  }

  static bool get isGemmaLoaded {
    try { return gemma.isLoaded; } catch (_) { return false; }
  }

  /// Returns true if the device has any active network connection.
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ── Teardown ─────────────────────────────────────────────────────────────────

  static Future<void> dispose() async {
    mobileBert.dispose();
    disEmbed.dispose();
    fitnessMlp.dispose();
    gemma.dispose();
    await isar.close();
  }
}
