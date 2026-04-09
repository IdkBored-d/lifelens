import 'dart:math' show sqrt;

import '../database/mood_entry.dart';
import '../database/symptom_entry.dart';
import 'eod_pipeline_service.dart' show EodCorrelation;

/// Deterministic end-of-day correlation engine.
///
/// Replaces Gemma's `generateEodSummary()` with statistical feature computation
/// + template-based narrative generation. Ported from `backend/services/intelligence.py`.
///
/// Produces:
///   - A user-facing 2–3 sentence narrative summary.
///   - A structured [EodCorrelation] with flag, flagReason, and correlationSummary.
class EodCorrelationEngine {
  const EodCorrelationEngine();

  /// Analyse the day's data and produce a summary + correlation.
  ///
  /// [recentMoods]     last 14 days of mood entries, newest first.
  /// [activeSymptoms]  currently active/monitoring symptom entries.
  /// [fitnessScores]   last 14 days of fitness scores, index 0 = most recent.
  /// [fitnessTrend]    "upward", "downward", or "stable".
  (String summaryText, EodCorrelation correlation) analyze({
    required List<MoodEntry>    recentMoods,
    required List<SymptomEntry> activeSymptoms,
    required List<double>       fitnessScores,
    required String             fitnessTrend,
    required double             todayFitnessScore,
  }) {
    final moodLabels  = recentMoods.map((e) => e.resolvedMood).toList();
    final moodScores  = _labelsToScores(moodLabels);
    final symptomCount = activeSymptoms.length;

    // ── Feature computation ─────────────────────────────────────────────────
    final moodAvg3  = _mean(_window(moodScores, 3));
    final moodAvg7  = _mean(_window(moodScores, 7));
    final moodSlope7 = _slope(_window(moodScores, 7));
    final moodVol7  = sqrt(_variance(_window(moodScores, 7)));

    final fitAvg7   = _mean(_window(fitnessScores, 7));
    final fitSlope7 = _slope(_window(fitnessScores, 7));

    final lowMood   = moodAvg3 <= 2.0;
    final lowFit    = fitAvg7 < 40.0;
    final moodDeclining = moodSlope7 < -0.1;
    final fitDeclining  = fitSlope7 < -2.0;
    final hasSymptoms   = symptomCount > 0;
    final hasUrgent     = activeSymptoms.any((s) => s.status == 'urgent');

    // ── Correlation detection ───────────────────────────────────────────────
    final correlations = <String>[];
    bool flag = false;
    String flagReason = '';

    if (moodDeclining && fitDeclining) {
      correlations.add('declining mood and fitness trend together');
    }
    if (lowMood && hasSymptoms) {
      correlations.add('low mood alongside active symptoms');
    }
    if (moodVol7 > 1.5) {
      correlations.add('high mood variability this week');
    }
    if (hasUrgent) {
      flag = true;
      flagReason = 'Active symptoms marked as urgent — professional evaluation recommended.';
    } else if (lowMood && moodDeclining && hasSymptoms) {
      flag = true;
      flagReason = 'Combination of declining mood and active symptoms detected.';
    }

    final correlationSummary = correlations.isEmpty
        ? 'No significant cross-domain correlations detected.'
        : 'Patterns noted: ${correlations.join("; ")}.';

    // ── Narrative generation ────────────────────────────────────────────────
    final narrative = _buildNarrative(
      moodAvg7: moodAvg7,
      moodSlope7: moodSlope7,
      fitnessTrend: fitnessTrend,
      todayFitnessScore: todayFitnessScore,
      symptomCount: symptomCount,
      hasUrgent: hasUrgent,
      lowMood: lowMood,
      moodDeclining: moodDeclining,
      correlations: correlations,
      latestMood: moodLabels.isNotEmpty ? moodLabels.first : 'neutral',
    );

    final eodCorrelation = EodCorrelation(
      flag:       flag,
      flagReason: flagReason,
      summary:    correlationSummary,
    );

    return (narrative, eodCorrelation);
  }

  // ── Narrative builder ────────────────────────────────────────────────────────

