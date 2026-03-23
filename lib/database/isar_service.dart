import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'mood_entry.dart';
import 'symptom_entry.dart';
import 'fitness_entry.dart';
import 'eod_entry.dart';

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
      ],
      directory: dir.path,
      name:      'lifelens',
    );
  }

  Isar get _db {
    assert(isOpen, 'IsarService not initialised. Call init() first.');
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
  /// Used by EodPipelineService for trend calculations.
  Future<List<double>> getLastNDaysFitnessScores(int n) async {
    final cutoff = DateTime.now().subtract(Duration(days: n));
    final entries = await _db.fitnessEntrys
        .filter()
        .inferenceTimestampGreaterThan(cutoff)
        .sortByDateDesc()
        .findAll();

    // Deduplicate: keep only the most recent entry per day
    final Map<String, FitnessEntry> byDate = {};
    for (final e in entries) {
      if (!byDate.containsKey(e.date)) {
        byDate[e.date] = e;
      }
    }

    // return scores only
    return byDate.values
        .toList()
        .map((e) => e.fitnessScore)
        .toList();
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
