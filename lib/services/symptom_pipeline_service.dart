import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import '../models/symptom_result.dart';
import '../models/escalation_level.dart';
import 'confidence_manager.dart';
import 'disembed_service.dart';
import 'model_lifecycle_service.dart';
import 'minime_backend_service.dart';
import '../database/isar_service.dart';
import '../database/symptom_entry.dart';

/// Orchestrates USE CASE 2: Symptom reporting pipeline.
///
/// ONLINE flow:
///   1. DisEmbed fast on-device prediction
///   2. Confidence check → escalate to MiniGen (on-device) if needed
///   3. MiniGen queries Weaviate RAG → expands to 5 diagnoses + next steps
///   NOTE: logic may be incorrect -- this is replacing our old version.
///   4. WRITE to ISAR (source of truth)
///   5. WRITE condensed entry to symptom quick-tracking file
///
/// OFFLINE flow:
///   Same but Weaviate RAG is skipped, offline warning shown.
class SymptomPipelineService {
  final DisEmbedService _disEmbed;
  final ConfidenceManager _confidence;

  final Map<String, List<int>> Function(String text, int maxLen) _tokenize;

  SymptomPipelineService({
    required DisEmbedService disEmbed,
    required ConfidenceManager confidence,
    required Map<String, List<int>> Function(String, int) tokenize,
  }) : _disEmbed = disEmbed,
       _confidence = confidence,
       _tokenize = tokenize;

  // ── Main entry point ────────────────────────────────────────────────────────

  Future<SymptomPipelineResult> analyze({
    required String userSymptoms,
    required bool isOnline,
  }) async {
    // ── STEP 1: DisEmbed fast embedding ───────────────────────────────────
    // If local model loading fails, continue with backend/Gemini paths so
    // symptom analysis still works instead of saving a tracking-only stub.
    List<double> embedding = const <double>[];
    try {
      await ModelLifecycleService.instance.ensureLoaded([ModelType.disEmbed]);
      embedding = await _disEmbed.embed(userSymptoms, _tokenize);
    } catch (e) {
      debugPrint(
        '[SymptomPipeline] DisEmbed unavailable, continuing without local embedding: $e',
      );
    }

    // ── STEP 2: Disease index lookup ───────────────────────────────────────
    // TODO(index): Replace with a real on-device disease embedding index once
    // built. Until then _disEmbedIndexReady = false routes all queries to
    // MiniGen via the escalation path (same quality, no wasted embedding compare).
    // NOTE: logic may be incorrect -- this is replacing our old version.
    const disEmbedIndexReady = false;

    if (!disEmbedIndexReady) {
      return _handleEscalation(
        userSymptoms: userSymptoms,
        embedding: embedding,
        isOnline: isOnline,
        disEmbedResult: null,
      );
    }

    // Dead path until index is ready — kept for structure.
    // ignore: dead_code
    const placeholderDiseaseName = 'Unknown';
    // ignore: dead_code
    final deConfidence = _confidence.evaluateDisEmbed(0.0);

    // ── STEP 3: Confidence check ───────────────────────────────────────────
    // ignore: dead_code
    if (_confidence.shouldEscalate(deConfidence)) {
      return _handleEscalation(
        userSymptoms: userSymptoms,
        embedding: embedding,
        isOnline: isOnline,
        disEmbedResult: deConfidence,
      );
    }

    // ignore: dead_code
    return _expandWithOnDevice(
      userSymptoms: userSymptoms,
      embedding: embedding,
      isOnline: isOnline,
      disEmbedPrediction: placeholderDiseaseName,
      disEmbedResult: deConfidence,
    );
  }

  /// Store a minimal symptom entry when model inference is unavailable.
  ///
  /// This keeps symptom logging functional even if ONNX or LLM analysis fails.
  Future<SymptomPipelineResult> storeWithoutAnalysis({
    required String userSymptoms,
    required bool isOnline,
  }) async {
    return _buildAndStore(
      userSymptoms: userSymptoms,
      diagnoses: const [
        DiagnosisEntry(
          diseaseName: 'Symptom log saved',
          reasoning:
              'AI analysis was unavailable, but your symptom entry was saved successfully.',
          nextSteps:
              'Review the symptom history in the app and retry analysis later if needed.',
          isUrgent: false,
        ),
      ],
      ragUsed: false,
      isOffline: !isOnline,
      resolvedBy: EscalationLevel.base,
      disEmbedPrediction: null,
      disEmbedResult: null,
    );
  }

