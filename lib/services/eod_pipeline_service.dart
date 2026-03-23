import '../models/fitness_result.dart';
import 'quick_track_service.dart';
import 'fitness_pipeline_service.dart';
import 'gemma_service.dart';
import 'gemini_service.dart';
import 'weaviate_service.dart';

// TODO: Import ISAR database service once schema is defined
// import '../database/isar_service.dart';

/// End-of-day data condensation and correlation analysis.
///
/// Flow:
///   1. Condense today's per-entry mood logs → single per-day entry in ISAR
///   2. Check quick-tracking mood file against ISAR (consistency check)
///   3. Check quick-tracking symptom file against ISAR
///   4. Compute fitness trend
///   5. Run Gemma2b (or Gemini if online) correlation analysis
///   6. Store EOD summary in ISAR
///   7. Update quick-tracking files if inconsistencies were found
class EodPipelineService {
  final GemmaService           _gemma;
  final GeminiService          _gemini;
  final WeaviateService        _weaviate;
  final QuickTrackService      _quickTrack;
  final FitnessPipelineService _fitness;

  EodPipelineService({
    required GemmaService           gemma,
    required GeminiService          gemini,
    required WeaviateService        weaviate,
    required QuickTrackService      quickTrack,
    required FitnessPipelineService fitness,
  })  : _gemma      = gemma,
        _gemini     = gemini,
        _weaviate   = weaviate,
        _quickTrack = quickTrack,
        _fitness    = fitness;

  // ── Main entry point ────────────────────────────────────────────────────────

