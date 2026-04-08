import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database/mood_entry.dart';
import '../database/symptom_entry.dart';
import '../database/chat_session.dart';

/// Manages reads and writes to the three on-device quick-tracking plaintext files.
///
/// Each file is a rolling narrative summary for its respective pipeline,
/// covering the last 7–14 days. Files are overwritten (not appended) after
/// every pipeline run so they always reflect the current user state.
///
/// WRITE ORDER (enforced by callers, not this service):
///   1. Write to ISAR database first (source of truth)
///   2. Call this service to overwrite the quick-tracking summary
///
/// On app startup, EodPipelineService.repairQuickTrackSummaries() compares
/// these files against fresh ISAR-derived summaries and regenerates any
/// that have diverged (e.g. after a crash between the two writes).
class QuickTrackService {
  static const _moodFileName         = 'mood_summary.txt';
  static const _symptomFileName      = 'symptom_summary.txt';
  static const _conversationFileName = 'conversation_summary.txt';

  // ── File helpers ─────────────────────────────────────────────────────────────

  Future<File> _moodFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_moodFileName');
  }

  Future<File> _symptomFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_symptomFileName');
  }

  Future<File> _conversationFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_conversationFileName');
  }

  // ── Mood summary ─────────────────────────────────────────────────────────────

  Future<String> readMoodSummary() async {
    final file = await _moodFile();
    if (!await file.exists()) return '';
    try {
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Overwrite the mood summary. Called AFTER ISAR write succeeds.
  Future<void> writeMoodSummary(String text) async {
    final file = await _moodFile();
    await file.writeAsString(text, flush: true);
  }

  // ── Symptom summary ──────────────────────────────────────────────────────────

  Future<String> readSymptomSummary() async {
    final file = await _symptomFile();
    if (!await file.exists()) return '';
    try {
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Overwrite the symptom summary. Called AFTER ISAR write succeeds.
  Future<void> writeSymptomSummary(String text) async {
    final file = await _symptomFile();
    await file.writeAsString(text, flush: true);
  }

  // ── Conversation summary ─────────────────────────────────────────────────────

  Future<String> readConversationSummary() async {
    final file = await _conversationFile();
    if (!await file.exists()) return '';
    try {
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Overwrite the conversation summary. Called AFTER ISAR write succeeds.
  Future<void> writeConversationSummary(String text) async {
    final file = await _conversationFile();
    await file.writeAsString(text, flush: true);
  }

  // ── Context builders for Gemma / pipelines ───────────────────────────────────

  Future<String> buildMoodContext() async {
    final s = await readMoodSummary();
    return s.isEmpty ? 'No mood history available.' : s;
  }

  Future<String> buildSymptomContext() async {
    final s = await readSymptomSummary();
    return s.isEmpty ? 'No symptom history available.' : s;
  }

  Future<String> buildConversationContext() async {
    final s = await readConversationSummary();
    return s.isEmpty ? 'No conversation history available.' : s;
  }

  // ── Static template builders ─────────────────────────────────────────────────

  /// Builds the template block for the mood summary.
  ///
  /// Format:
  ///   Mood: Calm (1 day). Previously: Stressed (8 days ago to 6 days ago), Sad (2 days ago to 1 day ago).
  ///   Fitness: up 3 pts over 7 days.
  ///
  /// [entries] should be the last 14 days of mood entries, newest first.
  /// [fitnessScores] should be the last 7 days of daily scores, index 0 = most recent.
  static String buildMoodTemplate(
      List<MoodEntry> entries, List<double> fitnessScores) {
    if (entries.isEmpty) return 'No mood history in the last 14 days.';

    final today = DateTime.now();

    // Deduplicate: keep most recent entry per date.
    final Map<String, MoodEntry> byDate = {};
    for (final e in entries) {
      if (!byDate.containsKey(e.date)) byDate[e.date] = e;
    }
    // Sort newest first.
    final deduped = byDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // Group consecutive same-mood runs.
    // Each group: (mood, startDaysAgo [oldest], endDaysAgo [newest]).
    final groups = <({String mood, int startDaysAgo, int endDaysAgo})>[];
    String? currentMood;
    int groupOldest = 0;
    int groupNewest = 0;

    for (final kv in deduped) {
      final daysAgo =
          today.difference(DateTime.parse(kv.key)).inDays;
      final mood = kv.value.resolvedMood;

      if (currentMood == null) {
        currentMood = mood;
        groupOldest = daysAgo;
        groupNewest = daysAgo;
      } else if (mood == currentMood) {
        // Extend the current group's oldest boundary.
        if (daysAgo > groupOldest) groupOldest = daysAgo;
      } else {
        groups.add((
          mood:         currentMood,
          startDaysAgo: groupOldest,
          endDaysAgo:   groupNewest,
        ));
        currentMood = mood;
        groupOldest = daysAgo;
        groupNewest = daysAgo;
      }
    }
    if (currentMood != null) {
      groups.add((
        mood:         currentMood,
        startDaysAgo: groupOldest,
        endDaysAgo:   groupNewest,
      ));
    }

    if (groups.isEmpty) return 'No mood history in the last 14 days.';

    final buf = StringBuffer();
    final current = groups.first;
    final currentCount = current.startDaysAgo - current.endDaysAgo + 1;

    if (groups.length == 1) {
      buf.write(
          'Mood: ${_cap(current.mood)} ($currentCount ${currentCount == 1 ? 'day' : 'days'}).');
    } else {
      buf.write(
          'Mood: ${_cap(current.mood)} ($currentCount ${currentCount == 1 ? 'day' : 'days'}).'
          ' Previously:');

      for (int i = 1; i < groups.length; i++) {
        final g = groups[i];
        if (i > 1) buf.write(',');
        if (g.startDaysAgo == g.endDaysAgo) {
          // Single day.
          buf.write(
              ' ${_cap(g.mood)} (${g.startDaysAgo} ${g.startDaysAgo == 1 ? 'day' : 'days'} ago)');
        } else {
          buf.write(
              ' ${_cap(g.mood)} (${g.startDaysAgo} days ago to ${g.endDaysAgo} days ago)');
        }
      }
      buf.write('.');
    }

    // Fitness line.
    if (fitnessScores.length >= 2) {
      final delta =
          (fitnessScores.first - fitnessScores.last).round().abs();
      final direction = fitnessScores.first >= fitnessScores.last
          ? (fitnessScores.first - fitnessScores.last).round() == 0
              ? 'stable'
              : 'up'
          : 'down';
      if (direction == 'stable') {
        buf.write('\nFitness: stable over ${fitnessScores.length} days.');
      } else {
        buf.write(
            '\nFitness: $direction $delta pts over ${fitnessScores.length} days.');
      }
    }

    return buf.toString();
  }

  /// Builds the template block for the symptom summary.
  ///
  /// Format:
  ///   Symptoms: Fever (active, 3 days), Headache (active, 2 days).
  ///
  /// [entries] should be the last 14 days of symptom entries.
  static String buildSymptomTemplate(List<SymptomEntry> entries) {
    final active = entries
        .where((e) => e.status == 'active' || e.status == 'monitoring')
        .toList();

    if (active.isEmpty) return 'Symptoms: None active in the last 14 days.';

    // For each unique symptom, count distinct dates it appears in active entries.
    final symptomDates  = <String, Set<String>>{};
    final symptomStatus = <String, String>{};

    for (final entry in active) {
      for (final symptom in entry.symptomList) {
        final key = symptom.trim();
        if (key.isEmpty) continue;
        symptomDates.putIfAbsent(key, () => {}).add(entry.date);
        // Keep the most recent status (entries are ordered newest first by caller).
        symptomStatus.putIfAbsent(key, () => entry.status);
      }
    }

    if (symptomDates.isEmpty) return 'Symptoms: None active in the last 14 days.';

    // Sort by day count descending (most persistent first).
    final sorted = symptomDates.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final parts = sorted.map((e) {
      final days   = e.value.length;
      final status = symptomStatus[e.key] ?? 'active';
      return '${_cap(e.key)} ($status, $days ${days == 1 ? 'day' : 'days'})';
    }).join(', ');

    return 'Symptoms: $parts.';
  }

  /// Builds the template block for the conversation summary.
  ///
  /// Format:
  ///   Sessions (last 7 days): 3 sessions, 12 messages.
  ///   Last session: 2025-04-07.
  ///
  /// [sessions] should be the last 7 days of chat sessions, newest first.
  static String buildConversationTemplate(List<ChatSession> sessions) {
    if (sessions.isEmpty) return 'Sessions (last 7 days): None.';

    final totalMessages =
        sessions.fold(0, (sum, s) => sum + (s.messageCount));
    final count        = sessions.length;
    final lastCreated  = sessions.first.createdAt;
    final y = lastCreated.year;
    final m = lastCreated.month.toString().padLeft(2, '0');
    final d = lastCreated.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';

    return 'Sessions (last 7 days): $count ${count == 1 ? 'session' : 'sessions'},'
        ' $totalMessages ${totalMessages == 1 ? 'message' : 'messages'}.'
        '\nLast session: $dateStr.';
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
