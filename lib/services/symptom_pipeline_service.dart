import 'dart:async' show unawaited;
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/symptom_result.dart';
import '../models/escalation_level.dart';
import 'confidence_manager.dart';
import 'quick_track_service.dart';
import 'disembed_service.dart';
import 'model_lifecycle_service.dart';
import 'weaviate_service.dart';
import 'gemini_service.dart';
import 'disease_knowledge_base.dart';
import 'template_summary_insight_service.dart';
import '../database/isar_service.dart';
import '../database/symptom_entry.dart';

/// Orchestrates USE CASE 2: Symptom reporting pipeline.
///
/// ONLINE flow:
///   1. DisEmbed fast on-device embedding
///   2. Weaviate RAG retrieves top-5 candidate diseases by vector similarity
///   3. DiseaseKnowledgeBase resolves candidates to structured DiagnosisEntry list
///   4. Gemini cloud fallback if KB lookup produces no useful results (online only)
///   5. WRITE to ISAR (source of truth)
///   6. WRITE condensed entry to symptom quick-tracking file (template insight)
///
/// OFFLINE flow:
///   Same but Weaviate RAG is skipped; KB uses keyword matching only.
class SymptomPipelineService {
  final DisEmbedService               _disEmbed;
  final GeminiService                 _gemini;
  final WeaviateService               _weaviate;
  final ConfidenceManager             _confidence;
  final QuickTrackService             _quickTrack;
  final DiseaseKnowledgeBase          _diseaseKb;
  final TemplateSummaryInsightService _templateInsight;

  final Map<String, List<int>> Function(String text, int maxLen) _tokenize;

