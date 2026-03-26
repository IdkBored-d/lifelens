import 'dart:convert';
import '../models/symptom_result.dart';
import '../models/escalation_level.dart';
import 'confidence_manager.dart';
import 'quick_track_service.dart';
import 'disembed_service.dart';
import 'weaviate_service.dart';
import 'gemma_service.dart';
import 'gemini_service.dart';
import '../database/isar_service.dart';
import '../database/symptom_entry.dart';

/// Orchestrates USE CASE 2: Symptom reporting pipeline.
///
/// ONLINE flow:
///   1. DisEmbed fast on-device prediction
///   2. Confidence check → escalate to Gemma2b if needed
///   3. Gemma2b queries Weaviate RAG → expands to 5 diagnoses + next steps
///   4. WRITE to ISAR (source of truth)
///   5. WRITE condensed entry to symptom quick-tracking file
///
/// OFFLINE flow:
///   Same but Weaviate RAG is skipped, offline warning shown.
class SymptomPipelineService {
  final DisEmbedService   _disEmbed;
  final GemmaService      _gemma;
  final GeminiService     _gemini;
  final WeaviateService   _weaviate;
  final ConfidenceManager _confidence;
  final QuickTrackService _quickTrack;

  final Map<String, List<int>> Function(String text, int maxLen) _tokenize;

  SymptomPipelineService({
    required DisEmbedService   disEmbed,
    required GemmaService      gemma,
    required GeminiService     gemini,
    required WeaviateService   weaviate,
    required ConfidenceManager confidence,
    required QuickTrackService quickTrack,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _disEmbed   = disEmbed,
        _gemma      = gemma,
        _gemini     = gemini,
        _weaviate   = weaviate,
        _confidence = confidence,
        _quickTrack = quickTrack,
        _tokenize   = tokenize;

  // ── Main entry point ────────────────────────────────────────────────────────

  Future<SymptomPipelineResult> analyze({
    required String userSymptoms,
    required bool   isOnline,
  }) async {
    // ── STEP 1: DisEmbed fast embedding ───────────────────────────────────
    final embedding = await _disEmbed.embed(userSymptoms, _tokenize);

    // ── STEP 2: Placeholder disease lookup ────────────────────────────────
    // TODO: Replace with a real on-device disease embedding index lookup.
    // For MVP, DisEmbed score is 0.3846 so it always escalates to Gemma2b,
    // which handles the full diagnosis using Weaviate RAG (online) or
    // parametric knowledge (offline).
    const placeholderDiseaseName = 'Unknown';
    const placeholderScore       = 0.3846; // Forces uncertain zone escalation

    final deConfidence = _confidence.evaluateDisEmbed(placeholderScore);

    // ── STEP 3: Confidence check ───────────────────────────────────────────
    if (_confidence.shouldEscalate(deConfidence)) {
      return _handleEscalation(
        userSymptoms:   userSymptoms,
        embedding:      embedding,
        isOnline:       isOnline,
        disEmbedResult: deConfidence,
      );
    }

    // ── STEP 4: Gemma2b expands prediction ────────────────────────────────
    return _expandWithGemma(
      userSymptoms:       userSymptoms,
      embedding:          embedding,
      isOnline:           isOnline,
      disEmbedPrediction: placeholderDiseaseName,
      disEmbedResult:     deConfidence,
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

    final diagnoses = _parseGemmaDiagnoses(geminiRaw);

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

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<SymptomPipelineResult> _expandWithGemma({
    required String         userSymptoms,
    required List<double>   embedding,
    required bool           isOnline,
    required String         disEmbedPrediction,
    required DisEmbedResult disEmbedResult,
  }) async {
    List<WeaviateDisease> ragResults = [];
    if (isOnline) {
      ragResults = await _weaviate.queryByVector(embedding, topK: 5);
    }
    // isOnline determines offline warning. If online but empty, passes an empty string.
    final ragContext = isOnline ? _weaviate.buildRagContext(ragResults) : null;
    final context   = await _quickTrack.buildSymptomContext();

    final gemmaRaw = await _gemma.expandDiagnosis(
      disEmbedPrediction: disEmbedPrediction,
      userSymptoms:       userSymptoms,
      context:            context,
      ragContext:         ragContext,
    );

    return _buildAndStore(
      userSymptoms:       userSymptoms,
      diagnoses:          _parseGemmaDiagnoses(gemmaRaw),
      ragUsed:            ragResults.isNotEmpty,
      isOffline:          !isOnline,
      resolvedBy:         EscalationLevel.base,
      disEmbedPrediction: disEmbedPrediction,
      disEmbedResult:     disEmbedResult,
    );
  }

  Future<SymptomPipelineResult> _handleEscalation({
    required String         userSymptoms,
    required List<double>   embedding,
    required bool           isOnline,
    required DisEmbedResult disEmbedResult,
  }) async {
    List<WeaviateDisease> ragResults = [];
    if (isOnline) {
      ragResults = await _weaviate.queryByVector(embedding, topK: 5);
    }
    final ragContext = ragResults.isNotEmpty
        ? _weaviate.buildRagContext(ragResults) : null;
    final context   = await _quickTrack.buildSymptomContext();

    final gemmaRaw = await _gemma.analyzeSymptomDirectly(
      userSymptoms: userSymptoms,
      context:      context,
      ragContext:   ragContext,
    );

    return _buildAndStore(
      userSymptoms:       userSymptoms,
      diagnoses:          _parseGemmaDiagnoses(gemmaRaw),
      ragUsed:            ragResults.isNotEmpty,
      isOffline:          !isOnline,
      resolvedBy:         EscalationLevel.gemma,
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

    // ── 2. WRITE TO QUICK-TRACKING FILE ──────────────────────────────────
    await _quickTrack.appendSymptomEntry(SymptomLogEntry(
      date:             dateStr,
      symptoms:         symptomList,
      predictedAilment: topDisease,
      status:           'active',
    ));

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

  List<DiagnosisEntry> _parseGemmaDiagnoses(String rawResponse) {
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
