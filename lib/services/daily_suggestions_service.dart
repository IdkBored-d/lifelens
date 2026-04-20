import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/eod_entry.dart';
import 'package:lifelens/database/fitness_entry.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/services/minime_backend_service.dart';
import 'package:lifelens/sleep_store.dart';

import '../models/sleep.dart';

class DailySuggestion {
  const DailySuggestion({
    required this.title,
    required this.reason,
    required this.action,
    this.icon = Icons.tips_and_updates_rounded,
    this.category = 'Suggestion',
    this.priority = 0,
    this.sourceSignals = const <String>[],
  });

  final String title;
  final String reason;
  final String action;
  final IconData icon;
  final String category;
  final int priority;
  final List<String> sourceSignals;
}

class DailySuggestionsSnapshot {
  const DailySuggestionsSnapshot({
    required this.generatedAt,
    required this.suggestions,
    required this.summary,
    required this.latestMoodLabel,
    required this.activeSymptomCount,
    required this.latestSleepHours,
    required this.latestFitnessScore,
    required this.todayExerciseCount,
  });

  final DateTime generatedAt;
  final List<DailySuggestion> suggestions;
  final String summary;
  final String latestMoodLabel;
  final int activeSymptomCount;
  final double? latestSleepHours;
  final double? latestFitnessScore;
  final int todayExerciseCount;
}

class _RequiredLogStatus {
  const _RequiredLogStatus({
    required this.hasAnyRequiredLogsToday,
    required this.hasAllRequiredLogsToday,
    required this.missingRequiredLogs,
  });

  final bool hasAnyRequiredLogsToday;
  final bool hasAllRequiredLogsToday;
  final List<String> missingRequiredLogs;
}

class DailySuggestionsService {
  DailySuggestionsService._();

  static final DailySuggestionsService instance = DailySuggestionsService._();

