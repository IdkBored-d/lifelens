import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/fitness_result.dart';
import 'quick_track_service.dart';
import 'fitness_pipeline_service.dart';
import 'disembed_service.dart';
import 'gemma_service.dart';
import 'gemini_service.dart';
import 'weaviate_service.dart';
import '../database/isar_service.dart';
import '../database/eod_entry.dart';

class EodPipelineService {
  final GemmaService           _gemma;
  final GeminiService          _gemini;
  final WeaviateService        _weaviate;
  final QuickTrackService      _quickTrack;
  final FitnessPipelineService _fitness;
  final DisEmbedService        _disEmbed;
  final Map<String, List<int>> Function(String, int) _tokenize;

  EodPipelineService({
    required GemmaService           gemma,
    required GeminiService          gemini,
    required WeaviateService        weaviate,
    required QuickTrackService      quickTrack,
    required FitnessPipelineService fitness,
    required DisEmbedService        disEmbed,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _gemma      = gemma,
        _gemini     = gemini,
        _weaviate   = weaviate,
        _quickTrack = quickTrack,
        _fitness    = fitness,
        _disEmbed   = disEmbed,
        _tokenize   = tokenize;

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
    // Wired up to your actual IsarService methods
    final lastIsarMood    = await IsarService.instance.lastMoodDate();
    final lastIsarSymptom = await IsarService.instance.lastSymptomDate();
    
    final syncResult = await _quickTrack.checkAndRepairSync(
      lastIsarMoodDate:    lastIsarMood,
      lastIsarSymptomDate: lastIsarSymptom,
    );
    
    if (!syncResult.isClean) {
      // If repairs happened, you could theoretically reload the entries here, 
      // but the baseline sync check is now officially running!
    }

    // ── STEP 3: Fitness data ───────────────────────────────────────────────
    // Wired up to your getLastNDaysFitnessScores method
    final last7FitnessScores = await IsarService.instance.getLastNDaysFitnessScores(7);
    
    final todayFitnessScore = last7FitnessScores.isNotEmpty 
        ? last7FitnessScores.first 
        : (todayMood.isNotEmpty ? todayMood.last.fitnessScore : 0.0);
        
    final weekAvg = last7FitnessScores.isNotEmpty
        ? last7FitnessScores.reduce((a, b) => a + b) / last7FitnessScores.length
        : todayFitnessScore;
        
    // Fix 5: Delegate to FitnessPipelineService.fitnessTrend() — uses a 3-day
    // rolling average vs the prior 4 days with a ±3-point deadband.
    // The old first-vs-last ternary is noise-sensitive and always returns
    // 'upward'/'downward', never 'stable'.
    final trend = _fitness.fitnessTrend(last7FitnessScores);

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
    String summaryText = 'End-of-day summary unavailable.';
    EodCorrelation? correlation;
    var useGemma = !isOnline; // flipped to true if Gemini fails

    if (isOnline) {
      // Build a real query vector from active symptoms, not a zero vector.
      // If there are no active symptoms, skip the RAG call entirely —
      // a zero vector returns arbitrary results which misleads the model.
      String ragContext = '';
      if (activeSymptoms.isNotEmpty) {
        try {
          final symptomQueryText = activeSymptoms
              .map((e) => '${e.predictedAilment}: ${e.symptoms.join(", ")}')
              .join('. ');
          final queryVector = await _disEmbed.embed(symptomQueryText, _tokenize);
          final ragResults  = await _weaviate.queryByVector(queryVector, topK: 3);
          ragContext = _weaviate.buildRagContext(ragResults);
        } catch (e) {
          debugPrint('[EodPipeline] RAG query failed (non-fatal): $e');
        }
      }

      try {
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
      } catch (e) {
        debugPrint('[EodPipeline] Gemini failed, falling back to Gemma: $e');
        useGemma = true;
      }
    }

    if (useGemma) {
      try {
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
      } catch (e) {
        debugPrint('[EodPipeline] Gemma failed, using stub summary: $e');
        summaryText = 'End-of-day summary unavailable.';
      }
    }

    // ── STEP 6: WRITE EOD SUMMARY TO ISAR ─────────────────────────────────
    final eodEntry = EodEntry()
      ..date               = dateStr
      ..summaryText        = summaryText
      ..correlationSummary = correlation?.summary
      ..flagged            = correlation?.flag ?? false
      ..flagReason         = correlation?.flagReason
      ..ragMatch           = correlation?.ragMatch
      ..fitnessScore       = todayFitnessScore
      ..moodEntryCount     = todayMood.length
      ..generatedOnline    = isOnline
      ..timestamp          = today;

    await IsarService.instance.writeEodEntry(eodEntry);

    return EodResult(
      date:         dateStr,
      summary:      summaryText,
      correlation:  correlation,
      fitnessScore: todayFitnessScore,
      flagged:      correlation?.flag ?? false,
      flagReason:   correlation?.flagReason,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Extract the user-facing summary text from the model's response.
  /// The model is instructed to put the correlation JSON at the end —
  /// everything before the JSON block is the user-facing text.
  String _extractUserFacingSummary(String raw) {
    // Strip markdown code fences the model may have added
    final cleaned = _stripCodeFences(raw);
    final jsonStart = cleaned.lastIndexOf('{');
    if (jsonStart > 0) {
      return cleaned.substring(0, jsonStart).trim();
    }
    return cleaned.trim();
  }

  EodCorrelation? _extractCorrelation(String raw) {
    try {
      final cleaned   = _stripCodeFences(raw);
      final jsonStart = cleaned.lastIndexOf('{');
      final jsonEnd   = cleaned.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final jsonStr = cleaned.substring(jsonStart, jsonEnd + 1);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      return EodCorrelation(
        flag:       decoded['flag']                 as bool?   ?? false,
        flagReason: decoded['flag_reason']          as String? ?? '',
        summary:    decoded['correlation_summary']  as String? ?? '',
        ragMatch:   decoded['rag_match']            as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Strip markdown code fences (```json ... ``` or ``` ... ```) that
  /// LLMs sometimes add around JSON blocks despite being told not to.
  String _stripCodeFences(String raw) {
    return raw.replaceAll(RegExp(r'```(?:json)?\s*'), '').trim();
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
  final bool    flag;
  final String  flagReason;
  final String  summary;
  /// Condition name from Weaviate RAG that was surfaced, if any (online only).
  final String? ragMatch;

  const EodCorrelation({
    required this.flag,
    required this.flagReason,
    required this.summary,
    this.ragMatch,
  });
}