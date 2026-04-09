// TODO(reconcile): SymptomAutoDetectorService.autoRegisterDetectedSymptoms()
// was removed from this pipeline in backend-v4. The service still exists at
// lib/services/symptom_auto_detector_service.dart and is called from UI screens
// (moodlog_screen.dart, symptoms_screen.dart). Decide whether to re-wire it here
// or keep it UI-only. See architecture notes in MERGE_NOTES.md.
import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/mood_result.dart';
import '../models/escalation_level.dart';
import 'confidence_manager.dart';
import 'quick_track_service.dart';
import 'mobilebert_service.dart';
import 'model_lifecycle_service.dart';
import 'gemma_service.dart';
import 'gemini_service.dart';
import '../database/isar_service.dart';
import '../database/mood_entry.dart';

/// Orchestrates USE CASE 1: Mood logging pipeline.
///
/// Full flow:
///   1. MobileBERT classifies mood from user log text
///   2. Confidence check → escalate to Gemma2b if needed
///   3. Present mood to user for confirmation (optional — user can skip)
///   4. If user rejects → re-run with rejection context OR escalate
///   5. Gemma2b generates personalised response using quick-track context
///   6. WRITE to ISAR database (source of truth)
///   7. WRITE condensed entry to quick-tracking file
class MoodPipelineService {
  final MobileBertService  _mobileBert;
  final GemmaService       _gemma;
  final GeminiService      _gemini;
  final ConfidenceManager  _confidence;
  final QuickTrackService  _quickTrack;

  // Tokenizer function injected from the app layer.
  // Must return { 'input_ids': List<int>, 'attention_mask': List<int> }
  // both padded to 128 tokens (MobileBERT's SEQ_LEN).
  final Map<String, List<int>> Function(String text, int maxLen) _tokenize;