  /// Run the full EOD pipeline.
  ///
  /// Should be triggered at a user-defined time (default: 11 PM) or
  /// when the user opens the app after midnight.
  Future<EodResult> runEndOfDay({required bool isOnline}) async {
    final today   = DateTime.now();
    final dateStr = today.toIso8601String().split('T').first;

    // ── STEP 1: Read today's data from quick-tracking files ───────────────
    final moodEntries    = await _quickTrack.readMoodLog();
    final symptomEntries = await _quickTrack.readSymptomLog();

    final todayMood = moodEntries
        .where((e) => e.date == dateStr)
        .toList();
    final activeSymptoms = symptomEntries
        .where((e) => e.status == 'active' || e.status == 'monitoring')
        .toList();

    // ── STEP 2: Consistency check (quick-track vs ISAR) ───────────────────
    // TODO: Replace with actual ISAR queries once database schema is defined
    // final lastIsarMood    = await IsarService.instance.lastMoodDate();
    // final lastIsarSymptom = await IsarService.instance.lastSymptomDate();
    // final syncResult = await _quickTrack.checkAndRepairSync(
    //   lastIsarMoodDate:    lastIsarMood,
    //   lastIsarSymptomDate: lastIsarSymptom,
    // );
    // if (!syncResult.isClean) { ... repair logic ... }

    // ── STEP 3: Fitness data ───────────────────────────────────────────────
    // TODO: Replace with actual ISAR queries once schema is defined
    // final last7FitnessScores = await IsarService.instance.lastNFitnessScores(7);
    // Placeholder values until ISAR is set up:
    final todayFitnessScore = todayMood.isNotEmpty
        ? todayMood.last.fitnessScore : 0.0;
    final weekAvg   = todayFitnessScore; // TODO: compute from ISAR history
    final trend     = 'stable';          // TODO: compute from ISAR history

    // ── STEP 4: Build context strings ─────────────────────────────────────
    final todayMoodStr = todayMood.isNotEmpty
        ? todayMood.map((e) => '${e.date} | ${e.predictedMood} | ${e.log}').join('\n')
        : 'No mood entries today.';

    final activeSymptomsStr = activeSymptoms.isNotEmpty
        ? activeSymptoms
            .map((e) => '${e.date} | ${e.predictedAilment} [${e.status}] | ${e.symptoms.join(", ")}')
            .join('\n')
        : 'No active symptoms.';

    final last7MoodStr = moodEntries
        .take(7)
        .map((e) => '${e.date} | ${e.predictedMood} | ${e.log}')
        .join('\n');

    // ── STEP 5: Correlation analysis ──────────────────────────────────────
    String summaryText;
    EodCorrelation? correlation;

    if (isOnline) {
      // Gemini with RAG grounding
      final ragResults = await _weaviate.queryByVector(
        List.filled(384, 0.0), // TODO: embed active symptoms for better RAG query
        topK: 3,
      );
      final ragContext = _weaviate.buildRagContext(ragResults);

      final geminiRaw = await _gemini.generateDeepEodAnalysis(
        todayMoodEntry:       todayMoodStr,
        activeSymptomEntries: activeSymptomsStr,
        todayFitnessScore:    todayFitnessScore,
        weekAvgFitnessScore:  weekAvg,
        fitnessTrend:         trend,
        last7MoodEntries:     last7MoodStr,
        ragContext:           ragContext,
      );
      summaryText = _extractUserFacingSummary(geminiRaw);
      correlation = _extractCorrelation(geminiRaw);
    } else {
      // Gemma2b offline — no RAG
      final gemmaRaw = await _gemma.generateEodSummary(
        todayMoodEntry:       todayMoodStr,
        activeSymptomEntries: activeSymptomsStr,
        todayFitnessScore:    todayFitnessScore,
        weekAvgFitnessScore:  weekAvg,
        fitnessTrend:         trend,
        last7MoodEntries:     last7MoodStr,
      );
      summaryText = _extractUserFacingSummary(gemmaRaw);
      correlation = _extractCorrelation(gemmaRaw);
    }

    // ── STEP 6: WRITE EOD SUMMARY TO ISAR ─────────────────────────────────
    // TODO: Replace with actual ISAR write once database schema is defined
    // await IsarService.instance.writeEodEntry(IsarEodEntry(
    //   date:              dateStr,
    //   summaryText:       summaryText,
    //   correlationJson:   correlation?.toJson(),
    //   fitnessScore:      todayFitnessScore,
    //   moodEntryCount:    todayMood.length,
    //   timestamp:         today,
    // ));

    return EodResult(
      date:        dateStr,
      summary:     summaryText,
      correlation: correlation,
      fitnessScore: todayFitnessScore,
      flagged:     correlation?.flag ?? false,
      flagReason:  correlation?.flagReason,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Extract the user-facing summary text from the model's response.
  /// The model is instructed to put correlation JSON at the end —
  /// everything before the JSON block is the user-facing text.
  String _extractUserFacingSummary(String raw) {
    final jsonStart = raw.lastIndexOf('{');
    if (jsonStart > 0) {
      return raw.substring(0, jsonStart).trim();
    }
    return raw.trim();
  }

  EodCorrelation? _extractCorrelation(String raw) {
    try {
      final jsonStart = raw.lastIndexOf('{');
      final jsonEnd   = raw.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final jsonStr = raw.substring(jsonStart, jsonEnd + 1);
      // Simple manual parse to avoid dart:convert dependency issues
      final flag      = jsonStr.contains('"flag": true');
      final reasonMatch = RegExp(r'"flag_reason":\s*"([^"]*)"').firstMatch(jsonStr);
      final summaryMatch = RegExp(r'"correlation_summary":\s*"([^"]*)"').firstMatch(jsonStr);

      return EodCorrelation(
        flag:       flag,
        flagReason: reasonMatch?.group(1) ?? '',
        summary:    summaryMatch?.group(1) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

// ── Result types ──────────────────────────────────────────────────────────────

class EodResult {
  final String         date;
  final String         summary;      // user-facing text
  final EodCorrelation? correlation;
  final double         fitnessScore;
  final bool           flagged;      // true = something warrants attention
  final String?        flagReason;

  const EodResult({
    required this.date,
    required this.summary,
    required this.fitnessScore,
    required this.flagged,
    this.correlation,
    this.flagReason,
  });
}

class EodCorrelation {
  final bool   flag;
  final String flagReason;
  final String summary;

  const EodCorrelation({
    required this.flag,
    required this.flagReason,
    required this.summary,
  });
}