  Future<DailySuggestionsSnapshot> buildSnapshot({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    String? suggestionWindow,
    String? triggerReason,
    bool eventOverride = false,
  }) async {
    await AppServices.isar.init();

    final exerciseStore = ExerciseStore();
    await exerciseStore.ensureReady();
    await exerciseStore.refreshFromCloud();

    final activeSymptoms = await AppServices.isar.getActiveSymptomEntries();
    final recentSymptoms = await AppServices.isar.getRecentSymptomEntries(
      days: 45,
    );
    final recentFitness = await AppServices.isar.getRecentFitnessEntries(
      days: 45,
    );
    final recentEod = await AppServices.isar.getRecentEodEntries(days: 30);
    final recentSessions = await AppServices.isar.getRecentChatSessions(
      limit: 6,
    );

    final recentChatMessages = <String>[];
    final backendHistory = <MiniMeChatTurn>[];
    for (final session in recentSessions) {
      final messages = await AppServices.isar.getMessagesForSession(
        session.sessionId,
      );
      for (final message in messages) {
        final trimmed = message.text.trim();
        if (trimmed.isEmpty) continue;
        recentChatMessages.add(trimmed);
        backendHistory.add(MiniMeChatTurn(role: message.role, text: trimmed));
      }
    }

    final latestMood = moodStore.items.isEmpty ? null : moodStore.items.first;
    final latestSleep = sleepStore.items.isEmpty
        ? null
        : sleepStore.items.first;
    final latestFitness = recentFitness.isEmpty ? null : recentFitness.first;
    final todayExerciseCount = _todayExerciseCount(exerciseStore);
    final requiredLogStatus = await _requiredLogStatus(
      moodStore: moodStore,
      sleepStore: sleepStore,
      todayExerciseCount: todayExerciseCount,
    );

    if (!requiredLogStatus.hasAnyRequiredLogsToday) {
      return DailySuggestionsSnapshot(
        generatedAt: DateTime.now(),
        suggestions: const <DailySuggestion>[],
        summary: _buildSummary(
          latestMoodLabel: latestMood?.moodLabel ?? 'No recent mood',
          latestSleepHours: latestSleep == null
              ? null
              : latestSleep.duration.inMinutes / 60.0,
          activeSymptomCount: activeSymptoms.length,
          latestFitnessScore: latestFitness?.fitnessScore,
          todayExerciseCount: todayExerciseCount,
        ),
        latestMoodLabel: latestMood?.moodLabel ?? 'Unknown',
        activeSymptomCount: activeSymptoms.length,
        latestSleepHours: latestSleep == null
            ? null
            : latestSleep.duration.inMinutes / 60.0,
        latestFitnessScore: latestFitness?.fitnessScore,
        todayExerciseCount: todayExerciseCount,
      );
    }

    if (!requiredLogStatus.hasAllRequiredLogsToday) {
      return DailySuggestionsSnapshot(
        generatedAt: DateTime.now(),
        suggestions: const <DailySuggestion>[],
        summary: _buildSummary(
          latestMoodLabel: latestMood?.moodLabel ?? 'No recent mood',
          latestSleepHours: latestSleep == null
              ? null
              : latestSleep.duration.inMinutes / 60.0,
          activeSymptomCount: activeSymptoms.length,
          latestFitnessScore: latestFitness?.fitnessScore,
          todayExerciseCount: todayExerciseCount,
        ),
        latestMoodLabel: latestMood?.moodLabel ?? 'Unknown',
        activeSymptomCount: activeSymptoms.length,
        latestSleepHours: latestSleep == null
            ? null
            : latestSleep.duration.inMinutes / 60.0,
        latestFitnessScore: latestFitness?.fitnessScore,
        todayExerciseCount: todayExerciseCount,
      );
    }

    final holisticSuggestions = await _generateHolisticSuggestions(
      moodStore: moodStore,
      sleepStore: sleepStore,
      activeSymptoms: activeSymptoms,
      recentSymptoms: recentSymptoms,
      recentFitness: recentFitness,
      recentEod: recentEod,
      exerciseStore: exerciseStore,
      backendHistory: backendHistory,
      recentChatMessages: recentChatMessages,
      todayExerciseCount: todayExerciseCount,
      suggestionWindow: suggestionWindow,
      triggerReason: triggerReason,
      eventOverride: eventOverride,
    );

    final suggestions = holisticSuggestions;

    final visibleSuggestions = suggestions
        .where((item) => item.action.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);

    return DailySuggestionsSnapshot(
      generatedAt: DateTime.now(),
      suggestions: visibleSuggestions,
      summary: _buildSummary(
        latestMoodLabel: latestMood?.moodLabel ?? 'No recent mood',
        latestSleepHours: latestSleep == null
            ? null
            : latestSleep.duration.inMinutes / 60.0,
        activeSymptomCount: activeSymptoms.length,
        latestFitnessScore: latestFitness?.fitnessScore,
        todayExerciseCount: todayExerciseCount,
      ),
      latestMoodLabel: latestMood?.moodLabel ?? 'Unknown',
      activeSymptomCount: activeSymptoms.length,
      latestSleepHours: latestSleep == null
          ? null
          : latestSleep.duration.inMinutes / 60.0,
      latestFitnessScore: latestFitness?.fitnessScore,
      todayExerciseCount: todayExerciseCount,
    );
  }

  Future<_RequiredLogStatus> _requiredLogStatus({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required int todayExerciseCount,
  }) async {
    final today = DateTime.now();

    final hasMoodToday = moodStore.items.any(
      (item) => _isSameDay(item.createdAt, today),
    );
    final hasSleepToday = sleepStore.items.any(
      (item) =>
          _isSameDay(item.date, today) || _isSameDay(item.wakeTime, today),
    );

    final missing = <String>[
      if (!hasMoodToday) 'mood',
      if (!hasSleepToday) 'sleep',
      if (todayExerciseCount <= 0) 'exercise',
    ];

    return _RequiredLogStatus(
      hasAnyRequiredLogsToday:
          hasMoodToday || hasSleepToday || todayExerciseCount > 0,
      hasAllRequiredLogsToday: missing.isEmpty,
      missingRequiredLogs: missing,
    );
  }

