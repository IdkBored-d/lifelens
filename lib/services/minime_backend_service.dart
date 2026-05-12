import 'dart:convert';

import 'package:http/http.dart' as http;

import 'context_builder_service.dart';

const Set<String> _canonicalMoodLabels = {
  'sadness',
  'joy',
  'love',
  'anger',
  'fear',
  'surprise',
};

const Map<String, String> _moodAliasToCanonical = {
  'sadness': 'sadness',
  'sad': 'sadness',
  'down': 'sadness',
  'low': 'sadness',
  'joy': 'joy',
  'happy': 'joy',
  'glad': 'joy',
  'love': 'love',
  'affectionate': 'love',
  'affection': 'love',
  'anger': 'anger',
  'angry': 'anger',
  'mad': 'anger',
  'frustrated': 'anger',
  'fear': 'fear',
  'scared': 'fear',
  'afraid': 'fear',
  'anxious': 'fear',
  'surprise': 'surprise',
  'surprised': 'surprise',
  'shocked': 'surprise',
  'startled': 'surprise',
};

String _sanitizeMoodLabel(String raw, {String fallback = ''}) {
  final lowered = raw.trim().toLowerCase();
  if (lowered.isEmpty) {
    return fallback;
  }

  if (_canonicalMoodLabels.contains(lowered)) {
    return lowered;
  }

  // Direct alias match from app-facing mood labels.
  final directAlias = _moodAliasToCanonical[lowered];
  if (directAlias != null) {
    return directAlias;
  }

  // Extract candidate words from noisy labels like "Scared (4/5)".
  final normalized = lowered
      .replaceAll(RegExp(r'\(.*?\)'), ' ')
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  for (final token in normalized.split(' ')) {
    final alias = _moodAliasToCanonical[token];
    if (alias != null) {
      return alias;
    }
  }

  // No reliable mapping found.
  return fallback;
}

List<String> _sanitizeRecentMoods(List<String> rawItems) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final item in rawItems) {
    final match = RegExp(
      r'(sadness|sad|joy|happy|love|affectionate|anger|angry|fear|scared|surprise|surprised|anxious|afraid)',
      caseSensitive: false,
    ).firstMatch(item);
    final candidate = _sanitizeMoodLabel(match?.group(1) ?? item);
    if (candidate.isEmpty) {
      continue;
    }
    if (seen.add(candidate)) {
      normalized.add(candidate);
    }
    if (normalized.length >= 8) {
      break;
    }
  }
  return normalized;
}

String _resolveLatestCanonicalMood(
  String rawLatest,
  List<String> canonicalRecentMoods,
) {
  final direct = _sanitizeMoodLabel(rawLatest);
  if (direct.isNotEmpty) {
    return direct;
  }

  if (canonicalRecentMoods.isNotEmpty) {
    return canonicalRecentMoods.first;
  }

  // Safer neutral fallback than forcing surprise.
  return 'sadness';
}

String _truncateText(String value, int maxLength) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return trimmed.substring(0, maxLength).trimRight();
}

List<String> _truncateListItems(
  List<String> values, {
  required int maxItems,
  required int maxItemLength,
}) {
  return values
      .map((item) => _truncateText(item, maxItemLength))
      .where((item) => item.isNotEmpty)
      .take(maxItems)
      .toList(growable: false);
}

List<MiniMeChatTurn> _truncateHistory(
  List<MiniMeChatTurn> history, {
  int maxItems = 20,
  int maxItemLength = 2000,
}) {
  final trimmed = history
      .map(
        (item) => MiniMeChatTurn(
          role: item.role.trim().toLowerCase(),
          text: _truncateText(item.text, maxItemLength),
        ),
      )
      .where((item) => item.text.isNotEmpty)
      .toList(growable: false);

  if (trimmed.length <= maxItems) {
    return trimmed;
  }
  return trimmed.sublist(trimmed.length - maxItems);
}

