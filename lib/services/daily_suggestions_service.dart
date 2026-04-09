import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lifelens/moodlog_store.dart';
import 'health_feature_computer.dart';
import 'health_suggestions_model_service.dart';
import 'sentence_bank_service.dart';
import '../database/symptom_entry.dart';

class DailySuggestion {
  const DailySuggestion({
    required this.title,
    required this.reason,
    required this.action,
  });

  final String title;
  final String reason;
  final String action;
}

class DailySuggestionsRequest {
  const DailySuggestionsRequest({
    required this.moodLogs,
    required this.generatedAt,
  });

  final List<MoodCheckIn> moodLogs;
  final DateTime generatedAt;
}

abstract class DailySuggestionsModelClient {
  Future<List<DailySuggestion>> generate(DailySuggestionsRequest request);
}

class DailySuggestionsService {
  DailySuggestionsService({DailySuggestionsModelClient? modelClient})
    : _modelClient = modelClient ?? LocalHeuristicSuggestionsClient();

  final DailySuggestionsModelClient _modelClient;

  static final DailySuggestionsService instance = DailySuggestionsService();

  Future<List<DailySuggestion>> getDailySuggestions({
    required List<MoodCheckIn> moodLogs,
  }) {
    final request = DailySuggestionsRequest(
      moodLogs: moodLogs,
      generatedAt: DateTime.now(),
    );

    return _modelClient.generate(request);
  }
}

class LocalHeuristicSuggestionsClient implements DailySuggestionsModelClient {
  @override
  Future<List<DailySuggestion>> generate(DailySuggestionsRequest request) async {
    final logs = request.moodLogs;

    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (logs.isEmpty) {
      return const [
        DailySuggestion(
          title: 'Start with one mood check-in',
          reason: 'There is not enough log data yet to personalize suggestions.',
          action: 'Log your current mood and one short note to unlock smarter daily guidance.',
        ),
      ];
    }

    final latest = logs.first;
    final averageIntensity = logs
            .take(7)
            .map((item) => item.intensity)
            .fold<int>(0, (sum, value) => sum + value) /
        logs.take(7).length;

    final tags = logs.take(7).expand((item) => item.tags).toList();
    final hasSleepTag = tags.map((t) => t.toLowerCase()).contains('sleep');
    final hasWorkTag = tags.map((t) => t.toLowerCase()).contains('work');

    final suggestions = <DailySuggestion>[
      DailySuggestion(
        title: 'Anchor your day with one guided check-in',
        reason: 'Your latest mood is ${latest.moodLabel} at intensity ${latest.intensity}/5.',
        action: 'Set one reminder for midday and log mood + one trigger to improve pattern detection.',
      ),
    ];

    if (averageIntensity >= 4) {
      suggestions.add(
        const DailySuggestion(
          title: 'Lower intensity with a short reset block',
          reason: 'Your recent logs show elevated emotional intensity.',
          action: 'Do a 3-minute breath or stretch reset before your next major task.',
        ),
      );
    } else {
      suggestions.add(
        const DailySuggestion(
          title: 'Keep momentum with a consistency habit',
          reason: 'Your recent intensity trend looks stable enough to build routine.',
          action: 'Repeat yesterday\'s best small habit at the same time today.',
        ),
      );
    }

    if (hasSleepTag) {
      suggestions.add(
        const DailySuggestion(
          title: 'Protect tonight\'s sleep window',
          reason: 'Sleep appears frequently in your recent check-in context.',
          action: 'Plan a fixed wind-down start time and avoid screens in the last 20 minutes.',
        ),
      );
    } else if (hasWorkTag) {
      suggestions.add(
        const DailySuggestion(
          title: 'Add a transition between work blocks',
          reason: 'Work context appears in your recent logs.',
          action: 'Take a 2-minute decompression break after each focused session.',
        ),
      );
    } else {
      suggestions.add(
        const DailySuggestion(
          title: 'Improve signal quality in your logs',
          reason: 'More context tags will improve recommendation quality.',
          action: 'Add at least one context tag to each check-in this week.',
        ),
      );
    }

    return suggestions;
  }
}

/// ML-powered suggestions client using [HealthSuggestionsModelService] and
/// [SentenceBankService] to rank and return personalised suggestions.
///
/// Falls back to [LocalHeuristicSuggestionsClient] when:
///   - The ONNX model is not loaded (model file not yet available)
///   - The sentence bank has no embeddings (training not yet complete)
///   - The model's relevance gate is below [HealthSuggestionsModelService.minGateThreshold]
///
/// See docs/training_plan.md for how to train and activate this client.
class OnnxSuggestionsClient implements DailySuggestionsModelClient {
  final HealthSuggestionsModelService _model;
  final SentenceBankService           _sentenceBank;
  final HealthFeatureComputer         _featureComputer;
  final Future<List<double>> Function(String, Map<String, List<int>> Function(String, int))
      _embed;
  final Map<String, List<int>> Function(String, int) _tokenize;
  final List<SymptomEntry> Function() _activeSymptoms;

