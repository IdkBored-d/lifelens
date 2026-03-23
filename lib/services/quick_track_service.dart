import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────
// QUICK-TRACK FILE SCHEMAS
// ─────────────────────────────────────────────

/// One entry in mood_log.json
/// Appended after every mood pipeline run.
class MoodLogEntry {
  final String date;          // ISO 8601 date string
  final String log;           // condensed log text
  final String predictedMood; // resolved mood label
  final double fitnessScore;  // snapshot from most recent fitness run

  const MoodLogEntry({
    required this.date,
    required this.log,
    required this.predictedMood,
    required this.fitnessScore,
  });

  factory MoodLogEntry.fromJson(Map<String, dynamic> j) => MoodLogEntry(
        date:           j['date'] as String,
        log:            j['log'] as String,
        predictedMood:  j['predicted_mood'] as String,
        fitnessScore:   (j['fitness_score'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'date':           date,
        'log':            log,
        'predicted_mood': predictedMood,
        'fitness_score':  fitnessScore,
      };
}

/// One entry in symptom_log.json
/// Appended after every symptom pipeline run.
class SymptomLogEntry {
  final String date;
  final List<String> symptoms;
  final String predictedAilment;

  /// "active" | "resolved" | "monitoring"
  final String status;

  const SymptomLogEntry({
    required this.date,
    required this.symptoms,
    required this.predictedAilment,
    this.status = 'active',
  });

  factory SymptomLogEntry.fromJson(Map<String, dynamic> j) => SymptomLogEntry(
        date:             j['date'] as String,
        symptoms:         List<String>.from(j['symptoms'] as List),
        predictedAilment: j['predicted_ailment'] as String,
        status:           j['status'] as String? ?? 'active',
      );

  Map<String, dynamic> toJson() => {
        'date':              date,
        'symptoms':          symptoms,
        'predicted_ailment': predictedAilment,
        'status':            status,
      };

  SymptomLogEntry copyWith({String? status}) => SymptomLogEntry(
        date:             date,
        symptoms:         symptoms,
        predictedAilment: predictedAilment,
        status:           status ?? this.status,
      );
}

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────

/// Manages reads and writes to the two on-device quick-tracking JSON files.
///
/// WRITE ORDER (enforced by callers, not this service):
///   1. Write to ISAR database first (source of truth)
///   2. Call this service to update the quick-tracking file
///
/// On app startup, callers should invoke [checkAndRepairSync] to detect
/// any crash that left ISAR ahead of the quick-tracking file.
class QuickTrackService {
  static const _moodFileName    = 'mood_log.json';
  static const _symptomFileName = 'symptom_log.json';

  // ── File helpers ────────────────────────────────────────────────────────────

  Future<File> _moodFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_moodFileName');
  }

  Future<File> _symptomFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_symptomFileName');
  }

  // ── Mood log ─────────────────────────────────────────────────────────────────