  Future<List<DailySuggestion>> _generateHolisticSuggestions({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required List<SymptomEntry> activeSymptoms,
    required List<SymptomEntry> recentSymptoms,
    required List<FitnessEntry> recentFitness,
    required List<EodEntry> recentEod,
    required ExerciseStore exerciseStore,
    required List<MiniMeChatTurn> backendHistory,
    required List<String> recentChatMessages,
    required int todayExerciseCount,
    String? suggestionWindow,
    String? triggerReason,
    bool eventOverride = false,
  }) async {
    final summaryContext = await _buildHolisticSummaryContext(
      moodStore: moodStore,
      sleepStore: sleepStore,
      activeSymptoms: activeSymptoms,
      recentSymptoms: recentSymptoms,
      recentFitness: recentFitness,
      recentEod: recentEod,
      exerciseStore: exerciseStore,
      recentChatMessages: recentChatMessages,
      todayExerciseCount: todayExerciseCount,
      suggestionWindow: suggestionWindow,
      triggerReason: triggerReason,
      eventOverride: eventOverride,
    );

    final latestMood = moodStore.items.isEmpty ? null : moodStore.items.first;
    final allRecentLogs = _buildCombinedRecentLogs(
      moodStore: moodStore,
      sleepStore: sleepStore,
      recentSymptoms: recentSymptoms,
      recentFitness: recentFitness,
      recentEod: recentEod,
      exerciseStore: exerciseStore,
      recentChatMessages: recentChatMessages,
    );

    try {
      final reply = await MiniMeBackendService.instance.suggestions(
        latestMoodLabel: latestMood?.moodLabel ?? 'neutral',
        latestMoodIntensity: _moodScoreForLabel(latestMood?.moodLabel ?? ''),
        latestMoodNotes: latestMood?.notes ?? '',
        recentMoods: moodStore.items
            .take(10)
            .map((item) => item.moodLabel)
            .toList(growable: false),
        recentLogs: allRecentLogs,
        activeSymptoms: _flattenSymptoms(activeSymptoms),
        history: backendHistory,
        summaryContext: summaryContext,
      );

      final suggestions = reply.suggestions
          .map(
            (item) => DailySuggestion(
              title: _titleFromAction(item.action),
              action: item.action.trim(),
              reason: item.reason.trim(),
              icon: _iconForAction(item.action),
              category: _categoryForSuggestion(item.action, item.reason),
              priority: 100,
              sourceSignals: const ['whole-picture analysis'],
            ),
          )
          .where((item) => item.action.isNotEmpty)
          .toList(growable: false);

      if (suggestions.isNotEmpty) {
        return suggestions;
      }
    } catch (_) {
      // Suggestions stay empty when backend generation is unavailable.
    }

    return const [];
  }

  Future<String> _buildHolisticSummaryContext({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required List<SymptomEntry> activeSymptoms,
    required List<SymptomEntry> recentSymptoms,
    required List<FitnessEntry> recentFitness,
    required List<EodEntry> recentEod,
    required ExerciseStore exerciseStore,
    required List<String> recentChatMessages,
    required int todayExerciseCount,
    String? suggestionWindow,
    String? triggerReason,
    bool eventOverride = false,
  }) async {
    final moodSummary = _buildMoodContext(moodStore.items);
    final sleepSummary = _buildSleepContext(sleepStore.items);
    final symptomSummary = _buildSymptomContext(activeSymptoms, recentSymptoms);
    final fitnessSummary = _buildFitnessContext(recentFitness);
    final exerciseSummary = _buildExerciseContext(
      exerciseStore,
      todayExerciseCount,
    );
    final eodSummary = _buildEodContext(recentEod);
    final crossSignalSummary = _buildCrossSignalContext(
      moodStore: moodStore,
      sleepStore: sleepStore,
      activeSymptoms: activeSymptoms,
      recentSymptoms: recentSymptoms,
      recentFitness: recentFitness,
      exerciseStore: exerciseStore,
      todayExerciseCount: todayExerciseCount,
    );
    final chatSummary = recentChatMessages.isEmpty
        ? 'No recent Mini-Me chat context.'
        : 'Recent Mini-Me chat themes: ${recentChatMessages.take(4).map(_trimShort).join(' | ')}';
    final backendGuidance =
        'Use all available logs together to find cross-category patterns, likely triggers, repeated combinations, and small next steps that fit the user\'s real energy.';
    final deliveryGuidance = [
      if ((suggestionWindow ?? '').trim().isNotEmpty)
        'Suggestion delivery window: ${suggestionWindow!.trim()}.',
      if ((triggerReason ?? '').trim().isNotEmpty)
        'Suggestion trigger reason: ${triggerReason!.trim()}.',
      if (eventOverride)
        'Event override is active: prioritize a supportive, immediate, low-friction action.',
    ].join(' ');

    return [
      moodSummary,
      sleepSummary,
      symptomSummary,
      fitnessSummary,
      exerciseSummary,
      eodSummary,
      crossSignalSummary,
      chatSummary,
      backendGuidance,
      deliveryGuidance,
    ].where((part) => part.trim().isNotEmpty).join('\n\n');
  }