class MiniMeChatTurn {
  const MiniMeChatTurn({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class MiniMeBackendReply {
  const MiniMeBackendReply({
    required this.reply,
    required this.openingSuggestion,
    required this.source,
  });

  final String reply;
  final String openingSuggestion;
  final String source;

  factory MiniMeBackendReply.fromJson(Map<String, dynamic> json) {
    return MiniMeBackendReply(
      reply: (json['reply'] as String? ?? '').trim(),
      openingSuggestion: (json['opening_suggestion'] as String? ?? '').trim(),
      source: (json['source'] as String? ?? 'fallback').trim(),
    );
  }
}

class MiniMeSuggestionReplyItem {
  const MiniMeSuggestionReplyItem({required this.action, required this.reason});

  final String action;
  final String reason;

  factory MiniMeSuggestionReplyItem.fromJson(Map<String, dynamic> json) {
    return MiniMeSuggestionReplyItem(
      action: (json['action'] as String? ?? '').trim(),
      reason: (json['reason'] as String? ?? '').trim(),
    );
  }
}

class MiniMeSuggestionsReply {
  const MiniMeSuggestionsReply({
    required this.suggestions,
    required this.source,
  });

  final List<MiniMeSuggestionReplyItem> suggestions;
  final String source;

  factory MiniMeSuggestionsReply.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'];
    final suggestions = rawSuggestions is List
        ? rawSuggestions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(MiniMeSuggestionReplyItem.fromJson)
              .where((item) => item.action.isNotEmpty && item.reason.isNotEmpty)
              .toList(growable: false)
        : const <MiniMeSuggestionReplyItem>[];

    return MiniMeSuggestionsReply(
      suggestions: suggestions,
      source: (json['source'] as String? ?? 'fallback').trim(),
    );
  }
}

class MiniMeExerciseCandidate {
  const MiniMeExerciseCandidate({
    required this.id,
    required this.name,
    required this.type,
    required this.muscle,
    required this.difficulty,
    this.description,
  });

  final String id;
  final String name;
  final String type;
  final String muscle;
  final String difficulty;
  final String? description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'muscle': muscle,
    'difficulty': difficulty,
    'description': description,
  };
}

class MiniMeExerciseRecommendationItem {
  const MiniMeExerciseRecommendationItem({
    required this.exerciseId,
    required this.focus,
    required this.reason,
  });

  final String exerciseId;
  final String focus;
  final String reason;

  factory MiniMeExerciseRecommendationItem.fromJson(Map<String, dynamic> json) {
    return MiniMeExerciseRecommendationItem(
      exerciseId: (json['exercise_id'] as String? ?? '').trim(),
      focus: (json['focus'] as String? ?? '').trim(),
      reason: (json['reason'] as String? ?? '').trim(),
    );
  }
}

class MiniMeExerciseRecommendationsReply {
  const MiniMeExerciseRecommendationsReply({
    required this.headline,
    required this.recommendations,
    required this.source,
  });

  final String headline;
  final List<MiniMeExerciseRecommendationItem> recommendations;
  final String source;

  factory MiniMeExerciseRecommendationsReply.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawRecommendations = json['recommendations'];
    final recommendations = rawRecommendations is List
        ? rawRecommendations
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(MiniMeExerciseRecommendationItem.fromJson)
              .where(
                (item) =>
                    item.exerciseId.isNotEmpty &&
                    item.focus.isNotEmpty &&
                    item.reason.isNotEmpty,
              )
              .toList(growable: false)
        : const <MiniMeExerciseRecommendationItem>[];

    return MiniMeExerciseRecommendationsReply(
      headline: (json['headline'] as String? ?? '').trim(),
      recommendations: recommendations,
      source: (json['source'] as String? ?? 'fallback').trim(),
    );
  }
}

