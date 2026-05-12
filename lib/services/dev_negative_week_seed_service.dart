import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/database/sleep_entry.dart';
import 'package:lifelens/database/exercise_entry.dart';
import 'package:lifelens/database/symptom_entry.dart';

class DevNegativeWeekSeedResult {
  const DevNegativeWeekSeedResult({
    required this.uid,
    required this.moodDays,
    required this.sleepDays,
    required this.exerciseDays,
    required this.symptomDays,
    required this.warnings,
  });

  final String uid;
  final int moodDays;
  final int sleepDays;
  final int exerciseDays;
  final int symptomDays;
  final List<String> warnings;

  String get summary {
    return 'Seeded this account with $moodDays mood logs, $sleepDays poor sleep logs, $exerciseDays no-exercise check-ins, and $symptomDays symptom days across the last week.';
  }
}

class DevNegativeWeekSeedService {
  DevNegativeWeekSeedService._();

  static const command = '/seed-negative-week';
  static const _seedMarker = '[LifeLens negative-week seed]';

  static Future<DevNegativeWeekSeedResult> seedCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in before seeding demo logs.');
    }

    final now = DateTime.now();
    final isar = AppServices.isar;
    debugPrint('[DevSeed] negative week seed requested for ${user.uid}');

    final plans = _buildPlans(now);
    for (final plan in plans) {
      await _writeMoodIfNeeded(isar: isar, plan: plan);

      if (plan.symptoms.isNotEmpty) {
        await _writeSymptomsIfNeeded(isar: isar, plan: plan);
      }
    }

    await _writeSleepLogs(isar: isar, plans: plans);
    await _writeExerciseLogs(isar: isar, plans: plans);

    final result = DevNegativeWeekSeedResult(
      uid: user.uid,
      moodDays: plans.length,
      sleepDays: plans.length,
      exerciseDays: plans.length,
      symptomDays: plans.where((plan) => plan.symptoms.isNotEmpty).length,
      warnings: const [],
    );
    debugPrint('[DevSeed] negative week seed complete: ${result.summary}');
    return result;
  }

  static List<_SeedDayPlan> _buildPlans(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final symptomPlans = <int, _SymptomPlan>{
      4: const _SymptomPlan(
        raw: 'Headache, fatigue, and nausea after a stressful day.',
        symptoms: ['headache', 'fatigue', 'nausea'],
        predictedAilment: 'Tension headache',
        diagnoses: ['Tension headache', 'Migraine', 'Viral illness'],
      ),
      1: const _SymptomPlan(
        raw: 'Sore throat, body aches, and chills with low energy.',
        symptoms: ['sore throat', 'body aches', 'chills', 'fatigue'],
        predictedAilment: 'Viral upper respiratory infection',
        diagnoses: [
          'Viral upper respiratory infection',
          'Influenza-like illness',
          'COVID-like respiratory infection',
        ],
      ),
    };

    final entries = <_SeedDayPlanData>[
      const _SeedDayPlanData(
        moodLabel: 'sadness',
        intensity: 2,
        note: 'Low energy all day and had trouble focusing at work.',
        sleepMinutes: 305,
        sleepNote: 'Restless night, woke up several times.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'anxiety',
        intensity: 2,
        note: 'Anxious about upcoming deadlines and felt overwhelmed.',
        sleepMinutes: 270,
        sleepNote: 'Could not fall asleep, mind racing.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'anger',
        intensity: 2,
        note: 'Frustrated with everything today, short tempered.',
        sleepMinutes: 315,
        sleepNote: 'Woke up multiple times, groggy in morning.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'sadness',
        intensity: 1,
        note: 'Really struggling today, everything feels heavy.',
        sleepMinutes: 240,
        sleepNote: 'Barely slept, kept waking up with anxiety.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'fear',
        intensity: 2,
        note: 'Headache all day, nausea, and felt completely off.',
        sleepMinutes: 285,
        sleepNote: 'Woke up feeling worse than when I went to bed.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'anxiety',
        intensity: 1,
        note: 'Sore throat and chills, feeling sick on top of everything.',
        sleepMinutes: 295,
        sleepNote: 'Fitful sleep, kept waking up cold then hot.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'sadness',
        intensity: 1,
        note: 'Exhausted, discouraged, and still feeling run down today.',
        sleepMinutes: 300,
        sleepNote: 'Poor sleep again and woke up already tired.',
      ),
    ];

    return List<_SeedDayPlan>.generate(entries.length, (index) {
      final offsetFromToday = entries.length - 1 - index;
      final day = today.subtract(Duration(days: offsetFromToday));
      final data = entries[index];
      return _SeedDayPlan(
        date: day,
        moodLabel: data.moodLabel,
        intensity: data.intensity,
        note: data.note,
        sleepMinutes: data.sleepMinutes,
        sleepNote: data.sleepNote,
        symptomPlan: symptomPlans[offsetFromToday],
      );
    }, growable: false);
  }

  static Future<bool> _writeMoodIfNeeded({
    required IsarService isar,
    required _SeedDayPlan plan,
  }) async {
    final existing = await isar.getMoodEntriesForDate(plan.dateKey);
    final alreadySeeded = existing.any(
      (entry) => entry.rawLog.contains(_seedMarker),
    );
    if (!alreadySeeded) {
      final entry = MoodEntry()
        ..date = plan.dateKey
        ..rawLog = '${plan.note} $_seedMarker'
        ..condensedLog = '${plan.moodLabel} ${plan.intensity}/5 - ${plan.note}'
        ..resolvedMood = plan.moodLabel
        ..resolvedBy = 'user'
        ..mobileBertPrediction = null
        ..mobileBertTopProb = null
        ..responseText = ''
        ..fitnessScoreSnapshot = 32.0
        ..timestamp = plan.moodTimestamp;
      await isar.writeMoodEntry(entry);
    }

    return !alreadySeeded;
  }

  static Future<void> _writeSleepLogs({
    required IsarService isar,
    required List<_SeedDayPlan> plans,
  }) async {
    for (final plan in plans) {
      final existing = await isar.getSleepEntriesForDate(plan.dateKey);
      final alreadySeeded = existing.any(
        (entry) => entry.notes.contains(_seedMarker),
      );
      if (!alreadySeeded) {
        await isar.writeSleepEntry(
          SleepEntry()
            ..date = plan.dateKey
            ..bedTime = plan.bedTime
            ..wakeTime = plan.wakeTime
            ..quality = 'poor'
            ..qualityValue = 1
            ..notes = '${plan.sleepNote} $_seedMarker'
            ..durationMinutes = plan.sleepMinutes
            ..timestamp = plan.bedTime,
        );
      }
    }
  }

  static Future<void> _writeExerciseLogs({
    required IsarService isar,
    required List<_SeedDayPlan> plans,
  }) async {
    for (final plan in plans) {
      final existing = await isar.getExerciseEntriesForDate(plan.dateKey);
      final alreadySeeded = existing.any(
        (entry) => entry.exerciseId == 'no_exercise' &&
            entry.exerciseName.contains(_seedMarker),
      );
      if (!alreadySeeded) {
        await isar.writeExerciseEntry(
          ExerciseEntry()
            ..date = plan.dateKey
            ..exerciseId = 'no_exercise'
            ..exerciseName = 'No exercise $_seedMarker'
            ..mood = plan.moodLabel
            ..durationMinutes = 0
            ..sets = 0
            ..reps = 0
            ..noExercise = true
            ..workoutItemsJson = ''
            ..workoutCount = 0
            ..timestamp = plan.exerciseTimestamp,
        );
      }
    }
  }

  static Future<bool> _writeSymptomsIfNeeded({
    required IsarService isar,
    required _SeedDayPlan plan,
  }) async {
    final symptomPlan = plan.symptomPlan;
    if (symptomPlan == null) return false;

    final existing = await isar.getSymptomEntriesForDate(plan.dateKey);
    final alreadySeeded = existing.any(
      (entry) => entry.rawSymptoms.contains(_seedMarker),
    );
    if (!alreadySeeded) {
      final entry = SymptomEntry()
        ..date = plan.dateKey
        ..rawSymptoms = '${symptomPlan.raw} $_seedMarker'
        ..symptomList = symptomPlan.symptoms
        ..predictedAilment = symptomPlan.predictedAilment
        ..disEmbedScore = 0.0
        ..diagnosesJson = jsonEncode(
          symptomPlan.diagnoses
              .map(
                (diagnosis) => {
                  'disease': diagnosis,
                  'reasoning':
                      'Demo seed based on the reported symptom cluster.',
                  'next_steps':
                      'Monitor symptoms, rest, hydrate, and seek care if symptoms worsen.',
                  'is_urgent': false,
                },
              )
              .toList(growable: false),
        )
        ..resolvedBy = 'gemini'
        ..ragUsed = true
        ..wasOffline = false
        ..status = 'active'
        ..timestamp = plan.symptomTimestamp
        ..updatedAt = plan.symptomTimestamp;
      await isar.writeSymptomEntry(entry);
    }

    return !alreadySeeded;
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _SeedDayPlanData {
  const _SeedDayPlanData({
    required this.moodLabel,
    required this.intensity,
    required this.note,
    required this.sleepMinutes,
    required this.sleepNote,
  });

  final String moodLabel;
  final int intensity;
  final String note;
  final int sleepMinutes;
  final String sleepNote;
}

class _SeedDayPlan extends _SeedDayPlanData {
  const _SeedDayPlan({
    required this.date,
    required super.moodLabel,
    required super.intensity,
    required super.note,
    required super.sleepMinutes,
    required super.sleepNote,
    required this.symptomPlan,
  });

  final DateTime date;
  final _SymptomPlan? symptomPlan;

  List<String> get symptoms => symptomPlan?.symptoms ?? const <String>[];
  String get dateKey => DevNegativeWeekSeedService._dateKey(date);
  DateTime get moodTimestamp =>
      date.add(const Duration(hours: 10, minutes: 15));
  DateTime get wakeTime => date.add(const Duration(hours: 6, minutes: 20));
  DateTime get bedTime => wakeTime.subtract(Duration(minutes: sleepMinutes));
  DateTime get exerciseTimestamp =>
      date.add(const Duration(hours: 18, minutes: 30));
  DateTime get symptomTimestamp =>
      date.add(const Duration(hours: 13, minutes: 45));
}

class _SymptomPlan {
  const _SymptomPlan({
    required this.raw,
    required this.symptoms,
    required this.predictedAilment,
    required this.diagnoses,
  });

  final String raw;
  final List<String> symptoms;
  final String predictedAilment;
  final List<String> diagnoses;
}
