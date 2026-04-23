import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreakSnapshot? _cachedSnapshot;
  String? _cachedKey;
  DateTime? _cachedAt;
  String? _lastPersistedFingerprint;

  Future<StreakSnapshot> buildSnapshot({
    required List<MoodCheckIn> moodLogs,
    int recentDays = 7,
  }) async {
    final uid = _auth.currentUser?.uid;
    final cacheUid = uid ?? 'guest';
    final today = _startOfDay(DateTime.now());
    final moodSignature = moodLogs.isEmpty
        ? 'none'
        : '${moodLogs.length}:${moodLogs.first.createdAt.toIso8601String()}';
    final requestKey =
        '$cacheUid|$recentDays|${today.toIso8601String()}|$moodSignature';

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

    StreakSnapshot? persisted;
    if (uid != null) {
      final snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
        _firestore
            .collection('users')
            .doc(uid)
            .collection('sleep_logs')
            .limit(500)
            .get(),
        _firestore
            .collection('symptom_entries')
            .where('userId', isEqualTo: uid)
            .limit(500)
            .get(),
        _firestore
            .collection('users')
            .doc(uid)
            .collection('exercise_logs')
            .limit(500)
            .get(),
      ]);

      for (final doc in snapshots[0].docs) {
        final day = _extractDate(doc.data(), keys: const ['date', 'createdAt']);
        if (day != null) loggedDays.add(_startOfDay(day));
      }
      for (final doc in snapshots[1].docs) {
        final day = _extractDate(doc.data(), keys: const ['createdAt', 'date']);
        if (day != null) loggedDays.add(_startOfDay(day));
      }
      for (final doc in snapshots[2].docs) {
        final day = _extractDate(
          doc.data(),
          keys: const ['timestamp', 'createdAt', 'date'],
        );
        if (day != null) loggedDays.add(_startOfDay(day));
      }

      persisted = await _loadPersistedSnapshot(
        uid: uid,
        today: today,
        recentDays: recentDays,
      );

      if (loggedDays.isEmpty && persisted != null) {
        await _clearPersistedSnapshot(uid);
        final emptySnapshot = _buildSnapshotFromLoggedDays(
          loggedDays: loggedDays,
          today: today,
          recentDays: recentDays,
          currentStreak: 0,
          bestStreak: 0,
        );
        _cachedSnapshot = emptySnapshot;
        _cachedKey = requestKey;
        _cachedAt = now;
        _lastPersistedFingerprint = null;
        return emptySnapshot;
      }
    }

    var currentStreak = _currentStreakLength(loggedDays, today);
    var bestStreak = _bestStreakLength(loggedDays);

    if (persisted != null) {
      if (persisted.loggedToday && persisted.currentStreak > currentStreak) {
        currentStreak = persisted.currentStreak;
      }
      if (persisted.bestStreak > bestStreak) {
        bestStreak = persisted.bestStreak;
      }
    }

    final snapshot = _buildSnapshotFromLoggedDays(
      loggedDays: loggedDays,
      today: today,
      recentDays: recentDays,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );

    if (uid != null) {
      final lastLoggedDay = snapshot.loggedToday
          ? today
          : _latestLoggedDay(loggedDays);
      if (lastLoggedDay != null) {
        final fingerprint =
            '$uid|$currentStreak|$bestStreak|${lastLoggedDay.toIso8601String()}';
        if (_lastPersistedFingerprint != fingerprint) {
          await _persistSnapshot(
            uid: uid,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            lastLoggedDay: lastLoggedDay,
          );
          _lastPersistedFingerprint = fingerprint;
        }
      }
    }

    _cachedSnapshot = snapshot;
    _cachedKey = requestKey;
    _cachedAt = now;
    return snapshot;
  }

  Future<void> _clearPersistedSnapshot(String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('streaks')
        .doc('daily')
        .delete()
        .catchError((_) {});
  }

  Future<void> _persistSnapshot({
    required String uid,
    required int currentStreak,
    required int bestStreak,
    required DateTime lastLoggedDay,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('streaks')
        .doc('daily')
        .set({
          'currentStreak': currentStreak,
          'bestStreak': bestStreak,
          'lastLoggedDay': Timestamp.fromDate(lastLoggedDay),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<StreakSnapshot?> _loadPersistedSnapshot({
    required String uid,
    required DateTime today,
    required int recentDays,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('streaks')
        .doc('daily')
        .get();

    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;

    final savedCurrent = (data['currentStreak'] as num?)?.toInt() ?? 0;
    final savedBest = (data['bestStreak'] as num?)?.toInt() ?? savedCurrent;
    final parsedLast = _parseDate(data['lastLoggedDay']);
    if (parsedLast == null) return null;

    final lastLoggedDay = _startOfDay(parsedLast);
    final loggedToday = lastLoggedDay == today;
    final effectiveCurrent = loggedToday ? savedCurrent : 0;

    final activeDays = _activeStreakDays(
      today: today,
      currentStreak: effectiveCurrent,
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

    final bestStreak = savedBest > effectiveCurrent
        ? savedBest
        : effectiveCurrent;
    return StreakSnapshot(
      currentStreak: effectiveCurrent,
      bestStreak: bestStreak,
      loggedToday: loggedToday,
      recentDays: renderedDays,
      badge: _badgeForStreak(effectiveCurrent, loggedToday),
      message: _messageForStreak(effectiveCurrent, bestStreak, loggedToday),
    );
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

  DateTime? _latestLoggedDay(Set<DateTime> loggedDays) {
    if (loggedDays.isEmpty) return null;
    final sorted = loggedDays.toList()..sort();
    return sorted.last;
  }

  DateTime? _extractDate(
    Map<String, dynamic> data, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final raw = data[key];
      final parsed = _parseDate(raw);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
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