class MiniMeIntelligenceReply {
  const MiniMeIntelligenceReply({
    required this.state,
    required this.healthStateVector,
    required this.healthStateVectorLabels,
    required this.features,
    required this.riskScore,
    required this.confidenceScore,
    required this.interventionTier,
    required this.userPhase,
    required this.selectedActions,
    required this.reasons,
    required this.evidence,
    required this.constraints,
    required this.explanationTrace,
    required this.actionProbabilities,
    required this.insights,
    required this.actions,
    required this.message,
    required this.flags,
    required this.projection,
    required this.trendClassification,
    required this.nextDayPredictions,
    required this.predictionModel,
    required this.anomalies,
    required this.miniMeLinkage,
    required this.calibration,
    required this.evaluation,
    required this.weaviateSignal,
    this.alert,
  });

  final Map<String, dynamic> state;
  final List<double> healthStateVector;
  final List<String> healthStateVectorLabels;
  final Map<String, double> features;
  final double riskScore;
  final double confidenceScore;
  final String interventionTier;
  final String userPhase;
  final List<String> selectedActions;
  final List<String> reasons;
  final List<String> evidence;
  final List<String> constraints;
  final List<String> explanationTrace;
  final Map<String, double> actionProbabilities;
  final List<String> insights;
  final List<String> actions;
  final String message;
  final List<String> flags;
  final Map<String, double> projection;
  final Map<String, String> trendClassification;
  final Map<String, double> nextDayPredictions;
  final Map<String, dynamic> predictionModel;
  final List<Map<String, dynamic>> anomalies;
  final Map<String, dynamic> miniMeLinkage;
  final Map<String, dynamic> calibration;
  final Map<String, dynamic> evaluation;
  final Map<String, dynamic> weaviateSignal;
  final String? alert;

  bool get lowSleep => state['low_sleep'] == true;
  bool get lowMood => state['low_mood'] == true;
  bool get inactive => state['inactive'] == true;

  static List<String> _toStringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, double> _toDoubleMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0),
      );
    }
    if (raw is Map) {
      return raw.map(
        (key, value) =>
            MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0.0),
      );
    }
    return const <String, double>{};
  }

  static Map<String, dynamic> _toDynamicMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  static List<double> _toDoubleList(Object? raw) {
    if (raw is! List) return const <double>[];
    return raw
        .map((item) => (item as num?)?.toDouble() ?? 0.0)
        .toList(growable: false);
  }

  static Map<String, String> _toStringMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw.map((key, value) => MapEntry(key, value.toString().trim()));
    }
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value.toString().trim()),
      );
    }
    return const <String, String>{};
  }

  static List<Map<String, dynamic>> _toDynamicMapList(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  factory MiniMeIntelligenceReply.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'];
    final rawActions = json['actions'];

    final selectedActions = _toStringList(json['selected_actions']);
    final parsedActions = _toStringList(rawActions);

    return MiniMeIntelligenceReply(
      state: rawState is Map<String, dynamic>
          ? rawState
          : (rawState is Map ? Map<String, dynamic>.from(rawState) : const {}),
      healthStateVector: _toDoubleList(json['health_state_vector']),
      healthStateVectorLabels: _toStringList(
        json['health_state_vector_labels'],
      ),
      features: _toDoubleMap(json['features']),
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      interventionTier: (json['intervention_tier'] as String? ?? 'low').trim(),
      userPhase: (json['user_phase'] as String? ?? 'stable').trim(),
      selectedActions: selectedActions,
      reasons: _toStringList(json['reasons']),
      evidence: _toStringList(json['evidence']),
      constraints: _toStringList(json['constraints']),
      explanationTrace: _toStringList(json['explanation_trace']),
      actionProbabilities: _toDoubleMap(json['action_probabilities']),
      insights: _toStringList(json['insights']),
      actions: parsedActions.isNotEmpty ? parsedActions : selectedActions,
      message: (json['message'] as String? ?? '').trim(),
      flags: _toStringList(json['flags']),
      projection: _toDoubleMap(json['projection']),
      trendClassification: _toStringMap(json['trend_classification']),
      nextDayPredictions: _toDoubleMap(json['next_day_predictions']),
      predictionModel: _toDynamicMap(json['prediction_model']),
      anomalies: _toDynamicMapList(json['anomalies']),
      miniMeLinkage: _toDynamicMap(json['mini_me_linkage']),
      calibration: _toDynamicMap(json['calibration']),
      evaluation: _toDynamicMap(json['evaluation']),
      weaviateSignal: _toDynamicMap(json['weaviate_signal']),
      alert: (json['alert'] as String?)?.trim(),
    );
  }
}

