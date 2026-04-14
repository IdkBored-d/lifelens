import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/fitness_entry.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/sleep_store.dart';

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

class DailySuggestionsService {
  DailySuggestionsService._();

  static final DailySuggestionsService instance = DailySuggestionsService._();

  Future<DailySuggestionsSnapshot> buildSnapshot({
    required MoodLogStore moodStore,
    required SleepStore sleepStore,
  }) async {
    await AppServices.isar.init();

    final exerciseStore = ExerciseStore();
    await exerciseStore.ensureReady();

    final activeSymptoms = await AppServices.isar.getActiveSymptomEntries();
    final recentFitness = await AppServices.isar.getRecentFitnessEntries(days: 14);
    final recentChatSessions = await AppServices.isar.getRecentChatSessions(limit: 1);
    final recentChatMessages = recentChatSessions.isEmpty
        ? const <String>[]
        : (await AppServices.isar
                .getMessagesForSession(recentChatSessions.first.sessionId))
            .map((item) => item.text.trim())
            .where((text) => text.isNotEmpty)
            .toList(growable: false);

    final latestMood = moodStore.items.isEmpty ? null : moodStore.items.first;
    final latestSleep = sleepStore.items.isEmpty ? null : sleepStore.items.first;
    final latestFitness = recentFitness.isEmpty ? null : recentFitness.first;
    final todayExerciseCount = _todayExerciseCount(exerciseStore);

    final suggestions = <DailySuggestion>[
      ..._moodSuggestions(moodStore),
      ..._sleepSuggestions(latestSleep, recentFitness),
      ..._symptomSuggestions(activeSymptoms),
      ..._fitnessSuggestions(latestFitness, recentFitness),
      ..._exerciseSuggestions(todayExerciseCount, exerciseStore, latestMood?.moodLabel ?? ''),
      ..._followThroughSuggestions(recentChatMessages, latestMood?.moodLabel ?? ''),
    ];

    suggestions.sort((a, b) => b.priority.compareTo(a.priority));

    final deduped = <DailySuggestion>[];
    final seenKeys = <String>{};
    for (final suggestion in suggestions) {
      final key = '${suggestion.category}|${suggestion.title}|${suggestion.action}';
      if (seenKeys.add(key)) {
        deduped.add(suggestion);
      }
      if (deduped.length == 5) {
        break;
      }
    }

    if (deduped.isEmpty) {
      deduped.add(
        const DailySuggestion(
          title: 'Add one fresh signal',
          reason: 'The app needs a recent check-in to sharpen its guidance.',
          action: 'Log your mood or sleep today so tomorrow\'s suggestions can be more specific.',
          icon: Icons.track_changes_rounded,
          category: 'Getting Started',
          priority: 1,
          sourceSignals: ['recent activity'],
        ),
      );
    }

    return DailySuggestionsSnapshot(
      generatedAt: DateTime.now(),
      suggestions: deduped,
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
      latestSleepHours:
          latestSleep == null ? null : latestSleep.duration.inMinutes / 60.0,
      latestFitnessScore: latestFitness?.fitnessScore,
      todayExerciseCount: todayExerciseCount,
    );
  }

