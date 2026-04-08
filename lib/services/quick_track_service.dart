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

/// One entry in conversations.json
/// Appended after every MiniMe message (user or assistant).
class ChatLogEntry {
  final String sessionId;    // UUID linking to ISAR ChatSession
  final String role;         // 'user' or 'assistant'
  final String text;
  final String timestamp;    // ISO 8601 full timestamp

  const ChatLogEntry({
    required this.sessionId,
    required this.role,
    required this.text,
    required this.timestamp,
  });

  factory ChatLogEntry.fromJson(Map<String, dynamic> j) => ChatLogEntry(
        sessionId: j['session_id'] as String,
        role:      j['role'] as String,
        text:      j['text'] as String,
        timestamp: j['timestamp'] as String,
      );

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'role':       role,
        'text':       text,
        'timestamp':  timestamp,
      };
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
  static const _chatFileName    = 'conversations.json';

  // ── File helpers ────────────────────────────────────────────────────────────

  Future<File> _moodFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_moodFileName');
  }

  Future<File> _symptomFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_symptomFileName');
  }

  Future<File> _chatFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_chatFileName');
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

  // ── Chat log ─────────────────────────────────────────────────────────────────

  Future<List<ChatLogEntry>> readChatLog() async {
    final file = await _chatFile();
    if (!await file.exists()) return [];
    try {
      final raw     = await file.readAsString();
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ChatLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Append a chat message entry. Called AFTER ISAR write succeeds.
  Future<void> appendChatEntry(ChatLogEntry entry) async {
    final entries = await readChatLog();
    entries.add(entry);
    await _writeChatLog(entries);
  }

  Future<void> _writeChatLog(List<ChatLogEntry> entries) async {
    final file    = await _chatFile();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }

  // ── Startup sync check ───────────────────────────────────────────────────────

  /// Compares ISAR entry counts against quick-tracking file entry counts.
  /// Detects entries lost in a crash between the ISAR write and file write —
  /// including same-day duplicates that the old date-only check would miss.
  ///
  /// [lastIsarMoodDate] / [lastIsarSymptomDate] are the most recent dates from ISAR.
  /// [lastIsarMoodCountForDate] / [lastIsarSymptomCountForDate] are how many entries
  /// ISAR has on those dates.
  /// Returns a [SyncCheckResult] indicating what (if anything) needs repair.
  Future<SyncCheckResult> checkAndRepairSync({
    required String? lastIsarMoodDate,
    required int     lastIsarMoodCountForDate,
    required String? lastIsarSymptomDate,
    required int     lastIsarSymptomCountForDate,
  }) async {
    final moodEntries    = await readMoodLog();
    final symptomEntries = await readSymptomLog();

    // Count how many quick-track entries exist for the ISAR date.
    final quickMoodCount    = lastIsarMoodDate == null    ? 0 : moodEntries.where((e)    => e.date == lastIsarMoodDate).length;
    final quickSymptomCount = lastIsarSymptomDate == null ? 0 : symptomEntries.where((e) => e.date == lastIsarSymptomDate).length;

    final moodOutOfSync    = lastIsarMoodDate    != null && quickMoodCount    < lastIsarMoodCountForDate;
    final symptomOutOfSync = lastIsarSymptomDate != null && quickSymptomCount < lastIsarSymptomCountForDate;

    return SyncCheckResult(
      moodNeedsRepair:         moodOutOfSync,
      symptomNeedsRepair:      symptomOutOfSync,
      missingMoodDate:         moodOutOfSync    ? lastIsarMoodDate    : null,
      missingMoodCount:        moodOutOfSync    ? lastIsarMoodCountForDate - quickMoodCount       : 0,
      missingSymptomDate:      symptomOutOfSync ? lastIsarSymptomDate : null,
      missingSymptomCount:     symptomOutOfSync ? lastIsarSymptomCountForDate - quickSymptomCount : 0,
      quickMoodCountForDate:    quickMoodCount,
      quickSymptomCountForDate: quickSymptomCount,
    );
  }
}

class SyncCheckResult {
  final bool moodNeedsRepair;
  final bool symptomNeedsRepair;
  final String? missingMoodDate;
  /// How many mood entries ISAR has that the quick-track file is missing.
  final int missingMoodCount;
  final String? missingSymptomDate;
  /// How many symptom entries ISAR has that the quick-track file is missing.
  final int missingSymptomCount;
  /// Quick-track count for the latest date (for the repair to skip already-present entries).
  final int quickMoodCountForDate;
  final int quickSymptomCountForDate;

  bool get isClean => !moodNeedsRepair && !symptomNeedsRepair;

  const SyncCheckResult({
    required this.moodNeedsRepair,
    required this.symptomNeedsRepair,
    required this.missingMoodCount,
    required this.missingSymptomCount,
    required this.quickMoodCountForDate,
    required this.quickSymptomCountForDate,
    this.missingMoodDate,
    this.missingSymptomDate,
  });
}
