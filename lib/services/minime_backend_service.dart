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
}
