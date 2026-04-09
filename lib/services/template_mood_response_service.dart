/// Replaces Gemma's `analyzeMoodDirectly()` with rule-based mood re-classification
/// and template-based response generation.
///
/// Used when MobileBERT is low-confidence or the user rejects a prediction.
///
/// Re-classification strategy:
///   1. Parse common rejection phrases to override the rejected label
///   2. Scan the enriched log for strong mood keywords to pick the best label
///   3. Fall back to the MobileBERT prediction if no signal is found
///
/// Response templates are selected based on the resolved mood and context flags.
class TemplateMoodResponseService {
  const TemplateMoodResponseService();

  /// Re-classify mood and produce a response without an LLM.
  ///
  /// [enrichedLog]   user log text, optionally including rejection clarification.
  /// [rejectedMood]  the label the user already rejected (null if first attempt).
  /// [mbTopLabel]    MobileBERT's original top prediction.
  /// [hasFitnessDip] true if fitness has been declining recently (from quick-track).
  ///
  /// Returns (resolvedMood, responseText).
  (String, String) analyze({
    required String enrichedLog,
    required String mbTopLabel,
    String? rejectedMood,
    bool hasFitnessDip = false,
  }) {
    final resolved = _reclassify(enrichedLog, rejectedMood, mbTopLabel);
    final response = _buildResponse(
      mood: resolved,
      enrichedLog: enrichedLog,
      hasFitnessDip: hasFitnessDip,
    );
    return (resolved, response);
  }

  // ── Re-classification ────────────────────────────────────────────────────────

  String _reclassify(String log, String? rejected, String mbLabel) {
    final lower = log.toLowerCase();

    // Phase 1: Explicit rejection overrides — common clarification phrases
    // e.g. "I'm not sad, I'm just tired" → check what they said AFTER "not X"
    if (rejected != null) {
      final afterNot = _extractAfterNot(lower, rejected);
      if (afterNot != null) {
        final override = _keywordToLabel(afterNot);
        if (override != null && override != rejected) return override;
      }
    }

    // Phase 2: Strong keyword signal in the log
    // Check in priority order — more specific before more general
    for (final entry in _kKeywordPriority) {
      final label = entry.key;
      if (label == rejected) continue; // skip the rejected one
      for (final kw in entry.value) {
        if (lower.contains(kw)) return label;
      }
    }

    // Phase 3: Fall back to MobileBERT's label (if not rejected),
    // or 'neutral' if MobileBERT's label was also rejected
    if (mbLabel != rejected) return mbLabel;
    return 'neutral';
  }

  /// Extracts the phrase after "not [rejectedMood]" in the log.
  String? _extractAfterNot(String lower, String rejected) {
    final pattern = RegExp("not\\s+$rejected[,\\s]+(.{0,40})");
    final m = pattern.firstMatch(lower);
    return m?.group(1);
  }

  /// Maps a short phrase to a mood label.
  String? _keywordToLabel(String phrase) {
    for (final entry in _kKeywordPriority) {
      for (final kw in entry.value) {
        if (phrase.contains(kw)) return entry.key;
      }
    }
    return null;
  }

  // ── Response generation ──────────────────────────────────────────────────────

  String _buildResponse({
    required String mood,
    required String enrichedLog,
    required bool hasFitnessDip,
  }) {
    final lower = enrichedLog.toLowerCase();
    final acknowledgment = _acknowledge(mood, lower);
    final suggestion = _suggest(mood, hasFitnessDip);
    return '$acknowledgment $suggestion';
  }

  String _acknowledge(String mood, String log) {
    // Extra nuance for common clarification contexts
    if (log.contains('tired') || log.contains('exhausted') || log.contains('fatigued')) {
      return 'Tiredness and low energy can weigh heavily — that makes a lot of sense.';
    }
    if (log.contains('stressed') || log.contains('overwhelmed') || log.contains('pressure')) {
      return "When everything feels like too much, it's okay to take a step back.";
    }
    if (log.contains('nervous') || log.contains('worried') || log.contains('anxious')) {
      return 'Feeling on edge is uncomfortable, but recognizing it is the first step.';
    }
    return switch (mood) {
      'joy'      => 'It sounds like things are going well — that positive energy is great to see.',
      'love'     => "That warmth and connection you're feeling is something to hold onto.",
      'content'  => 'A steady, calm feeling is something worth appreciating — not every day needs to be exciting.',
      'sadness'  => 'Feeling down is hard, and it takes courage to acknowledge it.',
      'anger'    => 'Frustration is valid, especially when things are not going as expected.',
      'fear'     => 'Uncertainty can feel overwhelming — you are not alone in that.',
      'surprise' => 'Unexpected moments can throw us off balance, and that is completely understandable.',
      'anxious'  => 'Anxiety has a way of making everything feel more intense than it is.',
      _          => 'Thanks for checking in — however you are feeling right now is valid.',
    };
  }

  String _suggest(String mood, bool hasFitnessDip) {
    if (hasFitnessDip && (mood == 'sadness' || mood == 'anxious' || mood == 'fear')) {
      return 'A short walk or light stretch can help both your mood and energy — even 10 minutes counts.';
    }
    return switch (mood) {
      'joy'     => 'Take a moment to note what made today positive — it can help you recreate it.',
      'love'    => 'Nurturing your relationships is a powerful form of self-care — keep it up.',
      'content' => 'Consistency is underrated — keep building on what is working.',
      'sadness' => 'Try one small, nurturing action for yourself today, even something tiny.',
      'anger'   => 'Writing out what triggered you can help process it without letting it linger.',
      'fear'    => 'Break down whatever is worrying you into the smallest possible next step.',
      'surprise'=> 'Give yourself space to process — not every surprise needs an immediate response.',
      'anxious' => 'A few slow breaths or a short walk can help quiet the anxious edge.',
      _         => 'Keep logging how you feel — patterns become clearer over time.',
    };
  }

  // ── Keyword tables ───────────────────────────────────────────────────────────

  /// Ordered keyword lookup: checked top-to-bottom, first match wins.
  /// Pairs are (label → keyword list).
  static const _kKeywordPriority = [
    MapEntry('anxious',  ['anxious', 'anxiety', 'nervous', 'worry', 'worried', 'panic', 'dread', 'uneasy', 'apprehensive']),
    MapEntry('fear',     ['scared', 'fear', 'afraid', 'frightened', 'terrified', 'dread']),
    MapEntry('anger',    ['angry', 'anger', 'furious', 'frustrated', 'irritated', 'annoyed', 'rage', 'mad']),
    MapEntry('sadness',  ['sad', 'sadness', 'depressed', 'depression', 'hopeless', 'grief', 'heartbroken', 'gloomy', 'down', 'miserable']),
    MapEntry('love',     ['love', 'grateful', 'gratitude', 'loved', 'affection', 'caring', 'warmth', 'appreciation']),
    MapEntry('joy',      ['happy', 'joy', 'joyful', 'excited', 'elated', 'great', 'wonderful', 'amazing', 'fantastic', 'thrilled']),
    MapEntry('content',  ['content', 'calm', 'peaceful', 'relaxed', 'ok', 'okay', 'fine', 'alright', 'stable', 'good']),
    MapEntry('surprise', ['surprised', 'surprised', 'shocked', 'astonished', 'unexpected', 'sudden', 'caught off guard']),
  ];
}