class SymptomConditionPrediction {
  const SymptomConditionPrediction({
    required this.condition,
    required this.confidence,
    required this.description,
    required this.severity,
    required this.whenToSeekCare,
  });

  final String condition;
  final double confidence;
  final String description;
  final String severity;
  final String whenToSeekCare;

  factory SymptomConditionPrediction.fromJson(Map<String, dynamic> json) {
    return SymptomConditionPrediction(
      condition: (json['condition'] as String? ?? '').trim(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      description: (json['description'] as String? ?? '').trim(),
      severity: (json['severity'] as String? ?? '').trim(),
      whenToSeekCare: (json['when_to_seek_care'] as String? ?? '').trim(),
    );
  }
}

class SymptomAnalysisReply {
  const SymptomAnalysisReply({
    required this.urgency,
    required this.analysis,
    required this.predictions,
    required this.selfCareRecommendations,
    required this.warningSigns,
    required this.source,
    this.confidenceScore,
  });

  /// 'emergency', 'urgent', or 'routine'
  final String urgency;
  final String analysis;
  final List<SymptomConditionPrediction> predictions;
  final List<String> selfCareRecommendations;
  final List<String> warningSigns;
  final String source;
  final double? confidenceScore;

  factory SymptomAnalysisReply.fromJson(Map<String, dynamic> json) {
    final rawPredictions = json['predictions'];
    final predictions = rawPredictions is List
        ? rawPredictions
              .whereType<Map>()
              .map((e) => SymptomConditionPrediction.fromJson(Map<String, dynamic>.from(e)))
              .where((p) => p.condition.isNotEmpty)
              .toList(growable: false)
        : const <SymptomConditionPrediction>[];

    List<String> _toStringList(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }

    return SymptomAnalysisReply(
      urgency: (json['urgency'] as String? ?? 'routine').trim(),
      analysis: (json['analysis'] as String? ?? '').trim(),
      predictions: predictions,
      selfCareRecommendations: _toStringList(json['self_care_recommendations']),
      warningSigns: _toStringList(json['warning_signs']),
      source: (json['source'] as String? ?? 'backend').trim(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
    );
  }
}

class MiniMeBackendService {
  MiniMeBackendService._();

  static final MiniMeBackendService instance = MiniMeBackendService._();
  String? _lastKnownGoodBaseUrl;

  static const String _configuredBaseUrl = String.fromEnvironment(
    'LIFELENS_API_BASE_URL',
    defaultValue: '',
  );

  List<String> _candidateBaseUrls() {
    final urls = <String>[];

    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      urls.add(configured);
    }

    urls.addAll(const [
      'http://192.168.1.166:8000',
      'http://127.0.0.1:8000',
      'http://localhost:8000',
      'http://10.0.2.2:8000',
    ]);

    final seen = <String>{};
    return urls.where((u) => seen.add(u)).toList();
  }

  List<String> _prioritizedBaseUrls() {
    final urls = _candidateBaseUrls();
    final lastGood = _lastKnownGoodBaseUrl;
    if (lastGood == null || lastGood.isEmpty) {
      return urls;
    }

    final ordered = <String>[lastGood, ...urls.where((u) => u != lastGood)];
    final seen = <String>{};
    return ordered.where((u) => seen.add(u)).toList(growable: false);
  }

