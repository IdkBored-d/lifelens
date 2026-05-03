/// Dual-tier crisis detection safety net for on-device LLM inference.
///
/// Scans both user input and model output for crisis-level content.
/// NOTE: logic may be incorrect -- this is replacing our old version.
///
/// Tier 1 (physical emergency → 911) is checked first (higher priority).
/// Tier 2 (mental health crisis → 988) is checked second.
library;

/// The type of crisis detected by [CrisisRegexNet].
enum CrisisType {
  none,
  mentalHealth988,
  physicalEmergency911,
}

/// Thrown when [CrisisRegexNet] detects crisis content in the prompt input
/// or model output token stream.
class CrisisInterventionException implements Exception {
  final CrisisType type;
  final String message;

  const CrisisInterventionException(this.type, [this.message = 'Crisis content detected']);

  @override
  String toString() => 'CrisisInterventionException($type): $message';
}

/// Deterministic Dart-level safety net — regex-based crisis detection.
///
/// Two tiers, checked in priority order:
///   1. **Physical emergency (911):** cardiac, stroke, seizure, OD, choking, etc.
///   2. **Mental health (988):** suicidal ideation, self-harm, etc.
///
/// This runs entirely in Dart — no model inference, no network calls.
class CrisisRegexNet {
  CrisisRegexNet._();

  // ── Tier 1: Physical emergency → 911 ────────────────────────────────────

  static final _physical911 = RegExp(
    r'(?:'
    r'call\s*911'
    r'|heart\s*attack'
    r'|having\s+a\s+stroke'
    r'|can\s*(?:no)?t\s+breathe'
    r'|seizure'
    r'|overdos(?:e|ing)'
    r'|anaphyla(?:xis|ctic)'
    r'|choking'
    r'|severe\s+(?:chest\s+pain|bleeding|burn)'
    r'|unconscious'
    r'|not\s+breathing'
    r'|stopped\s+breathing'
    r'|collapsed'
    r')',
    caseSensitive: false,
  );

  // ── Tier 2: Mental health → 988 ─────────────────────────────────────────

  static final _mental988 = RegExp(
    r'(?:'
    r'(?:want|wish|plan(?:ning)?|going|tried?)\s+to\s+(?:die|kill\s+(?:my|him|her)self|end\s+(?:it|my\s+life|everything))'
    r'|(?:kill|hurt|cut|harm)\s+(?:my|him|her)self'
    r'|sui(?:cid(?:e|al)|cude)'
    r'|self[- ]?harm'
    r"|(?:don't|do\s+not)\s+want\s+to\s+(?:be\s+alive|live|exist)"
    r'|end(?:ing)?\s+(?:it\s+all|my\s+life|everything)'
    r'|unalive'
    r'|no\s+(?:reason|point)\s+(?:to|in)\s+liv(?:e|ing)'
    r'|better\s+off\s+(?:dead|without\s+me)'
    r')',
    caseSensitive: false,
  );

  /// Check text for crisis content. Returns [CrisisType.none] if clean.
  /// Physical emergency (911) is checked first — higher priority.
  static CrisisType check(String text) {
    if (_physical911.hasMatch(text)) return CrisisType.physicalEmergency911;
    if (_mental988.hasMatch(text)) return CrisisType.mentalHealth988;
    return CrisisType.none;
  }

  /// Convenience: returns true if any crisis content is detected.
  static bool matches(String text) => check(text) != CrisisType.none;

  /// Pre-flight gate for CONDITION_STEPS from Weaviate.
  ///
  /// If the condition steps themselves contain 911-tier patterns,
  /// we should route directly to emergency — don't even invoke the model.
  static CrisisType checkConditionSteps(String? conditionSteps) {
    if (conditionSteps == null || conditionSteps.isEmpty) {
      return CrisisType.none;
    }
    return check(conditionSteps);
  }

  /// Throws [CrisisInterventionException] if crisis content is detected.
  static void guard(String text, {String context = 'input'}) {
    final type = check(text);
    if (type != CrisisType.none) {
      throw CrisisInterventionException(
        type,
        'Crisis content in $context — routing to ${type == CrisisType.physicalEmergency911 ? "911" : "988"}',
      );
    }
  }
}
