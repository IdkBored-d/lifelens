import 'package:flutter_gemma/flutter_gemma.dart';

/// Wraps flutter_gemma for on-device Gemma 2 2B IT inference.
///
/// Model: Gemma 2 2B IT (int8, MediaPipe LiteRT variant)
/// Source: litert-community/Gemma2-2B-IT on HuggingFace
///
/// The "IT" (instruction-tuned) variant is required — the base model
/// does not follow structured prompts reliably.
///
/// LOADING NOTE:
///   The model file is ~1.4 GB. Store on device after OTA download.
///   Pass the on-device path to load().
class GemmaService {
  InferenceModel? _model;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Install and activate the Gemma 2 2B IT model from [modelPath].
  /// Must be called before any generate() calls.
  Future<void> load(String modelPath) async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    ).fromFile(modelPath).install();

    _model    = await FlutterGemma.getActiveModel(maxTokens: 2048);
    _isLoaded = true;
  }

  // ── Core inference ──────────────────────────────────────────────────────────

  /// Run a single-turn inference. Opens a session, sends [prompt],
  /// collects the response, and closes the session.
  ///
  /// The session is always closed in a finally block — if [getResponse]
  /// throws, the MediaPipe session handle is not leaked.
  ///
  /// Token budget notes (Gemma 2 2B IT, 8192-token context window):
  ///   Mood response:    ~300 prompt + ~400 output  =  ~700  tokens
  ///   Symptom expand:   ~700 prompt + ~900 output  = ~1600  tokens
  ///   EOD summary:     ~1100 prompt + ~900 output  = ~2000  tokens
  /// All well within the 8192-token limit at maxTokens=2048.
  Future<String> generate(String prompt) async {
    assert(_isLoaded, 'GemmaService not loaded. Call load() first.');

    final session = await _model!.createSession(
      temperature: 0.4,   // lower = more predictable, less rambling
      randomSeed:  42,
      topK:        20,    // tighter sampling for structured health output
    );

    try {
      await session.addQueryChunk(
        Message.text(text: prompt, isUser: true),
      );
      return await session.getResponse();
    } finally {
      // Always close, even if getResponse() throws — prevents handle leaks.
      await session.close();
    }
  }

  // ── MOOD PIPELINE ───────────────────────────────────────────────────────────

  Future<String> generateMoodResponse({
    required String predictedMood,
    required String userLog,
    required String context,
  }) async {
    return generate(_moodResponsePrompt(predictedMood, userLog, context));
  }

  Future<String> analyzeMoodDirectly({
    required String userLog,
    required String context,
    String? rejectedMood,
  }) async {
    return generate(_moodDirectPrompt(userLog, context, rejectedMood));
  }

  Future<String> extractMoodLabel(String gemmaResponse) async {
    final prompt =
        'From the response below, extract ONLY a single emotion label.\n'
        'Choose from: sadness, joy, love, anger, fear, surprise, '
        'anxious, content, neutral.\n'
        'Reply with just the label — no punctuation, no explanation.\n\n'
        'Response: "$gemmaResponse"';
    final label = (await generate(prompt)).trim().toLowerCase();
    const valid = {
      'sadness', 'joy', 'love', 'anger', 'fear', 'surprise',
      'anxious', 'content', 'neutral',
    };
    return valid.contains(label) ? label : 'neutral';
  }

  // ── SYMPTOM PIPELINE ─────────────────────────────────────────────────────────

  Future<String> expandDiagnosis({
    required String disEmbedPrediction,
    required String userSymptoms,
    required String context,
    String? ragContext,
  }) async {
    return generate(
        _diagnosisExpandPrompt(disEmbedPrediction, userSymptoms, context, ragContext));
  }

  Future<String> analyzeSymptomDirectly({
    required String userSymptoms,
    required String context,
    String? ragContext,
  }) async {
    return generate(_symptomDirectPrompt(userSymptoms, context, ragContext));
  }

  // ── EOD PIPELINE ────────────────────────────────────────────────────────────

  Future<String> generateEodSummary({
    required String todayMoodEntry,
    required String activeSymptomEntries,
    required double todayFitnessScore,
    required double weekAvgFitnessScore,
    required String fitnessTrend,
    required String last7MoodEntries,
  }) async {
    return generate(_eodPrompt(
      todayMoodEntry:       todayMoodEntry,
      activeSymptomEntries: activeSymptomEntries,
      todayFitnessScore:    todayFitnessScore,
      weekAvgFitnessScore:  weekAvgFitnessScore,
      fitnessTrend:         fitnessTrend,
      last7MoodEntries:     last7MoodEntries,
    ));
  }

  // ── Prompt templates ─────────────────────────────────────────────────────────
  // flutter_gemma's session API handles chat formatting automatically.
  // Pass clean prompt text — do NOT include <start_of_turn> markers here.

  static String _moodResponsePrompt(String mood, String log, String context) =>
      'You are a warm, supportive personal health assistant.\n\n'
      'The user just submitted this log entry:\n"$log"\n\n'
      'Their current mood has been identified as: $mood\n\n'
      '$context\n\n'
      'Your task:\n'
      '1. Acknowledge their current mood warmly (1 sentence).\n'
      '2. Note any pattern from their recent history (1 sentence).\n'
      '3. Offer one gentle, actionable suggestion (1 sentence).\n\n'
      'Keep your entire response to 3 sentences. Be supportive, not clinical.';

  static String _moodDirectPrompt(
      String log, String context, String? rejected) {
    final note = rejected != null
        ? '"$rejected" was suggested but the user said it was incorrect.\n\n'
        : '';
    return 'You are a warm, supportive personal health assistant.\n\n'
        '$note'
        'The user submitted this log:\n"$log"\n\n'
        '$context\n\n'
        'Tasks:\n'
        '1. Identify the most likely current mood — be specific and nuanced.\n'
        '2. Acknowledge it warmly (1 sentence).\n'
        '3. Note any relevant pattern from their history (1 sentence).\n'
        '4. Offer one gentle, actionable suggestion (1 sentence).\n\n'
        'End your response with exactly:\nMOOD_LABEL: [single mood word]';
  }

  static String _diagnosisExpandPrompt(
      String prediction, String symptoms, String context, String? rag) {
    final ragBlock    = rag != null ? '\n$rag\n' : '';
    final offlineNote = rag == null
        ? '\nNOTE: You are offline. Be conservative — recommend professional evaluation.\n'
        : '';
    return 'You are a careful, evidence-based medical assistant.$offlineNote\n\n'
        'The user reported these symptoms:\n"$symptoms"\n\n'
        'An initial screening suggests: $prediction\n'
        '$ragBlock\n'
        '$context\n\n'
        'Provide exactly 5 possible conditions:\n'
        '1. The most likely condition\n'
        '2-5. Four other plausible conditions\n\n'
        'For each: name, 1-sentence reasoning, next steps, is_urgent flag.\n\n'
        'IMPORTANT: Always recommend seeing a doctor for serious conditions.\n'
        'Do not provide a definitive diagnosis — this is a screening tool only.\n\n'
        'Respond ONLY with valid JSON:\n'
        '{"diagnoses": [{"disease": "...", "reasoning": "...", '
        '"next_steps": "...", "is_urgent": false}]}';
  }

  static String _symptomDirectPrompt(
      String symptoms, String context, String? rag) {
    final ragBlock    = rag != null ? '\n$rag\n' : '';
    final offlineNote = rag == null
        ? '\nNOTE: You are offline. Be conservative — recommend professional evaluation.\n'
        : '';
    return 'You are a careful, evidence-based medical assistant.$offlineNote\n\n'
        'User symptoms:\n"$symptoms"\n'
        '$ragBlock\n'
        '$context\n\n'
        'Provide 5 possible conditions in the same JSON format.\n'
        'Always recommend seeing a doctor for serious conditions.';
  }

  static String _eodPrompt({
    required String todayMoodEntry,
    required String activeSymptomEntries,
    required double todayFitnessScore,
    required double weekAvgFitnessScore,
    required String fitnessTrend,
    required String last7MoodEntries,
  }) =>
      'You are a personal health assistant performing an end-of-day review.\n\n'
      "--- TODAY'S MOOD ---\n$todayMoodEntry\n\n"
      '--- ACTIVE / RECENT SYMPTOMS ---\n$activeSymptomEntries\n\n'
      '--- FITNESS ---\n'
      'Today: ${todayFitnessScore.toStringAsFixed(1)} / 100\n'
      '7-day average: ${weekAvgFitnessScore.toStringAsFixed(1)} / 100\n'
      'Trend: $fitnessTrend\n\n'
      '--- MOOD HISTORY (last 7 days) ---\n$last7MoodEntries\n\n'
      'Tasks:\n'
      '1. Identify correlations between mood, symptoms, and fitness trends.\n'
      '2. Flag anything warranting attention.\n'
      '3. Write a 2-3 sentence warm, non-alarmist user-facing summary.\n'
      '4. Recommend a doctor for anything potentially serious — do not diagnose.\n\n'
      'Write the user-facing summary first, then end with this JSON on its own line:\n'
      '{"correlation_summary": "...", "flag": false, "flag_reason": ""}\n\n'
      'Tone: supportive, concise, non-clinical.';

  // ── Teardown ────────────────────────────────────────────────────────────────

  void dispose() {
    _model = null;
    _isLoaded = false;
  }
}