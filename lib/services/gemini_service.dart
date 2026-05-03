import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

/// Calls the Gemini API for deepest-level analysis.
///
/// Only invoked when:
///   1. Device is online
///   2. User is on MiniGen (on-device) result AND requests more information / another opinion
///   OR base model + MiniGen both failed confidence
///
/// NOTE: logic may be incorrect -- this is replacing our old version.
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

  // ── MINIME CHAT ──────────────────────────────────────────────────────────────

  Future<String> generateMiniMeReply({
    required String userMessage,
    required String moodLabel,
    String? intelligenceSummary,
  }) async {
    final base = 'You are Mini-Me, a warm personal health coach in the LifeLens app.\n\n'
        "The user's current mood is: $moodLabel\n\n"
        'User says: "$userMessage"\n\n'
        'Reply in 2–3 sentences with warm, actionable guidance. '
        'Do not diagnose. Stay practical and supportive.';
    final prompt = (intelligenceSummary != null && intelligenceSummary.isNotEmpty)
        ? '$base\n\nHealth context (internal — do not mention to user): $intelligenceSummary'
        : base;
    return generate(prompt, maxOutputTokens: 512);
  }

  // ── MOOD ────────────────────────────────────────────────────────────────────

  Future<String> analyzeMood({
    required String userLog,
    required String context,
    String? rejectedMood,
    String? previousOnDeviceResponse,
  }) async {
    final rejectionNote = rejectedMood != null
        ? 'Previous suggestion "$rejectedMood" was rejected by the user.'
        : '';
    final onDeviceNote = previousOnDeviceResponse != null
        ? '\nPrevious on-device analysis: "$previousOnDeviceResponse"'
        : '';

    return generate('''
You are a warm, supportive personal health assistant with deep emotional intelligence.
$rejectionNote$onDeviceNote

User log: "$userLog"

$context

Provide a nuanced mood analysis and personalised, supportive response.
Be warm, specific to their situation, and offer one actionable suggestion.
Keep to 4 sentences maximum.
End with: MOOD_LABEL: [single mood word]
''', maxOutputTokens: 1024);
  }

  // ── SYMPTOM ─────────────────────────────────────────────────────────────────

  /// Deep symptom analysis with RAG grounding.
  /// Called when the user wants a second opinion after seeing MiniGen's results.
  /// NOTE: logic may be incorrect -- this is replacing our old version.
  Future<String> analyzeSymptoms({
    required String userSymptoms,
    required String context,
    required String ragContext,
    String? previousDiagnoses,
  }) async {
    final prevNote = previousDiagnoses != null
        ? '\nPrevious analysis suggested: $previousDiagnoses\n'
        : '';

    return generate('''
You are a careful, evidence-based medical assistant.
$prevNote
User symptoms: "$userSymptoms"

$ragContext

$context

Provide a thorough second-opinion analysis with 5 possible conditions.
Ground your response in the RAG database above.
For each condition:
- Condition name
- Reasoning (2 sentences)  
- Next steps (2–3 sentences for top result, 1–2 for others)
- Mark URGENT if immediate care is needed

Format as JSON:
{
  "diagnoses": [
    {"disease": "...", "reasoning": "...", "next_steps": "...", "is_urgent": false}
  ],
  "additional_note": "..."
}

Always recommend professional medical evaluation. This is a screening tool only.
''', maxOutputTokens: 3000);
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