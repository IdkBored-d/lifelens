import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
import 'services/mood_pipeline_service.dart';
import 'services/symptom_pipeline_service.dart';
import 'services/fitness_pipeline_service.dart';
import 'services/eod_pipeline_service.dart';

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
  static late final MoodPipelineService    moodPipeline;
  static late final SymptomPipelineService symptomPipeline;
  static late final FitnessPipelineService fitnessPipeline;
  static late final EodPipelineService     eodPipeline;

  // Two tokenizer instances — same vocab, different maxLength
  static late final WordPieceTokenizer _mbTokenizer; // maxLen=128 for MobileBERT
  static late final WordPieceTokenizer _deTokenizer; // maxLen=512 for DisEmbed

  // ── Configuration ────────────────────────────────────────────────────────────
  // TODO: Move to environment variables / secrets manager before production.

  static const String _weaviateHost   = 'https://your-cluster.weaviate.network';
  static const String _weaviateApiKey = 'YOUR_WEAVIATE_API_KEY';
  static const String _geminiApiKey   = 'YOUR_GEMINI_API_KEY';

  // Asset paths
  static const String _mobileBertAsset = 'assets/models/mobile_bert_emotion.onnx';
  //static const String _disEmbedAsset   = 'assets/models/disembed_fp16.onnx';
  static const String _disEmbedAsset   = 'assets/models/for MVP/disembed_fp32.onnx';
  //static const String _fitnessAsset    = 'assets/models/fitness_model.onnx';
  static const String _fitnessAsset    = 'assets/models/for MVP/fitness_model_v9.onnx';
  static const String _vocabAsset      = 'assets/models/vocab.txt';

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Initialise all services. Call once in main() before runApp().
  ///
  /// [gemmaPath] is the on-device path to the Gemma 2 2B IT model file.
  /// Pass an empty string if not yet downloaded — the app will run without
  /// on-device LLM and escalate to Gemini when online.
  static Future<void> init({required String gemmaPath}) async {
    WidgetsFlutterBinding.ensureInitialized();

    // ── 1. Database ──────────────────────────────────────────────────────────
    isar = IsarService.instance;
    await isar.init();

    // ── 2. Shared BERT tokenizers ────────────────────────────────────────────
    // Same vocab file works for both models.
    // Two instances needed because maxLength is set at construction time.
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

    // ── 3. Stateless services ────────────────────────────────────────────────
    confidence = const ConfidenceManager();
    quickTrack = QuickTrackService();

    // ── 4. External services ─────────────────────────────────────────────────
    weaviate = WeaviateService(host: _weaviateHost, apiKey: _weaviateApiKey);
    gemini   = GeminiService(apiKey: _geminiApiKey);

    // ── 5. ONNX model services (load in parallel) ────────────────────────────
    mobileBert = MobileBertService();
    disEmbed   = DisEmbedService();
    fitnessMlp = FitnessMlpService();

    await Future.wait([
      mobileBert.load(_mobileBertAsset),
      disEmbed.load(_disEmbedAsset),
      fitnessMlp.load(_fitnessAsset),
    ]);

    // ── 6. Gemma 2 2B IT (skip gracefully if not yet downloaded) ────────────
    gemma = GemmaService();
    if (gemmaPath.isNotEmpty) {
      await gemma.load(gemmaPath);
    }

    // ── 7. Startup sync check ────────────────────────────────────────────────
    await _runStartupSyncCheck();

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
      quickTrack: quickTrack,
      fitness:    fitnessPipeline,
      disEmbed:   disEmbed,
      tokenize:   _disEmbedTokenize,
    );
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

    final syncResult = await quickTrack.checkAndRepairSync(
      lastIsarMoodDate:    lastIsarMood,
      lastIsarSymptomDate: lastIsarSymptom,
    );

    if (syncResult.moodNeedsRepair && syncResult.missingMoodDate != null) {
      final entries =
          await isar.getMoodEntriesForDate(syncResult.missingMoodDate!);
      if (entries.isNotEmpty) {
        await quickTrack
            .appendMoodEntry(MoodLogEntryAdapter.fromIsarEntry(entries.last));
      }
    }

    if (syncResult.symptomNeedsRepair && syncResult.missingSymptomDate != null) {
      final allSymptoms = await isar.getAllSymptomEntries();
      final missing = allSymptoms
          .where((e) => e.date == syncResult.missingSymptomDate)
          .toList();
      for (final entry in missing) {
        await quickTrack
            .appendSymptomEntry(SymptomLogEntryAdapter.fromIsarEntry(entry));
      }
    }
  }

  // ── Health data fetcher ───────────────────────────────────────────────────────

  static Future<RawHealthData?> _fetchHealthData() async {
    try {
      // TODO: Implement native side returning a Map of these values
      final Map<dynamic, dynamic>? raw = await _healthChannel.invokeMethod('getDailyHealthMetrics');
      
      if (raw == null) return null;

      // Temporary stub return until native parsing is mapped
      return null; 
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

  static bool get isGemmaLoaded => gemma.isLoaded;

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