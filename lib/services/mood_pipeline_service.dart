// TODO(reconcile): SymptomAutoDetectorService.autoRegisterDetectedSymptoms()
// was removed from this pipeline in backend-v4. The service still exists at
// lib/services/symptom_auto_detector_service.dart and is called from UI screens
// (moodlog_screen.dart, symptoms_screen.dart). Decide whether to re-wire it here
// or keep it UI-only. See architecture notes in MERGE_NOTES.md.
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/mood_result.dart';
import '../models/escalation_level.dart';
import 'confidence_manager.dart';
import 'mobilebert_service.dart';
import 'model_lifecycle_service.dart';
import 'gemini_service.dart';
import '../database/isar_service.dart';
import '../database/mood_entry.dart';

/// Orchestrates USE CASE 1: Mood logging pipeline.
///
/// Full flow:
///   1. MobileBERT classifies mood from user log text
///   2. Confidence check → escalate to MiniGen (on-device) if needed
///   NOTE: logic may be incorrect -- this is replacing our old version.
///   3. Present mood to user for confirmation (optional — user can skip)
///   4. If user rejects → re-run with rejection context OR escalate
///   5. MiniGen generates personalised response using quick-track context
///   6. WRITE to ISAR database (source of truth)
///   7. WRITE condensed entry to quick-tracking file
class MoodPipelineService {
  final MobileBertService  _mobileBert;
  final GeminiService      _gemini;
  final ConfidenceManager  _confidence;

  // Tokenizer function injected from the app layer.
  // Must return { 'input_ids': List<int>, 'attention_mask': List<int> }
  // both padded to 128 tokens (MobileBERT's SEQ_LEN).
  final Map<String, List<int>> Function(String text, int maxLen) _tokenize;

  MoodPipelineService({
    required MobileBertService  mobileBert,
    required GeminiService      gemini,
    required ConfidenceManager  confidence,
    required Map<String, List<int>> Function(String, int) tokenize,
  })  : _mobileBert = mobileBert,
        _gemini     = gemini,
        _confidence = confidence,
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
    // Start the 15-second timer immediately so the model is unloaded shortly after inference completes.
    ModelLifecycleService.instance.scheduleUnload(ModelType.mobileBert);
    
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

    // ── STEP 4: MobileBERT passed — generate on-device response ─────────────
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
    final enrichedLog = rejectionContext != null
        ? '$userLog\n[User clarification: $rejectionContext]'
        : userLog;

    // ── Gemini (online only) ─────────────────────────────────────────────────
    if (isOnline) {
      try {
        final geminiRaw = await _gemini.analyzeMood(
          userLog:               enrichedLog,
          context:               '',
          rejectedMood:          rejectedMood,
          previousOnDeviceResponse: null,
        );
        final geminiLabel = _extractLabelFromText(geminiRaw);
        return _generateAndStore(
          userLog:             enrichedLog,
          resolvedMood:        geminiLabel,
          resolvedBy:          EscalationLevel.gemini,
          mobileBertResult:    mobileBertResult,
          userConfirmed:       false,
          currentFitnessScore: currentFitnessScore,
          onDeviceResponse:    geminiRaw,
        );
      } catch (e) {
        debugPrint('[MoodPipeline] Gemini failed, falling back to MobileBERT: $e');
      }
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
    String? onDeviceResponse,
  }) async {
    final responseText = onDeviceResponse ?? 'Mood logged as $resolvedMood.';

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

    return MoodPipelineResult(
      resolvedMood:     resolvedMood,
      responseText:     responseText,
      resolvedBy:       resolvedBy,
      mobileBertResult: mobileBertResult,
      userConfirmed:    userConfirmed,
      timestamp:        now,
    );
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