  MoodPipelineService({
    required MobileBertService  mobileBert,
    required GemmaService       gemma,
    required GeminiService      gemini,
    required ConfidenceManager  confidence,
    required QuickTrackService  quickTrack,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _mobileBert = mobileBert,
        _gemma      = gemma,
        _gemini     = gemini,
        _confidence = confidence,
        _quickTrack = quickTrack,
        _tokenize   = tokenize;

  // ── Main entry point ────────────────────────────────────────────────────────

  /// Run the full mood pipeline on [userLog].
  ///
  /// [isOnline]          whether the device has internet access.
  /// [userConfirmation]  null = user skipped confirmation step.
  ///                     true = user confirmed MobileBERT's prediction.
  ///                     false = user rejected — triggers re-run or escalation.
  /// [rejectionContext]  optional free-text from user explaining the rejection.
  ///                     e.g. "I'm not sad, I'm just tired"
  Future<MoodPipelineResult> analyze({
    required String userLog,
    required bool   isOnline,
    required double currentFitnessScore,
    bool?   userConfirmation,
    String? rejectionContext,
  }) async {
    // ── STEP 1: MobileBERT fast classification ─────────────────────────────
    await ModelLifecycleService.instance.ensureLoaded([ModelType.mobileBert]);
    final probs   = await _mobileBert.classify(userLog, _tokenize);
    final mbResult = _confidence.evaluateMobileBert(probs);

    // ── STEP 2: Confidence check ───────────────────────────────────────────
    if (_confidence.shouldEscalate(mbResult)) {
      return _handleEscalation(
        userLog:            userLog,
        isOnline:           isOnline,
        currentFitnessScore: currentFitnessScore,
        mobileBertResult:   mbResult,
        rejectedMood:       null,
        rejectionContext:   rejectionContext,
      );
    }

    // ── STEP 3: User confirmation ──────────────────────────────────────────
    // If userConfirmation is null, user skipped — continue with MobileBERT result
    if (userConfirmation == false) {
      // User rejected the prediction — re-run or escalate
      return _handleEscalation(
        userLog:            userLog,
        isOnline:           isOnline,
        currentFitnessScore: currentFitnessScore,
        mobileBertResult:   mbResult,
        rejectedMood:       mbResult.topLabel,
        rejectionContext:   rejectionContext,
      );
    }

    // ── STEP 4: MobileBERT passed — generate Gemma2b response ─────────────
    return _generateAndStore(
      userLog:             userLog,
      resolvedMood:        mbResult.topLabel,
      resolvedBy:          EscalationLevel.base,
      mobileBertResult:    mbResult,
      userConfirmed:       userConfirmation,
      currentFitnessScore: currentFitnessScore,
    );
  }

  // ── Escalation handler ───────────────────────────────────────────────────────

  Future<MoodPipelineResult> _handleEscalation({
    required String              userLog,
    required bool                isOnline,
    required double              currentFitnessScore,
    required MobileBertResult    mobileBertResult,
    required String?             rejectedMood,
    required String?             rejectionContext,
  }) async {
    // Build combined log text including rejection context if provided
    final enrichedLog = rejectionContext != null
        ? '$userLog\n[User clarification: $rejectionContext]'
        : userLog;

    // ── Try Gemma2b first ────────────────────────────────────────────────────
    final context = await _quickTrack.buildMoodContext();
    String? gemmaRaw;
    String  gemmaLabel = 'neutral';
    try {
      gemmaRaw   = await _gemma.analyzeMoodDirectly(
        userLog:      enrichedLog,
        context:      context,
        rejectedMood: rejectedMood,
      );
      gemmaLabel = await _gemma.extractMoodLabel(gemmaRaw);
    } on StateError catch (e) {
      debugPrint('[MoodPipeline] Gemma not ready, skipping: $e');
    }

    // Gemma2b resolved — no further escalation needed for mood
    // (NO re-generation step for Gemma2b per system design)
    if (gemmaRaw == null || gemmaLabel != 'neutral' || !isOnline) {
      return _generateAndStore(
        userLog:             enrichedLog,
        resolvedMood:        gemmaRaw != null ? gemmaLabel : mobileBertResult.topLabel,
        resolvedBy:          EscalationLevel.gemma,
        mobileBertResult:    mobileBertResult,
        userConfirmed:       false,
        currentFitnessScore: currentFitnessScore,
        gemmaResponse:       gemmaRaw,
      );
    }

    // ── Gemini fallback (online only) ────────────────────────────────────────
    try {
      final geminiRaw = await _gemini.analyzeMood(
        userLog:               enrichedLog,
        context:               context,
        rejectedMood:          rejectedMood,
        previousGemmaResponse: gemmaRaw,
      );

      // Extract label from Gemini response
      final geminiLabel = _extractLabelFromText(geminiRaw);

      return _generateAndStore(
        userLog:             enrichedLog,
        resolvedMood:        geminiLabel,
        resolvedBy:          EscalationLevel.gemini,
        mobileBertResult:    mobileBertResult,
        userConfirmed:       false,
        currentFitnessScore: currentFitnessScore,
        gemmaResponse:       geminiRaw,
      );
    } catch (e) {
      debugPrint('[MoodPipeline] Gemini failed, falling back to MobileBERT: $e');
    }

    // ── Final fallback: MobileBERT result ────────────────────────────────────
    return _generateAndStore(
      userLog:             enrichedLog,
      resolvedMood:        mobileBertResult.topLabel,
      resolvedBy:          EscalationLevel.base,
      mobileBertResult:    mobileBertResult,
      userConfirmed:       false,
      currentFitnessScore: currentFitnessScore,
    );
  }

  // ── Store result and build return value ──────────────────────────────────────

  Future<MoodPipelineResult> _generateAndStore({
    required String           userLog,
    required String           resolvedMood,
    required EscalationLevel  resolvedBy,
    required MobileBertResult mobileBertResult,
    required double           currentFitnessScore,
    bool?   userConfirmed,
    String? gemmaResponse,
  }) async {
    // Generate response text if not already provided by Gemma2b/Gemini
    String responseText;
    if (gemmaResponse != null) {
      responseText = gemmaResponse;
    } else {
      try {
        responseText = await _gemma.generateMoodResponse(
          predictedMood: resolvedMood,
          userLog:       userLog,
          context:       await _quickTrack.buildMoodContext(),
        );
      } on StateError {
        responseText = 'Mood logged as $resolvedMood.';
      }
    }

    final now       = DateTime.now();
    final dateStr   = now.toIso8601String().split('T').first;
    final condensed = _condenseLog(userLog);

// ── 1. WRITE TO ISAR (source of truth) ────────────────────────────────
    final moodEntry = MoodEntry()
      ..date                 = dateStr
      ..rawLog               = userLog
      ..condensedLog         = condensed
      ..resolvedMood         = resolvedMood
      ..resolvedBy           = resolvedBy.name
      ..mobileBertPrediction = mobileBertResult.topLabel
      ..mobileBertTopProb    = mobileBertResult.topProb
      ..userConfirmed        = userConfirmed ?? false
      ..responseText         = responseText
      ..fitnessScoreSnapshot = currentFitnessScore
      ..timestamp            = now;

    await IsarService.instance.writeMoodEntry(moodEntry);

    // ── 2. REGENERATE MOOD QUICK-TRACK SUMMARY ───────────────────────────
    // Unawaited: ISAR is the source of truth (already written above).
    // Queries ISAR for the last 14 days, builds a template + Gemma insight,
    // then overwrites mood_summary.txt.
    unawaited(_generateAndWriteMoodSummary());

    return MoodPipelineResult(
      resolvedMood:     resolvedMood,
      responseText:     responseText,
      resolvedBy:       resolvedBy,
      mobileBertResult: mobileBertResult,
      userConfirmed:    userConfirmed,
      timestamp:        now,
    );
  }

  // ── Quick-track summary generation ──────────────────────────────────────────

  /// Queries ISAR for the last 14 days of mood + 7 days of fitness, builds
  /// the template block, appends a Gemma insight, and overwrites mood_summary.txt.
  Future<void> _generateAndWriteMoodSummary() async {
    try {
      final entries       = await IsarService.instance.getRecentMoodEntries(days: 14);
      final fitnessScores = await IsarService.instance.getLastNDaysFitnessScores(14);
      final template      = QuickTrackService.buildMoodTemplate(entries, fitnessScores);

      String summary = template;
      try {
        final insight = await _gemma.generateSummaryInsight(template: template);
        summary = '$template\n\n$insight';
      } on StateError catch (e) {
        debugPrint('[MoodPipeline] Gemma not ready for summary insight: $e');
      }

      await _quickTrack.writeMoodSummary(summary);
    } catch (e) {
      debugPrint('[MoodPipeline] Mood summary write failed: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Condense a raw log entry to a short summary for the ISAR condensedLog field.
  String _condenseLog(String rawLog) {
    if (rawLog.length <= 100) return rawLog;
    return '${rawLog.substring(0, 97)}...';
  }

  String _extractLabelFromText(String text) {
    const labels = [
      'sadness', 'joy', 'love', 'anger', 'fear', 'surprise',
      'anxious', 'content', 'neutral',
    ];
    final lower = text.toLowerCase();

    // 1. Prefer the explicit MOOD_LABEL: tag — most reliable signal.
    for (final label in labels) {
      if (lower.contains('mood_label: $label')) return label;
    }

    // 2. Fall back to word-boundary matching to avoid false positives
    //    e.g. "fear" inside "fearful", "anger" inside "danger",
    //         "content" inside "discontent" or "contents".
    for (final label in labels) {
      if (RegExp(r'\b' + label + r'\b').hasMatch(lower)) return label;
    }

    return 'neutral';
  }
}