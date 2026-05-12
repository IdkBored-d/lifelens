import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

/// Calls the Gemini API. Used exclusively by EodPipelineService.
///
/// Uses gemini-2.5-flash.
/// Token limits (Gemini 2.5 Flash):
///   Input:  1,048,576 tokens
///   Output: 65,536 tokens (default cap)
class GeminiService {
  final String _apiKey;

  static const String _model   = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  GeminiService({required String apiKey}) : _apiKey = apiKey;

  // ── Core inference ──────────────────────────────────────────────────────────

  /// Core inference method.
  ///
  /// [maxOutputTokens] is per-call configurable because different pipelines
  /// have very different output size needs:
  ///   Mood response:       ~400 tokens
  ///   Symptom 2nd opinion: ~3000 tokens (5 diagnoses + reasoning)
  ///   EOD deep analysis:   ~3000 tokens (summary + correlation JSON)
  ///
  /// Gemini 2.5 Flash hard cap is 65,536 output tokens — all values
  /// used here are well within that limit.
  Future<String> generate(String prompt, {int maxOutputTokens = 1024}) async {
    final uri = Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'temperature':     0.7,
        'topP':            0.95,
      },
    });

    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 15));

        // 4xx errors are not retryable (bad key, quota, bad request).
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return 'Unable to reach Gemini. Please try again when online.';
        }

        // 5xx errors are transient — retry.
        if (response.statusCode >= 500) {
          if (attempt < maxAttempts) {
            await Future<void>.delayed(const Duration(seconds: 1));
            continue;
          }
          return 'Unable to reach Gemini. Please try again when online.';
        }

        final decoded  = jsonDecode(response.body) as Map<String, dynamic>;
        final parts    = decoded['candidates']?[0]?['content']?['parts'] as List?;
        final text     = parts?.map((p) => p['text'] as String).join('') ?? '';
        return text.trim();
      } on SocketException {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
      } catch (_) {
        // TimeoutException and any other transient error — retry.
        if (attempt < maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
      }
    }
    return 'Unable to reach Gemini. Please try again when online.';
  }

  // ── EOD (deeper correlation analysis) ──────────────────────────────────────

  Future<String> generateDeepEodAnalysis({
    required String todayMoodEntry,
    required String activeSymptomEntries,
    required double todayFitnessScore,
    required double periodAvgFitnessScore,
    required String fitnessTrend,
    required String last14MoodEntries,
    required String ragContext,
  }) async {
    return generate('''
You are a personal health assistant performing a deep end-of-day review.

--- TODAY'S MOOD ---
$todayMoodEntry

--- ACTIVE / RECENT SYMPTOMS ---
$activeSymptomEntries

--- FITNESS ---
Today: ${todayFitnessScore.toStringAsFixed(1)} / 100
14-day average: ${periodAvgFitnessScore.toStringAsFixed(1)} / 100
Trend: $fitnessTrend

--- MOOD HISTORY (last 14 days) ---
$last14MoodEntries

--- MEDICAL KNOWLEDGE BASE (RAG) ---
$ragContext

Your tasks:
1. Identify correlations between mood, symptoms, and fitness — use the RAG database 
   to check if any combination of patterns matches a known condition.
2. Flag anything warranting attention. If RAG data suggests a possible match,
   surface it gently and recommend professional evaluation.
3. Write a 3–4 sentence warm, non-alarmist user-facing summary.
4. If anything is potentially serious, recommend a doctor. Do not diagnose.

End with this JSON on its own line (no markdown fences):
{"correlation_summary": "...", "flag": false, "flag_reason": "", "rag_match": null}

Tone: supportive, concise, non-clinical.
''', maxOutputTokens: 3000);
  }
}