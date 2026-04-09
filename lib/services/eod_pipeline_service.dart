import 'dart:async' show unawaited;
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'quick_track_service.dart';
import 'fitness_pipeline_service.dart';
import 'disembed_service.dart';
import 'gemma_service.dart';
import 'gemini_service.dart';
import 'weaviate_service.dart';
import '../database/isar_service.dart';
import '../database/eod_entry.dart';
import '../database/mood_entry.dart';
import '../database/symptom_entry.dart';

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

    // ── STEP 1: Read ISAR directly (source of truth) ──────────────────────
    final recentMoods    = await IsarService.instance.getRecentMoodEntries(days: 14);
    final activeSymptoms = await IsarService.instance.getActiveSymptomEntries();
    final last14Fitness  = await IsarService.instance.getLastNDaysFitnessScores(14);

    // ── STEP 2: Quick-track sync repair ───────────────────────────────────
    // Compares existing plaintext summaries against fresh ISAR-derived
    // templates. Regenerates any that have diverged (e.g. after a crash).
    await _repairQuickTrackSummaries(
      isOnline:       isOnline,
      recentMoods:    recentMoods,
      activeSymptoms: activeSymptoms,
      fitnessScores:  last14Fitness,
    );

    // ── STEP 3: Fitness data ───────────────────────────────────────────────
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

    // ── STEP 4: Build context strings ─────────────────────────────────────
    // ISAR data for detailed structured analysis.
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

    // Quick-track summaries provide additional narrative context for the LLM.
    final moodSummary         = await _quickTrack.buildMoodContext();
    final symptomSummary      = await _quickTrack.buildSymptomContext();
    final conversationSummary = await _quickTrack.buildConversationContext();
    final quickTrackSummaries =
        'Mood summary:\n$moodSummary\n\n'
        'Symptom summary:\n$symptomSummary\n\n'
        'Conversation summary:\n$conversationSummary';

    // ── STEP 5: Correlation analysis ──────────────────────────────────────
    String summaryText = 'End-of-day summary unavailable.';
    EodCorrelation? correlation;

    try {
      final gemmaRaw = await _gemma.generateEodSummary(
        todayMoodEntry:        todayMoodStr,
        activeSymptomEntries:  activeSymptomsStr,
        todayFitnessScore:     todayFitnessScore,
        periodAvgFitnessScore: periodAvg,
        fitnessTrend:          trend,
        lastPeriodMoodEntries: last14MoodStr,
        quickTrackSummaries:   quickTrackSummaries,
      );
      summaryText = _extractUserFacingSummary(gemmaRaw);
      correlation = _extractCorrelation(gemmaRaw);
    } catch (e) {
      debugPrint('[EodPipeline] Gemma failed, falling back to Gemini: $e');

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

        // Append quick-track summaries to the mood entries context so
        // GeminiService signature does not need to change.
        final enrichedMoodEntries = last14MoodStr.isEmpty
            ? quickTrackSummaries
            : '$last14MoodStr\n\n$quickTrackSummaries';

        try {
          final geminiRaw = await _gemini.generateDeepEodAnalysis(
            todayMoodEntry:       todayMoodStr,
            activeSymptomEntries: activeSymptomsStr,
            todayFitnessScore:    todayFitnessScore,
            periodAvgFitnessScore: periodAvg,
            fitnessTrend:          trend,
            last14MoodEntries:     enrichedMoodEntries,
            ragContext:           ragContext,
          );
          summaryText = _extractUserFacingSummary(geminiRaw);
          correlation = _extractCorrelation(geminiRaw);
        } catch (e) {
          debugPrint('[EodPipeline] Gemini failed, using stub summary: $e');
        }
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

  // ── Quick-track sync repair ──────────────────────────────────────────────────

  /// Compares existing quick-track summary files against fresh ISAR-derived
  /// templates. If a file has diverged (Jaccard similarity < 0.5), it is
  /// regenerated from ISAR data + a Gemma insight block.
  Future<void> _repairQuickTrackSummaries({
    required bool              isOnline,
    required List<MoodEntry>    recentMoods,
    required List<SymptomEntry> activeSymptoms,
    required List<double>       fitnessScores,
  }) async {
    final freshMoodTemplate    =
        QuickTrackService.buildMoodTemplate(recentMoods, fitnessScores);
    final freshSymptomTemplate =
        QuickTrackService.buildSymptomTemplate(activeSymptoms);

    final existingMood    = await _quickTrack.readMoodSummary();
    final existingSymptom = await _quickTrack.readSymptomSummary();

    final moodSim    = _jaccardSimilarity(
        _templateBlock(existingMood), freshMoodTemplate);
    final symptomSim = _jaccardSimilarity(
        _templateBlock(existingSymptom), freshSymptomTemplate);

    if (moodSim < 0.5) {
      debugPrint('[EodPipeline] Mood summary diverged (sim=$moodSim) — regenerating');
      unawaited(_regenerateSummary(
        template:  freshMoodTemplate,
        write:     _quickTrack.writeMoodSummary,
        label:     'mood',
      ));
    }

    if (symptomSim < 0.5) {
      debugPrint(
          '[EodPipeline] Symptom summary diverged (sim=$symptomSim) — regenerating');
      unawaited(_regenerateSummary(
        template:  freshSymptomTemplate,
        write:     _quickTrack.writeSymptomSummary,
        label:     'symptom',
      ));
    }
  }

  Future<void> _regenerateSummary({
    required String template,
    required Future<void> Function(String) write,
    required String label,
  }) async {
    String summary = template;
    try {
      final insight = await _gemma.generateSummaryInsight(template: template);
      summary = '$template\n\n$insight';
    } on StateError catch (e) {
      debugPrint('[EodPipeline] Gemma not available for $label repair: $e');
    }
    try {
      await write(summary);
    } catch (e) {
      debugPrint('[EodPipeline] $label summary repair write failed: $e');
    }
  }

  /// Extracts the template block (everything before the first blank line).
  String _templateBlock(String summary) {
    final idx = summary.indexOf('\n\n');
    return idx == -1 ? summary.trim() : summary.substring(0, idx).trim();
  }

  /// Jaccard similarity between the word sets of two strings.
  double _jaccardSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final wordsA = a.toLowerCase().split(RegExp(r'\s+')).toSet();
    final wordsB = b.toLowerCase().split(RegExp(r'\s+')).toSet();
    final intersection = wordsA.intersection(wordsB).length;
    final union        = wordsA.union(wordsB).length;
    return union == 0 ? 0.0 : intersection / union;
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
