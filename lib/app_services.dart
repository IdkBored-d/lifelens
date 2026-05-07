import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_wordpiece/dart_wordpiece.dart';

import 'database/isar_service.dart';
import 'services/confidence_manager.dart';
import 'services/weaviate_service.dart';
import 'services/mobilebert_service.dart';
import 'services/disembed_service.dart';
import 'services/fitness_mlp_service.dart';
import 'services/minigen_service.dart';
import 'services/minigen_chat.dart';
import 'services/minigen_downloader.dart';
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

  static const MethodChannel _healthChannel = MethodChannel('lifelens/health');

  // ── Singletons ──────────────────────────────────────────────────────────────
  static late final IsarService isar;
  static late final ConfidenceManager confidence;
  static late final WeaviateService weaviate;
  static late final MobileBertService mobileBert;
  static late final DisEmbedService disEmbed;
  static late final FitnessMlpService fitnessMlp;
  static late final MiniGenService miniGen;
  static late final MiniGenChat miniGenChat;
  static late final GeminiService gemini;
  static late final MoodPipelineService moodPipeline;
  static late final SymptomPipelineService symptomPipeline;
  static late final FitnessPipelineService fitnessPipeline;
  static late final EodPipelineService eodPipeline;

  // Two tokenizer instances — same vocab, different maxLength
  static late final WordPieceTokenizer _mbTokenizer; // maxLen=128 for MobileBERT
  static late final WordPieceTokenizer _deTokenizer; // maxLen=512 for DisEmbed

  // ── Configuration ────────────────────────────────────────────────────────────
  static const String _weaviateHost   = 'https://your-cluster.weaviate.network';
  static const String _weaviateApiKey = 'YOUR_WEAVIATE_API_KEY';
  static const String _geminiApiKey   = 'YOUR_GEMINI_API_KEY';

  // Asset paths
  static const String _mobileBertAsset = 'assets/models/mobile_bert_emotion.onnx';
  static const String _disEmbedAsset   = 'assets/models/disembed_fp16.onnx';
  static const String _fitnessAsset    = 'assets/models/for MVP/fitness_model_v9.onnx';
  static const String _vocabAsset      = 'assets/models/vocab.txt';


  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Initialise all services. Call once before runApp().
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final sw = Stopwatch()..start();
    debugPrint('[AppServices] init: start');

    // ── 1. Database ──────────────────────────────────────────────────────────
    isar = IsarService.instance;
    final dbStart = sw.elapsedMilliseconds;
    try {
      await isar.init();
      debugPrint('[AppServices] init: Isar initialised in ${sw.elapsedMilliseconds - dbStart}ms');
    } catch (e) {
      debugPrint('[AppServices] init: Isar init failed (non-fatal): $e');
    }

    // ── 2. Shared BERT tokenizers ────────────────────────────────────────────
    final vocabRaw = await rootBundle.loadString(_vocabAsset);
    final vocab    = VocabLoader.fromString(vocabRaw);
    _mbTokenizer   = WordPieceTokenizer(vocab: vocab, config: TokenizerConfig(maxLength: 128, normalizeText: true));
    _deTokenizer   = WordPieceTokenizer(vocab: vocab, config: TokenizerConfig(maxLength: 512, normalizeText: true));

    // ── 3. Stateless services ────────────────────────────────────────────────
    confidence = const ConfidenceManager();

    // ── 4. External services ─────────────────────────────────────────────────
    weaviate = WeaviateService(host: _weaviateHost, apiKey: _weaviateApiKey);
    gemini   = GeminiService(apiKey: _geminiApiKey);

    // ── 5. Model services (load in parallel) ───────────────────────────────
    final modelsStart = sw.elapsedMilliseconds;
    mobileBert = MobileBertService();
    disEmbed   = DisEmbedService();
    fitnessMlp = FitnessMlpService();
    miniGen    = MiniGenService();
    miniGenChat = MiniGenChat(miniGen);

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
      loadModel('FitnessMLP', () => fitnessMlp.load(_fitnessAsset)),
    ]);

    // MiniGen requires an OTA download on first launch (~96 MB); fire it in the
    // background so the 30-second startup timeout in app_init.dart doesn't kill it.
    unawaited(loadModel('MiniGen', () async {
      final path = await MiniGenDownloader.ensureModel();
      await miniGen.load(path);
    }));

    debugPrint('[AppServices] init: models ready $loadedCount/4 in ${sw.elapsedMilliseconds - modelsStart}ms');

    // ── 6. Lifecycle + startup repair ───────────────────────────────────────
    ModelLifecycleService.instance.init(
      mobileBert: mobileBert,
      disEmbed:   disEmbed,
      fitnessMlp: fitnessMlp,
      miniGen:    miniGen,
      mobileBertAssetPath: _mobileBertAsset,
      disEmbedAssetPath: _disEmbedAsset,
    );
    WidgetsBinding.instance.addObserver(ModelLifecycleService.instance);

    final repairStart = sw.elapsedMilliseconds;
    try {
      final chatSessions = ChatSessionService();
      await chatSessions.repairIncompleteSessions();
      debugPrint('[AppServices] init: Startup repair in ${sw.elapsedMilliseconds - repairStart}ms');
    } catch (e) {
      debugPrint('[AppServices] startup repair failed (non-fatal): $e');
    }

    // ── 7. Pipeline services ─────────────────────────────────────────────────
    moodPipeline = MoodPipelineService(
      mobileBert: mobileBert,
      gemini:     gemini,
      confidence: confidence,
      tokenize:   _mobileBertTokenize,
    );

    symptomPipeline = SymptomPipelineService(
      disEmbed:   disEmbed,
      gemini:     gemini,
      weaviate:   weaviate,
      confidence: confidence,
      tokenize:   _disEmbedTokenize,
    );

    fitnessPipeline = FitnessPipelineService(
      mlp:             fitnessMlp,
      confidence:      confidence,
      fetchHealthData: _fetchHealthData,
    );

    eodPipeline = EodPipelineService(
      gemini:   gemini,
      weaviate: weaviate,
      fitness:  fitnessPipeline,
      disEmbed: disEmbed,
      tokenize: _disEmbedTokenize,
    );

    debugPrint('[AppServices] init: completed in ${sw.elapsedMilliseconds}ms');
  }

  // ── Tokenizer functions ───────────────────────────────────────────────────────

  static Map<String, List<int>> _mobileBertTokenize(String text, int maxLen) {
    final output = _mbTokenizer.encode(text);
    return {
      'input_ids':      output.inputIds.take(maxLen).toList(),
      'attention_mask': output.attentionMask.take(maxLen).toList(),
    };
  }

  static Map<String, List<int>> _disEmbedTokenize(String text, int maxLen) {
    final output = _deTokenizer.encode(text);
    return {
      'input_ids':      output.inputIds.take(maxLen).toList(),
      'attention_mask': output.attentionMask.take(maxLen).toList(),
    };
  }

  static Map<String, List<int>> mobileBertTokenize(String text, int maxLen) =>
      _mobileBertTokenize(text, maxLen);

  static Map<String, List<int>> disEmbedTokenize(String text, int maxLen) =>
      _disEmbedTokenize(text, maxLen);

  // ── Health data fetcher ───────────────────────────────────────────────────────

  static Future<RawHealthData?> _fetchHealthData() async {
    try {
      final Map<dynamic, dynamic>? raw = await _healthChannel.invokeMethod('getDailyHealthMetrics');
      if (raw == null) return null;
      return RawHealthData(
        age:               (raw['age'] as num?)?.toDouble()               ?? 0,
        weightKg:          (raw['weightKg'] as num?)?.toDouble()          ?? 0,
        heightCm:          (raw['heightCm'] as num?)?.toDouble()          ?? 0,
        restingHeartRate:  (raw['restingHeartRate'] as num?)?.toDouble()  ?? 0,
        sleepHours:        (raw['sleepHours'] as num?)?.toDouble()        ?? 0,
        smokes:            raw['smokes'] as bool?                         ?? false,
        nutritionQuality:  (raw['nutritionQuality'] as num?)?.toDouble()  ?? 0,
        activityIndex:     (raw['activityIndex'] as num?)?.toDouble()     ?? 0,
        isMale:            raw['isMale'] as bool?                         ?? false,
        timestamp:         DateTime.tryParse(raw['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Health channel error: $e');
      return null;
    }
  }

  // ── Runtime helpers ───────────────────────────────────────────────────────────

  static bool get isMiniGenLoaded {
    try { return miniGen.isLoaded; } catch (_) { return false; }
  }

  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ── Teardown ─────────────────────────────────────────────────────────────────

  static Future<void> dispose() async {
    mobileBert.dispose();
    disEmbed.dispose();
    fitnessMlp.dispose();
    await miniGen.dispose();
    await isar.close();
  }
}