  List<String> _buildCombinedRecentLogs({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required List<SymptomEntry> recentSymptoms,
    required List<FitnessEntry> recentFitness,
    required List<EodEntry> recentEod,
    required ExerciseStore exerciseStore,
    required List<String> recentChatMessages,
  }) {
    final combined = <_CombinedLogPoint>[];

    for (final mood in moodStore.items.take(18)) {
      final details = <String>[
        'mood ${mood.moodLabel}',
        if (mood.notes.trim().isNotEmpty) mood.notes.trim(),
        if (mood.tags.isNotEmpty) 'context ${mood.tags.join(', ')}',
      ];
      combined.add(
        _CombinedLogPoint(
          timestamp: mood.createdAt,
          text: 'Mood log: ${details.join(' | ')}',
        ),
      );
    }

    for (final sleep in sleepStore.items.take(14)) {
      final details = <String>[
        '${(sleep.duration.inMinutes / 60.0).toStringAsFixed(1)}h',
        'quality ${sleep.quality.label}',
        if (sleep.notes.trim().isNotEmpty) sleep.notes.trim(),
      ];
      combined.add(
        _CombinedLogPoint(
          timestamp: sleep.date,
          text: 'Sleep log: ${details.join(' | ')}',
        ),
      );
    }

    for (final entry in recentSymptoms.take(16)) {
      final details = <String>[
        if (entry.symptomList.isNotEmpty) entry.symptomList.join(', '),
        'status ${entry.status}',
        if (entry.predictedAilment.trim().isNotEmpty)
          'possible ailment ${entry.predictedAilment.trim()}',
      ];
      combined.add(
        _CombinedLogPoint(
          timestamp: entry.timestamp,
          text: 'Symptom log: ${details.join(' | ')}',
        ),
      );
    }

    for (final entry in recentFitness.take(12)) {
      final details = <String>[
        'score ${entry.fitnessScore.toStringAsFixed(0)}/100',
        'sleep input ${entry.sleepHours.toStringAsFixed(1)}h',
        'activity ${entry.activityIndex.toStringAsFixed(1)}',
        'heart rate ${entry.heartRate.toStringAsFixed(0)}',
      ];
      combined.add(
        _CombinedLogPoint(
          timestamp: entry.inferenceTimestamp,
          text: 'Fitness log: ${details.join(' | ')}',
        ),
      );
    }

    for (final entry in recentEod.take(10)) {
      final details = <String>[
        _trimShort(entry.summaryText),
        if ((entry.correlationSummary ?? '').trim().isNotEmpty)
          'correlations ${(entry.correlationSummary ?? '').trim()}',
      ];
      combined.add(
        _CombinedLogPoint(
          timestamp: entry.timestamp,
          text: 'End-of-day summary: ${details.join(' | ')}',
        ),
      );
    }

    for (final item in exerciseStore.getRecentExerciseHistory(limit: 16)) {
      final timestamp = DateTime.tryParse((item['timestamp'] ?? '').trim());
      if (timestamp == null) {
        continue;
      }
      final name = (item['exerciseName'] ?? '').trim();
      final duration = (item['durationMinutes'] ?? '').trim();
      final sets = (item['sets'] ?? '').trim();
      final reps = (item['reps'] ?? '').trim();
      final noExercise = (item['noExercise'] ?? '').trim() == 'true';
      final notes = (item['notes'] ?? '').trim();
      final details = <String>[
        if (name.isNotEmpty)
          name
        else
          (item['exerciseId'] ?? 'activity').trim(),
        if (noExercise)
          'no exercise'
        else if (sets.isNotEmpty && reps.isNotEmpty)
          '$sets sets x $reps reps'
        else if (duration.isNotEmpty)
          '$duration min',
        if (notes.isNotEmpty) notes,
      ];
      combined.add(
        _CombinedLogPoint(
          timestamp: timestamp,
          text: 'Exercise log: ${details.join(' | ')}',
        ),
      );
    }

    for (var i = 0; i < recentChatMessages.take(12).length; i++) {
      final message = recentChatMessages[i].trim();
      if (message.isEmpty) {
        continue;
      }
      combined.add(
        _CombinedLogPoint(
          timestamp: DateTime.now().subtract(Duration(minutes: i)),
          text: 'Mini-Me chat: ${_trimShort(message)}',
        ),
      );
    }

    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return combined
        .map((item) => '${_formatDateLabel(item.timestamp)}: ${item.text}')
        .where((text) => text.trim().isNotEmpty)
        .take(28)
        .toList(growable: false);
  }