  /// Request a second pass through the same non-Gemini backend disease predictor.
  Future<SymptomPipelineResult> requestSecondOpinion({
    required String userSymptoms,
    required List<double> embedding,
    required SymptomPipelineResult previousResult,
  }) async {
    final symptomList = userSymptoms
        .split(RegExp(r'[,.]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final backendReply = await MiniMeBackendService.instance.analyzeSymptoms(
      symptoms: symptomList,
    );

    return _buildAndStore(
      userSymptoms: userSymptoms,
      diagnoses: _backendReplyToDiagnoses(backendReply),
      ragUsed: backendReply.source.contains('rag'),
      isOffline: false,
      resolvedBy: EscalationLevel.base,
      disEmbedPrediction: previousResult.disEmbedPrediction,
      disEmbedResult: previousResult.disEmbedResult,
    );
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<SymptomPipelineResult> _expandWithOnDevice({
    required String userSymptoms,
    required List<double> embedding,
    required bool isOnline,
    required String disEmbedPrediction,
    required DisEmbedResult disEmbedResult,
  }) async {
    return _buildAndStore(
      userSymptoms: userSymptoms,
      diagnoses: _fallbackDiagnoses(''),
      ragUsed: false,
      isOffline: !isOnline,
      resolvedBy: EscalationLevel.base,
      disEmbedPrediction: disEmbedPrediction,
      disEmbedResult: disEmbedResult,
    );
  }

  /// Convert a backend [SymptomAnalysisReply] into the shared [DiagnosisEntry] list.
  List<DiagnosisEntry> _backendReplyToDiagnoses(SymptomAnalysisReply reply) {
    if (reply.predictions.isNotEmpty) {
      final isEmergency = reply.urgency == 'emergency';
      return reply.predictions.map((p) {
        final nextSteps = p.whenToSeekCare.isNotEmpty
            ? p.whenToSeekCare
            : reply.selfCareRecommendations.take(2).join(' ');
        return DiagnosisEntry(
          diseaseName: p.condition,
          reasoning: p.description,
          nextSteps: nextSteps,
          isUrgent: isEmergency,
        );
      }).toList();
    }
    // Backend returned analysis text but no structured predictions
    return [
      DiagnosisEntry(
        diseaseName: 'See analysis',
        reasoning: reply.analysis,
        nextSteps: reply.selfCareRecommendations.take(2).join(' '),
        isUrgent: reply.urgency == 'emergency',
      ),
    ];
  }

  Future<SymptomPipelineResult> _handleEscalation({
    required String userSymptoms,
    required List<double> embedding,
    required bool isOnline,
    required DisEmbedResult? disEmbedResult,
  }) async {
    // ── Backend (online, DisEmbed + RAG on server) ─────────────────────────
    if (isOnline) {
      try {
        final symptomList = userSymptoms
            .split(RegExp(r'[,.]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final backendReply = await MiniMeBackendService.instance
            .analyzeSymptoms(symptoms: symptomList);
        return _buildAndStore(
          userSymptoms: userSymptoms,
          diagnoses: _backendReplyToDiagnoses(backendReply),
          ragUsed: backendReply.source.contains('rag'),
          isOffline: false,
          resolvedBy: EscalationLevel.base,
          disEmbedPrediction: null,
          disEmbedResult: disEmbedResult,
        );
      } catch (e) {
        debugPrint(
          '[SymptomPipeline] Backend analyze failed, using fallback: $e',
        );
      }
    }

    return _buildAndStore(
      userSymptoms: userSymptoms,
      diagnoses: _fallbackDiagnoses(''),
      ragUsed: false,
      isOffline: !isOnline,
      resolvedBy: EscalationLevel.base,
      disEmbedPrediction: null,
      disEmbedResult: disEmbedResult,
    );
  }

  Future<SymptomPipelineResult> _buildAndStore({
    required String userSymptoms,
    required List<DiagnosisEntry> diagnoses,
    required bool ragUsed,
    required bool isOffline,
    required EscalationLevel resolvedBy,
    required String? disEmbedPrediction,
    required DisEmbedResult? disEmbedResult,
  }) async {
    final now = DateTime.now();
    final dateStr = now.toIso8601String().split('T').first;
    final topDisease = diagnoses.isNotEmpty
        ? diagnoses.first.diseaseName
        : 'Unknown';
    final symptomList = userSymptoms
        .split(RegExp(r'[,.]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // ── 1. WRITE TO ISAR (source of truth) ────────────────────────────────
    final symptomEntry = SymptomEntry()
      ..date = dateStr
      ..rawSymptoms = userSymptoms
      ..symptomList = symptomList
      ..predictedAilment = topDisease
      ..disEmbedScore = disEmbedResult?.cosineScore ?? 0.0
      ..diagnosesJson = jsonEncode(
        diagnoses
            .map(
              (d) => {
                'disease': d.diseaseName,
                'reasoning': d.reasoning,
                'next_steps': d.nextSteps,
                'is_urgent': d.isUrgent,
              },
            )
            .toList(),
      )
      ..resolvedBy = resolvedBy.name
      ..ragUsed = ragUsed
      ..wasOffline = isOffline
      ..status = 'active'
      ..timestamp = now
      ..updatedAt = now;

    await IsarService.instance.writeSymptomEntry(symptomEntry);

    return SymptomPipelineResult(
      userSymptoms: userSymptoms,
      diagnoses: diagnoses,
      ragUsed: ragUsed,
      isOffline: isOffline,
      resolvedBy: resolvedBy,
      timestamp: now,
      disEmbedPrediction: disEmbedPrediction,
      disEmbedResult: disEmbedResult,
    );
  }

  List<DiagnosisEntry> _fallbackDiagnoses(String rawText) => [
    DiagnosisEntry(
      diseaseName: 'Analysis incomplete',
      reasoning: rawText.length > 200 ? rawText.substring(0, 200) : rawText,
      nextSteps: 'Please consult a healthcare professional.',
    ),
  ];
}
