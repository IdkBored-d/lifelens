import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'fitness_pipeline_service.dart';
import 'disembed_service.dart';
import 'gemini_service.dart';
import 'weaviate_service.dart';
import '../database/isar_service.dart';
import '../database/eod_entry.dart';

class EodPipelineService {
  final GeminiService          _gemini;
  final WeaviateService        _weaviate;
  final FitnessPipelineService _fitness;
  final DisEmbedService        _disEmbed;
  final Map<String, List<int>> Function(String, int) _tokenize;

  EodPipelineService({
    required GeminiService          gemini,
    required WeaviateService        weaviate,
    required FitnessPipelineService fitness,
    required DisEmbedService        disEmbed,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _gemini     = gemini,
        _weaviate   = weaviate,
        _fitness    = fitness,
        _disEmbed   = disEmbed,
        _tokenize   = tokenize;

  Future<EodResult> runEndOfDay({required bool isOnline}) async {
    final today   = DateTime.now();
    final dateStr = today.toIso8601String().split('T').first;

    // ── STEP 1: Read ISAR directly (source of truth) ──────────────────────
    final recentMoods    = await IsarService.instance.getRecentMoodEntries(days: 14);
    final activeSymptoms = await IsarService.instance.getActiveSymptomEntries();

    // ── STEP 2: Fitness data ───────────────────────────────────────────────
    await _fitness.score();

    final last14FitnessScores =
        await IsarService.instance.getLastNDaysFitnessScores(14);

    final todayFitnessScore = last14FitnessScores.isNotEmpty
        ? last14FitnessScores.first
        : 0.0;

    final periodAvg = last14FitnessScores.isNotEmpty
        ? last14FitnessScores.reduce((a, b) => a + b) / last14FitnessScores.length
        : todayFitnessScore;

    final trend = _fitness.fitnessTrend(last14FitnessScores);

    // ── STEP 3: Build context strings ─────────────────────────────────────
    final todayMoods = recentMoods.where((e) => e.date == dateStr).toList();

    final todayMoodStr = todayMoods.isNotEmpty
        ? todayMoods
            .map((e) => '${e.date} | ${e.resolvedMood} | ${e.condensedLog}')
            .join('\n')
        : 'No mood entries today.';

    final activeSymptomsStr = activeSymptoms.isNotEmpty
        ? activeSymptoms
            .map((e) =>
                '${e.date} | ${e.predictedAilment} [${e.status}] | ${e.symptomList.join(", ")}')
            .join('\n')
        : 'No active symptoms.';

    final last14MoodStr = recentMoods
        .take(14)
        .map((e) => '${e.date} | ${e.resolvedMood} | ${e.condensedLog}')
        .join('\n');

    // ── STEP 4: Gemini analysis ────────────────────────────────────────────
    String summaryText = 'End-of-day summary unavailable.';
    EodCorrelation? correlation;

    if (isOnline) {
      String ragContext = '';
      if (activeSymptoms.isNotEmpty) {
        try {
          final symptomQueryText = activeSymptoms
              .map((e) => '${e.predictedAilment}: ${e.symptomList.join(", ")}')
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
          todayMoodEntry:        todayMoodStr,
          activeSymptomEntries:  activeSymptomsStr,
          todayFitnessScore:     todayFitnessScore,
          periodAvgFitnessScore: periodAvg,
          fitnessTrend:          trend,
          last14MoodEntries:     last14MoodStr,
          ragContext:            ragContext,
        );
        summaryText = _extractUserFacingSummary(geminiRaw);
        correlation = _extractCorrelation(geminiRaw);
      } catch (e) {
        debugPrint('[EodPipeline] Gemini failed, using stub summary: $e');
      }
    }

    // ── STEP 5: Write EOD summary to ISAR ─────────────────────────────────
    final eodEntry = EodEntry()
      ..date               = dateStr
      ..summaryText        = summaryText
      ..correlationSummary = correlation?.summary
      ..flagged            = correlation?.flag ?? false
      ..flagReason         = correlation?.flagReason
      ..ragMatch           = correlation?.ragMatch
      ..fitnessScore       = todayFitnessScore
      ..moodEntryCount     = todayMoods.length
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

  String _extractUserFacingSummary(String raw) {
    final cleaned   = _stripCodeFences(raw);
    final jsonStart = cleaned.lastIndexOf('{');
    if (jsonStart > 0) return cleaned.substring(0, jsonStart).trim();
    return cleaned.trim();
  }

  EodCorrelation? _extractCorrelation(String raw) {
    try {
      final cleaned   = _stripCodeFences(raw);
      final jsonStart = cleaned.lastIndexOf('{');
      final jsonEnd   = cleaned.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final decoded = jsonDecode(cleaned.substring(jsonStart, jsonEnd + 1))
          as Map<String, dynamic>;

      return EodCorrelation(
        flag:       decoded['flag']                as bool?   ?? false,
        flagReason: decoded['flag_reason']         as String? ?? '',
        summary:    decoded['correlation_summary'] as String? ?? '',
        ragMatch:   decoded['rag_match']           as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String _stripCodeFences(String raw) =>
      raw.replaceAll(RegExp(r'```(?:json)?\s*'), '').trim();
}

// ── Result types ──────────────────────────────────────────────────────────────

class EodResult {
  final String          date;
  final String          summary;
  final EodCorrelation? correlation;
  final double          fitnessScore;
  final bool            flagged;
  final String?         flagReason;

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
  final String? ragMatch;

  const EodCorrelation({
    required this.flag,
    required this.flagReason,
    required this.summary,
    this.ragMatch,
  });
}