  String _buildMoodContext(List<MoodCheckIn> moods) {
    if (moods.isEmpty) {
      return 'Mood logs: none yet.';
    }
    final recent = moods.take(7).toList(growable: false);
    final labels = recent.map((item) => item.moodLabel).toList(growable: false);
    final distinctLabels = labels.toSet().length;
    final positiveCount = recent
        .where((item) => _moodScoreForLabel(item.moodLabel) >= 4)
        .length;
    final heavyCount = recent
        .where((item) => _moodScoreForLabel(item.moodLabel) <= 2)
        .length;
    final notes = recent
        .map((item) => item.notes.trim())
        .where((text) => text.isNotEmpty)
        .take(4)
        .map(_trimShort)
        .toList(growable: false);
    final volatility = distinctLabels >= 4
        ? 'more variable than usual'
        : distinctLabels >= 2
        ? 'mixed'
        : 'fairly consistent';
    return 'Mood logs: latest ${recent.first.moodLabel}. Recent moods: ${labels.join(', ')}. Pattern looks $volatility, with $positiveCount higher-energy check-ins and $heavyCount heavier check-ins.${notes.isEmpty ? '' : ' Recent notes: ${notes.join(' | ')}'}';
  }

  String _buildSleepContext(List<Sleep> sleepLogs) {
    if (sleepLogs.isEmpty) {
      return 'Sleep logs: none yet.';
    }
    final recent = sleepLogs.take(7).toList(growable: false);
    final avgHours =
        recent
            .map((item) => item.duration.inMinutes / 60.0)
            .fold<double>(0, (sum, value) => sum + value) /
        recent.length;
    final qualityLabels = recent.map((item) => item.quality.label).join(', ');
    final lowSleepCount = recent
        .where((item) => (item.duration.inMinutes / 60.0) < 7.0)
        .length;
    return 'Sleep logs: average ${avgHours.toStringAsFixed(1)} hours over the recent entries. Sleep quality pattern: $qualityLabels. ${lowSleepCount == 0 ? 'Recent sleep has mostly met the baseline.' : '$lowSleepCount recent entries were under 7 hours.'}';
  }

  String _buildSymptomContext(
    List<SymptomEntry> activeSymptoms,
    List<SymptomEntry> recentSymptoms,
  ) {
    if (activeSymptoms.isEmpty && recentSymptoms.isEmpty) {
      return 'Symptom logs: none.';
    }
    final active = _flattenSymptoms(activeSymptoms);
    final recent = recentSymptoms
        .take(6)
        .expand((entry) => entry.symptomList)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final monitoringCount = recentSymptoms
        .where((entry) => entry.status.toLowerCase() == 'monitoring')
        .length;
    return 'Symptom logs: active ${active.isEmpty ? 'none' : active.join(', ')}. Recent symptom history includes ${recent.isEmpty ? 'no named symptoms' : recent.join(', ')}. Monitoring entries: $monitoringCount.';
  }

  String _buildFitnessContext(List<FitnessEntry> recentFitness) {
    if (recentFitness.isEmpty) {
      return 'Fitness logs: none.';
    }
    final scores = recentFitness
        .take(7)
        .map((entry) => entry.fitnessScore)
        .toList(growable: false);
    final avg =
        scores.fold<double>(0, (sum, value) => sum + value) / scores.length;
    final latest = recentFitness.first.fitnessScore;
    final trend = scores.length >= 2 ? latest - scores[1] : 0.0;
    final trendLabel = trend > 4
        ? 'improving'
        : trend < -4
        ? 'declining'
        : 'steady';
    return 'Fitness logs: latest ${latest.toStringAsFixed(0)}/100, recent average ${avg.toStringAsFixed(0)}/100, overall $trendLabel.';
  }