  SymptomPipelineService({
    required DisEmbedService               disEmbed,
    required GeminiService                 gemini,
    required WeaviateService               weaviate,
    required ConfidenceManager             confidence,
    required QuickTrackService             quickTrack,
    required DiseaseKnowledgeBase          diseaseKb,
    required TemplateSummaryInsightService templateInsight,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _disEmbed       = disEmbed,
        _gemini         = gemini,
        _weaviate       = weaviate,
        _confidence     = confidence,
        _quickTrack     = quickTrack,
        _diseaseKb      = diseaseKb,
        _templateInsight = templateInsight,
        _tokenize       = tokenize;

  // ── Main entry point ────────────────────────────────────────────────────────

  Future<SymptomPipelineResult> analyze({
    required String userSymptoms,
    required bool   isOnline,
  }) async {
    // ── STEP 1: DisEmbed fast embedding ───────────────────────────────────
    await ModelLifecycleService.instance.ensureLoaded([ModelType.disEmbed]);
    final embedding = await _disEmbed.embed(userSymptoms, _tokenize);

    // ── STEP 2: Disease index lookup ───────────────────────────────────────
    // On-device disease index not yet built — route directly to KB + RAG.
    const disEmbedIndexReady = false;

    if (!disEmbedIndexReady) {
      return _handleWithKnowledgeBase(
        userSymptoms: userSymptoms,
        embedding:    embedding,
        isOnline:     isOnline,
      );
    }

    // Dead path until index is ready — kept for structure.
    // ignore: dead_code
    final deConfidence = _confidence.evaluateDisEmbed(0.0);
    // ignore: dead_code
    if (_confidence.shouldEscalate(deConfidence)) {
      return _handleWithKnowledgeBase(
        userSymptoms:   userSymptoms,
        embedding:      embedding,
        isOnline:       isOnline,
        disEmbedResult: deConfidence,
      );
    }

    // ignore: dead_code
    return _handleWithKnowledgeBase(
      userSymptoms:   userSymptoms,
      embedding:      embedding,
      isOnline:       isOnline,
      disEmbedResult: deConfidence,
    );
  }

  /// Request a second opinion from Gemini using all available context.
  /// Only callable when online.
  Future<SymptomPipelineResult> requestSecondOpinion({
    required String               userSymptoms,
    required List<double>         embedding,
    required SymptomPipelineResult previousResult,
  }) async {
    final ragResults  = await _weaviate.queryByVector(embedding, topK: 5);
    final ragContext  = _weaviate.buildRagContext(ragResults);
    final context     = await _quickTrack.buildSymptomContext();
    final prevDiseases = previousResult.diagnoses
        .map((d) => d.diseaseName)
        .join(', ');

    final geminiRaw = await _gemini.analyzeSymptoms(
      userSymptoms:      userSymptoms,
      context:           context,
      ragContext:        ragContext,
      previousDiagnoses: prevDiseases,
    );

    final diagnoses = _parseGeminiDiagnoses(geminiRaw);

    return _buildAndStore(
      userSymptoms:       userSymptoms,
      diagnoses:          diagnoses,
      ragUsed:            ragResults.isNotEmpty,
      isOffline:          false,
      resolvedBy:         EscalationLevel.gemini,
      disEmbedPrediction: previousResult.disEmbedPrediction,
      disEmbedResult:     previousResult.disEmbedResult,
    );
  }

  // ── Knowledge base handler ───────────────────────────────────────────────────

  Future<SymptomPipelineResult> _handleWithKnowledgeBase({
    required String         userSymptoms,
    required List<double>   embedding,
    required bool           isOnline,
    DisEmbedResult?         disEmbedResult,
  }) async {
    List<WeaviateDisease> ragResults = [];
    if (isOnline) {
      try {
        ragResults = await _weaviate.queryByVector(embedding, topK: 5);
      } catch (e) {
        debugPrint('[SymptomPipeline] Weaviate query failed: $e');
      }
    }

    // ── Phase 1: DiseaseKnowledgeBase lookup (primary, always available) ──
    final ragNames = ragResults.map((r) => r.diseaseName).toList();
    final kbDiagnoses = _diseaseKb.resolve(
      ragDiseaseNames: ragNames,
      userSymptoms:    userSymptoms,
      isOffline:       !isOnline,
    );

    // If KB produced real matches (not just generic fillers), use them
    final hasRealMatches = kbDiagnoses.any(
      (d) => !d.diseaseName.startsWith('Other possible condition'),
    );

    if (hasRealMatches) {
      return _buildAndStore(
        userSymptoms:       userSymptoms,
        diagnoses:          kbDiagnoses,
        ragUsed:            ragResults.isNotEmpty,
        isOffline:          !isOnline,
        resolvedBy:         EscalationLevel.base,
        disEmbedPrediction: null,
        disEmbedResult:     disEmbedResult,
      );
    }

    // ── Phase 2: Gemini fallback (online, when KB has no useful matches) ──
    if (isOnline) {
      try {
        final context    = await _quickTrack.buildSymptomContext();
        final ragContext  = _weaviate.buildRagContext(ragResults);
        final geminiRaw  = await _gemini.analyzeSymptoms(
          userSymptoms: userSymptoms,
          context:      context,
          ragContext:   ragContext,
        );
        return _buildAndStore(
          userSymptoms:       userSymptoms,
          diagnoses:          _parseGeminiDiagnoses(geminiRaw),
          ragUsed:            ragResults.isNotEmpty,
          isOffline:          false,
          resolvedBy:         EscalationLevel.gemini,
          disEmbedPrediction: null,
          disEmbedResult:     disEmbedResult,
        );
      } catch (e) {
        debugPrint('[SymptomPipeline] Gemini failed, using KB results: $e');
      }
    }

    // ── Phase 3: Return KB results as-is (even generic ones) ──────────────
    return _buildAndStore(
      userSymptoms:       userSymptoms,
      diagnoses:          kbDiagnoses,
      ragUsed:            false,
      isOffline:          !isOnline,
      resolvedBy:         EscalationLevel.base,
      disEmbedPrediction: null,
      disEmbedResult:     disEmbedResult,
    );
  }

  Future<SymptomPipelineResult> _buildAndStore({
    required String            userSymptoms,
    required List<DiagnosisEntry> diagnoses,
    required bool              ragUsed,
    required bool              isOffline,
    required EscalationLevel   resolvedBy,
    required String?           disEmbedPrediction,
    required DisEmbedResult?   disEmbedResult,
  }) async {
    final now        = DateTime.now();
    final dateStr    = now.toIso8601String().split('T').first;
    final topDisease = diagnoses.isNotEmpty ? diagnoses.first.diseaseName : 'Unknown';
    final symptomList = userSymptoms
        .split(RegExp(r'[,.]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // ── 1. WRITE TO ISAR (source of truth) ────────────────────────────────
    final symptomEntry = SymptomEntry()
      ..date             = dateStr
      ..rawSymptoms      = userSymptoms
      ..symptomList      = symptomList
      ..predictedAilment = topDisease
      ..disEmbedScore    = disEmbedResult?.cosineScore ?? 0.0
      ..diagnosesJson    = jsonEncode(diagnoses.map((d) => {
          'disease':    d.diseaseName,
          'reasoning':  d.reasoning,
          'next_steps': d.nextSteps,
          'is_urgent':  d.isUrgent,
        }).toList())
      ..resolvedBy       = resolvedBy.name
      ..ragUsed          = ragUsed
      ..wasOffline       = isOffline
      ..status           = 'active'
      ..timestamp        = now
      ..updatedAt        = now;

    await IsarService.instance.writeSymptomEntry(symptomEntry);

    // ── 2. REGENERATE SYMPTOM QUICK-TRACK SUMMARY ────────────────────────
    // Unawaited: ISAR is the source of truth (already written above).
    unawaited(_generateAndWriteSymptomSummary());

    return SymptomPipelineResult(
      userSymptoms:       userSymptoms,
      diagnoses:          diagnoses,
      ragUsed:            ragUsed,
      isOffline:          isOffline,
      resolvedBy:         resolvedBy,
      timestamp:          now,
      disEmbedPrediction: disEmbedPrediction,
      disEmbedResult:     disEmbedResult,
    );
  }

  // ── Quick-track summary generation ──────────────────────────────────────────

  Future<void> _generateAndWriteSymptomSummary() async {
    try {
      final entries  = await IsarService.instance.getRecentSymptomEntries(days: 14);
      final template = QuickTrackService.buildSymptomTemplate(entries);
      final insight  = _templateInsight.generateSymptomInsight(template);
      final summary  = '$template\n\n$insight';
      await _quickTrack.writeSymptomSummary(summary);
    } catch (e) {
      debugPrint('[SymptomPipeline] Symptom summary write failed: $e');
    }
  }

  // ── Gemini JSON parsing ──────────────────────────────────────────────────────

  List<DiagnosisEntry> _parseGeminiDiagnoses(String rawResponse) {
    try {
      final jsonStart = rawResponse.indexOf('{');
      final jsonEnd   = rawResponse.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return _fallbackDiagnoses(rawResponse);

      final decoded = jsonDecode(rawResponse.substring(jsonStart, jsonEnd + 1))
          as Map<String, dynamic>;
      final list    = decoded['diagnoses'] as List<dynamic>;

      return list.map((e) {
        final entry = e as Map<String, dynamic>;
        return DiagnosisEntry(
          diseaseName: entry['disease']    as String? ?? 'Unknown',
          reasoning:   entry['reasoning']  as String? ?? '',
          nextSteps:   entry['next_steps'] as String? ?? '',
          isUrgent:    entry['is_urgent']  as bool?   ?? false,
        );
      }).toList();
    } catch (_) {
      return _fallbackDiagnoses(rawResponse);
    }
  }

  List<DiagnosisEntry> _fallbackDiagnoses(String rawText) => [
    DiagnosisEntry(
      diseaseName: 'Analysis incomplete',
      reasoning:   rawText.length > 200 ? rawText.substring(0, 200) : rawText,
      nextSteps:   'Please consult a healthcare professional.',
    ),
  ];
}