  List<DailySuggestion> _moodSuggestions(MoodLogStore moodStore) {
    if (moodStore.items.isEmpty) {
      return const [
        DailySuggestion(
          title: 'Log how you feel',
          reason: 'Mood is the fastest signal for tailoring the rest of your recommendations.',
          action: 'Open Mood Log and write how you feel right now, plus one short line about what is going on.',
          icon: Icons.emoji_emotions_outlined,
          category: 'Mood',
          priority: 95,
          sourceSignals: ['missing mood log'],
        ),
      ];
    }

    final latest = moodStore.items.first;
    final mood = latest.moodLabel.toLowerCase();
    final suggestions = <DailySuggestion>[];

    if (latest.intensity >= 4) {
      suggestions.add(
        DailySuggestion(
          title: 'Keep the next hour simple',
          reason: 'Your latest mood was ${latest.moodLabel} at ${latest.intensity}/5, which suggests a high-intensity state.',
          action: 'Make your next task the easy version, and try not to pile extra decisions or commitments on top of it.',
          icon: Icons.tune_rounded,
          category: 'Mood',
          priority: 88,
          sourceSignals: ['latest mood', 'intensity ${latest.intensity}/5'],
        ),
      );
    }

    if (mood.contains('angry')) {
      suggestions.add(
        const DailySuggestion(
          title: 'Let some of the anger out first',
          reason: 'Anger-driven choices usually improve after a short physical reset.',
          action: 'Before your next hard conversation, take a brisk 5-minute walk or slow your breathing for one minute.',
          icon: Icons.local_fire_department_outlined,
          category: 'Mood',
          priority: 92,
          sourceSignals: ['angry mood'],
        ),
      );
    } else if (mood.contains('scared')) {
      suggestions.add(
        const DailySuggestion(
          title: 'Slow things down first',
          reason: 'Fear tends to shrink when you bring attention back to the immediate environment.',
          action: 'Look around and name five things you can see, then choose the smallest next step that helps.',
          icon: Icons.shield_outlined,
          category: 'Mood',
          priority: 92,
          sourceSignals: ['scared mood'],
        ),
      );
    } else if (mood.contains('sad')) {
      suggestions.add(
        const DailySuggestion(
          title: 'Be extra gentle with yourself today',
          reason: 'When sadness is present, smaller supportive actions work better than big goals.',
          action: 'Pick one small caring action today: step outside, text someone safe, or drink some water before your next task.',
          icon: Icons.favorite_border_rounded,
          category: 'Mood',
          priority: 90,
          sourceSignals: ['sad mood'],
        ),
      );
    } else if (mood.contains('affectionate')) {
      suggestions.add(
        const DailySuggestion(
          title: 'Hold onto this good connection',
          reason: 'Warm, connected moments are useful signals worth preserving.',
          action: 'Send a short thank-you message or write down what made this moment feel warm and meaningful.',
          icon: Icons.favorite_rounded,
          category: 'Mood',
          priority: 74,
          sourceSignals: ['affectionate mood'],
        ),
      );
    } else if (mood.contains('surprised')) {
      suggestions.add(
        const DailySuggestion(
          title: 'Write down what caught you off guard',
          reason: 'Unexpected events often carry good context for later pattern review.',
          action: 'Add a quick note about what happened and whether the surprise felt good, stressful, or a bit of both.',
          icon: Icons.wb_incandescent_outlined,
          category: 'Mood',
          priority: 73,
          sourceSignals: ['surprised mood'],
        ),
      );
    } else if (mood.contains('happy')) {
      suggestions.add(
        const DailySuggestion(
          title: 'Use this good energy while it is here',
          reason: 'Positive states are a good time to reinforce habits that are harder on rougher days.',
          action: 'Do one helpful thing for later today, like setting up your evening routine or clearing one lingering task.',
          icon: Icons.sunny,
          category: 'Mood',
          priority: 70,
          sourceSignals: ['happy mood'],
        ),
      );
    }

    return suggestions;
  }

