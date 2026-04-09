import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'mood_entry.dart';
import 'symptom_entry.dart';
import 'fitness_entry.dart';
import 'eod_entry.dart';
import 'chat_session.dart';
import 'chat_message.dart';

/// Singleton ISAR database service.
///
/// All pipeline services write to and read from this service.
/// ISAR write always happens BEFORE the quick-tracking file is updated.
///
/// Usage:
///   await IsarService.instance.init();
///   await IsarService.instance.writeMoodEntry(...);
///
/// Collections:
///   MoodEntry     — mood log entries (source of truth for mood data)
///   SymptomEntry  — symptom/illness entries (never truncated)
///   FitnessEntry  — daily fitness scores
///   EodEntry      — end-of-day summaries
///   ChatSession   — MiniMe chat session metadata
///   ChatMessage   — individual MiniMe chat messages
class IsarService {
  IsarService._();
  static final IsarService instance = IsarService._();

  Isar? _isar;

  bool get isOpen => _isar?.isOpen ?? false;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Open the ISAR database. Must be called once at app startup
  /// before any read/write operations.
  Future<void> init() async {
    if (isOpen) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        MoodEntrySchema,
        SymptomEntrySchema,
        FitnessEntrySchema,
        EodEntrySchema,
        ChatSessionSchema,
        ChatMessageSchema,
      ],
      directory: dir.path,
      name:      'lifelens',
    );
  }

  Isar get _db {
    if (!isOpen) throw StateError('IsarService not initialised. Call init() first.');
    return _isar!;
  }

  // ─────────────────────────────────────────────
  // MOOD ENTRIES
  // ─────────────────────────────────────────────

  /// Write a mood entry. Called by MoodPipelineService BEFORE
  /// updating the quick-tracking file.
  Future<void> writeMoodEntry(MoodEntry entry) async {
    await _db.writeTxn(() async {
      await _db.moodEntrys.put(entry);
    });
  }

  /// All mood entries for a specific date, ordered by timestamp.
  Future<List<MoodEntry>> getMoodEntriesForDate(String date) async {
    return _db.moodEntrys
        .filter()
        .dateEqualTo(date)
        .sortByTimestamp()
        .findAll();
  }

  /// Most recent mood entry across all dates.
  Future<MoodEntry?> getLastMoodEntry() async {
    return _db.moodEntrys
        .where()
        .sortByTimestampDesc()
        .findFirst();
  }

  /// ISO date string of the most recent mood entry.
  /// Used by QuickTrackService.checkAndRepairSync().
  Future<String?> lastMoodDate() async {
    final entry = await getLastMoodEntry();
    return entry?.date;
  }

  /// Number of mood entries for a specific date.
  /// Used by the sync repair to detect same-day duplicates lost in a crash.
  Future<int> getMoodCountForDate(String date) async {
    return _db.moodEntrys
        .filter()
        .dateEqualTo(date)
        .count();
  }

  /// Mood entries for the last [days] days, ordered newest first.
  Future<List<MoodEntry>> getRecentMoodEntries({int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _db.moodEntrys
        .filter()
        .timestampGreaterThan(cutoff)
        .sortByTimestampDesc()
        .findAll();
  }

  /// Raw log texts for the last [days] days — used for Gemma2b context injection.
  Future<List<String>> getRecentRawLogs({int days = 3}) async {
    final entries = await getRecentMoodEntries(days: days);
    return entries.map((e) => e.rawLog).toList();
  }

  // ─────────────────────────────────────────────
  // SYMPTOM ENTRIES
  // ─────────────────────────────────────────────

  /// Write a symptom entry. Called by SymptomPipelineService BEFORE
  /// updating the quick-tracking file.
  Future<void> writeSymptomEntry(SymptomEntry entry) async {
    await _db.writeTxn(() async {
      await _db.symptomEntrys.put(entry);
    });
  }

  /// All symptom entries, ordered by date descending.
  Future<List<SymptomEntry>> getAllSymptomEntries() async {
    return _db.symptomEntrys
        .where()
        .sortByDateDesc()
        .findAll();
  }

  /// Active and monitoring symptom entries only.
  Future<List<SymptomEntry>> getActiveSymptomEntries() async {
    return _db.symptomEntrys
        .filter()
        .statusEqualTo('active')
        .or()
        .statusEqualTo('monitoring')
        .sortByDateDesc()
        .findAll();
  }

  /// ISO date string of the most recent symptom entry.
  /// Used by QuickTrackService.checkAndRepairSync().
  Future<String?> lastSymptomDate() async {
    final entry = await _db.symptomEntrys
        .where()
        .sortByTimestampDesc()
        .findFirst();
    return entry?.date;
  }

  /// All symptom entries for a specific date, ordered by timestamp.
  Future<List<SymptomEntry>> getSymptomEntriesForDate(String date) async {
    return _db.symptomEntrys
        .filter()
        .dateEqualTo(date)
        .sortByTimestamp()
        .findAll();
  }

  /// Number of symptom entries for a specific date.
  /// Used by the sync repair to detect same-day duplicates lost in a crash.
  Future<int> getSymptomCountForDate(String date) async {
    return _db.symptomEntrys
        .filter()
        .dateEqualTo(date)
        .count();
  }

  /// Symptom entries for the last [days] days, ordered newest first.
  Future<List<SymptomEntry>> getRecentSymptomEntries({int days = 14}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _db.symptomEntrys
        .filter()
        .timestampGreaterThan(cutoff)
        .sortByTimestampDesc()
        .findAll();
  }

  /// Live stream of the most recent [limit] symptom entries, newest first.
  /// Fires immediately with current data, then re-emits on every write.
  Stream<List<SymptomEntry>> watchRecentSymptomEntries({int limit = 250}) {
    return _db.symptomEntrys
        .where()
        .sortByTimestampDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Update the status of a symptom entry.
  /// Values: "active", "resolved", "monitoring"
  Future<void> updateSymptomStatus(
      int id, String status, String updatedDate) async {
    await _db.writeTxn(() async {
      final entry = await _db.symptomEntrys.get(id);
      if (entry != null) {
        entry.status            = status;
        entry.statusUpdatedDate = updatedDate;
        entry.updatedAt         = DateTime.now();
        await _db.symptomEntrys.put(entry);
      }
    });
  }

  // ─────────────────────────────────────────────
  // FITNESS ENTRIES
  // ─────────────────────────────────────────────

  /// Write a fitness entry. Called by FitnessPipelineService.
  Future<void> writeFitnessEntry(FitnessEntry entry) async {
    await _db.writeTxn(() async {
      await _db.fitnessEntrys.put(entry);
    });
  }

  /// Most recent fitness entry.
  Future<FitnessEntry?> getLastFitnessEntry() async {
    return _db.fitnessEntrys
        .where()
        .sortByInferenceTimestampDesc()
        .findFirst();
  }

  /// Most recent fitness score (0–100). Returns 0 if no entries exist.
  Future<double> getLastFitnessScore() async {
    final entry = await getLastFitnessEntry();
    return entry?.fitnessScore ?? 0.0;
  }

  /// Fitness scores for the last [n] days, one per day (most recent per day).
  /// Returns scores newest-first so index 0 = today, index n-1 = oldest.
  /// Used by EodPipelineService for trend calculations.
  Future<List<double>> getLastNDaysFitnessScores(int n) async {
    final cutoff = DateTime.now().subtract(Duration(days: n));
    final entries = await _db.fitnessEntrys
        .filter()
        .inferenceTimestampGreaterThan(cutoff)
        .sortByDateDesc()
        .findAll();

    // Deduplicate: keep only the most recent entry per day.
    // NOTE: Map insertion order in Dart is guaranteed, but after iterating
    // all entries in sortByDateDesc order the Map already preserves that.
    // We sort explicitly after dedup to be safe — Map.values does NOT
    // guarantee ordering when keys are inserted out of order.
    final Map<String, FitnessEntry> byDate = {};
    for (final e in entries) {
      if (!byDate.containsKey(e.date)) {
        byDate[e.date] = e;
      }
    }

    // Sort by date string descending (ISO 8601 sorts lexicographically).
    // Result: index 0 = most recent day, last index = oldest day.
    final sorted = byDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return sorted.map((e) => e.value.fitnessScore).toList();
  }

  // ─────────────────────────────────────────────
  // EOD ENTRIES
  // ─────────────────────────────────────────────

  /// Write (or replace) an EOD entry for a given date.
  /// EodEntry uses @Index(unique: true, replace: true) on date,
  /// so re-running EOD on the same day safely overwrites.
  Future<void> writeEodEntry(EodEntry entry) async {
    await _db.writeTxn(() async {
      await _db.eodEntrys.put(entry);
    });
  }

  /// EOD entry for a specific date.
  Future<EodEntry?> getEodEntry(String date) async {
    return _db.eodEntrys
        .filter()
        .dateEqualTo(date)
        .findFirst();
  }

  /// EOD entries for the last [days] days, ordered newest first.
  Future<List<EodEntry>> getRecentEodEntries({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _db.eodEntrys
        .filter()
        .timestampGreaterThan(cutoff)
        .sortByTimestampDesc()
        .findAll();
  }

  /// All EOD entries that were flagged for attention.
  Future<List<EodEntry>> getFlaggedEodEntries() async {
    return _db.eodEntrys
        .filter()
        .flaggedEqualTo(true)
        .sortByTimestampDesc()
        .findAll();
  }

  // ─────────────────────────────────────────────
  // CROSS-COLLECTION HELPERS
  // ─────────────────────────────────────────────

  /// Full data snapshot for a single day — used by EOD pipeline.
  Future<DaySnapshot> getDaySnapshot(String date) async {
    final moods    = await getMoodEntriesForDate(date);
    final symptoms = await getActiveSymptomEntries();
    final fitness  = await _db.fitnessEntrys
        .filter()
        .dateEqualTo(date)
        .sortByInferenceTimestampDesc()
        .findFirst();
    final eod      = await getEodEntry(date);

    return DaySnapshot(
      date:     date,
      moods:    moods,
      symptoms: symptoms,
      fitness:  fitness,
      eod:      eod,
    );
  }

  // ─────────────────────────────────────────────
  // CHAT SESSIONS & MESSAGES
  // ─────────────────────────────────────────────

  /// Write a new [ChatSession]. Called by ChatSessionService at session start.
  Future<void> writeChatSession(ChatSession session) async {
    await _db.writeTxn(() async {
      await _db.chatSessions.put(session);
    });
  }

  /// Write a new [ChatMessage]. Called by ChatSessionService on every message.
  /// Must be called BEFORE the quick-tracking file is updated.
  Future<void> writeChatMessage(ChatMessage message) async {
    await _db.writeTxn(() async {
      await _db.chatMessages.put(message);
    });
  }

  /// Update a session's [endTime], [messageCount], and [wasInterrupted] flag.
  Future<void> endChatSession(String sessionId, DateTime endTime) async {
    await _db.writeTxn(() async {
      final session = await _db.chatSessions
          .filter()
          .sessionIdEqualTo(sessionId)
          .findFirst();
      if (session == null) return;
      session.endTime       = endTime;
      session.wasInterrupted = false;
      final count = await _db.chatMessages
          .filter()
          .sessionIdEqualTo(sessionId)
          .count();
      session.messageCount = count;
      await _db.chatSessions.put(session);
    });
  }

  /// On startup, find sessions that have no [endTime] (app was killed mid-chat)
  /// and mark them as interrupted. Sets endTime to the last message timestamp,
  /// or to startTime if there are no messages.
  Future<void> markIncompleteChatSessions() async {
    final incomplete = await _db.chatSessions
        .filter()
        .endTimeIsNull()
        .findAll();
    if (incomplete.isEmpty) return;

    await _db.writeTxn(() async {
      for (final session in incomplete) {
        final lastMsg = await _db.chatMessages
            .filter()
            .sessionIdEqualTo(session.sessionId)
            .sortByTimestampDesc()
            .findFirst();
        session.endTime        = lastMsg?.timestamp ?? session.startTime;
        session.wasInterrupted = true;
        final count = await _db.chatMessages
            .filter()
            .sessionIdEqualTo(session.sessionId)
            .count();
        session.messageCount = count;
        await _db.chatSessions.put(session);
      }
    });
  }

  /// All messages for a session, ordered by sequence number.
  Future<List<ChatMessage>> getMessagesForSession(String sessionId) async {
    return _db.chatMessages
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortBySequenceNumber()
        .findAll();
  }

  /// Most recent [limit] chat sessions, newest first.
  Future<List<ChatSession>> getRecentChatSessions({int limit = 20}) async {
    return _db.chatSessions
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  /// Chat sessions created in the last [days] days, newest first.
  /// Used by ChatSessionService to build the conversation quick-track summary.
  Future<List<ChatSession>> getChatSessionsForLastNDays({int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _db.chatSessions
        .filter()
        .createdAtGreaterThan(cutoff)
        .sortByCreatedAtDesc()
        .findAll();
  }

  // ─────────────────────────────────────────────
  // DATABASE MANAGEMENT
  // ─────────────────────────────────────────────

  Future<void> close() async {
    await _isar?.close();
  }

  /// Clear all data — for development/testing only.
  /// NOT exposed in production UI.
  Future<void> clearAll() async {
    await _db.writeTxn(() async {
      await _db.moodEntrys.clear();
      await _db.symptomEntrys.clear();
      await _db.fitnessEntrys.clear();
      await _db.eodEntrys.clear();
      await _db.chatSessions.clear();
      await _db.chatMessages.clear();
    });
  }
}

// ─────────────────────────────────────────────
// HELPER TYPES
// ─────────────────────────────────────────────

/// A full data snapshot for a single day.
/// Used by the EOD pipeline to build Gemma2b/Gemini context.
class DaySnapshot {
  final String             date;
  final List<MoodEntry>    moods;
  final List<SymptomEntry> symptoms;   // active + monitoring
  final FitnessEntry?      fitness;
  final EodEntry?          eod;

  const DaySnapshot({
    required this.date,
    required this.moods,
    required this.symptoms,
    this.fitness,
    this.eod,
  });

  bool get hasMood    => moods.isNotEmpty;
  bool get hasSymptoms => symptoms.isNotEmpty;
  bool get hasFitness  => fitness != null;
  bool get hasEod      => eod != null;
}