/// Which model should handle a given inference result.
enum EscalationLevel {
  /// Base model result is trustworthy — use it directly.
  base,

  /// Escalate to on-device Gemma2b for deeper analysis.
  gemma,

  /// Escalate to online Gemini (requires connectivity).
  /// Only reached if user is online AND has declined/failed previous options.
  gemini,
}

/// Confidence band for DisEmbed cosine similarity results.
enum DisEmbedConfidence {
  high,
  medium,
  uncertain,
}
