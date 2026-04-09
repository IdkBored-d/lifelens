import 'dart:collection';
import 'dart:convert';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// A single sentence in the sentence bank, with its pre-computed embedding.
class SentenceEntry {
  final String       id;
  final String       text;
  final String       category;
  /// 384-dim DisEmbed vector. Empty list until training generates embeddings.
  final List<double> embedding;

  const SentenceEntry({
    required this.id,
    required this.text,
    required this.category,
    required this.embedding,
  });

  factory SentenceEntry.fromJson(Map<String, dynamic> json) {
    return SentenceEntry(
      id:        json['id']       as String,
      text:      json['text']     as String,
      category:  json['category'] as String,
      embedding: (json['embedding'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );
  }
}

/// A sentence paired with its cosine similarity score.
class ScoredSentence {
  final SentenceEntry entry;
  final double        score;
  const ScoredSentence({required this.entry, required this.score});
}

/// Loads pre-authored sentence banks and ranks entries by cosine similarity
/// between a model-produced context vector and pre-computed sentence embeddings.
///
/// Used by [EodPipelineService] (summary) and [OnnxSuggestionsClient]
/// (suggestions) once trained ONNX models are available.
///
/// Falls back gracefully when embeddings are not yet populated — callers
/// should check [embeddingsReady] and fall back to template logic if false.
class SentenceBankService {
  static const String _summaryBankAsset    = 'assets/data/summary_sentence_bank.json';
  static const String _suggestionBankAsset = 'assets/data/suggestion_bank.json';

  /// Number of recently returned sentence IDs to track for diversity.
  static const int _diversityWindowSize = 7;

  /// Similarity penalty applied to recently used sentences.
  static const double _diversityPenalty = 0.15;

  bool _isLoaded = false;

  late final Map<String, List<SentenceEntry>> _summaryBanks;
  late final List<SentenceEntry>              _suggestionBank;

  // LRU cache of recently returned sentence IDs
  final Queue<String> _recentIds = Queue();

  bool get isLoaded => _isLoaded;

  /// True once the banks are loaded AND embeddings have been populated
  /// (i.e., after models have been trained and the JSON has been updated).
  bool get embeddingsReady {
    if (!_isLoaded) return false;
    final first = _summaryBanks.values.firstOrNull?.firstOrNull;
    return first != null && first.embedding.isNotEmpty;
  }

  /// Summary bank categories.
  static const String categoryMoodStatus       = 'mood_status';
  static const String categoryHealthContext    = 'health_context';
  static const String categoryActionableClosing = 'actionable_closing';

  Future<void> load() async {
    try {
      final summaryJson    = jsonDecode(await rootBundle.loadString(_summaryBankAsset))
          as Map<String, dynamic>;
      final suggestionJson = jsonDecode(await rootBundle.loadString(_suggestionBankAsset))
          as Map<String, dynamic>;

      _summaryBanks = {};
      for (final kv in summaryJson.entries) {
        _summaryBanks[kv.key] = (kv.value as List<dynamic>)
            .map((e) => SentenceEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      _suggestionBank = (suggestionJson['suggestions'] as List<dynamic>)
          .map((e) => SentenceEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
      debugPrint('[SentenceBankService] load failed (non-fatal): $e');
    }
  }

  /// Returns all entries in a named summary bank category.
  /// Categories: [categoryMoodStatus], [categoryHealthContext],
  ///             [categoryActionableClosing].
  List<SentenceEntry> summaryCategory(String category) =>
      _summaryBanks[category] ?? const [];

  List<SentenceEntry> get suggestionEntries => _suggestionBank;

  /// Rank all entries in [bank] by cosine similarity to [contextVector].
  ///
  /// Applies a [_diversityPenalty] to recently returned sentences and
  /// records selected IDs for future diversity tracking.
  ///
  /// Returns the top [topK] scored entries. If embeddings are empty,
  /// falls back to returning [topK] entries from the front of the bank.
  List<ScoredSentence> rank(
    List<double> contextVector,
    List<SentenceEntry> bank, {
    int topK = 1,
  }) {
    if (bank.isEmpty) return const [];

    // Fallback: no embeddings yet → return first topK entries unscored
    if (contextVector.isEmpty || bank.first.embedding.isEmpty) {
      return bank.take(topK).map((e) => ScoredSentence(entry: e, score: 0.0)).toList();
    }

    final scored = bank.map((entry) {
      double sim = _cosineSimilarity(contextVector, entry.embedding);
      if (_recentIds.contains(entry.id)) sim -= _diversityPenalty;
      return ScoredSentence(entry: entry, score: sim);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final results = scored.take(topK).toList();

    // Track selected IDs for diversity
    for (final r in results) {
      _recentIds.addLast(r.entry.id);
      if (_recentIds.length > _diversityWindowSize) _recentIds.removeFirst();
    }

    return results;
  }

  // ── Math ──────────────────────────────────────────────────────────────────────

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot   += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }
}
