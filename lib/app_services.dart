import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_wordpiece/dart_wordpiece.dart';

import 'database/isar_service.dart';
import 'services/confidence_manager.dart';
import 'services/quick_track_service.dart';
import 'services/weaviate_service.dart';
import 'services/mobilebert_service.dart';
import 'services/disembed_service.dart';
import 'services/fitness_mlp_service.dart';
import 'services/gemini_service.dart';
import 'services/health_service.dart';
import 'services/mood_pipeline_service.dart';
import 'services/symptom_pipeline_service.dart';
import 'services/fitness_pipeline_service.dart';
import 'services/eod_pipeline_service.dart';
import 'services/chat_session_service.dart';
import 'services/model_lifecycle_service.dart';
import 'services/disease_knowledge_base.dart';
import 'services/eod_correlation_engine.dart';
import 'services/template_mood_response_service.dart';
import 'services/template_summary_insight_service.dart';
import 'services/health_feature_computer.dart';
import 'services/health_summary_model_service.dart';
import 'services/health_suggestions_model_service.dart';
import 'services/sentence_bank_service.dart';

/// Central service locator for LifeLens.
/// Initialised once at app startup — all pipelines accessible as singletons.
///
/// Usage:
///   await AppServices.init();
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

  // ── Singletons ──────────────────────────────────────────────────────────────
  static late final IsarService                isar;
  static late final ConfidenceManager          confidence;
  static late final QuickTrackService          quickTrack;
  static late final WeaviateService            weaviate;
  static late final MobileBertService          mobileBert;
  static late final DisEmbedService            disEmbed;
  static late final FitnessMlpService          fitnessMlp;
  static late final GeminiService              gemini;
  static late final DiseaseKnowledgeBase       diseaseKb;
  static late final EodCorrelationEngine          eodCorrelation;
  static late final TemplateMoodResponseService   templateMoodResponse;
  static late final TemplateSummaryInsightService templateInsight;
  static late final HealthFeatureComputer         healthFeatureComputer;
  static late final HealthSummaryModelService     healthSummaryModel;
  static late final HealthSuggestionsModelService healthSuggestionsModel;
  static late final SentenceBankService           sentenceBank;
  static ModelLifecycleService get models      => ModelLifecycleService.instance;
  static late final MoodPipelineService        moodPipeline;
  static late final SymptomPipelineService     symptomPipeline;
  static late final FitnessPipelineService     fitnessPipeline;
  static late final EodPipelineService         eodPipeline;

  // Two tokenizer instances — same vocab, different maxLength
  static late final WordPieceTokenizer _mbTokenizer; // maxLen=128 for MobileBERT
  static late final WordPieceTokenizer _deTokenizer; // maxLen=512 for DisEmbed

  // Initialisation sentinel — set on first init() call; cleared on failure so retries are possible.
  static Future<void>? _initFuture;

  // ── Configuration ────────────────────────────────────────────────────────────
  // Keys are injected at build time via --dart-define-from-file=config.json.
  // config.json is gitignored — never commit real keys.
  //
  // TODO(prod): Move key retrieval to a server-side call before release.

  static const String _weaviateHost   = String.fromEnvironment('WEAVIATE_HOST',    defaultValue: '');
  static const String _weaviateApiKey = String.fromEnvironment('WEAVIATE_API_KEY', defaultValue: '');
  static const String _geminiApiKey   = String.fromEnvironment('GEMINI_API_KEY',   defaultValue: '');

  // Asset paths
  static const String _mobileBertAsset      = 'assets/models/mobile_bert_emotion.onnx';
  // TODO(ship): Switch back to FP16 model when shipping — FP32 is for MVP only.
  static const String _disEmbedAsset        = 'assets/models/for MVP/disembed_fp32.onnx';
  // TODO(ship): Retrain/re-export and swap in a versioned production model before shipping.
  static const String _fitnessAsset         = 'assets/models/for MVP/fitness_model_v9.onnx';
  static const String _vocabAsset           = 'assets/models/vocab.txt';
  // In-house models — drop trained .onnx files here to activate ML inference.
  // See docs/training_plan.md for training and export instructions.
  static const String _healthSummaryAsset     = 'assets/models/health_summary_model.onnx';
  static const String _healthSuggestionsAsset = 'assets/models/health_suggestions_model.onnx';

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Returns the in-flight or completed init future. Safe to call from any
  /// screen — awaiting it guarantees all services are ready before use.
  static Future<void> ensureInitialized() =>
      _initFuture ?? init();

  /// Idempotent init — returns the same [Future] on every concurrent call.
  static Future<void> init() {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initInternal().catchError((Object e) {
      _initFuture = null;
      throw e;
    });
    return _initFuture!;
  }

  static Future<void> _initInternal() async {
    WidgetsFlutterBinding.ensureInitialized();
    final sw = Stopwatch()..start();
    debugPrint('[AppServices] init: start');

    // ── 1. Database ──────────────────────────────────────────────────────────
    isar = IsarService.instance;
    final dbStart = sw.elapsedMilliseconds;
    try {
      await isar.init();
      debugPrint('[AppServices] init: Isar initialised in ${sw.elapsedMilliseconds - dbStart}ms (total ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      debugPrint('[AppServices] init: Isar init failed (non-fatal): $e');
    }

    // ── 2. Shared BERT tokenizers ────────────────────────────────────────────
    final vocabStart = sw.elapsedMilliseconds;
    try {
      final vocabRaw = await rootBundle.loadString(_vocabAsset);
      final vocab    = VocabLoader.fromString(vocabRaw);
      _mbTokenizer = WordPieceTokenizer(
        vocab:  vocab,
        config: TokenizerConfig(maxLength: 128, normalizeText: true),
      );
      _deTokenizer = WordPieceTokenizer(
        vocab:  vocab,
        config: TokenizerConfig(maxLength: 512, normalizeText: true),
      );
      debugPrint('[AppServices] init: Tokenizers ready in ${sw.elapsedMilliseconds - vocabStart}ms (total ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      debugPrint('[AppServices] init: Tokenizer init failed (non-fatal): $e');
    }

    // ── 3. Stateless services ────────────────────────────────────────────────
    confidence            = const ConfidenceManager();
    quickTrack            = QuickTrackService();
    eodCorrelation        = const EodCorrelationEngine();
    templateMoodResponse  = const TemplateMoodResponseService();
    templateInsight       = const TemplateSummaryInsightService();
    healthFeatureComputer = const HealthFeatureComputer();

    // ── 4. External services ─────────────────────────────────────────────────
    final externalStart = sw.elapsedMilliseconds;
    weaviate = WeaviateService(host: _weaviateHost, apiKey: _weaviateApiKey);
    gemini   = GeminiService(apiKey: _geminiApiKey);
    debugPrint('[AppServices] init: External services init in ${sw.elapsedMilliseconds - externalStart}ms');

    // ── 5. ONNX model services (load in parallel) ────────────────────────────
    final modelsStart = sw.elapsedMilliseconds;
    mobileBert             = MobileBertService();
    disEmbed               = DisEmbedService();
    fitnessMlp             = FitnessMlpService();
    healthSummaryModel     = HealthSummaryModelService();
    healthSuggestionsModel = HealthSuggestionsModelService();

    // Load disease knowledge base (lightweight JSON, ~40KB)
    diseaseKb    = DiseaseKnowledgeBase();
    sentenceBank = SentenceBankService();

    try {
      await Future.wait([
        mobileBert.load(_mobileBertAsset),
        disEmbed.load(_disEmbedAsset),
        fitnessMlp.load(_fitnessAsset),
        diseaseKb.load(),
        sentenceBank.load(),
      ]);
      debugPrint('[AppServices] init: ONNX models + KB loaded in ${sw.elapsedMilliseconds - modelsStart}ms');
    } catch (e) {
      debugPrint('[AppServices] init: Model/KB load failed: $e');
    }

    // Load in-house models if trained ONNX files are present
    try {
      await Future.wait([
        healthSummaryModel.load(_healthSummaryAsset),
        healthSuggestionsModel.load(_healthSuggestionsAsset),
      ]);
      debugPrint('[AppServices] init: In-house models loaded');
    } catch (e) {
      // Non-fatal: models fall back to template logic when ONNX files are absent
      debugPrint('[AppServices] init: In-house models not available (using templates): $e');
    }

    // ── 6. Model lifecycle service ───────────────────────────────────────────
    ModelLifecycleService.instance.init(
      mobileBert:        mobileBert,
      disEmbed:          disEmbed,
      fitnessMlp:        fitnessMlp,
      healthSummary:     healthSummaryModel,
      healthSuggestions: healthSuggestionsModel,
    );
    WidgetsBinding.instance.addObserver(ModelLifecycleService.instance);

    // ── 7. Startup sync check ───────────────────────────────────────────────
    final syncStart = sw.elapsedMilliseconds;
    try {
      await _runStartupSyncCheck();
      debugPrint('[AppServices] init: Startup sync check in ${sw.elapsedMilliseconds - syncStart}ms');
    } catch (e) {
      debugPrint('[AppServices] startup sync check failed (non-fatal): $e');
    }

    // ── 7b. Chat session repair ─────────────────────────────────────────────
    try {
      await ChatSessionService(quickTrack, templateInsight).repairIncompleteSessions();
    } catch (e) {
      debugPrint('[AppServices] chat session repair failed (non-fatal): $e');
    }

    // ── 8. Pipeline services ─────────────────────────────────────────────────
    moodPipeline = MoodPipelineService(
      mobileBert:      mobileBert,
      gemini:          gemini,
      confidence:      confidence,
      quickTrack:      quickTrack,
      templateMood:    templateMoodResponse,
      templateInsight: templateInsight,
      tokenize:        _mobileBertTokenize,
    );

    symptomPipeline = SymptomPipelineService(
      disEmbed:        disEmbed,
      gemini:          gemini,
      weaviate:        weaviate,
      confidence:      confidence,
      quickTrack:      quickTrack,
      diseaseKb:       diseaseKb,
      templateInsight: templateInsight,
      tokenize:        _disEmbedTokenize,
    );

    fitnessPipeline = FitnessPipelineService(
      mlp:             fitnessMlp,
      confidence:      confidence,
      fetchHealthData: _fetchHealthData,
    );

    eodPipeline = EodPipelineService(
      gemini:              gemini,
      weaviate:            weaviate,
      quickTrack:          quickTrack,
      fitness:             fitnessPipeline,
      disEmbed:            disEmbed,
      correlationEngine:   eodCorrelation,
      templateInsight:     templateInsight,
      featureComputer:     healthFeatureComputer,
      summaryModel:        healthSummaryModel,
      sentenceBank:        sentenceBank,
      tokenize:            _disEmbedTokenize,
    );

    debugPrint('[AppServices] init: completed in ${sw.elapsedMilliseconds}ms');
  }

  // ── Tokenizer functions ───────────────────────────────────────────────────────

  /// MobileBERT tokenizer — enforces maxLen slice
  static Map<String, List<int>> _mobileBertTokenize(String text, int maxLen) {
    final output = _mbTokenizer.encode(text);
    return {
      'input_ids':      output.inputIds.take(maxLen).toList(),
      'attention_mask': output.attentionMask.take(maxLen).toList(),
    };
  }

  /// DisEmbed tokenizer — enforces maxLen slice
  static Map<String, List<int>> _disEmbedTokenize(String text, int maxLen) {
    final output = _deTokenizer.encode(text);
    return {
      'input_ids':      output.inputIds.take(maxLen).toList(),
      'attention_mask': output.attentionMask.take(maxLen).toList(),
    };
  }

  // ── Public tokenizer accessors ────────────────────────────────────────────────

  /// Public accessor for MobileBERT tokenizer (maxLen=128).
  static Map<String, List<int>> mobileBertTokenize(String text, int maxLen) =>
      _mobileBertTokenize(text, maxLen);

  /// Public accessor for DisEmbed tokenizer (maxLen=512).
  static Map<String, List<int>> disEmbedTokenize(String text, int maxLen) =>
      _disEmbedTokenize(text, maxLen);

  // ── Startup sync check ───────────────────────────────────────────────────────
  static Future<void> _runStartupSyncCheck() async {}

  // ── Health data fetcher ───────────────────────────────────────────────────────

  static Future<RawHealthData?> _fetchHealthData() async {
    try {
      final snapshot = await HealthService().fetchSnapshot();
      // TODO(health): replace placeholder defaults with real profile values
      return RawHealthData(
        age:              0.0,
        weightKg:         snapshot.weight ?? 70.0,
        heightCm:         0.0,
        restingHeartRate: snapshot.heartRate ?? 70.0,
        sleepHours:       snapshot.sleepHours ?? 7.0,
        smokes:           false,
        nutritionQuality: 5.0,
        activityIndex:    snapshot.workoutSummary != null ? 6.0 : 3.0,
        isMale:           true,
        timestamp:        snapshot.capturedAt,
      );
    } catch (e) {
      debugPrint('[AppServices] HealthService fetch failed: $e');
      return null;
    }
  }

  // ── Runtime helpers ───────────────────────────────────────────────────────────

  /// Returns true if the device has any active network connection.
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Refresh fitness score from latest health data. Safe to call from any context.
  static Future<void> refreshFitnessScore() async {
    await fitnessPipeline.score();
  }

  // ── Teardown ─────────────────────────────────────────────────────────────────

  static Future<void> dispose() async {
    mobileBert.dispose();
    disEmbed.dispose();
    fitnessMlp.dispose();
    healthSummaryModel.dispose();
    healthSuggestionsModel.dispose();
    await isar.close();
  }
}
