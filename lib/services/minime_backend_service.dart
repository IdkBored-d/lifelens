import 'dart:convert';

import 'package:http/http.dart' as http;

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

class MiniMeBackendService {
  MiniMeBackendService._();

  static final MiniMeBackendService instance = MiniMeBackendService._();

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
      'http://127.0.0.1:8000',
      'http://localhost:8000',
      'http://10.0.2.2:8000',
    ]);

    final seen = <String>{};
    return urls.where((u) => seen.add(u)).toList();
  }

  Future<MiniMeBackendReply> chat({
    required String userMessage,
    required String moodLabel,
    required int moodIntensity,
    required String moodNotes,
    required List<String> recentMoods,
    required List<String> activeSymptoms,
    required List<MiniMeChatTurn> history,
  }) async {
    final payload = {
      'user_message': userMessage,
      'latest_mood_label': moodLabel,
      'latest_mood_intensity': moodIntensity,
      'latest_mood_notes': moodNotes,
      'recent_moods': recentMoods,
      'active_symptoms': activeSymptoms,
      'chat_history': history.map((e) => e.toJson()).toList(),
    };

    Object? lastError;
    for (final baseUrl in _candidateBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/minime/chat');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Mini-Me backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
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
  }) async {
    final payload = {
      'latest_mood_label': latestMoodLabel,
      'latest_mood_intensity': latestMoodIntensity,
      'latest_mood_notes': latestMoodNotes,
      'recent_moods': recentMoods,
      'recent_logs': recentLogs,
      'active_symptoms': activeSymptoms,
      'chat_history': history.map((e) => e.toJson()).toList(),
    };

    Object? lastError;
    for (final baseUrl in _candidateBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/minime/suggestions');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Mini-Me backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
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
  }) async {
    final payload = {
      'latest_mood_label': latestMoodLabel,
      'latest_mood_intensity': latestMoodIntensity,
      'latest_mood_notes': latestMoodNotes,
      'recent_moods': recentMoods,
      'recent_logs': recentLogs,
      'active_symptoms': activeSymptoms,
      'chat_history': history.map((e) => e.toJson()).toList(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };

    Object? lastError;
    for (final baseUrl in _candidateBaseUrls()) {
      final uri = Uri.parse('$baseUrl/api/v1/minime/exercise-recommendations');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) {
          lastError = Exception(
            'Mini-Me backend error ${response.statusCode}: ${response.body}',
          );
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return MiniMeExerciseRecommendationsReply.fromJson(decoded);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Unable to reach Mini-Me backend: $lastError');
  }
}
