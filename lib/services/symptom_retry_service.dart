import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/weaviate_service.dart';

// ─────────────────────────────────────────────
// RESULT TYPE
// ─────────────────────────────────────────────

/// Result returned after each retry round.
class SymptomRetryResult {
  const SymptomRetryResult({
    required this.results,
    required this.topCertainty,
    required this.confidenceOk,
    required this.roundsUsed,
  });

  /// Top-K Weaviate results for this round.
  final List<WeaviateDisease> results;

  /// Certainty of the top result (0–1).
  final double topCertainty;

  /// Whether certainty has crossed [SymptomRetryService.confidenceThreshold].
  final bool confidenceOk;

  /// How many rounds have been completed so far (1-indexed).
  final int roundsUsed;

  /// True when we've hit [SymptomRetryService.maxRounds] with no confidence.
  bool get exhausted => roundsUsed >= SymptomRetryService.maxRounds;

  /// Encode the top results as a JSON string suitable for [SymptomEntry.diagnosesJson].
  String toDiagnosesJson() {
    return jsonEncode(
      results
          .map((r) => {
                'disease': r.disease,
                'reasoning': r.description,
                'treatment': r.treatment ?? '',
                'next_steps': '',
                'is_urgent': false,
              })
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────

/// Dart port of the Python `diagnose()` retry loop.
///
/// This service is **stateless** — the caller (widget) tracks round state.
/// Call [queryRound] on every round, passing the accumulated confirmed /
/// denied symptom lists built by the UI.
///
/// Weaviate collection used: the same `WeaviateService` instance in
/// [AppServices.weaviate], which is already configured and connected.
class SymptomRetryService {
  /// Certainty threshold below which a re-query is triggered.
  /// Calibrated to match [kDisEmbedThreshold] from ConfidenceManager.
  static const double confidenceThreshold = 0.3846;

  /// Maximum number of re-query rounds (matches Python MAX_ROUNDS = 3).
  static const int maxRounds = 3;

  /// Number of top candidates whose symptom/risk_factor fields are used
  /// to build follow-up chip suggestions.
  static const int _followUpSourceK = 3;

  /// Maximum follow-up chips to present per round.
  static const int _maxChipsPerRound = 8;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Run a single query round and return the result.
  ///
  /// [baseSymptoms]  – original symptoms the user typed.
  /// [confirmed]     – symptoms the user confirmed in previous rounds.
  /// [denied]        – symptoms the user denied in previous rounds.
  /// [roundNum]      – current round number (1 = first / initial query).
  Future<SymptomRetryResult> queryRound({
    required List<String> baseSymptoms,
    List<String> confirmed = const [],
    List<String> denied = const [],
    required int roundNum,
  }) async {
    final queryText = _buildQueryText(baseSymptoms, confirmed, denied);

    try {
      final embedding = await AppServices.disEmbed.embed(
        queryText,
        AppServices.disEmbedTokenize,
      );
      final results =
          await AppServices.weaviate.queryByVector(embedding, topK: 5);
      final topCertainty =
          results.isNotEmpty ? (results.first.certainty) : 0.0;
      final confidenceOk = topCertainty >= confidenceThreshold;

      return SymptomRetryResult(
        results: results,
        topCertainty: topCertainty,
        confidenceOk: confidenceOk,
        roundsUsed: roundNum,
      );
    } catch (e) {
      debugPrint('[SymptomRetryService] queryRound error: $e');
      return SymptomRetryResult(
        results: const [],
        topCertainty: 0.0,
        confidenceOk: false,
        roundsUsed: roundNum,
      );
    }
  }

  /// Build a deduplicated list of symptom / risk-factor keywords from the
  /// top Weaviate results, excluding anything in [alreadyAsked].
  ///
  /// These become the follow-up chip suggestions shown to the user.
  List<String> buildFollowUpCandidates(
    List<WeaviateDisease> results,
    Set<String> alreadyAsked,
  ) {
    final seen = <String>{};
    final candidates = <String>[];

    for (final r in results.take(_followUpSourceK)) {
      // symptoms field is a comma-separated string in the current schema
      final symptomItems = r.symptoms
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      for (final item in symptomItems) {
        final key = item.toLowerCase();
        if (!alreadyAsked.contains(key) && !seen.contains(key)) {
          seen.add(key);
          candidates.add(item);
        }
      }

      // risk_factors field (if present on the model)
      final rfItems = r.riskFactors
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty) ??
          [];
      for (final item in rfItems) {
        final key = item.toLowerCase();
        if (!alreadyAsked.contains(key) && !seen.contains(key)) {
          seen.add(key);
          candidates.add(item);
        }
      }
    }

    return candidates.take(_maxChipsPerRound).toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Concatenate base symptoms + confirmed/denied extras into a single
  /// query string, matching the Python script's prompt-building strategy.
  String _buildQueryText(
    List<String> base,
    List<String> confirmed,
    List<String> denied,
  ) {
    final buffer = StringBuffer(base.join(', '));
    if (confirmed.isNotEmpty) {
      buffer.write('. I also have: ${confirmed.join(', ')}.');
    }
    if (denied.isNotEmpty) {
      buffer.write('. I do NOT have: ${denied.join(', ')}.');
    }
    return buffer.toString();
  }
}
