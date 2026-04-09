import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/symptom_result.dart';

/// On-device disease knowledge base that replaces Gemma's symptom analysis.
///
/// Loads a curated JSON database of common conditions, each with pre-authored
/// reasoning and next-steps text. Matches diseases from Weaviate RAG results
/// by name, supplemented by keyword matching on the user's symptom text.
///
/// Resolves to 5 DiagnosisEntry objects — the same format as the Gemma pipeline.
/// Call [load] once at startup via AppServices.
class DiseaseKnowledgeBase {
  static const _assetPath = 'assets/data/disease_kb.json';

  List<_KbEntry> _entries = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final list = jsonDecode(raw) as List<dynamic>;
      _entries = list.map((e) => _KbEntry.fromJson(e as Map<String, dynamic>)).toList();
      _loaded = true;
      debugPrint('[DiseaseKnowledgeBase] Loaded ${_entries.length} entries.');
    } catch (e) {
      debugPrint('[DiseaseKnowledgeBase] Load failed: $e');
    }
  }

  /// Build 5 DiagnosisEntry objects from:
  ///   [ragDiseaseNames]  Weaviate RAG top-K disease names (ordered by relevance)
  ///   [userSymptoms]     raw user symptom text for keyword matching
  ///   [isOffline]        if true, append an offline advisory to the top entry
  List<DiagnosisEntry> resolve({
    required List<String> ragDiseaseNames,
    required String userSymptoms,
    bool isOffline = false,
  }) {
    if (!_loaded) return _emergencyFallback(isOffline);

    final results = <DiagnosisEntry>[];
    final used = <String>{};

    // Phase 1: Match RAG-provided disease names against the knowledge base
    for (final name in ragDiseaseNames) {
      if (results.length >= 5) break;
      final entry = _findByName(name);
      if (entry != null && !used.contains(entry.name)) {
        results.add(_toEntry(entry, isOffline && results.isEmpty));
        used.add(entry.name);
      }
    }

    // Phase 2: Fill remaining slots using keyword matching on user symptoms
    if (results.length < 5) {
      final keywordMatches = _rankByKeywords(userSymptoms)
          .where((e) => !used.contains(e.name));
      for (final entry in keywordMatches) {
        if (results.length >= 5) break;
        results.add(_toEntry(entry, false));
        used.add(entry.name);
      }
    }

    // Phase 3: Generic fill if still under 5
    while (results.length < 5) {
      results.add(_genericEntry(results.length + 1, isOffline));
    }

    return results;
  }

  // ── Matching helpers ─────────────────────────────────────────────────────────

  _KbEntry? _findByName(String name) {
    final lower = name.toLowerCase().trim();
    // Exact or contained match
    for (final e in _entries) {
      final eName = e.name.toLowerCase();
      if (eName == lower || eName.contains(lower) || lower.contains(eName)) {
        return e;
      }
    }
    return null;
  }

  /// Score each entry by how many of its keywords appear in the symptom text,
  /// then return entries in descending score order.
  List<_KbEntry> _rankByKeywords(String symptoms) {
    final lower = symptoms.toLowerCase();
    final scored = _entries.map((e) {
      final hits = e.keywords.where((kw) => lower.contains(kw.toLowerCase())).length;
      return (entry: e, score: hits);
    }).where((x) => x.score > 0).toList();
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((x) => x.entry).toList();
  }

  DiagnosisEntry _toEntry(_KbEntry entry, bool addOfflineNote) {
    final steps = addOfflineNote
        ? '${entry.nextSteps} Note: offline analysis — consult a healthcare professional for a proper evaluation.'
        : entry.nextSteps;
    return DiagnosisEntry(
      diseaseName: entry.name,
      reasoning: entry.reasoning,
      nextSteps: steps,
      isUrgent: entry.isUrgent,
    );
  }

  DiagnosisEntry _genericEntry(int rank, bool offline) {
    final advice = offline
        ? 'Please consult a healthcare professional for a proper evaluation.'
        : 'Consult a healthcare professional for an accurate diagnosis.';
    return DiagnosisEntry(
      diseaseName: 'Other possible condition ($rank)',
      reasoning: 'Your symptom combination may match additional conditions not covered by the offline knowledge base.',
      nextSteps: advice,
    );
  }

  List<DiagnosisEntry> _emergencyFallback(bool offline) => [
    DiagnosisEntry(
      diseaseName: 'Analysis incomplete',
      reasoning: 'The symptom knowledge base could not be loaded.',
      nextSteps: 'Please consult a healthcare professional for an evaluation.',
    ),
  ];
}

// ── Internal model ────────────────────────────────────────────────────────────

class _KbEntry {
  final String       name;
  final List<String> keywords;
  final String       reasoning;
  final String       nextSteps;
  final bool         isUrgent;

  const _KbEntry({
    required this.name,
    required this.keywords,
    required this.reasoning,
    required this.nextSteps,
    required this.isUrgent,
  });

  factory _KbEntry.fromJson(Map<String, dynamic> json) => _KbEntry(
    name:      json['name']      as String,
    keywords:  (json['keywords'] as List<dynamic>).cast<String>(),
    reasoning: json['reasoning'] as String,
    nextSteps: json['next_steps'] as String,
    isUrgent:  json['is_urgent'] as bool,
  );
}