  List<DailySuggestion> _sleepSuggestions(
    dynamic latestSleep,
    List<FitnessEntry> recentFitness,
  ) {
    if (latestSleep == null) {
      return const [
        DailySuggestion(
          title: 'Log your most recent sleep',
          reason: 'Sleep is one of the strongest inputs for daily guidance, and it is currently missing.',
          action: 'Add last night\'s sleep so the app can judge recovery and strain more accurately.',
          icon: Icons.nightlight_round,
          category: 'Sleep',
          priority: 84,
          sourceSignals: ['missing sleep'],
        ),
      ];
    }

    final latestSleepHours = latestSleep.duration.inMinutes / 60.0;
    final suggestions = <DailySuggestion>[];

    if (latestSleepHours < 6.5) {
      suggestions.add(
        DailySuggestion(
          title: 'Set yourself up for better sleep tonight',
          reason: 'Your latest sleep was ${latestSleepHours.toStringAsFixed(1)} hours, which is below a solid recovery window.',
          action: 'Choose a wind-down time now and keep the last 20 minutes before bed quiet and low-screen.',
          icon: Icons.bedtime_rounded,
          category: 'Sleep',
          priority: 89,
          sourceSignals: ['sleep ${latestSleepHours.toStringAsFixed(1)}h'],
        ),
      );
    } else if (latestSleepHours >= 8) {
      suggestions.add(
        DailySuggestion(
          title: 'Use your rested energy well',
          reason: 'You logged ${latestSleepHours.toStringAsFixed(1)} hours of sleep, which gives you a stronger base for today.',
          action: 'Use that extra energy on one bigger task earlier in the day, before it fades.',
          icon: Icons.hotel_rounded,
          category: 'Sleep',
          priority: 62,
          sourceSignals: ['sleep ${latestSleepHours.toStringAsFixed(1)}h'],
        ),
      );
    }

    if (recentFitness.isNotEmpty && recentFitness.first.sleepHours < 6.5) {
      suggestions.add(
        const DailySuggestion(
          title: 'Match your day to your energy',
          reason: 'Your latest fitness inputs also point to reduced rest, so pacing matters more than pushing.',
          action: 'Choose shorter tasks with clear stopping points instead of long tasks that may drag on.',
          icon: Icons.speed_rounded,
          category: 'Sleep',
          priority: 78,
          sourceSignals: ['fitness sleep signal'],
        ),
      );
    }

    return suggestions;
  }

  List<DailySuggestion> _symptomSuggestions(List<SymptomEntry> activeSymptoms) {
    if (activeSymptoms.isEmpty) {
      return const [];
    }

    final symptomLabels = <String>{};
    for (final entry in activeSymptoms.take(3)) {
      symptomLabels.addAll(
        entry.symptomList.map((item) => item.trim()).where((item) => item.isNotEmpty),
      );
    }

    final preview = symptomLabels.take(3).join(', ');

    return [
      DailySuggestion(
        title: 'Make today easier on your body',
        reason: activeSymptoms.length == 1
            ? 'You have 1 active symptom log${preview.isEmpty ? '' : ' related to $preview'}.'
            : 'You have ${activeSymptoms.length} active symptom logs${preview.isEmpty ? '' : ' including $preview'}.',
        action: 'Choose the easiest version of your next task, and update your symptoms if anything clearly changes.',
        icon: Icons.healing_outlined,
        category: 'Symptoms',
        priority: 86,
        sourceSignals: ['${activeSymptoms.length} active symptoms'],
      ),
    ];
  }

  List<DailySuggestion> _fitnessSuggestions(
    FitnessEntry? latestFitness,
    List<FitnessEntry> recentFitness,
  ) {
    if (latestFitness == null) {
      return const [];
    }

    final suggestions = <DailySuggestion>[];
    final score = latestFitness.fitnessScore;

    if (score < 55) {
      suggestions.add(
        DailySuggestion(
          title: 'Keep today manageable',
          reason: 'Your latest fitness score is ${score.toStringAsFixed(0)}/100, which points to lower reserve right now.',
          action: 'Focus on essentials, protect your rest, and skip extra strain where you can.',
          icon: Icons.monitor_heart_outlined,
          category: 'Fitness',
          priority: 87,
          sourceSignals: ['fitness ${score.toStringAsFixed(0)}'],
        ),
      );
    } else if (score >= 75) {
      suggestions.add(
        DailySuggestion(
          title: 'Take advantage of a stronger day',
          reason: 'Your latest fitness score is ${score.toStringAsFixed(0)}/100, suggesting you have more reserve than usual.',
          action: 'Put one meaningful task or workout earlier in the day while your energy is still high.',
          icon: Icons.trending_up_rounded,
          category: 'Fitness',
          priority: 61,
          sourceSignals: ['fitness ${score.toStringAsFixed(0)}'],
        ),
      );
    }

    if (recentFitness.length >= 2) {
      final trend = recentFitness.first.fitnessScore - recentFitness[1].fitnessScore;
      if (trend <= -8) {
        suggestions.add(
          const DailySuggestion(
            title: 'Catch the slump early',
            reason: 'Your recent fitness trend dropped noticeably, which is often easier to correct early than late.',
            action: 'Keep water, food, and recovery simple and steady today instead of winging it.',
            icon: Icons.trending_down_rounded,
            category: 'Fitness',
            priority: 80,
            sourceSignals: ['declining fitness trend'],
          ),
        );
      }
    }

    return suggestions;
  }

