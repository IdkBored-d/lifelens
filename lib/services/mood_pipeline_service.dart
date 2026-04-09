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
import 'gemini_service.dart';
import 'template_mood_response_service.dart';
import 'template_summary_insight_service.dart';
import '../database/isar_service.dart';
import '../database/mood_entry.dart';

/// Orchestrates USE CASE 1: Mood logging pipeline.
///
/// Full flow:
///   1. MobileBERT classifies mood from user log text
///   2. Confidence check → escalate to template re-classifier if needed
///   3. Present mood to user for confirmation (optional — user can skip)
///   4. If user rejects → re-run with rejection context via template service
///   5. Template service generates personalised response using mood + context
///   6. WRITE to ISAR database (source of truth)
///   7. WRITE condensed entry to quick-tracking file (template insight, no LLM)
class MoodPipelineService {
  final MobileBertService               _mobileBert;
  final GeminiService                   _gemini;
  final ConfidenceManager               _confidence;
  final QuickTrackService               _quickTrack;
  final TemplateMoodResponseService     _templateMood;
  final TemplateSummaryInsightService   _templateInsight;

  // Tokenizer function injected from the app layer.
  // Must return { 'input_ids': List<int>, 'attention_mask': List<int> }
  // both padded to 128 tokens (MobileBERT's SEQ_LEN).
  final Map<String, List<int>> Function(String text, int maxLen) _tokenize;

  MoodPipelineService({
    required MobileBertService             mobileBert,
    required GeminiService                 gemini,
    required ConfidenceManager             confidence,
    required QuickTrackService             quickTrack,
    required TemplateMoodResponseService   templateMood,
    required TemplateSummaryInsightService templateInsight,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _mobileBert     = mobileBert,
        _gemini         = gemini,
        _confidence     = confidence,
        _quickTrack     = quickTrack,
        _templateMood   = templateMood,
        _templateInsight = templateInsight,
        _tokenize       = tokenize;

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

    // ── STEP 4: MobileBERT passed — generate template response ────────────
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

    // ── Template re-classification (primary — no network required) ───────
    final (templateMood, templateResponse) = _templateMood.analyze(
      enrichedLog:    enrichedLog,
      mbTopLabel:     mobileBertResult.topLabel,
      rejectedMood:   rejectedMood,
    );

    // If template resolved a non-neutral mood OR we are offline, use it
    if (templateMood != 'neutral' || !isOnline) {
      return _generateAndStore(
        userLog:             enrichedLog,
        resolvedMood:        templateMood,
        resolvedBy:          EscalationLevel.gemma, // re-using existing level label
        mobileBertResult:    mobileBertResult,
        userConfirmed:       false,
        currentFitnessScore: currentFitnessScore,
        responseText:        templateResponse,
      );
    }

    // ── Gemini fallback (online only) ────────────────────────────────────
    try {
      final context    = await _quickTrack.buildMoodContext();
      final geminiRaw  = await _gemini.analyzeMood(
        userLog:               enrichedLog,
        context:               context,
        rejectedMood:          rejectedMood,
        previousGemmaResponse: null,
      );

      final geminiLabel = _extractLabelFromText(geminiRaw);

      return _generateAndStore(
        userLog:             enrichedLog,
        resolvedMood:        geminiLabel,
        resolvedBy:          EscalationLevel.gemini,
        mobileBertResult:    mobileBertResult,
        userConfirmed:       false,
        currentFitnessScore: currentFitnessScore,
        responseText:        geminiRaw,
      );
    } catch (e) {
      debugPrint('[MoodPipeline] Gemini failed, using template result: $e');
    }

    // ── Final fallback: use template result ──────────────────────────────
    return _generateAndStore(
      userLog:             enrichedLog,
      resolvedMood:        templateMood != 'neutral' ? templateMood : mobileBertResult.topLabel,
      resolvedBy:          EscalationLevel.base,
      mobileBertResult:    mobileBertResult,
      userConfirmed:       false,
      currentFitnessScore: currentFitnessScore,
      responseText:        templateResponse,
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
    String? responseText,
  }) async {
    final response = responseText ?? 'Mood logged as $resolvedMood.';

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
      ..responseText         = response
      ..fitnessScoreSnapshot = currentFitnessScore
      ..timestamp            = now;

    await IsarService.instance.writeMoodEntry(moodEntry);

    // ── 2. REGENERATE MOOD QUICK-TRACK SUMMARY ───────────────────────────
    // Unawaited: ISAR is the source of truth (already written above).
    unawaited(_generateAndWriteMoodSummary());

    return MoodPipelineResult(
      resolvedMood:     resolvedMood,
      responseText:     response,
      resolvedBy:       resolvedBy,
      mobileBertResult: mobileBertResult,
      userConfirmed:    userConfirmed,
      timestamp:        now,
    );
  }

  // ── Quick-track summary generation ──────────────────────────────────────────

  /// Queries ISAR for the last 14 days of mood + 7 days of fitness, builds
  /// the template block, appends a template insight, and overwrites mood_summary.txt.
  Future<void> _generateAndWriteMoodSummary() async {
    try {
      final entries       = await IsarService.instance.getRecentMoodEntries(days: 14);
      final fitnessScores = await IsarService.instance.getLastNDaysFitnessScores(14);
      final template      = QuickTrackService.buildMoodTemplate(entries, fitnessScores);
      final insight       = _templateInsight.generateMoodInsight(template);
      final summary       = '$template\n\n$insight';
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
    for (final label in labels) {
      if (RegExp(r'\b' + label + r'\b').hasMatch(lower)) return label;
    }

    return 'neutral';
  }
}