  String _buildExerciseContext(
    ExerciseStore exerciseStore,
    int todayExerciseCount,
  ) {
    final recent = exerciseStore.getRecentExerciseHistory(limit: 10);
    if (recent.isEmpty) {
      return 'Exercise logs: none yet.';
    }
    final names = recent
        .map((item) => (item['exerciseName'] ?? '').trim())
        .where((name) => name.isNotEmpty)
        .take(5)
        .toList(growable: false);
    final weeklyCount = exerciseStore
        .getRecentExerciseActivity(days: 7)
        .fold<int>(0, (sum, count) => sum + count);
    return 'Exercise logs: $todayExerciseCount today and $weeklyCount in the last 7 days. Recent sessions include ${names.isEmpty ? 'recorded activity' : names.join(', ')}.';
  }

  String _buildEodContext(List<EodEntry> recentEod) {
    if (recentEod.isEmpty) {
      return 'End-of-day summaries: none yet.';
    }
    final summaries = recentEod
        .take(3)
        .map((entry) => _trimShort(entry.summaryText))
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    return summaries.isEmpty
        ? 'End-of-day summaries: available but empty.'
        : 'Recent end-of-day summaries: ${summaries.join(' | ')}';
  }

  String _buildCrossSignalContext({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required List<SymptomEntry> activeSymptoms,
    required List<SymptomEntry> recentSymptoms,
    required List<FitnessEntry> recentFitness,
    required ExerciseStore exerciseStore,
    required int todayExerciseCount,
  }) {
    final observations = <String>[];
    final recentMoods = moodStore.items.take(7).toList(growable: false);
    final recentSleep = sleepStore.items.take(7).toList(growable: false);
    final heavyMoodCount = recentMoods
        .where((item) => _moodScoreForLabel(item.moodLabel) <= 2)
        .length;
    final lowSleepCount = recentSleep
        .where((item) => (item.duration.inMinutes / 60.0) < 7.0)
        .length;
    final weeklyExerciseCount = exerciseStore
        .getRecentExerciseActivity(days: 7)
        .fold<int>(0, (sum, count) => sum + count);

    if (heavyMoodCount >= 2 && lowSleepCount >= 2) {
      observations.add(
        'Heavier moods and shorter sleep are both showing up recently, so low recovery may be amplifying emotional strain.',
      );
    }
    if (activeSymptoms.isNotEmpty && lowSleepCount >= 2) {
      observations.add(
        'Symptoms and short sleep are overlapping, which may be making the day feel harder to recover from.',
      );
    }
    if (recentFitness.isNotEmpty &&
        recentFitness.first.fitnessScore < 60 &&
        weeklyExerciseCount == 0) {
      observations.add(
        'Lower recent fitness signals plus little movement suggest energy may be trending down rather than just fluctuating day to day.',
      );
    }
    if (todayExerciseCount > 0 && recentMoods.isNotEmpty) {
      final latestMoodScore = _moodScoreForLabel(recentMoods.first.moodLabel);
      if (latestMoodScore >= 4) {
        observations.add(
          'You already have movement logged today and your latest mood is steadier, which may mean routine is helping.',
        );
      }
    }
    if (recentSymptoms.length >= 3) {
      final recurringSymptoms = recentSymptoms
          .take(10)
          .expand((entry) => entry.symptomList)
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      final repeated = recurringSymptoms.toSet().where(
        (item) => recurringSymptoms.where((value) => value == item).length >= 2,
      );
      if (repeated.isNotEmpty) {
        observations.add(
          'Some symptoms appear more than once recently, especially ${repeated.take(3).join(', ')}, which may point to a repeating pattern instead of a one-off day.',
        );
      }
    }

    if (observations.isEmpty) {
      observations.add(
        'Look for links across mood, sleep, symptoms, movement, and recent summaries rather than treating each tracker separately.',
      );
    }

    return 'Cross-signal observations: ${observations.join(' ')}';
  }

  List<String> _flattenSymptoms(List<SymptomEntry> entries) {
    final values = <String>{};
    for (final entry in entries) {
      for (final symptom in entry.symptomList) {
        final text = symptom.trim();
        if (text.isNotEmpty) {
          values.add(text);
        }
      }
    }
    return values.toList(growable: false);
  }