  String _buildNarrative({
    required double  moodAvg7,
    required double  moodSlope7,
    required String  fitnessTrend,
    required double  todayFitnessScore,
    required int     symptomCount,
    required bool    hasUrgent,
    required bool    lowMood,
    required bool    moodDeclining,
    required List<String> correlations,
    required String  latestMood,
  }) {
    final sentences = <String>[];

    // Sentence 1: Mood summary
    if (moodSlope7 > 0.15) {
      sentences.add("Your mood has been trending upward this week — that's a positive sign worth acknowledging.");
    } else if (moodSlope7 < -0.15 && lowMood) {
      sentences.add("Your mood has been lower than usual lately. It is okay to have harder stretches — be gentle with yourself.");
    } else if (moodSlope7 < -0.15) {
      sentences.add('Your mood has dipped a little over the past few days. Keep tracking — patterns help identify what helps.');
    } else if (moodAvg7 >= 3.5) {
      sentences.add('Your mood has been steady and fairly positive over the past week. Nice to see that consistency.');
    } else {
      sentences.add("You've been checking in consistently, which is the most important habit for understanding your wellbeing.");
    }

    // Sentence 2: Fitness + symptoms combo
    if (hasUrgent) {
      sentences.add('Some of your active symptoms may warrant a professional check-in — consider reaching out to a healthcare provider soon.');
    } else if (symptomCount > 1 && moodDeclining) {
      sentences.add("Having multiple active symptoms while your mood is dipping can feel draining. Rest and hydration are a good starting point.");
    } else if (symptomCount > 0) {
      sentences.add('You have active symptoms to keep monitoring. Note any changes and consult a professional if things worsen.');
    } else if (fitnessTrend == 'upward') {
      sentences.add('Your fitness trend is heading upward — physical momentum like this often carries over into energy and mood.');
    } else if (fitnessTrend == 'downward' && moodDeclining) {
      sentences.add('Both your fitness and mood have been declining — even a short walk or rest day can help break that cycle.');
    } else if (fitnessTrend == 'stable') {
      sentences.add('Your fitness level has been consistent, which provides a stable base to build on.');
    }

    // Sentence 3: Actionable closing
    if (correlations.contains('declining mood and fitness trend together')) {
      sentences.add('Try to prioritize one small act of self-care today — movement, sleep, or connection — and see what shifts.');
    } else if (correlations.contains('high mood variability this week')) {
      sentences.add('Your mood has been variable this week. Identifying triggers in your logs can help bring more consistency.');
    } else {
      // Generic positive close
      final closes = [
        'Keep logging — every entry helps build a clearer picture of your health.',
        'You are doing the right thing by staying consistent with your check-ins.',
        'Small, consistent actions add up. Keep building on what you track here.',
      ];
      final idx = (latestMood.hashCode.abs()) % closes.length;
      sentences.add(closes[idx]);
    }

    return sentences.take(3).join(' ');
  }

  // ── Statistical helpers (ported from intelligence.py) ────────────────────────

  List<double> _window(List<num> values, int n) {
    if (values.isEmpty) return [];
    final start = values.length > n ? values.length - n : 0;
    return values.sublist(start).map((v) => v.toDouble()).toList();
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _variance(List<double> values) {
    if (values.length < 2) return 0.0;
    final m = _mean(values);
    return values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / values.length;
  }

  double _slope(List<double> values) {
    if (values.length < 2) return 0.0;
    final n = values.length;
    final xs = List<double>.generate(n, (i) => i.toDouble());
    final xMean = _mean(xs);
    final yMean = _mean(values);
    double num = 0;
    double den = 0;
    for (int i = 0; i < n; i++) {
      num += (xs[i] - xMean) * (values[i] - yMean);
      den += (xs[i] - xMean) * (xs[i] - xMean);
    }
    return den == 0 ? 0.0 : num / den;
  }

  /// Convert mood label strings to ordinal scores for trend computation.
  List<double> _labelsToScores(List<String> labels) {
    return labels.map((l) => _moodScore(l)).toList();
  }

  double _moodScore(String mood) => switch (mood.toLowerCase()) {
    'joy'      => 5.0,
    'love'     => 4.5,
    'content'  => 4.0,
    'surprise' => 3.5,
    'neutral'  => 3.0,
    'anxious'  => 2.5,
    'fear'     => 2.0,
    'sadness'  => 1.5,
    'anger'    => 1.0,
    _          => 3.0,
  };
}
