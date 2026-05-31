import 'dart:convert';

import '../database/isar_service.dart';
import 'minigen_prompt.dart' show buildContextBlock;

// ── Value types ───────────────────────────────────────────────────────────────

class MoodSnapshot {
  const MoodSnapshot({
    required this.label,
    required this.intensity,
    this.notes,
    this.bertPrediction,
    this.bertTopProb,
    required this.timestamp,
  });

  final String label;
  final int intensity;      // parsed from condensedLog; 3 when absent
  final String? notes;      // stripped rawLog; null when rawLog == mood label
  final String? bertPrediction;
  final double? bertTopProb;
  final DateTime timestamp;
}

class SymptomSnapshot {
  const SymptomSnapshot({
    required this.symptoms,
    this.predictedAilment,
    this.topTreatment,
    required this.status,
    required this.diagnoses,
    this.disEmbedScore,
    required this.ragUsed,
    required this.timestamp,
  });

  final List<String> symptoms;      // raw symptom words from symptomList
  final String? predictedAilment;   // top Weaviate match; null when empty/sentinel
  final String? topTreatment;       // treatment for top Weaviate match; null when absent
  final String status;
  final List<String> diagnoses;     // top disease names from diagnosesJson (up to 3)
  final double? disEmbedScore;
  final bool ragUsed;
  final DateTime timestamp;
}

class LifeLensContext {
  const LifeLensContext({
    required this.userName,
    this.latestMood,
    required this.recentMoods,
    required this.activeSymptoms,
    this.intelligenceSummary,
    this.currentTone,
    required this.latestAction,
    required this.assembledAt,
  });

  final String userName;
  final MoodSnapshot? latestMood;
  final List<MoodSnapshot> recentMoods;   // newest first, length ≤ recentMoodWindow
  final List<SymptomSnapshot> activeSymptoms;
  final String? intelligenceSummary;
  final String? currentTone;              // MobileBERT-derived tone for the current session
  final String latestAction;              // 'Chat' | 'Mood Log' | 'Symptom Log'
  final DateTime assembledAt;
}

// ── Builder ───────────────────────────────────────────────────────────────────

class ContextBuilderService {
  ContextBuilderService(this._isar);

  final IsarService _isar;

  static const _ailmentSentinels = {'auto-detected', 'auto_detector'};
  static final _intensityRe = RegExp(r'([1-5])\/5');
  static final _contextMetaRe = RegExp(
    r'\s*\[context:\s*[^\]]+\]\s*',
    caseSensitive: false,
  );

