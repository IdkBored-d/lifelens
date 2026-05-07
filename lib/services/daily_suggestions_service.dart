import 'dart:convert';
import 'dart:math' as math;

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
    required this.requiresInitialSetup,
    required this.hasAnyRequiredLogsToday,
    required this.hasAllRequiredLogsToday,
    required this.missingRequiredLogs,
  });

  final bool requiresInitialSetup;
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
    List<String> recentSuggestionActions = const <String>[],
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
      recentSuggestionActions: recentSuggestionActions,
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
    final hasAnyCoreLogToday =
        hasMoodToday || hasSleepToday || todayExerciseCount > 0;

    final exerciseStore = ExerciseStore();
    await exerciseStore.ensureReady();
    final hasExerciseEver = exerciseStore
        .getRecentExerciseHistory(limit: 1)
        .isNotEmpty;

    final hasMoodEver = moodStore.items.isNotEmpty;
    final hasSleepEver = sleepStore.items.isNotEmpty;
    final requiresInitialSetup =
        !(hasMoodEver && hasSleepEver && hasExerciseEver);

    final missing = <String>[
      if (!hasMoodToday) 'mood',
      if (!hasSleepToday) 'sleep',
      if (todayExerciseCount <= 0) 'exercise',
    ];

    return _RequiredLogStatus(
      requiresInitialSetup: requiresInitialSetup,
      hasAnyRequiredLogsToday: hasAnyCoreLogToday,
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
    required List<String> recentSuggestionActions,
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
      recentSuggestionActions: recentSuggestionActions,
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
    final latestLogFocus = _buildLatestLogFocus(allRecentLogs);

    final localMiniGenSuggestions = await _tryGenerateMiniGenSuggestions(
      summaryContext: summaryContext,
      latestMoodLabel: latestMood?.moodLabel ?? 'neutral',
      latestMoodIntensity:
          latestMood?.intensity ??
          _moodScoreForLabel(latestMood?.moodLabel ?? ''),
      recentMoods: moodStore.items
          .take(10)
          .map((item) => item.moodLabel)
          .toList(growable: false),
      recentLogs: allRecentLogs,
      activeSymptoms: _flattenSymptoms(activeSymptoms),
      latestLogFocus: latestLogFocus,
      recentSuggestionActions: recentSuggestionActions,
      suggestionWindow: suggestionWindow,
      triggerReason: triggerReason,
    );

    if (localMiniGenSuggestions.isNotEmpty) {
      return localMiniGenSuggestions;
    }

    try {
      final reply = await MiniMeBackendService.instance.suggestions(
        latestMoodLabel: latestMood?.moodLabel ?? 'neutral',
        latestMoodIntensity:
            latestMood?.intensity ??
            _moodScoreForLabel(latestMood?.moodLabel ?? ''),
        latestMoodNotes: latestMood?.notes ?? '',
        recentMoods: moodStore.items
            .take(10)
            .map((item) => item.moodLabel)
            .toList(growable: false),
        recentLogs: allRecentLogs,
        activeSymptoms: _flattenSymptoms(activeSymptoms),
        history: backendHistory,
        summaryContext: summaryContext,
        suggestionWindow: suggestionWindow,
        triggerReason: triggerReason,
        eventOverride: eventOverride,
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
          .where(
            (item) => !_isNearRepeatSuggestion(
              item.action,
              item.reason,
              recentSuggestionActions,
            ),
          )
          .where(
            (item) => _isGroundedDailySuggestion(
              item,
              latestLogFocus: latestLogFocus,
              activeSymptoms: _flattenSymptoms(activeSymptoms),
              suggestionWindow: suggestionWindow,
            ),
          )
          .where((item) => item.action.isNotEmpty)
          .toList(growable: false);

      if (suggestions.isNotEmpty) {
        return suggestions;
      }
    } catch (_) {
      // Fall through to local fallback when backend generation is unavailable.
    }

    return _buildGroundedFallbackSuggestions(
      latestLogFocus: latestLogFocus,
      moodStore: moodStore,
      sleepStore: sleepStore,
      activeSymptoms: activeSymptoms,
      recentSymptoms: recentSymptoms,
      recentFitness: recentFitness,
      exerciseStore: exerciseStore,
      todayExerciseCount: todayExerciseCount,
      recentSuggestionActions: recentSuggestionActions,
    );
  }

  Future<List<DailySuggestion>> _tryGenerateMiniGenSuggestions({
    required String summaryContext,
    required String latestMoodLabel,
    required int latestMoodIntensity,
    required List<String> recentMoods,
    required List<String> recentLogs,
    required List<String> activeSymptoms,
    required _LatestLogFocus? latestLogFocus,
    required List<String> recentSuggestionActions,
    String? suggestionWindow,
    String? triggerReason,
  }) async {
    if (!AppServices.isMiniGenLoaded) {
      return const <DailySuggestion>[];
    }

    final targetCount = _targetSuggestionCount(suggestionWindow);
    final candidateCount = _candidateSuggestionCount(
      targetCount: targetCount,
      suggestionWindow: suggestionWindow,
    );
    try {
      final raw = await AppServices.miniGenChat.generateMiniMeSuggestionsJson(
        summaryContext: summaryContext,
        latestMoodLabel: latestMoodLabel,
        latestMoodIntensity: latestMoodIntensity,
        recentMoods: recentMoods,
        recentLogs: recentLogs,
        activeSymptoms: activeSymptoms,
        latestLogFocus: latestLogFocus?.promptText,
        avoidedSuggestions: recentSuggestionActions,
        targetCount: candidateCount,
        suggestionWindow: suggestionWindow,
        triggerReason: triggerReason,
      );
      final suggestions =
          _groundMiniGenSuggestions(
                suggestions: _parseMiniGenSuggestions(raw),
                latestLogFocus: latestLogFocus,
                activeSymptoms: activeSymptoms,
                recentSuggestionActions: recentSuggestionActions,
                suggestionWindow: suggestionWindow,
              )
              .take(targetCount)
              .map(
                (item) => DailySuggestion(
                  title: _titleFromAction(item.action),
                  action: item.action,
                  reason: item.reason,
                  icon: _iconForAction(item.action),
                  category: _categoryForSuggestion(item.action, item.reason),
                  priority: 110,
                  sourceSignals: const ['MiniGen on-device'],
                ),
              )
              .where((item) => item.action.trim().isNotEmpty)
              .toList(growable: false);

      return suggestions;
    } catch (error) {
      debugPrint('[DailySuggestions] MiniGen suggestions skipped: $error');
      return const <DailySuggestion>[];
    }
  }

  List<DailySuggestion> _buildGroundedFallbackSuggestions({
    required _LatestLogFocus? latestLogFocus,
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required List<SymptomEntry> activeSymptoms,
    required List<SymptomEntry> recentSymptoms,
    required List<FitnessEntry> recentFitness,
    required ExerciseStore exerciseStore,
    required int todayExerciseCount,
    required List<String> recentSuggestionActions,
  }) {
    final candidates = _fallbackCandidatesForLatestLog(
      latestLogFocus: latestLogFocus,
      moodStore: moodStore,
      sleepStore: sleepStore,
      activeSymptoms: activeSymptoms,
      recentSymptoms: recentSymptoms,
      recentFitness: recentFitness,
      exerciseStore: exerciseStore,
      todayExerciseCount: todayExerciseCount,
    );
    if (candidates.isEmpty) return const <DailySuggestion>[];

    final seed =
        (latestLogFocus?.occurrenceCountToday ?? 1) +
        recentSuggestionActions.length;
    final rotated = _rotateSuggestions(candidates, seed);
    final selected = _selectBestFallbackCandidate(
      rotated,
      latestLogFocus: latestLogFocus,
      recentSuggestionActions: recentSuggestionActions,
    );

    return [
      DailySuggestion(
        title: _titleFromAction(selected.action),
        action: selected.action,
        reason: selected.reason,
        icon: _iconForAction(selected.action),
        category: _categoryForSuggestion(selected.action, selected.reason),
        priority: 80,
        sourceSignals: const ['local log fallback'],
      ),
    ];
  }

  List<_GeneratedSuggestion> _fallbackCandidatesForLatestLog({
    required _LatestLogFocus? latestLogFocus,
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required List<SymptomEntry> activeSymptoms,
    required List<SymptomEntry> recentSymptoms,
    required List<FitnessEntry> recentFitness,
    required ExerciseStore exerciseStore,
    required int todayExerciseCount,
  }) {
    final latestMood = moodStore.items.isEmpty ? null : moodStore.items.first;
    final latestSleep = sleepStore.items.isEmpty
        ? null
        : sleepStore.items.first;
    final sleepHours = latestSleep == null
        ? null
        : latestSleep.duration.inMinutes / 60.0;
    final symptomText = _fallbackSymptomText(activeSymptoms, recentSymptoms);
    final latestFitness = recentFitness.isEmpty ? null : recentFitness.first;
    final latestExercise = exerciseStore.getRecentExerciseHistory(limit: 1);
    final latestExerciseIsNoExercise =
        latestExercise.isNotEmpty &&
        (latestExercise.first['noExercise'] ?? '').trim() == 'true';
    final exerciseLabel = latestExercise.isEmpty
        ? 'your latest movement log'
        : _fallbackExerciseLabel(latestExercise.first);
    final latestContext = _latestContextFromFocus(latestLogFocus);
    final contextClause = latestContext == null ? '' : ' about $latestContext';

    final kind = latestLogFocus?.kind;
    if (kind == _LatestLogKind.mood) {
      final moodLabel = latestMood?.moodLabel.toLowerCase() ?? 'this mood';
      final intensity = latestMood?.intensity ?? _moodScoreForLabel(moodLabel);
      final note = latestMood?.notes.trim() ?? '';
      final profile = _moodSuggestionProfile(moodLabel);
      if (intensity <= 2) {
        return [
          _GeneratedSuggestion(
            action: profile.lowAction,
            reason: profile.lowReason,
          ),
          _GeneratedSuggestion(
            action: profile.reflectAction,
            reason: note.isEmpty
                ? profile.reflectReasonNoNote
                : profile.reflectReasonWithNote,
          ),
          if (latestContext != null)
            _GeneratedSuggestion(
              action:
                  'Use the note about $latestContext to choose one concrete boundary, reset, or support step before the next hour gets busier.',
              reason:
                  'Your mood label gives the feeling, but your note names the context that should shape the suggestion.',
            ),
          if (sleepHours != null && sleepHours < 7)
            _GeneratedSuggestion(
              action:
                  'Treat low recovery as part of the mood today: hydrate, avoid stacking hard tasks, and plan an earlier wind-down.',
              reason:
                  'Your mood log and recent sleep both point toward lower recovery, so pacing should help more than pushing harder.',
            ),
          if (symptomText.isNotEmpty)
            _GeneratedSuggestion(
              action:
                  'Keep today gentle around $symptomText and choose the easiest version of your next obligation.',
              reason:
                  'Mood and symptoms can amplify each other, so lowering intensity is a practical way to protect energy.',
            ),
        ];
      }

      return [
        _GeneratedSuggestion(
          action: profile.steadyAction,
          reason: profile.steadyReason,
        ),
        if (latestContext != null)
          _GeneratedSuggestion(
            action:
                'Turn the note about $latestContext into one small follow-up: write the next step, send one message, or set a reminder.',
            reason:
                'The most useful suggestion should address the context you logged, not just the mood label.',
          ),
        _GeneratedSuggestion(
          action: profile.followThroughAction,
          reason: profile.followThroughReason,
        ),
        _GeneratedSuggestion(
          action: profile.crossSignalAction,
          reason: profile.crossSignalReason,
        ),
      ];
    }

    if (kind == _LatestLogKind.sleep) {
      final quality = latestSleep?.quality.label.toLowerCase() ?? 'unknown';
      final hoursText = sleepHours == null
          ? 'your sleep log'
          : '${sleepHours.toStringAsFixed(1)} hours';
      return [
        if (latestContext != null)
          _GeneratedSuggestion(
            action:
                'Use your sleep note about $latestContext to remove one matching friction point before bedtime tonight.',
            reason:
                'Your sleep entry included context, so the best next step should target what affected the night.',
          ),
        _GeneratedSuggestion(
          action:
              'Protect recovery for the next block: choose a lighter task first and delay anything that needs peak focus.',
          reason:
              'Your latest sleep log shows $hoursText with $quality quality, so pacing the day around recovery makes sense.',
        ),
        _GeneratedSuggestion(
          action:
              'Set up tonight now: pick a wind-down time and remove one source of friction before bedtime.',
          reason:
              'Sleep suggestions work best when the next sleep window is prepared before you are already tired.',
        ),
        if (latestMood != null)
          _GeneratedSuggestion(
            action:
                'Watch how sleep affects your ${latestMood.moodLabel.toLowerCase()} mood today, and log one energy note later.',
            reason:
                'Pairing sleep with mood gives Mini-Me a clearer pattern than either log by itself.',
          ),
        if (sleepHours != null && sleepHours < 6)
          _GeneratedSuggestion(
            action:
                'Keep the day in recovery mode: avoid adding extra intensity, hydrate early, and choose the shortest version of one demanding task.',
            reason:
                'A shorter sleep log changes what is realistic today, so pacing matters more than adding goals.',
          ),
        if (sleepHours != null && sleepHours >= 8)
          _GeneratedSuggestion(
            action:
                'Use the stronger sleep base for one planned task, but keep tonight\'s wind-down steady so the pattern is repeatable.',
            reason:
                'Longer sleep is useful when it turns into a repeatable routine rather than a one-day push.',
          ),
      ];
    }

    if (kind == _LatestLogKind.exercise) {
      if (latestExerciseIsNoExercise) {
        return [
          if (latestContext != null)
            _GeneratedSuggestion(
              action:
                  'Use the reason you skipped exercise today, $latestContext, to make the next movement option smaller instead of forcing a workout.',
              reason:
                  'Your exercise log says no exercise, so the useful advice is removing friction rather than giving workout recovery steps.',
            ),
          _GeneratedSuggestion(
            action:
                'Choose one tiny movement option for later, like a two-minute stretch or a short walk, only if your energy allows it.',
            reason:
                'A no-exercise log means the next step should be low-pressure and realistic, not a full workout plan.',
          ),
          _GeneratedSuggestion(
            action:
                'Notice what blocked movement today: time, energy, soreness, mood, or symptoms, then adjust tomorrow\'s plan around that one barrier.',
            reason:
                'The missed-movement context is the signal Mini-Me needs to make future exercise suggestions fit better.',
          ),
          if (sleepHours != null && sleepHours < 7)
            _GeneratedSuggestion(
              action:
                  'Treat no exercise plus shorter sleep as a recovery signal: keep expectations lighter and set up rest before adding movement.',
              reason:
                  'Short sleep can explain lower movement, so recovery may be more useful than pushing intensity.',
            ),
        ];
      }

      return [
        if (latestContext != null)
          _GeneratedSuggestion(
            action:
                'Use the exercise note about $latestContext as feedback: adjust the next session by changing duration, intensity, or recovery.',
            reason:
                'Your workout context says more than completion alone, so the suggestion should respond to that detail.',
          ),
        _GeneratedSuggestion(
          action:
              'Use $exerciseLabel as recovery information: hydrate, stretch lightly, and keep the next workout easier if soreness rises.',
          reason:
              'Your latest exercise log is most helpful when it guides recovery, not just completion.',
        ),
        _GeneratedSuggestion(
          action:
              'Log how your mood or energy feels after this movement so Mini-Me can learn whether this workout type helps you.',
          reason:
              'Exercise advice gets more accurate when movement is connected to mood and energy afterward.',
        ),
        _GeneratedSuggestion(
          action: todayExerciseCount > 1
              ? 'Since you have multiple movement logs today, make the rest of the day recovery-focused instead of adding more intensity.'
              : 'Repeat the easiest part of this movement next time, even if you make the session shorter.',
          reason: todayExerciseCount > 1
              ? 'More than one exercise log today means recovery is now the useful signal to protect.'
              : 'Consistency usually comes from repeating the most doable part, not making the next session bigger.',
        ),
        if (sleepHours != null && sleepHours < 7)
          _GeneratedSuggestion(
            action:
                'Because sleep was shorter, treat $exerciseLabel as enough movement for now and make the next block easier.',
            reason:
                'Exercise and sleep together suggest recovery should guide the rest of the day.',
          ),
      ];
    }

    if (kind == _LatestLogKind.symptom) {
      return [
        if (latestContext != null)
          _GeneratedSuggestion(
            action:
                'Use the symptom context$contextClause to avoid one likely trigger and check intensity again later today.',
            reason:
                'Your symptom log included context, so monitoring should focus on what might be connected to it.',
          ),
        _GeneratedSuggestion(
          action:
              'Track symptom intensity once later today and avoid the activity that seems most likely to worsen it.',
          reason:
              'Your symptom log is useful for monitoring patterns, and a second intensity check makes changes easier to spot.',
        ),
        _GeneratedSuggestion(
          action:
              'Keep recovery simple around $symptomText: rest, fluids, and lower intensity until the pattern is clearer.',
          reason:
              'Symptom-related advice should reduce strain while your logged pattern is still being watched.',
        ),
        _GeneratedSuggestion(
          action:
              'If symptoms worsen, feel severe, or keep returning, contact a healthcare professional or visit a doctor.',
          reason:
              'Mini-Me can help track patterns, but worsening or persistent symptoms need professional guidance.',
        ),
        if (sleepHours != null && sleepHours < 7)
          _GeneratedSuggestion(
            action:
                'Pair symptom monitoring with recovery today: rest earlier, keep fluids nearby, and skip nonessential strain.',
            reason:
                'Symptoms plus shorter sleep can make recovery harder, so the next step should reduce load.',
          ),
      ];
    }

    if (kind == _LatestLogKind.fitness) {
      final score = latestFitness?.fitnessScore.toStringAsFixed(0) ?? 'unknown';
      return [
        if (latestContext != null)
          _GeneratedSuggestion(
            action:
                'Connect the fitness note about $latestContext with sleep, movement, and mood before changing your routine.',
            reason:
                'The extra context can explain the score better than the number alone.',
          ),
        _GeneratedSuggestion(
          action:
              'Use the fitness score as a pacing signal today: choose movement that matches your current energy instead of forcing intensity.',
          reason:
              'Your latest fitness score is $score/100, so the helpful move is matching effort to readiness.',
        ),
        _GeneratedSuggestion(
          action:
              'Pair the fitness score with sleep and mood in your next log so Mini-Me can tell whether recovery or activity is driving it.',
          reason:
              'Fitness data becomes more useful when it is connected to the logs that explain why it changed.',
        ),
      ];
    }

    final fallback = <_GeneratedSuggestion>[];
    if (latestMood != null) {
      final moodLabel = latestMood.moodLabel.toLowerCase();
      final profile = _moodSuggestionProfile(moodLabel);
      fallback.add(
        _GeneratedSuggestion(
          action: profile.steadyAction,
          reason: profile.steadyReason,
        ),
      );
      if (latestContext != null) {
        fallback.add(
          _GeneratedSuggestion(
            action:
                'Use the logged context about $latestContext to choose one next step that fits the actual situation, not just the tracker category.',
            reason:
                'User notes are the strongest clue for making Mini-Me suggestions feel specific and accurate.',
          ),
        );
      }
    }
    if (sleepHours != null) {
      fallback.add(
        _GeneratedSuggestion(
          action: sleepHours < 7
              ? 'Treat today as a lower-recovery day: do the easiest important task first and move one demanding task later if you can.'
              : 'Use the steadier sleep base today for one maintenance action, like prepping water, planning dinner, or setting tonight\'s wind-down time.',
          reason:
              'Your sleep log shows ${sleepHours.toStringAsFixed(1)} hours, so recovery should shape the next step.',
        ),
      );
    }
    if (latestExercise.isNotEmpty && !latestExerciseIsNoExercise) {
      fallback.add(
        _GeneratedSuggestion(
          action:
              'After $exerciseLabel, check hydration and keep the next movement choice easy if soreness or fatigue shows up.',
          reason:
              'Your exercise log gives a recovery signal, so the useful follow-up is protecting how your body feels afterward.',
        ),
      );
    }
    if (symptomText != 'your symptoms') {
      fallback.add(
        _GeneratedSuggestion(
          action:
              'Keep intensity lower around $symptomText and check once later whether it improved, stayed the same, or worsened.',
          reason:
              'Your symptom context is a reason to monitor the pattern instead of pushing through blindly.',
        ),
      );
    }

    return fallback.isEmpty
        ? const <_GeneratedSuggestion>[]
        : fallback.toList(growable: false);
  }

  List<_GeneratedSuggestion> _rotateSuggestions(
    List<_GeneratedSuggestion> suggestions,
    int seed,
  ) {
    if (suggestions.length <= 1) return suggestions;
    final offset = seed.abs() % suggestions.length;
    return [...suggestions.skip(offset), ...suggestions.take(offset)];
  }

  _GeneratedSuggestion _selectBestFallbackCandidate(
    List<_GeneratedSuggestion> candidates, {
    required _LatestLogFocus? latestLogFocus,
    required List<String> recentSuggestionActions,
  }) {
    final context = _latestContextFromFocus(latestLogFocus);
    final nonRepeats = candidates
        .where(
          (item) => !_isNearRepeatSuggestion(
            item.action,
            item.reason,
            recentSuggestionActions,
          ),
        )
        .toList(growable: false);
    final pool = nonRepeats.isEmpty
        ? _leastSimilarFallbackCandidates(candidates, recentSuggestionActions)
        : nonRepeats;
    if (context == null) return pool.first;

    final contextTokens = _keywordTokens(context).take(6).toSet();
    if (contextTokens.isEmpty) return pool.first;
    return pool.firstWhere((item) {
      final combined = '${item.action} ${item.reason}'.toLowerCase();
      return contextTokens.any(combined.contains);
    }, orElse: () => pool.first);
  }

  List<_GeneratedSuggestion> _leastSimilarFallbackCandidates(
    List<_GeneratedSuggestion> candidates,
    List<String> recentSuggestionActions,
  ) {
    if (candidates.length <= 1 || recentSuggestionActions.isEmpty) {
      return candidates;
    }

    final scored =
        candidates
            .map((candidate) {
              final combined = '${candidate.action} ${candidate.reason}';
              final worstSimilarity = recentSuggestionActions
                  .map((previous) => _textSimilarity(combined, previous))
                  .fold<double>(0, math.max);
              return (candidate: candidate, similarity: worstSimilarity);
            })
            .toList(growable: false)
          ..sort((a, b) => a.similarity.compareTo(b.similarity));

    return scored.map((item) => item.candidate).toList(growable: false);
  }

  String? _latestContextFromFocus(_LatestLogFocus? latestLogFocus) {
    final text = latestLogFocus?.text ?? '';
    if (text.trim().isEmpty) return null;

    final fragments = text
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (fragments.length <= 1) return null;

    for (final fragment in fragments.skip(1)) {
      final lower = fragment.toLowerCase();
      if (lower.startsWith('quality ') ||
          lower.startsWith('status ') ||
          lower.startsWith('score ') ||
          lower.startsWith('sleep input ') ||
          lower.startsWith('activity ') ||
          lower.startsWith('heart rate ') ||
          lower.startsWith('possible ailment ') ||
          RegExp(r'^\d+(\.\d+)?h$').hasMatch(lower) ||
          RegExp(r'^\d+\s*min$').hasMatch(lower) ||
          RegExp(r'^\d+\s*sets\s*x\s*\d+\s*reps$').hasMatch(lower)) {
        continue;
      }

      final cleaned = fragment
          .replaceFirst(RegExp(r'^context\s+', caseSensitive: false), '')
          .trim();
      if (cleaned.length >= 3) return _trimShort(cleaned);
    }

    return null;
  }

  String _fallbackSymptomText(
    List<SymptomEntry> activeSymptoms,
    List<SymptomEntry> recentSymptoms,
  ) {
    final symptoms = [...activeSymptoms, ...recentSymptoms]
        .expand((entry) => entry.symptomList)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList(growable: false);
    if (symptoms.isNotEmpty) return symptoms.join(', ');
    return 'your symptoms';
  }

  String _fallbackExerciseLabel(Map<String, String> entry) {
    final noExercise = (entry['noExercise'] ?? '').trim() == 'true';
    if (noExercise) return 'no exercise';
    final name = (entry['exerciseName'] ?? '').trim();
    if (name.isNotEmpty) return name;
    final id = (entry['exerciseId'] ?? '').trim();
    if (id.isNotEmpty && id != 'no_exercise') return id;
    return 'your latest movement log';
  }

  List<_GeneratedSuggestion> _groundMiniGenSuggestions({
    required List<_GeneratedSuggestion> suggestions,
    required _LatestLogFocus? latestLogFocus,
    required List<String> activeSymptoms,
    required List<String> recentSuggestionActions,
    String? suggestionWindow,
  }) {
    if (suggestions.isEmpty) {
      return const <_GeneratedSuggestion>[];
    }

    final window = (suggestionWindow ?? '').trim().toLowerCase();
    final strictLatestLog =
        window == 'log_update' || window == 'event_override';
    final grounded = <_GeneratedSuggestion>[];
    for (final suggestion in suggestions) {
      if (!_hasUsefulShape(suggestion)) continue;
      if (_containsUnsupportedMedicalLanguage(suggestion)) continue;
      if (_isNearRepeatSuggestion(
        suggestion.action,
        suggestion.reason,
        recentSuggestionActions,
      )) {
        continue;
      }
      if (grounded.any(
        (existing) => _suggestionsAreTooSimilar(existing, suggestion),
      )) {
        continue;
      }
      if (strictLatestLog && latestLogFocus != null) {
        if (!_matchesLatestLogFocus(
          suggestion,
          latestLogFocus: latestLogFocus,
          activeSymptoms: activeSymptoms,
        )) {
          continue;
        }
      }
      grounded.add(suggestion);
    }
    return grounded;
  }

  bool _isNearRepeatSuggestion(
    String action,
    String reason,
    List<String> recentSuggestionActions,
  ) {
    if (recentSuggestionActions.isEmpty) return false;
    final candidate = '$action $reason';
    return recentSuggestionActions.any(
      (previous) => _textSimilarity(candidate, previous) >= 0.58,
    );
  }

  bool _suggestionsAreTooSimilar(
    _GeneratedSuggestion left,
    _GeneratedSuggestion right,
  ) {
    return _textSimilarity(
          '${left.action} ${left.reason}',
          '${right.action} ${right.reason}',
        ) >=
        0.62;
  }

  double _textSimilarity(String left, String right) {
    final leftTokens = _similarityTokens(left);
    final rightTokens = _similarityTokens(right);
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0;
    final intersection = leftTokens.intersection(rightTokens).length;
    final union = leftTokens.union(rightTokens).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  Set<String> _similarityTokens(String value) {
    return _keywordTokens(value).where((token) => token.length >= 4).toSet();
  }

  bool _hasUsefulShape(_GeneratedSuggestion suggestion) {
    final action = suggestion.action.trim();
    final reason = suggestion.reason.trim();
    if (action.length < 12 || reason.length < 12) return false;
    if (action.length > 260 || reason.length > 260) return false;
    return true;
  }

  bool _containsUnsupportedMedicalLanguage(_GeneratedSuggestion suggestion) {
    final combined = '${suggestion.action} ${suggestion.reason}'.toLowerCase();
    return combined.contains('diagnose yourself') ||
        combined.contains('you have ') ||
        combined.contains('definitely ') ||
        combined.contains('cure ') ||
        combined.contains('ignore symptoms');
  }

  bool _isGroundedDailySuggestion(
    DailySuggestion suggestion, {
    required _LatestLogFocus? latestLogFocus,
    required List<String> activeSymptoms,
    String? suggestionWindow,
  }) {
    final generated = _GeneratedSuggestion(
      action: suggestion.action,
      reason: suggestion.reason,
    );
    if (!_hasUsefulShape(generated)) return false;
    if (_containsUnsupportedMedicalLanguage(generated)) return false;

    final window = (suggestionWindow ?? '').trim().toLowerCase();
    final strictLatestLog =
        window == 'log_update' || window == 'event_override';
    if (!strictLatestLog || latestLogFocus == null) return true;

    return _matchesLatestLogFocus(
      generated,
      latestLogFocus: latestLogFocus,
      activeSymptoms: activeSymptoms,
    );
  }

  bool _matchesLatestLogFocus(
    _GeneratedSuggestion suggestion, {
    required _LatestLogFocus latestLogFocus,
    required List<String> activeSymptoms,
  }) {
    final combined = '${suggestion.action} ${suggestion.reason}'.toLowerCase();
    final focusTokens = latestLogFocus.keywords;
    final symptomTokens = activeSymptoms
        .expand((item) => _keywordTokens(item))
        .toSet();

    bool containsAny(Iterable<String> tokens) {
      return tokens.any((token) => combined.contains(token));
    }

    switch (latestLogFocus.kind) {
      case _LatestLogKind.mood:
        final profile = _moodSuggestionProfileForLogText(latestLogFocus.text);
        return containsAny(focusTokens) ||
            _matchesMoodProfile(combined, profile);
      case _LatestLogKind.sleep:
        return containsAny(focusTokens) ||
            containsAny(const [
              'sleep',
              'rest',
              'bed',
              'wake',
              'night',
              'wind-down',
              'recovery',
            ]);
      case _LatestLogKind.symptom:
        return containsAny(focusTokens) ||
            containsAny(symptomTokens) ||
            containsAny(const [
              'symptom',
              'body',
              'pain',
              'hydrate',
              'fluids',
              'rest',
              'recovery',
              'intensity',
            ]);
      case _LatestLogKind.exercise:
        return containsAny(focusTokens) ||
            containsAny(const [
              'exercise',
              'workout',
              'movement',
              'walk',
              'stretch',
              'session',
              'intensity',
              'recovery',
            ]);
      case _LatestLogKind.fitness:
        return containsAny(focusTokens) ||
            containsAny(const [
              'fitness',
              'activity',
              'heart',
              'score',
              'energy',
            ]);
      case _LatestLogKind.eod:
        return containsAny(focusTokens) ||
            containsAny(const [
              'today',
              'tomorrow',
              'reflect',
              'summary',
              'pattern',
            ]);
      case _LatestLogKind.chat:
        return containsAny(focusTokens) ||
            containsAny(const ['chat', 'mini-me', 'message', 'talk']);
    }
  }

  int _targetSuggestionCount(String? suggestionWindow) {
    final window = (suggestionWindow ?? '').trim().toLowerCase();
    return {
          'morning_anchor',
          'midday_checkin',
          'evening_reflection',
          'event_override',
          'log_update',
        }.contains(window)
        ? 1
        : 3;
  }

  int _candidateSuggestionCount({
    required int targetCount,
    String? suggestionWindow,
  }) {
    final window = (suggestionWindow ?? '').trim().toLowerCase();
    if (window == 'log_update' || window == 'event_override') {
      return targetCount + 3;
    }
    return targetCount + 2;
  }

  List<_GeneratedSuggestion> _parseMiniGenSuggestions(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const <_GeneratedSuggestion>[];
    }

    final jsonText = _extractJsonObject(trimmed);
    if (jsonText == null) {
      return const <_GeneratedSuggestion>[];
    }

    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      return const <_GeneratedSuggestion>[];
    }

    final rawSuggestions = decoded['suggestions'];
    if (rawSuggestions is! List) {
      return const <_GeneratedSuggestion>[];
    }

    return rawSuggestions
        .whereType<Map>()
        .map(
          (item) => _GeneratedSuggestion(
            action: (item['action'] ?? '').toString().trim(),
            reason: (item['reason'] ?? '').toString().trim(),
          ),
        )
        .where((item) => item.action.isNotEmpty && item.reason.isNotEmpty)
        .toList(growable: false);
  }

  String? _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }
    return raw.substring(start, end + 1);
  }

  _LatestLogFocus? _buildLatestLogFocus(List<String> recentLogs) {
    if (recentLogs.isEmpty) return null;
    final latest = recentLogs.first.trim();
    if (latest.isEmpty) return null;

    final kind = _kindForLogText(latest);
    if (kind == null) return null;

    final todayStamp = _formatDateLabel(DateTime.now());
    final occurrenceCountToday = recentLogs
        .where(
          (log) => log.startsWith(todayStamp) && _kindForLogText(log) == kind,
        )
        .length;
    final keywords = _keywordTokens(latest).take(12).toSet();
    return _LatestLogFocus(
      kind: kind,
      text: latest,
      keywords: keywords,
      occurrenceCountToday: occurrenceCountToday,
      variationCue: _variationCueForLog(kind, occurrenceCountToday),
    );
  }

  _LatestLogKind? _kindForLogText(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('mood log:')) return _LatestLogKind.mood;
    if (lower.contains('sleep log:')) return _LatestLogKind.sleep;
    if (lower.contains('symptom log:')) return _LatestLogKind.symptom;
    if (lower.contains('exercise log:')) return _LatestLogKind.exercise;
    if (lower.contains('fitness log:')) return _LatestLogKind.fitness;
    if (lower.contains('end-of-day summary:')) return _LatestLogKind.eod;
    if (lower.contains('mini-me chat:')) return _LatestLogKind.chat;
    return null;
  }

  String _variationCueForLog(_LatestLogKind kind, int occurrenceCountToday) {
    final index = occurrenceCountToday <= 0 ? 0 : occurrenceCountToday - 1;
    final cues = switch (kind) {
      _LatestLogKind.mood => const [
        'name the likely trigger or context behind this mood',
        'connect this mood with earlier sleep, exercise, or symptoms today',
        'suggest a different low-effort reset than a previous mood check-in',
        'focus on what to protect for the next few hours',
      ],
      _LatestLogKind.sleep => const [
        'connect this sleep log with today\'s mood and energy',
        'focus on recovery pacing for the next block of the day',
        'suggest one evening adjustment based on this sleep pattern',
      ],
      _LatestLogKind.symptom => const [
        'connect symptoms with rest, hydration, and earlier logs today',
        'focus on monitoring intensity and avoiding overexertion',
        'suggest a practical comfort or recovery step',
      ],
      _LatestLogKind.exercise => const [
        'connect this workout with mood, sleep, and recovery today',
        'focus on post-workout recovery or pacing',
        'suggest how to use this movement as information for the rest of today',
      ],
      _LatestLogKind.fitness => const [
        'connect the fitness score with sleep, activity, and mood context',
        'focus on the most practical next health signal to watch',
      ],
      _LatestLogKind.eod => const [
        'turn today\'s pattern into one specific tomorrow plan',
        'name the clearest cross-log pattern from today',
      ],
      _LatestLogKind.chat => const [
        'connect the chat theme with the logged health context',
        'suggest one grounded follow-up based on the conversation',
      ],
    };
    return cues[index % cues.length];
  }

  Iterable<String> _keywordTokens(String value) sync* {
    const stopWords = {
      'with',
      'from',
      'that',
      'this',
      'your',
      'have',
      'were',
      'been',
      'today',
      'quality',
      'status',
      'possible',
      'latest',
      'recent',
      'log',
      'mood',
      'sleep',
      'symptom',
      'exercise',
    };
    final matches = RegExp(r'[a-zA-Z][a-zA-Z-]{3,}').allMatches(value);
    for (final match in matches) {
      final token = match.group(0)!.toLowerCase();
      if (stopWords.contains(token)) continue;
      yield token;
    }
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
    required List<String> recentSuggestionActions,
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
    final todayContext = _buildTodayContext(
      moodStore: moodStore,
      sleepStore: sleepStore,
      activeSymptoms: activeSymptoms,
      recentSymptoms: recentSymptoms,
      exerciseStore: exerciseStore,
      todayExerciseCount: todayExerciseCount,
    );
    final chatSummary = recentChatMessages.isEmpty
        ? 'No recent Mini-Me chat context.'
        : 'Recent Mini-Me chat themes: ${recentChatMessages.take(4).map(_trimShort).join(' | ')}';
    final suggestionMemory = recentSuggestionActions.isEmpty
        ? 'Recent suggestion memory: none yet.'
        : 'Recent suggestion memory: avoid repeating these angles: ${recentSuggestionActions.take(6).map(_trimShort).join(' | ')}';
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
      todayContext,
      eodSummary,
      crossSignalSummary,
      chatSummary,
      suggestionMemory,
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
      final workoutItems = _decodeExerciseItems(
        (item['workoutItemsJson'] ?? '').trim(),
      );
      final name = (item['exerciseName'] ?? '').trim();
      final duration = (item['durationMinutes'] ?? '').trim();
      final sets = (item['sets'] ?? '').trim();
      final reps = (item['reps'] ?? '').trim();
      final noExercise = (item['noExercise'] ?? '').trim() == 'true';
      final notes = (item['notes'] ?? '').trim();
      final details = <String>[
        if (workoutItems.isNotEmpty)
          workoutItems
              .take(3)
              .map(
                (entry) =>
                    '${entry['name']}${entry['sets']!.isNotEmpty && entry['reps']!.isNotEmpty ? ' (${entry['sets']}x${entry['reps']})' : ''}',
              )
              .join(', ')
        else if (name.isNotEmpty)
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
        .map((item) => '${_formatTimelineLabel(item.timestamp)}: ${item.text}')
        .where((text) => text.trim().isNotEmpty)
        .take(28)
        .toList(growable: false);
  }

  String _buildTodayContext({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
    required List<SymptomEntry> activeSymptoms,
    required List<SymptomEntry> recentSymptoms,
    required ExerciseStore exerciseStore,
    required int todayExerciseCount,
  }) {
    final now = DateTime.now();
    final parts = <String>[];

    final todayMoods = moodStore.items
        .where((item) => _isSameDay(item.createdAt, now))
        .take(6)
        .map(
          (item) =>
              '${item.moodLabel} ${item.intensity}/5${item.notes.trim().isEmpty ? '' : ' (${_trimShort(item.notes)})'}',
        )
        .toList(growable: false);
    if (todayMoods.isNotEmpty) {
      parts.add('mood ${todayMoods.join(' -> ')}');
    }

    final todaySleep = sleepStore.items
        .where(
          (item) =>
              _isSameDay(item.date, now) || _isSameDay(item.wakeTime, now),
        )
        .take(3)
        .map(
          (item) =>
              '${(item.duration.inMinutes / 60.0).toStringAsFixed(1)}h ${item.quality.label}',
        )
        .toList(growable: false);
    if (todaySleep.isNotEmpty) {
      parts.add('sleep ${todaySleep.join(' | ')}');
    }

    final todaySymptoms = recentSymptoms
        .where((entry) => _isSameDay(entry.timestamp, now))
        .take(5)
        .expand((entry) => entry.symptomList)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (todaySymptoms.isNotEmpty) {
      parts.add('symptoms ${todaySymptoms.join(', ')}');
    } else if (activeSymptoms.isNotEmpty) {
      final active = _flattenSymptoms(activeSymptoms).take(5).join(', ');
      if (active.isNotEmpty) parts.add('active symptoms $active');
    }

    final todayExerciseNames = exerciseStore
        .getRecentExerciseHistory(limit: 16)
        .where((item) {
          final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
          return timestamp != null && _isSameDay(timestamp, now);
        })
        .map((item) => (item['exerciseName'] ?? '').trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList(growable: false);
    if (todayExerciseCount > 0) {
      parts.add(
        'exercise $todayExerciseCount logged${todayExerciseNames.isEmpty ? '' : ' (${todayExerciseNames.join(', ')})'}',
      );
    }

    if (parts.isEmpty) {
      return 'Today\'s log context: no same-day logs yet.';
    }
    return 'Today\'s log context so far: ${parts.join('; ')}. If this is not the first log today, use these earlier same-day logs to make the suggestion more specific.';
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
        final latestMoodProfile = _moodSuggestionProfile(
          recentMoods.first.moodLabel,
        );
        if (latestMoodProfile.tone == _MoodSuggestionTone.positive) {
          observations.add(
            'You already have movement logged today and your latest mood is positive, which may mean routine is helping.',
          );
        } else {
          observations.add(
            'You already have movement logged today and your latest mood is ${recentMoods.first.moodLabel.toLowerCase()}, so use movement as context rather than assuming it means the mood is positive.',
          );
        }
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

  List<Map<String, String>> _decodeExerciseItems(String encoded) {
    if (encoded.trim().isEmpty) return const <Map<String, String>>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const <Map<String, String>>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => <String, String>{
              'name': (item['exerciseName'] ?? '').toString().trim(),
              'sets': (item['sets'] ?? '').toString().trim(),
              'reps': (item['reps'] ?? '').toString().trim(),
            },
          )
          .where((item) => (item['name'] ?? '').isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, String>>[];
    }
  }

  _MoodSuggestionProfile _moodSuggestionProfileForLogText(String value) {
    final match = RegExp(
      r'mood\s+([a-zA-Z-]+)',
      caseSensitive: false,
    ).firstMatch(value);
    return _moodSuggestionProfile(match?.group(1) ?? value);
  }

  _MoodSuggestionProfile _moodSuggestionProfile(String label) {
    final normalized = label.trim().toLowerCase();
    switch (normalized) {
      case 'happy':
      case 'joy':
        return const _MoodSuggestionProfile(
          tone: _MoodSuggestionTone.positive,
          allowedWords: {
            'happy',
            'joy',
            'good',
            'positive',
            'steady',
            'support',
            'repeat',
            'protect',
            'energy',
            'maintenance',
          },
          lowAction:
              'Keep the next step simple even with a happy mood: choose one useful task and stop before you overextend.',
          lowReason:
              'Your happy mood is useful signal, but low intensity means pacing still matters.',
          steadyAction:
              'Save one detail about what supported this happy mood so you can reuse it on a harder day.',
          steadyReason:
              'Your latest mood log is positive, and capturing the cause makes future advice more specific.',
          reflectAction:
              'Write one sentence about what helped this mood, then repeat the smallest part of it today.',
          reflectReasonNoNote:
              'A quick support note helps Mini-Me learn what is actually working.',
          reflectReasonWithNote:
              'Your note gives real context, so turning it into one repeatable support makes the advice less random.',
          followThroughAction:
              'Use this steadier mood for one maintenance action: prep water, set up sleep, or clear one small task.',
          followThroughReason:
              'Positive mood is a good time for a small setup action, not a reason to overload the day.',
          crossSignalAction:
              'Check whether movement, sleep, or a social moment helped this mood, then repeat the smallest piece of it today.',
          crossSignalReason:
              'Connecting the mood log to a likely support pattern makes the suggestion more reusable.',
        );
      case 'affectionate':
      case 'love':
        return const _MoodSuggestionProfile(
          tone: _MoodSuggestionTone.positive,
          allowedWords: {
            'affectionate',
            'love',
            'connected',
            'connection',
            'support',
            'message',
            'social',
            'care',
            'warm',
            'relationship',
          },
          lowAction:
              'Keep connection low-pressure: send one short message or make one kind gesture without adding a big commitment.',
          lowReason:
              'Your affectionate mood points toward connection, but the next step should still match your energy.',
          steadyAction:
              'Use this affectionate mood for one small connection action, like a short check-in message or a quick thank-you.',
          steadyReason:
              'The logged mood is connection-oriented, so a small social follow-through fits better than generic productivity advice.',
          reflectAction:
              'Name who or what helped you feel affectionate, then choose one small way to protect that connection today.',
          reflectReasonNoNote:
              'A connection note helps Mini-Me tell whether this mood came from a person, place, or moment.',
          reflectReasonWithNote:
              'Your note gives context, so the useful next step is preserving the connection signal it points to.',
          followThroughAction:
              'Protect the good signal without overdoing it: keep one boundary or rest window alongside connection time.',
          followThroughReason:
              'Affectionate moods can support the day best when connection and recovery both stay realistic.',
          crossSignalAction:
              'Compare this affectionate mood with sleep and exercise today to see whether connection came with higher or lower energy.',
          crossSignalReason:
              'Pairing connection with body signals makes future suggestions more precise.',
        );
      case 'surprised':
      case 'surprise':
        return const _MoodSuggestionProfile(
          tone: _MoodSuggestionTone.ambiguous,
          allowedWords: {
            'surprised',
            'surprise',
            'unexpected',
            'changed',
            'change',
            'orient',
            'pause',
            'notice',
            'name',
            'process',
            'ground',
            'settle',
            'trigger',
          },
          lowAction:
              'Pause for a minute and name what changed, then pick the next step only after your body settles.',
          lowReason:
              'Surprised can be positive or stressful, so orienting first is safer than treating it like a happy mood.',
          steadyAction:
              'Write one sentence about what surprised you, then decide whether it needs action now or can wait.',
          steadyReason:
              'Your latest mood was surprised, so the useful step is sorting the unexpected change before reacting.',
          reflectAction:
              'Name whether the surprise felt good, stressful, or unclear, then choose one matching reset.',
          reflectReasonNoNote:
              'Surprise needs context before Mini-Me can tell whether to suggest celebration, grounding, or problem-solving.',
          reflectReasonWithNote:
              'Your note points to the source of the surprise, so labeling its direction makes the next action fit better.',
          followThroughAction:
              'Keep the next action reversible: send one message, make one note, or wait ten minutes before deciding.',
          followThroughReason:
              'Unexpected moods are easier to handle with a small, low-commitment next step.',
          crossSignalAction:
              'Check whether sleep, symptoms, or exercise made the surprise feel more intense before adding more stimulation.',
          crossSignalReason:
              'Surprise can feel sharper when recovery is low, so cross-checking body signals keeps the advice grounded.',
        );
      case 'angry':
      case 'anger':
        return const _MoodSuggestionProfile(
          tone: _MoodSuggestionTone.heavy,
          allowedWords: {
            'angry',
            'anger',
            'frustrated',
            'cool',
            'space',
            'pause',
            'pressure',
            'boundary',
            'tension',
            'reset',
          },
          lowAction:
              'Create space before responding: step away, unclench your jaw or hands, and wait a few minutes before the next message or task.',
          lowReason:
              'Your angry mood log points to tension, so reducing reactivity fits better than pushing forward.',
          steadyAction:
              'Choose one pressure valve: take a short walk, write the unsent response, or move one irritating task later.',
          steadyReason:
              'Anger often needs discharge or space before problem-solving becomes useful.',
          reflectAction:
              'Write the boundary or need underneath the anger in one sentence, without sending it yet.',
          reflectReasonNoNote:
              'Naming the trigger helps turn anger into useful information instead of a generic mood label.',
          reflectReasonWithNote:
              'Your note gives context, so the next helpful step is identifying the boundary it points toward.',
          followThroughAction:
              'Handle one concrete source of friction today, but keep the action small enough that it does not escalate the mood.',
          followThroughReason:
              'The logged anger can guide a practical fix if the next step stays controlled.',
          crossSignalAction:
              'Check whether short sleep, symptoms, or skipped recovery made the anger louder before judging the whole day.',
          crossSignalReason:
              'Body strain can amplify anger, so cross-checking recovery makes the advice more accurate.',
        );
      case 'scared':
      case 'fear':
        return const _MoodSuggestionProfile(
          tone: _MoodSuggestionTone.heavy,
          allowedWords: {
            'scared',
            'fear',
            'safe',
            'safety',
            'ground',
            'support',
            'reassure',
            'steady',
            'breath',
            'body',
            'check',
          },
          lowAction:
              'Ground first: look around, name five things you can see, and choose one safe next step instead of solving everything at once.',
          lowReason:
              'Your scared mood log calls for safety and grounding before bigger decisions.',
          steadyAction:
              'Make the next step feel safer: lower the task size, move to a calmer place, or ask one trusted person for support.',
          steadyReason:
              'Fear-related moods usually need reassurance and control, not generic productivity advice.',
          reflectAction:
              'Name what feels unsafe or uncertain, then separate what needs action today from what can wait.',
          reflectReasonNoNote:
              'A fear trigger note helps Mini-Me suggest support instead of guessing.',
          reflectReasonWithNote:
              'Your note gives context, so sorting immediate risk from worry makes the next step fit better.',
          followThroughAction:
              'Pick one reassurance action: check the fact, prepare the item, or ask for help, then stop there.',
          followThroughReason:
              'A scared mood benefits from one concrete safety signal rather than many new tasks.',
          crossSignalAction:
              'Check sleep and symptoms before interpreting the fear, because low recovery can make threat signals feel louder.',
          crossSignalReason:
              'Grounding the mood in body context keeps the advice practical and less alarmist.',
        );
      case 'sad':
      case 'sadness':
        return const _MoodSuggestionProfile(
          tone: _MoodSuggestionTone.heavy,
          allowedWords: {
            'sad',
            'sadness',
            'low',
            'gentle',
            'comfort',
            'connect',
            'support',
            'pressure',
            'small',
            'care',
            'rest',
          },
          lowAction:
              'Make the next hour smaller: choose one low-pressure task, add one comfort cue, and leave anything optional for later.',
          lowReason:
              'Your sad mood log points toward lower emotional energy, so gentler pacing fits better than forcing productivity.',
          steadyAction:
              'Choose one tiny care action: drink water, step outside briefly, or message someone safe without needing a long conversation.',
          steadyReason:
              'Sad moods often respond best to small support signals rather than big plans.',
          reflectAction:
              'Write one sentence about what happened before this sadness, then pick one reset you can do in under five minutes.',
          reflectReasonNoNote:
              'A quick trigger note gives Mini-Me better signal for the next suggestion.',
          reflectReasonWithNote:
              'Your note points to real context, so naming the trigger can make the next step feel less random.',
          followThroughAction:
              'Protect energy for the next block: do the easiest necessary thing and postpone one nonessential demand.',
          followThroughReason:
              'The logged sadness makes reducing pressure more relevant than adding more goals.',
          crossSignalAction:
              'Check whether sleep, symptoms, or skipped movement are overlapping with this sadness before deciding what the day means.',
          crossSignalReason:
              'Sadness can be amplified by recovery signals, so cross-checking avoids advice that misses the real driver.',
        );
      case 'neutral':
      case 'content':
      default:
        return const _MoodSuggestionProfile(
          tone: _MoodSuggestionTone.neutral,
          allowedWords: {
            'neutral',
            'content',
            'steady',
            'maintenance',
            'check',
            'notice',
            'routine',
            'energy',
            'small',
            'baseline',
          },
          lowAction:
              'Keep it simple: choose one maintenance task and use it as a baseline check for your energy.',
          lowReason:
              'A neutral mood with lower intensity is best treated as a pacing signal, not a push signal.',
          steadyAction:
              'Use the neutral mood as baseline data: do one normal routine step and notice whether energy rises or drops after it.',
          steadyReason:
              'Neutral logs are useful because they show what your regular day feels like, especially when paired with sleep and exercise.',
          reflectAction:
              'Add one note about what feels ordinary or different today so future suggestions have more context.',
          reflectReasonNoNote:
              'Neutral mood needs a bit of context before Mini-Me can tell what should change.',
          reflectReasonWithNote:
              'Your note gives context, so the next useful step is testing one small routine adjustment.',
          followThroughAction:
              'Pick one low-friction routine action: prep water, tidy one surface, or set a sleep reminder.',
          followThroughReason:
              'A neutral mood is a good fit for maintenance, not intense emotional advice.',
          crossSignalAction:
              'Compare this neutral mood with sleep and exercise today to see what your baseline looks like.',
          crossSignalReason:
              'Baseline mood becomes meaningful when it is connected to the rest of the day\'s logs.',
        );
    }
  }

  bool _matchesMoodProfile(String combined, _MoodSuggestionProfile profile) {
    final hasProfileWord = profile.allowedWords.any(combined.contains);
    if (!hasProfileWord) return false;

    if (profile.tone != _MoodSuggestionTone.positive &&
        _containsAny(combined, const [
          'celebrate',
          'happy mood',
          'good mood',
          'positive mood',
          'reuse it on a harder day',
          'repeat what helped',
        ])) {
      return false;
    }

    if (profile.tone == _MoodSuggestionTone.positive &&
        _containsAny(combined, const [
          'fear',
          'unsafe',
          'anger',
          'angry',
          'sadness',
          'sad mood',
        ])) {
      return false;
    }

    return true;
  }

  bool _containsAny(String value, Iterable<String> needles) {
    return needles.any(value.contains);
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
        return 3;
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

  String _formatTimelineLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_formatDateLabel(local)} $hour:$minute';
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

class _GeneratedSuggestion {
  const _GeneratedSuggestion({required this.action, required this.reason});

  final String action;
  final String reason;
}

class _MoodSuggestionProfile {
  const _MoodSuggestionProfile({
    required this.tone,
    required this.allowedWords,
    required this.lowAction,
    required this.lowReason,
    required this.steadyAction,
    required this.steadyReason,
    required this.reflectAction,
    required this.reflectReasonNoNote,
    required this.reflectReasonWithNote,
    required this.followThroughAction,
    required this.followThroughReason,
    required this.crossSignalAction,
    required this.crossSignalReason,
  });

  final _MoodSuggestionTone tone;
  final Set<String> allowedWords;
  final String lowAction;
  final String lowReason;
  final String steadyAction;
  final String steadyReason;
  final String reflectAction;
  final String reflectReasonNoNote;
  final String reflectReasonWithNote;
  final String followThroughAction;
  final String followThroughReason;
  final String crossSignalAction;
  final String crossSignalReason;
}

enum _MoodSuggestionTone { positive, neutral, ambiguous, heavy }

class _LatestLogFocus {
  const _LatestLogFocus({
    required this.kind,
    required this.text,
    required this.keywords,
    required this.occurrenceCountToday,
    required this.variationCue,
  });

  final _LatestLogKind kind;
  final String text;
  final Set<String> keywords;
  final int occurrenceCountToday;
  final String variationCue;

  String get promptText =>
      '${kind.label}: $text\nSame-category logs today: $occurrenceCountToday\nVariation cue: $variationCue';
}

enum _LatestLogKind {
  mood('mood'),
  sleep('sleep'),
  symptom('symptom'),
  exercise('exercise'),
  fitness('fitness'),
  eod('end-of-day'),
  chat('chat');

  const _LatestLogKind(this.label);

  final String label;
}