  List<DailySuggestion> _exerciseSuggestions(
    int todayExerciseCount,
    ExerciseStore exerciseStore,
    String latestMoodLabel,
  ) {
    final recentExercise = exerciseStore.getRecentExerciseHistory(limit: 14);
    if (todayExerciseCount > 0) {
      return const [
        DailySuggestion(
          title: 'Let your workout help you recover',
          reason: 'You already logged exercise today, so the useful next step is recovery rather than more volume.',
          action: 'Have some water, do a short stretch, or take an easy walk later so today\'s movement helps instead of piles on.',
          icon: Icons.directions_walk_rounded,
          category: 'Exercise',
          priority: 55,
          sourceSignals: ['exercise logged today'],
        ),
      ];
    }

    if (recentExercise.isEmpty) {
      return const [
        DailySuggestion(
          title: 'Make movement easy to start',
          reason: 'There is no recent exercise history yet, so the best target is consistency, not intensity.',
          action: 'Pick a 5 to 10 minute walk, stretch, or easy session you would realistically do today.',
          icon: Icons.fitness_center_outlined,
          category: 'Exercise',
          priority: 66,
          sourceSignals: ['missing exercise history'],
        ),
      ];
    }

    final mood = latestMoodLabel.toLowerCase();
    if (mood.contains('angry') || mood.contains('scared') || mood.contains('sad')) {
      return const [
        DailySuggestion(
          title: 'Use movement to settle yourself',
          reason: 'Your latest mood suggests calming or release may matter more than performance today.',
          action: 'Choose gentle movement like walking, stretching, or yoga instead of turning exercise into another test.',
          icon: Icons.self_improvement_rounded,
          category: 'Exercise',
          priority: 68,
          sourceSignals: ['mood + exercise context'],
        ),
      ];
    }

    return const [];
  }

  List<DailySuggestion> _followThroughSuggestions(
    List<String> recentChatMessages,
    String latestMoodLabel,
  ) {
    if (recentChatMessages.isNotEmpty) {
      final last = recentChatMessages.last;
      return [
        DailySuggestion(
          title: 'Pick up where you left off',
          reason: 'Your recent Mini-Me chat already has context, which usually beats starting over with a new plan.',
          action: 'Go back to the last idea you discussed with Mini-Me and try the smallest version of it today.',
          icon: Icons.chat_bubble_outline_rounded,
          category: 'Follow-through',
          priority: 72,
          sourceSignals: [_trim(last, 80)],
        ),
      ];
    }

    if (latestMoodLabel.isNotEmpty) {
      return [
        DailySuggestion(
          title: 'Give yourself a little more context next time',
          reason: 'The app can give better guidance when mood labels are paired with one real trigger or situation.',
          action: 'On your next check-in, add one short line about what happened right before the mood shift.',
          icon: Icons.edit_note_rounded,
          category: 'Follow-through',
          priority: 58,
          sourceSignals: ['mood logging habit'],
        ),
      ];
    }

    return const [];
  }

  int _todayExerciseCount(ExerciseStore exerciseStore) {
    final history = exerciseStore.getRecentExerciseHistory(limit: 40);
    final today = DateTime.now();
    return history.where((item) {
      final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
      if (timestamp == null) {
        return false;
      }
      return timestamp.year == today.year &&
          timestamp.month == today.month &&
          timestamp.day == today.day;
    }).length;
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

  String _trim(String value, int maxLength) {
    final text = value.trim();
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - 3).trimRight()}...';
  }
}
