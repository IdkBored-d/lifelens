import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_wordpiece/dart_wordpiece.dart';

import 'database/isar_service.dart';
import 'database/mood_entry.dart';
import 'database/symptom_entry.dart';
import 'services/confidence_manager.dart';
import 'services/quick_track_service.dart';
import 'services/weaviate_service.dart';
import 'services/mobilebert_service.dart';
import 'services/disembed_service.dart';
import 'services/fitness_mlp_service.dart';
import 'services/gemma_service.dart';
import 'services/gemini_service.dart';
import 'services/health_service.dart';
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

  // ── Singletons ──────────────────────────────────────────────────────────────
  static late final IsarService            isar;
  static late final ConfidenceManager      confidence;
  static late final QuickTrackService      quickTrack;
  static late final WeaviateService        weaviate;
  static late final MobileBertService      mobileBert;
  static late final DisEmbedService        disEmbed;
  static late final FitnessMlpService      fitnessMlp;
  static late final GemmaService           gemma;
  static late final GeminiService          gemini;
  static ModelLifecycleService get models  => ModelLifecycleService.instance;
  static late final MoodPipelineService    moodPipeline;
  static late final SymptomPipelineService symptomPipeline;
  static late final FitnessPipelineService fitnessPipeline;
  static late final EodPipelineService     eodPipeline;

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
  //   The client should fetch a short-lived token from the backend at login
  //   rather than bundling API keys in the binary.

  static const String _weaviateHost   = String.fromEnvironment('WEAVIATE_HOST',    defaultValue: '');
  static const String _weaviateApiKey = String.fromEnvironment('WEAVIATE_API_KEY', defaultValue: '');
  static const String _geminiApiKey   = String.fromEnvironment('GEMINI_API_KEY',   defaultValue: '');

  // Asset paths
  static const String _mobileBertAsset = 'assets/models/mobile_bert_emotion.onnx';
  // TODO(ship): Switch back to FP16 model when shipping — FP32 is for MVP only.
  //static const String _disEmbedAsset = 'assets/models/disembed_fp16.onnx';
  static const String _disEmbedAsset   = 'assets/models/for MVP/disembed_fp32.onnx';
  // TODO(ship): Retrain/re-export and swap in a versioned production model before shipping.
  //static const String _fitnessAsset = 'assets/models/fitness_model.onnx';
  static const String _fitnessAsset    = 'assets/models/for MVP/fitness_model_v9.onnx';
  static const String _vocabAsset      = 'assets/models/vocab.txt';

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Returns the in-flight or completed init future. Safe to call from any
  /// screen — awaiting it guarantees all services are ready before use.
  /// Starts a fresh init if [init] was never called or previously failed.
  static Future<void> ensureInitialized({String gemmaPath = ''}) =>
      _initFuture ?? init(gemmaPath: gemmaPath);

  /// Idempotent init — returns the same [Future] on every concurrent call.
  /// Clears [_initFuture] on failure so the caller can retry by calling [init].
  ///
  /// NOTE: [late final] fields cannot be reassigned, so retrying after a
  /// partial init failure will throw "already assigned". Treat init failures
  /// as fatal and guide the user to restart the app.
  static Future<void> init({required String gemmaPath}) {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initInternal(gemmaPath: gemmaPath).catchError((Object e) {
      _initFuture = null;
      throw e;
    });
    return _initFuture!;
  }

  static Future<void> _initInternal({required String gemmaPath}) async {
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
    final statelessStart = sw.elapsedMilliseconds;
    confidence = const ConfidenceManager();
    quickTrack = QuickTrackService();
    debugPrint('[AppServices] init: Stateless services in ${sw.elapsedMilliseconds - statelessStart}ms');

    // ── 4. External services ─────────────────────────────────────────────────
    final externalStart = sw.elapsedMilliseconds;
    weaviate = WeaviateService(host: _weaviateHost, apiKey: _weaviateApiKey);
    gemini   = GeminiService(apiKey: _geminiApiKey);
    debugPrint('[AppServices] init: External services init in ${sw.elapsedMilliseconds - externalStart}ms');

    // ── 5. ONNX model services (load in parallel) ────────────────────────────
    final modelsStart = sw.elapsedMilliseconds;
    mobileBert = MobileBertService();
    disEmbed   = DisEmbedService();
    fitnessMlp = FitnessMlpService();

    try {
      await Future.wait([
        mobileBert.load(_mobileBertAsset),
        disEmbed.load(_disEmbedAsset),
        fitnessMlp.load(_fitnessAsset),
      ]);
      debugPrint('[AppServices] init: ONNX models loaded in ${sw.elapsedMilliseconds - modelsStart}ms');
    } catch (e) {
      debugPrint('[AppServices] init: ONNX model load failed: $e');
    }

    // ── 6. Gemma 2 2B IT (skip gracefully if not yet downloaded) ────────────
    final gemmaStart = sw.elapsedMilliseconds;
    gemma = GemmaService();
    if (gemmaPath.isNotEmpty) {
      try {
        await gemma.load(gemmaPath);
        debugPrint('[AppServices] init: Gemma loaded in ${sw.elapsedMilliseconds - gemmaStart}ms');
      } catch (e) {
        debugPrint('[AppServices] init: Gemma load failed: $e');
      }
    } else {
      debugPrint('[AppServices] init: Gemma skipped (no path provided)');
    }

    // ── 6b. Model lifecycle service ─────────────────────────────────────────
    ModelLifecycleService.instance.init(
      mobileBert: mobileBert,
      disEmbed:   disEmbed,
      fitnessMlp: fitnessMlp,
      gemma:      gemma,
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
    // Mark any sessions that had no endTime (app killed mid-chat) as interrupted.
    try {
      await ChatSessionService(quickTrack).repairIncompleteSessions();
    } catch (e) {
      debugPrint('[AppServices] chat session repair failed (non-fatal): $e');
    }

    // ── 8. Pipeline services ─────────────────────────────────────────────────
    moodPipeline = MoodPipelineService(
      mobileBert: mobileBert,
      gemma:      gemma,
      gemini:     gemini,
      confidence: confidence,
      quickTrack: quickTrack,
      tokenize:   _mobileBertTokenize,
    );

    symptomPipeline = SymptomPipelineService(
      disEmbed:   disEmbed,
      gemma:      gemma,
      gemini:     gemini,
      weaviate:   weaviate,
      confidence: confidence,
      quickTrack: quickTrack,
      tokenize:   _disEmbedTokenize,
    );

    fitnessPipeline = FitnessPipelineService(
      mlp:             fitnessMlp,
      confidence:      confidence,
      fetchHealthData: _fetchHealthData,
    );

    eodPipeline = EodPipelineService(
      gemma:      gemma,
      gemini:     gemini,
      weaviate:   weaviate,
      quickTrack:  quickTrack,
      fitness:     fitnessPipeline,
      disEmbed:    disEmbed,
      tokenize:    _disEmbedTokenize,
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
  // These expose the private tokenizer functions so that dev_test_screen and
  // any other callers outside this class can pass them as callbacks.

  /// Public accessor for MobileBERT tokenizer (maxLen=128).
  static Map<String, List<int>> mobileBertTokenize(String text, int maxLen) =>
      _mobileBertTokenize(text, maxLen);

  /// Public accessor for DisEmbed tokenizer (maxLen=512).
  static Map<String, List<int>> disEmbedTokenize(String text, int maxLen) =>
      _disEmbedTokenize(text, maxLen);

  // ── Startup sync check ───────────────────────────────────────────────────────

  static Future<void> _runStartupSyncCheck() async {
    final lastIsarMood    = await isar.lastMoodDate();
    final lastIsarSymptom = await isar.lastSymptomDate();

    // Fetch per-date counts so the check can catch same-day duplicate entries
    // that would be invisible to the old date-string-only comparison.
    final moodCountForDate    = lastIsarMood    != null ? await isar.getMoodCountForDate(lastIsarMood)       : 0;
    final symptomCountForDate = lastIsarSymptom != null ? await isar.getSymptomCountForDate(lastIsarSymptom) : 0;

    final syncResult = await quickTrack.checkAndRepairSync(
      lastIsarMoodDate:            lastIsarMood,
      lastIsarMoodCountForDate:    moodCountForDate,
      lastIsarSymptomDate:         lastIsarSymptom,
      lastIsarSymptomCountForDate: symptomCountForDate,
    );

    if (syncResult.moodNeedsRepair && syncResult.missingMoodDate != null) {
      // Fetch all ISAR entries for the date, skip the ones already in quick-track.
      final entries = await isar.getMoodEntriesForDate(syncResult.missingMoodDate!);
      final toAppend = entries.skip(syncResult.quickMoodCountForDate).toList();
      for (final entry in toAppend) {
        await quickTrack.appendMoodEntry(MoodLogEntryAdapter.fromIsarEntry(entry));
      }
    }

    if (syncResult.symptomNeedsRepair && syncResult.missingSymptomDate != null) {
      final allForDate = await isar.getSymptomEntriesForDate(syncResult.missingSymptomDate!);
      final toAppend = allForDate.skip(syncResult.quickSymptomCountForDate).toList();
      for (final entry in toAppend) {
        await quickTrack.appendSymptomEntry(SymptomLogEntryAdapter.fromIsarEntry(entry));
      }
    }
  }

  // ── Health data fetcher ───────────────────────────────────────────────────────

  static Future<RawHealthData?> _fetchHealthData() async {
    try {
      final snapshot = await HealthService().fetchSnapshot();
      // TODO(health): replace placeholder defaults with real profile values
      // once onboarding collects height (CLAUDE.md #7) and profile is wired (#10).
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
      // No permissions, Health Connect unavailable, or no data — skip silently.
      debugPrint('[AppServices] HealthService fetch failed: $e');
      return null;
    }
  }
  // ── Runtime helpers ───────────────────────────────────────────────────────────

  /// Load Gemma after OTA download completes — no app restart needed.
  static Future<void> loadGemmaModel(String path) async {
    if (gemma.isLoaded) return;
    await gemma.load(path);
  }

  static bool get isGemmaLoaded => gemma.isLoaded;

  /// Refresh fitness score from latest health data. Safe to call from any context.
  /// Returns null silently if health data is unavailable (no permissions, no data).
  static Future<void> refreshFitnessScore() async {
    await fitnessPipeline.score();
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

// ── ISAR → QuickTrack adapters ─────────────────────────────────────────────────

class MoodLogEntryAdapter {
  static MoodLogEntry fromIsarEntry(MoodEntry e) => MoodLogEntry(
        date:          e.date,
        log:           e.condensedLog,
        predictedMood: e.resolvedMood,
        fitnessScore:  e.fitnessScoreSnapshot,
      );
}

class SymptomLogEntryAdapter {
  static SymptomLogEntry fromIsarEntry(SymptomEntry e) => SymptomLogEntry(
        date:             e.date,
        symptoms:         e.symptomList,
        predictedAilment: e.predictedAilment,
        status:           e.status,
      );
}