  Future<List<MoodLogEntry>> readMoodLog() async {
    final file = await _moodFile();
    if (!await file.exists()) return [];
    try {
      final raw     = await file.readAsString();
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => MoodLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Append a new mood entry. Called AFTER ISAR write succeeds.
  Future<void> appendMoodEntry(MoodLogEntry entry) async {
    final entries = await readMoodLog();
    entries.add(entry);
    await _writeMoodLog(entries);
  }

  /// Replace an existing mood entry by date (used by EOD consistency check).
  Future<void> updateMoodEntry(String date, MoodLogEntry updated) async {
    final entries = await readMoodLog();
    final idx     = entries.indexWhere((e) => e.date == date);
    if (idx == -1) {
      entries.add(updated);
    } else {
      entries[idx] = updated;
    }
    await _writeMoodLog(entries);
  }

  Future<void> _writeMoodLog(List<MoodLogEntry> entries) async {
    final file    = await _moodFile();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }

  // ── Symptom log ──────────────────────────────────────────────────────────────

  Future<List<SymptomLogEntry>> readSymptomLog() async {
    final file = await _symptomFile();
    if (!await file.exists()) return [];
    try {
      final raw     = await file.readAsString();
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => SymptomLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Append a new symptom entry. Called AFTER ISAR write succeeds.
  Future<void> appendSymptomEntry(SymptomLogEntry entry) async {
    final entries = await readSymptomLog();
    entries.add(entry);
    await _writeSymptomLog(entries);
  }

  /// Update the status of a symptom entry by date + ailment name.
  Future<void> updateSymptomStatus(
      String date, String ailment, String status) async {
    final entries = await readSymptomLog();
    final idx = entries.indexWhere(
        (e) => e.date == date && e.predictedAilment == ailment);
    if (idx != -1) {
      entries[idx] = entries[idx].copyWith(status: status);
      await _writeSymptomLog(entries);
    }
  }

  Future<void> _writeSymptomLog(List<SymptomLogEntry> entries) async {
    final file    = await _symptomFile();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }

  // ── Context builders for Gemma2b ─────────────────────────────────────────────

  /// Returns a Gemma2b-ready context string from the quick-tracking files.
  /// Strategy: 100% quick-tracking file, OR 70% quick-track + 30% recent logs.
  ///
  /// [recentLogs] should be the last 3 days of raw log text from ISAR.
  /// Pass null to use quick-tracking file only.
  Future<String> buildMoodContext({List<String>? recentLogs}) async {
    final entries = await readMoodLog();
    if (entries.isEmpty) return 'No mood history available.';

    final buffer = StringBuffer();
    buffer.writeln('--- MOOD HISTORY (quick-track) ---');
    for (final e in entries.take(14)) {
      // Cap at 2 weeks for context window management
      buffer.writeln('${e.date} | ${e.predictedMood} | ${e.log}');
    }

    if (recentLogs != null && recentLogs.isNotEmpty) {
      buffer.writeln('\n--- RECENT DETAILED LOGS (last 3 days) ---');
      for (final log in recentLogs.take(3)) {
        buffer.writeln(log);
      }
    }

    return buffer.toString();
  }

  Future<String> buildSymptomContext() async {
    final entries = await readSymptomLog();
    if (entries.isEmpty) return 'No symptom history available.';

    final buffer = StringBuffer();
    buffer.writeln('--- SYMPTOM HISTORY ---');
    for (final e in entries) {
      buffer.writeln(
          '${e.date} | ${e.predictedAilment} [${e.status}] | ${e.symptoms.join(", ")}');
    }
    return buffer.toString();
  }

  // ── Startup sync check ───────────────────────────────────────────────────────

  /// Compares the last ISAR entry date against the last quick-tracking entry date.
  /// If ISAR is ahead (e.g. crash between ISAR write and file write),
  /// returns the date that needs to be re-condensed.
  ///
  /// [lastIsarMoodDate] and [lastIsarSymptomDate] come from ISAR queries.
  /// Returns a [SyncCheckResult] indicating what (if anything) needs repair.
  Future<SyncCheckResult> checkAndRepairSync({
    required String? lastIsarMoodDate,
    required String? lastIsarSymptomDate,
  }) async {
    final moodEntries    = await readMoodLog();
    final symptomEntries = await readSymptomLog();

    final lastQuickMood    = moodEntries.isNotEmpty    ? moodEntries.last.date    : null;
    final lastQuickSymptom = symptomEntries.isNotEmpty ? symptomEntries.last.date : null;

    final moodOutOfSync    = lastIsarMoodDate    != null && lastIsarMoodDate    != lastQuickMood;
    final symptomOutOfSync = lastIsarSymptomDate != null && lastIsarSymptomDate != lastQuickSymptom;

    return SyncCheckResult(
      moodNeedsRepair:    moodOutOfSync,
      symptomNeedsRepair: symptomOutOfSync,
      missingMoodDate:    moodOutOfSync    ? lastIsarMoodDate    : null,
      missingSymptomDate: symptomOutOfSync ? lastIsarSymptomDate : null,
    );
  }
}

class SyncCheckResult {
  final bool moodNeedsRepair;
  final bool symptomNeedsRepair;
  final String? missingMoodDate;
  final String? missingSymptomDate;

  bool get isClean => !moodNeedsRepair && !symptomNeedsRepair;

  const SyncCheckResult({
    required this.moodNeedsRepair,
    required this.symptomNeedsRepair,
    this.missingMoodDate,
    this.missingSymptomDate,
  });
}
