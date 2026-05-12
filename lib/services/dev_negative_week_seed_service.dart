import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final warningText = warnings.isEmpty
        ? ''
        : '\n\nCloud sync warnings: ${warnings.join('; ')}';
    return 'Seeded this account with $moodDays mood logs, $sleepDays poor sleep logs, $exerciseDays no-exercise check-ins, and $symptomDays symptom days across the last week.$warningText';
  }
}

class DevNegativeWeekSeedService {
  DevNegativeWeekSeedService._();

  static const command = '/seed-negative-week';
  static const _seedId = 'lifelens_negative_week_v1';
  static const _seedMarker = '[LifeLens negative-week seed]';

  static Future<DevNegativeWeekSeedResult> seedCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in before seeding demo logs.');
    }

    final now = DateTime.now();
    final firestore = FirebaseFirestore.instance;
    final isar = IsarService.instance;
    final warnings = <String>[];
    debugPrint('[DevSeed] negative week seed requested for ${user.uid}');
    await isar.init();

    final plans = _buildPlans(now);
    for (final plan in plans) {
      await _writeMoodIfNeeded(
        isar: isar,
        firestore: firestore,
        uid: user.uid,
        plan: plan,
        warnings: warnings,
      );

      if (plan.symptoms.isNotEmpty) {
        await _writeSymptomsIfNeeded(
          isar: isar,
          firestore: firestore,
          uid: user.uid,
          plan: plan,
          warnings: warnings,
        );
      }
    }

    await _writeSleepLogs(
      firestore: firestore,
      uid: user.uid,
      plans: plans,
      warnings: warnings,
    );
    await _writeExerciseLogs(
      firestore: firestore,
      uid: user.uid,
      plans: plans,
      warnings: warnings,
    );

    final result = DevNegativeWeekSeedResult(
      uid: user.uid,
      moodDays: plans.length,
      sleepDays: plans.length,
      exerciseDays: plans.length,
      symptomDays: plans.where((plan) => plan.symptoms.isNotEmpty).length,
      warnings: warnings,
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
        moodLabel: 'fear',
        intensity: 2,
        note: 'Anxious and tense, kept worrying about small things.',
        sleepMinutes: 270,
        sleepNote: 'Took a long time to fall asleep and woke up tired.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'anger',
        intensity: 2,
        note: 'Frustrated, irritable, and overwhelmed most of the afternoon.',
        sleepMinutes: 340,
        sleepNote: 'Light sleep with a lot of tossing and turning.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'sadness',
        intensity: 1,
        note: 'Felt drained, isolated, and not motivated to do much.',
        sleepMinutes: 250,
        sleepNote: 'Very short sleep and felt unrefreshed.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'fear',
        intensity: 2,
        note: 'Stress stayed high and I felt physically worn down.',
        sleepMinutes: 315,
        sleepNote: 'Woke up with a headache and low energy.',
      ),
      const _SeedDayPlanData(
        moodLabel: 'sadness',
        intensity: 2,
        note: 'Heavy mood, low appetite, and did not feel like socializing.',
        sleepMinutes: 285,
        sleepNote: 'Interrupted sleep and felt groggy in the morning.',
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
    required FirebaseFirestore firestore,
    required String uid,
    required _SeedDayPlan plan,
    required List<String> warnings,
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
        ..userConfirmed = true
        ..responseText = ''
        ..fitnessScoreSnapshot = 32.0
        ..timestamp = plan.moodTimestamp;
      await isar.writeMoodEntry(entry);
    }

    try {
      await firestore
          .collection('users')
          .doc(uid)
          .collection('mood_logs')
          .doc('${_seedId}_${plan.compactDateKey}')
          .set({
            'date': plan.dateKey,
            'rawLog': '${plan.note} $_seedMarker',
            'condensedLog':
                '${plan.moodLabel} ${plan.intensity}/5 - ${plan.note}',
            'resolvedMood': plan.moodLabel,
            'resolvedBy': 'user',
            'mobileBertPrediction': null,
            'mobileBertTopProb': null,
            'userConfirmed': true,
            'responseText': '',
            'fitnessScoreSnapshot': 32.0,
            'tags': const ['low energy', 'stress', 'demo seed'],
            'createdAt': Timestamp.fromDate(plan.moodTimestamp),
            'seedId': _seedId,
          }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      warnings.add('mood cloud sync failed for ${plan.dateKey}: ${error.code}');
    }

    return !alreadySeeded;
  }

  static Future<void> _writeSleepLogs({
    required FirebaseFirestore firestore,
    required String uid,
    required List<_SeedDayPlan> plans,
    required List<String> warnings,
  }) async {
    for (final plan in plans) {
      try {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('sleep_logs')
            .doc('${_seedId}_${plan.compactDateKey}')
            .set({
              'bedTime': Timestamp.fromDate(plan.bedTime),
              'wakeTime': Timestamp.fromDate(plan.wakeTime),
              'quality': 'poor',
              'qualityValue': 1,
              'date': Timestamp.fromDate(plan.date),
              'notes': '${plan.sleepNote} $_seedMarker',
              'durationMinutes': plan.sleepMinutes,
              'seedId': _seedId,
            }, SetOptions(merge: true));
      } on FirebaseException catch (error) {
        warnings.add(
          'sleep cloud sync failed for ${plan.dateKey}: ${error.code}',
        );
      }
    }
  }

  static Future<void> _writeExerciseLogs({
    required FirebaseFirestore firestore,
    required String uid,
    required List<_SeedDayPlan> plans,
    required List<String> warnings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = 'exercise_history_v2_$uid';
    final existing =
        prefs
            .getStringList(historyKey)
            ?.map(_decodeHistoryRecord)
            .where((record) => record['seedId'] != _seedId)
            .toList(growable: true) ??
        <Map<String, String>>[];
    final seedRecords = plans
        .map(
          (plan) => <String, String>{
            'exerciseId': 'no_exercise',
            'exerciseName': 'No exercise',
            'mood': plan.moodLabel,
            'durationMinutes': '0',
            'sets': '0',
            'reps': '0',
            'noExercise': 'true',
            'timestamp': plan.exerciseTimestamp.toIso8601String(),
            'seedId': _seedId,
          },
        )
        .toList(growable: false);
    final merged = <Map<String, String>>[...seedRecords, ...existing]
      ..sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
    await prefs.setStringList(
      historyKey,
      merged.map(jsonEncode).toList(growable: false),
    );

    for (final record in seedRecords) {
      final timestamp = DateTime.parse(record['timestamp']!);
      final dateKey = _dateKey(timestamp);
      try {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('exercise_logs')
            .doc('${_seedId}_${_compactDateKey(timestamp)}')
            .set({
              'exerciseId': record['exerciseId'],
              'exerciseName': record['exerciseName'],
              'mood': record['mood'],
              'durationMinutes': 0,
              'sets': 0,
              'reps': 0,
              'noExercise': true,
              'timestamp': Timestamp.fromDate(timestamp),
              'createdAt': FieldValue.serverTimestamp(),
              'seedId': _seedId,
            }, SetOptions(merge: true));
      } on FirebaseException catch (error) {
        warnings.add('exercise cloud sync failed for $dateKey: ${error.code}');
      }
    }
  }

  static Future<bool> _writeSymptomsIfNeeded({
    required IsarService isar,
    required FirebaseFirestore firestore,
    required String uid,
    required _SeedDayPlan plan,
    required List<String> warnings,
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

    try {
      await firestore
          .collection('symptom_entries')
          .doc('${_safeDocId(uid)}_${_seedId}_${plan.compactDateKey}')
          .set({
            'userId': uid,
            'rawInput': symptomPlan.raw,
            'symptoms': symptomPlan.symptoms,
            'createdAt': Timestamp.fromDate(plan.symptomTimestamp),
            'date': Timestamp.fromDate(plan.date),
            'seedId': _seedId,
          }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      warnings.add(
        'symptom cloud sync failed for ${plan.dateKey}: ${error.code}',
      );
    }

    return !alreadySeeded;
  }

  static Map<String, String> _decodeHistoryRecord(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      }
    } catch (_) {}
    return const <String, String>{};
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _compactDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}$month$day';
  }

  static String _safeDocId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
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
  String get compactDateKey => DevNegativeWeekSeedService._compactDateKey(date);
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
