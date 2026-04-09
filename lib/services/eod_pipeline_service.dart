import 'dart:async' show unawaited;
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'quick_track_service.dart';
import 'fitness_pipeline_service.dart';
import 'disembed_service.dart';
import 'model_lifecycle_service.dart';
import 'gemini_service.dart';
import 'weaviate_service.dart';
import 'eod_correlation_engine.dart';
import 'template_summary_insight_service.dart';
import 'health_feature_computer.dart';
import 'health_summary_model_service.dart';
import 'sentence_bank_service.dart';
import '../database/isar_service.dart';
import '../database/eod_entry.dart';
import '../database/mood_entry.dart';
import '../database/symptom_entry.dart';

class EodPipelineService {
  final GeminiService                 _gemini;
  final WeaviateService               _weaviate;
  final QuickTrackService             _quickTrack;
  final FitnessPipelineService        _fitness;
  final DisEmbedService               _disEmbed;
  final EodCorrelationEngine          _correlationEngine;
  final TemplateSummaryInsightService _templateInsight;
  final HealthFeatureComputer         _featureComputer;
  final HealthSummaryModelService     _summaryModel;
  final SentenceBankService           _sentenceBank;
  final Map<String, List<int>> Function(String, int) _tokenize;

  EodPipelineService({
    required GeminiService                 gemini,
    required WeaviateService               weaviate,
    required QuickTrackService             quickTrack,
    required FitnessPipelineService        fitness,
    required DisEmbedService               disEmbed,
    required EodCorrelationEngine          correlationEngine,
    required TemplateSummaryInsightService templateInsight,
    required HealthFeatureComputer         featureComputer,
    required HealthSummaryModelService     summaryModel,
    required SentenceBankService           sentenceBank,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _gemini            = gemini,
        _weaviate          = weaviate,
        _quickTrack        = quickTrack,
        _fitness           = fitness,
        _disEmbed          = disEmbed,
        _correlationEngine = correlationEngine,
        _templateInsight   = templateInsight,
        _featureComputer   = featureComputer,
        _summaryModel      = summaryModel,
        _sentenceBank      = sentenceBank,
        _tokenize          = tokenize;

  Future<EodResult> runEndOfDay({required bool isOnline}) async {
    final today   = DateTime.now();
    final dateStr = today.toIso8601String().split('T').first;

    // ── STEP 1: Read ISAR directly (source of truth) ──────────────────────
    final recentMoods    = await IsarService.instance.getRecentMoodEntries(days: 14);
    final activeSymptoms = await IsarService.instance.getActiveSymptomEntries();
    final last14Fitness  = await IsarService.instance.getLastNDaysFitnessScores(14);

    // ── STEP 2: Quick-track sync repair ───────────────────────────────────
    await _repairQuickTrackSummaries(
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

    // ── STEP 5: Correlation analysis + narrative generation ──────────────
    //
    // Narrative strategy (in priority order):
    //   1. HealthSummaryModel (ML) — when loaded and sentence bank has embeddings
    //   2. EodCorrelationEngine   — deterministic template fallback (always available)
    //
    // Safety: correlation/flag detection always uses EodCorrelationEngine.
    // The ML model only replaces the narrative sentences, never the flag logic.
    String summaryText;
    EodCorrelation? correlation;

    final (engineSummary, engineCorrelation) = _correlationEngine.analyze(
      recentMoods:       recentMoods,
      activeSymptoms:    activeSymptoms,
      fitnessScores:     last14FitnessScores,
      fitnessTrend:      trend,
      todayFitnessScore: todayFitnessScore,
    );

    // Correlation/flagging always comes from the deterministic engine
    correlation = engineCorrelation;

    // Attempt ML-based narrative if model and sentence bank are ready
    summaryText = await _tryMlNarrative(
      recentMoods:    recentMoods,
      fitnessScores:  last14FitnessScores,
      activeSymptoms: activeSymptoms,
    ) ?? engineSummary;

    // ── STEP 6: Gemini enrichment (online, optional — improves narrative) ──
    // Only attempt if the engine flagged a concern or there are active symptoms,
    // as Gemini adds the most value for complex/concerning patterns.
    if (isOnline && (correlation.flag || activeSymptoms.isNotEmpty)) {
      try {
        String ragContext = '';
        if (activeSymptoms.isNotEmpty) {
          try {
            final symptomQueryText = activeSymptoms
                .map((e) => '${e.predictedAilment}: ${e.symptomList.join(", ")}')
                .join('. ');
            await ModelLifecycleService.instance.ensureLoaded([ModelType.disEmbed]);
            final queryVector = await _disEmbed.embed(symptomQueryText, _tokenize);
            final ragResults  = await _weaviate.queryByVector(queryVector, topK: 3);
            ragContext = _weaviate.buildRagContext(ragResults);
          } catch (e) {
            debugPrint('[EodPipeline] RAG query failed (non-fatal): $e');
          }
        }

        final quickTrackSummaries =
            'Mood summary:\n${await _quickTrack.buildMoodContext()}\n\n'
            'Symptom summary:\n${await _quickTrack.buildSymptomContext()}\n\n'
            'Conversation summary:\n${await _quickTrack.buildConversationContext()}';

        final enrichedMoodEntries = last14MoodStr.isEmpty
            ? quickTrackSummaries
            : '$last14MoodStr\n\n$quickTrackSummaries';

        final geminiRaw = await _gemini.generateDeepEodAnalysis(
          todayMoodEntry:       todayMoodStr,
          activeSymptomEntries: activeSymptomsStr,
          todayFitnessScore:    todayFitnessScore,
          periodAvgFitnessScore: periodAvg,
          fitnessTrend:          trend,
          last14MoodEntries:     enrichedMoodEntries,
          ragContext:           ragContext,
        );

        final geminiSummary     = _extractUserFacingSummary(geminiRaw);
        final geminiCorrelation = _extractCorrelation(geminiRaw);

        // Use Gemini's richer narrative if it produced a non-empty result
        if (geminiSummary.isNotEmpty) {
          summaryText = geminiSummary;
          correlation = geminiCorrelation ?? correlation;
        }
      } catch (e) {
        debugPrint('[EodPipeline] Gemini enrichment failed (using engine result): $e');
      }
    }

    // ── STEP 7: WRITE EOD SUMMARY TO ISAR ─────────────────────────────────
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

  // ── ML narrative generation ──────────────────────────────────────────────────

  /// Attempt to generate a narrative using the HealthSummaryModel + sentence bank.
  /// Returns null if the model is not loaded or the bank has no embeddings yet,
  /// allowing callers to fall back to the template engine.
  Future<String?> _tryMlNarrative({
    required List<MoodEntry>    recentMoods,
    required List<double>       fitnessScores,
    required List<SymptomEntry> activeSymptoms,
  }) async {
    if (!_summaryModel.isLoaded || !_sentenceBank.embeddingsReady) return null;

    try {
      await ModelLifecycleService.instance.ensureLoaded([
        ModelType.disEmbed,
        ModelType.healthSummary,
      ]);

      // Build text context: concatenate recent mood logs for DisEmbed
      final moodLogText = recentMoods
          .take(7)
          .map((e) => '${e.resolvedMood}: ${e.condensedLog}')
          .join('. ');
      final textEmbedding = moodLogText.isNotEmpty
          ? await _disEmbed.embed(moodLogText, _tokenize)
          : List<double>.filled(384, 0.0);

      final numericalFeatures = _featureComputer.compute(
        recentMoods:    recentMoods,
        fitnessScores:  fitnessScores,
        activeSymptoms: activeSymptoms,
      );

      final contextVectors = await _summaryModel.predict(
        numericalFeatures: numericalFeatures,
        textEmbedding:     textEmbedding,
      );

      final s1 = _sentenceBank.rank(
        contextVectors[0],
        _sentenceBank.summaryCategory(SentenceBankService.categoryMoodStatus),
      ).firstOrNull?.entry.text;

      final s2 = _sentenceBank.rank(
        contextVectors[1],
        _sentenceBank.summaryCategory(SentenceBankService.categoryHealthContext),
      ).firstOrNull?.entry.text;

      final s3 = _sentenceBank.rank(
        contextVectors[2],
        _sentenceBank.summaryCategory(SentenceBankService.categoryActionableClosing),
      ).firstOrNull?.entry.text;

      if (s1 == null || s2 == null || s3 == null) return null;
      return '$s1 $s2 $s3';
    } catch (e) {
      debugPrint('[EodPipeline] ML narrative failed (using template): $e');
      return null;
    }
  }

  // ── Quick-track sync repair ──────────────────────────────────────────────────

  Future<void> _repairQuickTrackSummaries({
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
        insight:   _templateInsight.generateMoodInsight(freshMoodTemplate),
        write:     _quickTrack.writeMoodSummary,
        label:     'mood',
      ));
    }

    if (symptomSim < 0.5) {
      debugPrint('[EodPipeline] Symptom summary diverged (sim=$symptomSim) — regenerating');
      unawaited(_regenerateSummary(
        template:  freshSymptomTemplate,
        insight:   _templateInsight.generateSymptomInsight(freshSymptomTemplate),
        write:     _quickTrack.writeSymptomSummary,
        label:     'symptom',
      ));
    }
  }

  Future<void> _regenerateSummary({
    required String template,
    required String insight,
    required Future<void> Function(String) write,
    required String label,
  }) async {
    try {
      await write('$template\n\n$insight');
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

  // ── Gemini response parsing ──────────────────────────────────────────────────

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