  /// Safety: suggestions in these categories are never returned when
  /// intervention tier is not "high". Guards against over-escalation.
  static const Set<String> _highRiskOnlyCategories = {'clinician_followup'};

  const OnnxSuggestionsClient({
    required HealthSuggestionsModelService model,
    required SentenceBankService           sentenceBank,
    required HealthFeatureComputer         featureComputer,
    required Future<List<double>> Function(String, Map<String, List<int>> Function(String, int)) embed,
    required Map<String, List<int>> Function(String, int) tokenize,
    required List<SymptomEntry> Function() activeSymptoms,
  })  : _model           = model,
        _sentenceBank    = sentenceBank,
        _featureComputer = featureComputer,
        _embed           = embed,
        _tokenize        = tokenize,
        _activeSymptoms  = activeSymptoms;

  @override
  Future<List<DailySuggestion>> generate(DailySuggestionsRequest request) async {
    // Fall back to heuristic client if ML isn't ready
    if (!_model.isLoaded || !_sentenceBank.embeddingsReady) {
      return LocalHeuristicSuggestionsClient().generate(request);
    }

    try {
      final symptoms = _activeSymptoms();
      final fitnessScores = <double>[]; // no fitness data in this request type

      final baseFeatures = _featureComputer.compute(
        recentMoods:    [], // mood list not available in DailySuggestionsRequest
        fitnessScores:  fitnessScores,
        activeSymptoms: symptoms,
      );

      // Build a simple risk/tier estimate from the 25 base features
      // (full intelligence.py logic is not wired here — use conservative defaults)
      final moodSlope7 = baseFeatures[11]; // index 11 = mood_slope_7
      final riskScore  = _estimateRiskScore(baseFeatures);
      final tier       = riskScore >= 70 ? 'high' : riskScore >= 40 ? 'medium' : 'low';
      final phase      = _estimatePhase(moodSlope7, baseFeatures[10], riskScore, tier);

      final featureVec = SuggestionsFeatureVector(
        baseFeatures:     baseFeatures,
        riskScore:        riskScore,
        interventionTier: tier,
        userPhase:        phase,
        symptomCount:     symptoms.length,
      );

      // Build symptom text for DisEmbed context
      final symptomText = symptoms.isNotEmpty
          ? symptoms.map((s) => s.symptomList.join(', ')).join('. ')
          : '';
      final textEmbedding = symptomText.isNotEmpty
          ? await _embed(symptomText, _tokenize)
          : List<double>.filled(384, 0.0);

      final output = await _model.predict(
        numericalFeatures: featureVec.toList(),
        textEmbedding:     textEmbedding,
      );

      // Gate check — fall back if model is not confident
      if (output.relevanceGate < HealthSuggestionsModelService.minGateThreshold) {
        return LocalHeuristicSuggestionsClient().generate(request);
      }

      // Rank suggestion bank and apply safety guardrails
      final ranked = _sentenceBank.rank(
        output.contextVector,
        _sentenceBank.suggestionEntries,
        topK: 6, // fetch extra to allow filtering
      );

      final filtered = ranked
          .where((s) =>
              !_highRiskOnlyCategories.contains(s.entry.category) || tier == 'high')
          .take(3)
          .map((s) => DailySuggestion(
                title:  _extractTitle(s.entry.text),
                reason: 'Based on your recent health patterns.',
                action: s.entry.text,
              ))
          .toList();

      if (filtered.isEmpty) return LocalHeuristicSuggestionsClient().generate(request);
      return filtered;
    } catch (e) {
      debugPrint('[OnnxSuggestionsClient] inference failed (using heuristic): $e');
      return LocalHeuristicSuggestionsClient().generate(request);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Simple risk score estimate from base features (mirrors intelligence.py weights).
  double _estimateRiskScore(List<double> f) {
    double score = 0;
    if (f[3] <= 2.0) score += 24; // low mood
    if (f[0] < 6.0)  score += 20; // low sleep
    if (f[9] > 0.8)  score += 16; // inactive
    if (f[11] < 0)   score += 12 * (f[11].abs().clamp(0.0, 1.0)); // mood slope decline
    if (f[10] < 0)   score += 10 * (f[10].abs().clamp(0.0, 1.0)); // sleep slope decline
    return score.clamp(0.0, 100.0);
  }

  String _estimatePhase(double moodSlope7, double sleepSlope7, double risk, String tier) {
    if (tier == 'high' && moodSlope7 <= 0) return 'acute-risk';
    if (moodSlope7 > 0 && sleepSlope7 >= 0) return 'recovering';
    if (moodSlope7 < 0 || sleepSlope7 < 0) return 'declining';
    if (risk < 25) return 'stable';
    return 'declining';
  }

  /// Extract a short title from the suggestion text (first clause before comma/dash).
  String _extractTitle(String text) {
    final separators = RegExp(r'[,—–]');
    final match = separators.firstMatch(text);
    if (match != null) {
      return text.substring(0, match.start).trim();
    }
    return text.length > 50 ? '${text.substring(0, 47)}...' : text;
  }
}