  int _todayExerciseCount(ExerciseStore exerciseStore) {
    final history = exerciseStore.getRecentExerciseHistory(limit: 40);
    final today = DateTime.now();
    return history.where((item) {
      final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
      if (timestamp == null) {
        return false;
      }
      return _isSameDay(timestamp, today);
    }).length;
  }

  int _moodScoreForLabel(String label) {
    final normalized = label.trim().toLowerCase();
    switch (normalized) {
      case 'happy':
      case 'affectionate':
      case 'joy':
      case 'love':
        return 5;
      case 'surprised':
      case 'surprise':
        return 4;
      case 'neutral':
      case 'content':
        return 3;
      case 'sad':
      case 'sadness':
      case 'scared':
      case 'fear':
        return 2;
      case 'angry':
      case 'anger':
        return 1;
      default:
        return 3;
    }
  }

  String _buildSummary({
    required String latestMoodLabel,
    required double? latestSleepHours,
    required int activeSymptomCount,
    required double? latestFitnessScore,
    required int todayExerciseCount,
  }) {
    final parts = <String>[
      'Mood: $latestMoodLabel',
      'Sleep: ${latestSleepHours == null ? 'not logged' : '${latestSleepHours.toStringAsFixed(1)}h'}',
      'Symptoms: $activeSymptomCount active',
      'Fitness: ${latestFitnessScore == null ? 'not available' : '${latestFitnessScore.toStringAsFixed(0)}/100'}',
      'Exercise today: $todayExerciseCount',
    ];
    return parts.join('  •  ');
  }

  String _titleFromAction(String action) {
    final trimmed = action.trim();
    if (trimmed.isEmpty) {
      return 'Suggestion';
    }
    final firstSentence = trimmed.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
    final cleaned = firstSentence
        .replaceFirst(
          RegExp(
            r'^(Try|Take|Keep|Use|Set|Focus on|Because|Since|If possible|Consider|Aim to|Start by)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(r"^(your|today's|today)\s+", caseSensitive: false),
          '',
        )
        .trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(5)
        .toList();
    if (words.isEmpty) {
      return 'Suggestion';
    }
    return words.map(_capitalizeWord).join(' ');
  }

  String _categoryForSuggestion(String action, String reason) {
    final combined = '$action $reason'.toLowerCase();
    if (combined.contains('sleep') ||
        combined.contains('rest') ||
        combined.contains('bed') ||
        combined.contains('wind-down')) {
      return 'Sleep';
    }
    if (combined.contains('symptom') ||
        combined.contains('pain') ||
        combined.contains('headache') ||
        combined.contains('body')) {
      return 'Symptoms';
    }
    if (combined.contains('walk') ||
        combined.contains('stretch') ||
        combined.contains('exercise') ||
        combined.contains('movement') ||
        combined.contains('workout')) {
      return 'Exercise';
    }
    if (combined.contains('mood') ||
        combined.contains('overwhelmed') ||
        combined.contains('anxious') ||
        combined.contains('angry') ||
        combined.contains('sad') ||
        combined.contains('scared') ||
        combined.contains('calm') ||
        combined.contains('ground')) {
      return 'Mood';
    }
    return 'Overall';
  }

  IconData _iconForAction(String action) {
    final lowered = action.toLowerCase();
    if (lowered.contains('sleep') ||
        lowered.contains('wind-down') ||
        lowered.contains('bed')) {
      return Icons.nightlight_round;
    }
    if (lowered.contains('walk') ||
        lowered.contains('stretch') ||
        lowered.contains('exercise') ||
        lowered.contains('movement')) {
      return Icons.fitness_center_outlined;
    }
    if (lowered.contains('breathe') ||
        lowered.contains('calm') ||
        lowered.contains('ground') ||
        lowered.contains('pressure')) {
      return Icons.self_improvement_rounded;
    }
    if (lowered.contains('chat') || lowered.contains('mini-me')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (lowered.contains('symptom') || lowered.contains('body')) {
      return Icons.healing_outlined;
    }
    return Icons.tips_and_updates_rounded;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _trimShort(String value) {
    final text = value.trim();
    if (text.length <= 120) {
      return text;
    }
    return '${text.substring(0, 117).trimRight()}...';
  }

  String _formatDateLabel(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _capitalizeWord(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }
}

class _CombinedLogPoint {
  const _CombinedLogPoint({required this.timestamp, required this.text});

  final DateTime timestamp;
  final String text;
}