  Future<MiniMeBackendReply> chat({
    required LifeLensContext context,
    required String userMessage,
    required List<MiniMeChatTurn> history,
    MiniMeIntelligenceReply? intelligence,
  }) async {
    final sanitizedHistory = _truncateHistory(history);
    final sanitizedUserMessage = _truncateText(userMessage, 2000);

    final payload = <String, dynamic>{
      ...toBackendJson(context),
      'user_message': sanitizedUserMessage,
      'chat_history': sanitizedHistory.map((e) => e.toJson()).toList(),
    };
    if (intelligence != null) {
      payload['intelligence_tier'] = intelligence.interventionTier;
      payload['intelligence_phase'] = intelligence.userPhase;
      payload['intelligence_insights'] = intelligence.insights;
      payload['intelligence_actions'] = intelligence.selectedActions;
      if (intelligence.alert != null) {
        payload['intelligence_alert'] = intelligence.alert;
      }
      payload['intelligence_risk_score'] = intelligence.riskScore;
      payload['intelligence_confidence'] = intelligence.confidenceScore;
      payload['intelligence_state'] = intelligence.state;
    }

    Object? lastError;
    for (final baseUrl in _prioritizedBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/minime/chat');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Mini-Me backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _lastKnownGoodBaseUrl = baseUrl;
        return MiniMeBackendReply.fromJson(decoded);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Unable to reach Mini-Me backend: $lastError');
  }

  Future<MiniMeSuggestionsReply> suggestions({
    required String latestMoodLabel,
    required int latestMoodIntensity,
    required String latestMoodNotes,
    required List<String> recentMoods,
    required List<String> recentLogs,
    required List<String> activeSymptoms,
    required List<MiniMeChatTurn> history,
    String? summaryContext,
    String? suggestionWindow,
    String? triggerReason,
    bool eventOverride = false,
  }) async {
    final canonicalRecentMoods = _sanitizeRecentMoods(recentMoods);
    final canonicalMoodLabel = _resolveLatestCanonicalMood(
      latestMoodLabel,
      canonicalRecentMoods,
    );
    final sanitizedRecentLogs = _truncateListItems(
      recentLogs,
      maxItems: 28,
      maxItemLength: 1000,
    );
    final sanitizedSymptoms = _truncateListItems(
      activeSymptoms,
      maxItems: 20,
      maxItemLength: 120,
    );
    final sanitizedHistory = _truncateHistory(history);
    final sanitizedMoodNotes = _truncateText(latestMoodNotes, 1000);
    final sanitizedSummaryContext = summaryContext == null
        ? null
        : _truncateText(summaryContext, 8000);

    final payload = {
      'latest_mood_label': canonicalMoodLabel,
      'latest_mood_intensity': latestMoodIntensity,
      'latest_mood_notes': sanitizedMoodNotes,
      'recent_moods': canonicalRecentMoods,
      'recent_logs': sanitizedRecentLogs,
      'active_symptoms': sanitizedSymptoms,
      'chat_history': sanitizedHistory.map((e) => e.toJson()).toList(),
    };
    if (sanitizedSummaryContext != null && sanitizedSummaryContext.isNotEmpty) {
      payload['summary_context'] = sanitizedSummaryContext;
    }
    if (suggestionWindow != null && suggestionWindow.trim().isNotEmpty) {
      payload['suggestion_window'] = suggestionWindow.trim();
    }
    if (triggerReason != null && triggerReason.trim().isNotEmpty) {
      payload['trigger_reason'] = _truncateText(triggerReason, 240);
    }
    payload['event_override'] = eventOverride;

    Object? lastError;
    for (final baseUrl in _prioritizedBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/minime/suggestions');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 7));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Mini-Me backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _lastKnownGoodBaseUrl = baseUrl;
        return MiniMeSuggestionsReply.fromJson(decoded);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Unable to reach Mini-Me backend: $lastError');
  }

  Future<MiniMeExerciseRecommendationsReply> exerciseRecommendations({
    required String latestMoodLabel,
    required int latestMoodIntensity,
    required String latestMoodNotes,
    required List<String> recentMoods,
    required List<String> recentLogs,
    required List<String> activeSymptoms,
    required List<MiniMeChatTurn> history,
    required List<MiniMeExerciseCandidate> exercises,
    String? summaryContext,
  }) async {
    final canonicalRecentMoods = _sanitizeRecentMoods(recentMoods);
    final canonicalMoodLabel = _resolveLatestCanonicalMood(
      latestMoodLabel,
      canonicalRecentMoods,
    );
    final sanitizedRecentLogs = _truncateListItems(
      recentLogs,
      maxItems: 12,
      maxItemLength: 1000,
    );
    final sanitizedSymptoms = _truncateListItems(
      activeSymptoms,
      maxItems: 20,
      maxItemLength: 120,
    );
    final sanitizedHistory = _truncateHistory(history);
    final sanitizedMoodNotes = _truncateText(latestMoodNotes, 1000);
    final sanitizedSummaryContext = summaryContext == null
        ? null
        : _truncateText(summaryContext, 8000);

    final payload = {
      'latest_mood_label': canonicalMoodLabel,
      'latest_mood_intensity': latestMoodIntensity,
      'latest_mood_notes': sanitizedMoodNotes,
      'recent_moods': canonicalRecentMoods,
      'recent_logs': sanitizedRecentLogs,
      'active_symptoms': sanitizedSymptoms,
      'chat_history': sanitizedHistory.map((e) => e.toJson()).toList(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
    if (sanitizedSummaryContext != null && sanitizedSummaryContext.isNotEmpty) {
      payload['summary_context'] = sanitizedSummaryContext;
    }

    Object? lastError;
    for (final baseUrl in _prioritizedBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/minime/exercise-recommendations');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 7));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Mini-Me backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _lastKnownGoodBaseUrl = baseUrl;
        return MiniMeExerciseRecommendationsReply.fromJson(decoded);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Unable to reach Mini-Me backend: $lastError');
  }

  Future<MiniMeIntelligenceReply> analyzeIntelligence({
    required List<int> sleep,
    required List<int> mood,
    required List<int> exercise,
    List<int> symptomCount = const [],
    bool includeGeminiMessage = true,
  }) async {
    final payload = {
      'sleep': sleep,
      'mood': mood,
      'exercise': exercise,
      'symptom_count': symptomCount,
      'include_gemini_message': includeGeminiMessage,
    };

    Object? lastError;
    for (final baseUrl in _prioritizedBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/intelligence/analyze');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 7));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Mini-Me backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _lastKnownGoodBaseUrl = baseUrl;
        return MiniMeIntelligenceReply.fromJson(decoded);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Unable to reach Mini-Me backend: $lastError');
  }

  Future<SymptomAnalysisReply> analyzeSymptoms({
    required List<String> symptoms,
    int? age,
    String? sex,
    String? duration,
    String? additionalInfo,
  }) async {
    final payload = <String, dynamic>{
      'symptoms': symptoms.take(20).toList(),
    };
    if (age != null) payload['age'] = age;
    if (sex != null && sex.isNotEmpty) payload['sex'] = sex;
    if (duration != null && duration.isNotEmpty) payload['duration'] = _truncateText(duration, 200);
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      payload['additional_info'] = _truncateText(additionalInfo, 1000);
    }

    Object? lastError;
    for (final baseUrl in _prioritizedBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/symptoms/analyze');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Symptom backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _lastKnownGoodBaseUrl = baseUrl;
        return SymptomAnalysisReply.fromJson(decoded);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Unable to reach symptom analysis backend: $lastError');
  }
}
