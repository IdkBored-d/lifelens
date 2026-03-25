import '../moodlog_store.dart';
import '../models/sleep.dart';

class DashboardInsight {
  const DashboardInsight({required this.title, required this.body});

  final String title;
  final String body;
}

class SummaryMetrics {
  const SummaryMetrics({
    required this.moodCheckIns7d,
    required this.avgSleepHours7d,
    required this.sleepLogs7d,
  });

  final int moodCheckIns7d;
  final double avgSleepHours7d;
  final int sleepLogs7d;
}

class PersonalInsightsService {
  static DashboardInsight buildDashboardInsight({
    required List<MoodCheckIn> moods,
    required List<Sleep> sleeps,
  }) {
    if (moods.isEmpty && sleeps.isEmpty) {
      return const DashboardInsight(
        title: 'Start your first pattern',
        body:
            'Log one mood and one sleep entry today to unlock personalized insights.',
      );
    }

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recentMoods = moods.where((m) => m.createdAt.isAfter(weekAgo)).toList();
    final recentSleeps = sleeps.where((s) => s.date.isAfter(weekAgo)).toList();

    final linked = _linkSleepAndMood(recentMoods, recentSleeps);

    if (linked.highSleepMoodCount >= 2 && linked.lowSleepMoodCount >= 2) {
      final highRate = linked.highSleepPositiveRatio;
      final lowRate = linked.lowSleepPositiveRatio;
      final delta = highRate - lowRate;

      if (delta >= 0.2) {
        return DashboardInsight(
          title: 'Sleep seems to improve your mood',
          body:
              'On nights with 7h+ sleep, your positive mood ratio is ${_asPercent(highRate)} vs ${_asPercent(lowRate)} after shorter sleep.',
        );
      }

      if (delta <= -0.2) {
        return DashboardInsight(
          title: 'Short sleep might not be your main trigger',
          body:
              'Your positive mood ratio is ${_asPercent(highRate)} after 7h+ sleep vs ${_asPercent(lowRate)} after shorter sleep. Consider checking stress or workload tags too.',
        );
      }
    }

    if (recentMoods.length >= 3) {
      final moodCounts = <String, int>{};
      for (final item in recentMoods) {
        moodCounts.update(item.moodLabel, (v) => v + 1, ifAbsent: () => 1);
      }

      final topMood = moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return DashboardInsight(
        title: 'Your weekly mood pattern is forming',
        body:
            'This week, ${topMood.first.key} appeared most often (${topMood.first.value}/${recentMoods.length} check-ins).',
      );
    }

    if (recentSleeps.length >= 3) {
      final avgHours = recentSleeps
              .map((s) => s.duration.inMinutes)
              .fold<int>(0, (a, b) => a + b) /
          (recentSleeps.length * 60);

      return DashboardInsight(
        title: 'Your sleep baseline is now visible',
        body:
            'Your average sleep this week is ${avgHours.toStringAsFixed(1)}h. Keep logging mood to connect sleep and emotional patterns.',
      );
    }

    return const DashboardInsight(
      title: 'Consistency beats intensity',
      body: 'A few more check-ins will unlock stronger pattern detection.',
    );
  }

  static SummaryMetrics buildSummaryMetrics({
    required List<MoodCheckIn> moods,
    required List<Sleep> sleeps,
  }) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final moodCount = moods.where((m) => m.createdAt.isAfter(weekAgo)).length;
    final recentSleeps = sleeps.where((s) => s.date.isAfter(weekAgo)).toList();

    final avgSleepHours = recentSleeps.isEmpty
        ? 0.0
        : recentSleeps
                .map((s) => s.duration.inMinutes)
                .fold<int>(0, (a, b) => a + b) /
            (recentSleeps.length * 60);

    return SummaryMetrics(
      moodCheckIns7d: moodCount,
      avgSleepHours7d: avgSleepHours,
      sleepLogs7d: recentSleeps.length,
    );
  }

  static _SleepMoodLinkResult _linkSleepAndMood(
    List<MoodCheckIn> moods,
    List<Sleep> sleeps,
  ) {
    final sleepByDate = <String, double>{};

    for (final sleep in sleeps) {
      sleepByDate[_dayKey(sleep.date)] = sleep.duration.inMinutes / 60.0;
    }

    var highSleepMoodCount = 0;
    var lowSleepMoodCount = 0;
    var highSleepPositiveCount = 0;
    var lowSleepPositiveCount = 0;

    for (final mood in moods) {
      final hours = sleepByDate[_dayKey(mood.createdAt)];
      if (hours == null) {
        continue;
      }

      final positive = _isPositiveMood(mood.moodLabel);
      if (hours >= 7) {
        highSleepMoodCount += 1;
        if (positive) {
          highSleepPositiveCount += 1;
        }
      } else {
        lowSleepMoodCount += 1;
        if (positive) {
          lowSleepPositiveCount += 1;
        }
      }
    }

    return _SleepMoodLinkResult(
      highSleepMoodCount: highSleepMoodCount,
      lowSleepMoodCount: lowSleepMoodCount,
      highSleepPositiveCount: highSleepPositiveCount,
      lowSleepPositiveCount: lowSleepPositiveCount,
    );
  }

  static String _dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String();
  }

  static bool _isPositiveMood(String label) {
    final normalized = label.toLowerCase();
    return normalized == 'happy' || normalized == 'calm';
  }

  static String _asPercent(double value) {
    return '${(value * 100).round()}%';
  }
}

class _SleepMoodLinkResult {
  const _SleepMoodLinkResult({
    required this.highSleepMoodCount,
    required this.lowSleepMoodCount,
    required this.highSleepPositiveCount,
    required this.lowSleepPositiveCount,
  });

  final int highSleepMoodCount;
  final int lowSleepMoodCount;
  final int highSleepPositiveCount;
  final int lowSleepPositiveCount;

  double get highSleepPositiveRatio {
    if (highSleepMoodCount == 0) {
      return 0;
    }
    return highSleepPositiveCount / highSleepMoodCount;
  }

  double get lowSleepPositiveRatio {
    if (lowSleepMoodCount == 0) {
      return 0;
    }
    return lowSleepPositiveCount / lowSleepMoodCount;
  }
}
