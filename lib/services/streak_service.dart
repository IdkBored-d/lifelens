import 'package:lifelens/app_services.dart';

import '../moodlog_store.dart';

class StreakCalendarDay {
  const StreakCalendarDay({
    required this.date,
    required this.isLogged,
    required this.runLevel,
  });

  final DateTime date;
  final bool isLogged;
  final int runLevel;
}

class StreakSnapshot {
  const StreakSnapshot({
    required this.currentStreak,
    required this.bestStreak,
    required this.loggedToday,
    required this.recentDays,
    required this.badge,
    required this.message,
  });

  final int currentStreak;
  final int bestStreak;
  final bool loggedToday;
  final List<StreakCalendarDay> recentDays;
  final String badge;
  final String message;
}

class StreakService {
  StreakService._();

  static final StreakService instance = StreakService._();

  StreakSnapshot? _cachedSnapshot;
  String? _cachedKey;
  DateTime? _cachedAt;

  Future<StreakSnapshot> buildSnapshot({
    required List<MoodCheckIn> moodLogs,
    int recentDays = 7,
  }) async {
    final today = _startOfDay(DateTime.now());
    final moodSignature = moodLogs.isEmpty
        ? 'none'
        : '${moodLogs.length}:${moodLogs.first.createdAt.toIso8601String()}';
    final requestKey =
        '$recentDays|${today.toIso8601String()}|$moodSignature';

    final now = DateTime.now();
    if (_cachedSnapshot != null &&
        _cachedKey == requestKey &&
        _cachedAt != null &&
        now.difference(_cachedAt!).inSeconds < 30) {
      return _cachedSnapshot!;
    }

    final loggedDays = <DateTime>{};
    for (final mood in moodLogs) {
      loggedDays.add(_startOfDay(mood.createdAt));
    }

    final sleepEntries =
        await AppServices.isar.getRecentSleepEntries(days: 365);
    final exerciseEntries =
        await AppServices.isar.getRecentExerciseEntries(days: 365);
    final symptomEntries =
        await AppServices.isar.getRecentSymptomEntries(days: 365);

    for (final e in sleepEntries) {
      final d = DateTime.tryParse(e.date);
      if (d != null) loggedDays.add(_startOfDay(d));
    }
    for (final e in exerciseEntries) {
      loggedDays.add(_startOfDay(e.timestamp));
    }
    for (final e in symptomEntries) {
      final d = DateTime.tryParse(e.date);
      if (d != null) loggedDays.add(_startOfDay(d));
    }

    final currentStreak = _currentStreakLength(loggedDays, today);
    final bestStreak = _bestStreakLength(loggedDays);

    final snapshot = _buildSnapshotFromLoggedDays(
      loggedDays: loggedDays,
      today: today,
      recentDays: recentDays,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );

    _cachedSnapshot = snapshot;
    _cachedKey = requestKey;
    _cachedAt = now;
    return snapshot;
  }

  Set<DateTime> _activeStreakDays({
    required DateTime today,
    required int currentStreak,
    required bool loggedToday,
  }) {
    if (!loggedToday || currentStreak <= 0) {
      return <DateTime>{};
    }

    final days = <DateTime>{};
    for (var i = 0; i < currentStreak; i++) {
      days.add(_startOfDay(today.subtract(Duration(days: i))));
    }
    return days;
  }

  StreakSnapshot _buildSnapshotFromLoggedDays({
    required Set<DateTime> loggedDays,
    required DateTime today,
    required int recentDays,
    required int currentStreak,
    required int bestStreak,
  }) {
    final loggedToday = currentStreak > 0;
    final activeDays = _activeStreakDays(
      today: today,
      currentStreak: currentStreak,
      loggedToday: loggedToday,
    );

    final recent = List<DateTime>.generate(
      recentDays,
      (index) =>
          _startOfDay(today.subtract(Duration(days: recentDays - 1 - index))),
    );

    final renderedDays = <StreakCalendarDay>[];
    var rollingLevel = 0;
    for (final day in recent) {
      final isLogged = activeDays.contains(day);
      if (isLogged) {
        rollingLevel += 1;
      } else {
        rollingLevel = 0;
      }
      renderedDays.add(
        StreakCalendarDay(
          date: day,
          isLogged: isLogged,
          runLevel: rollingLevel,
        ),
      );
    }

    return StreakSnapshot(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      loggedToday: loggedToday,
      recentDays: renderedDays,
      badge: _badgeForStreak(currentStreak, loggedToday),
      message: _messageForStreak(currentStreak, bestStreak, loggedToday),
    );
  }

  int _currentStreakLength(Set<DateTime> loggedDays, DateTime today) {
    var streak = 0;
    var cursor = today;
    while (loggedDays.contains(cursor)) {
      streak += 1;
      cursor = _startOfDay(cursor.subtract(const Duration(days: 1)));
    }
    return streak;
  }

  int _bestStreakLength(Set<DateTime> loggedDays) {
    if (loggedDays.isEmpty) return 0;

    final sorted = loggedDays.toList()..sort();
    var best = 1;
    var current = 1;

    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final currentDay = sorted[i];
      final dayDiff = currentDay.difference(previous).inDays;

      if (dayDiff == 1) {
        current += 1;
      } else {
        current = 1;
      }

      if (current > best) best = current;
    }

    return best;
  }

  DateTime _startOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _badgeForStreak(int streak, bool loggedToday) {
    if (!loggedToday) return 'spark';
    if (streak <= 1) return 'sprout';
    if (streak == 2) return 'leaf';
    if (streak == 3) return 'bolt';
    if (streak <= 5) return 'flame';
    if (streak <= 9) return 'star';
    return 'crown';
  }

  String _messageForStreak(int streak, int bestStreak, bool loggedToday) {
    if (!loggedToday) {
      return 'Log any tracker today to keep your streak alive.';
    }
    if (streak == 1) return '';
    if (streak == 2) return 'Day 2 momentum. Keep rolling.';
    if (streak == 3) {
      return 'Day 3 focus streak. You are building consistency.';
    }
    if (streak <= 6) return 'Strong rhythm. Your routine is stabilizing.';
    if (streak <= 13) return 'Elite consistency. Mini-Me is impressed.';
    if (bestStreak > streak) {
      return 'Locked in. Chase your best of $bestStreak days.';
    }
    return 'Personal best pace. Keep protecting this streak.';
  }
}