  Future<LifeLensContext> build({
    required String userName,
    required String latestAction,
    String? intelligenceSummary,
    String? currentTone,
    int recentMoodWindow = 5,
  }) async {
    final moodEntries = await _isar.getRecentMoodEntries(days: 30);
    final symptomEntries = await _isar.getActiveSymptomEntries();

    final moodSnapshots = moodEntries.map((e) {
      final match = _intensityRe.firstMatch(e.condensedLog);
      final intensity =
          match != null ? (int.tryParse(match.group(1) ?? '') ?? 3) : 3;
      final rawStripped = e.rawLog
          .replaceAll(_contextMetaRe, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final notes = (rawStripped.isEmpty ||
              rawStripped.toLowerCase() == e.resolvedMood.toLowerCase())
          ? null
          : rawStripped;
      return MoodSnapshot(
        label: e.resolvedMood,
        intensity: intensity,
        notes: notes,
        bertPrediction: e.mobileBertPrediction,
        bertTopProb: e.mobileBertTopProb,
        timestamp: e.timestamp,
      );
    }).toList();

    final activeSnapshots = symptomEntries.map((e) {
      final ailment = e.predictedAilment.trim();
      final cleanAilment =
          (ailment.isEmpty || _ailmentSentinels.contains(ailment.toLowerCase()))
              ? null
              : ailment;

      List<String> diagnoses = [];
      String? topTreatment;
      try {
        final parsed = jsonDecode(e.diagnosesJson) as List<dynamic>;
        diagnoses = parsed
            .take(3)
            .map((d) =>
                (d as Map<String, dynamic>)['disease'] as String? ?? '')
            .where((d) => d.isNotEmpty)
            .toList();
        if (parsed.isNotEmpty) {
          final t = (parsed.first as Map<String, dynamic>)['treatment'] as String?;
          if (t != null && t.trim().isNotEmpty) topTreatment = t.trim();
        }
      } catch (_) {}

      return SymptomSnapshot(
        symptoms:
            e.symptomList.where((s) => s.trim().isNotEmpty).toList(),
        predictedAilment: cleanAilment,
        topTreatment: topTreatment,
        status: e.status,
        diagnoses: diagnoses,
        disEmbedScore: e.disEmbedScore,
        ragUsed: e.ragUsed,
        timestamp: e.timestamp,
      );
    }).toList();

    return LifeLensContext(
      userName: userName,
      latestMood: moodSnapshots.isEmpty ? null : moodSnapshots.first,
      recentMoods: moodSnapshots.take(recentMoodWindow).toList(),
      activeSymptoms: activeSnapshots,
      intelligenceSummary: intelligenceSummary,
      currentTone: currentTone,
      latestAction: latestAction,
      assembledAt: DateTime.now(),
    );
  }
}

// ── Adapters ──────────────────────────────────────────────────────────────────

/// Returns the MiniGen bracket entries map for use with [buildPrompt].
///
/// Slot semantics:
///   SYMPTOMS         = raw symptom words (cough, fatigue, …)
///   CONDITIONS       = top Weaviate-predicted ailments, sorted by disEmbedScore desc
///   CONDITION_STEPS  = treatment steps for the highest-certainty condition
///   CURRENT_TONE     = MobileBERT-derived tone for the current session (chat path only)
Map<String, String?> toMiniGenEntries(LifeLensContext ctx) {
  final latest = ctx.latestMood;

  final String? moodLog;
  if (latest != null) {
    moodLog = latest.notes != null
        ? '${latest.label} (${latest.intensity}/5): ${latest.notes}'
        : ctx.recentMoods.take(3).map((m) => m.label).join(', ');
  } else {
    moodLog = null;
  }

  final allSymptoms = ctx.activeSymptoms.expand((s) => s.symptoms).toSet();
  final symptomsStr = allSymptoms.isNotEmpty ? allSymptoms.join(', ') : null;

  final sorted = [...ctx.activeSymptoms]
    ..sort((a, b) => (b.disEmbedScore ?? 0).compareTo(a.disEmbedScore ?? 0));
  final conditionsStr = sorted
          .where((s) => s.predictedAilment != null)
          .take(3)
          .map((s) => s.predictedAilment!)
          .join(', ')
          .let((s) => s.isEmpty ? null : s);
  final conditionStepsStr = sorted
          .map((s) => s.topTreatment)
          .firstWhere((t) => t != null && t.isNotEmpty, orElse: () => null);

  return {
    'USER':             ctx.userName,
    'TRENDS':           ctx.intelligenceSummary,
    'SYMPTOMS':         symptomsStr,
    'CONDITIONS':       conditionsStr,
    'CONDITION_STEPS':  conditionStepsStr,
    'MOOD_LOG':         moodLog,
    'CURRENT_TONE':     ctx.currentTone,
    'LATEST_ACTION':    ctx.latestAction,
  };
}

/// Convenience: bracket string equivalent to buildContextBlock(toMiniGenEntries(ctx)).
String toMiniGenBrackets(LifeLensContext ctx) =>
    buildContextBlock(toMiniGenEntries(ctx));

/// Returns the backend JSON payload fields for the /api/v1/minime/chat endpoint.
/// Caller should merge with user_message, chat_history, and intelligence_* fields.
Map<String, dynamic> toBackendJson(LifeLensContext ctx) {
  final latest = ctx.latestMood;

  final allSymptomWords =
      ctx.activeSymptoms.expand((s) => s.symptoms).toSet().toList();

  final sorted = [...ctx.activeSymptoms]
    ..sort((a, b) => (b.disEmbedScore ?? 0).compareTo(a.disEmbedScore ?? 0));
  final conditionNames = sorted
      .where((s) => s.predictedAilment != null)
      .take(3)
      .map((s) => s.predictedAilment!)
      .toList();

  return {
    'latest_mood_label':     latest?.label ?? 'neutral',
    'latest_mood_intensity': latest?.intensity ?? 0,
    'latest_mood_notes':     latest?.notes ?? '',
    'recent_moods':          ctx.recentMoods.map((m) => m.label).toList(),
    'active_symptoms':       allSymptomWords,
    'predicted_conditions':  conditionNames,
    if (ctx.intelligenceSummary != null && ctx.intelligenceSummary!.isNotEmpty)
      'summary_context': ctx.intelligenceSummary,
  };
}

// Dart doesn't have a built-in .let() so we add a minimal extension here.
extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
