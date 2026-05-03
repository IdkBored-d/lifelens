/// Which model should handle a given inference result.
enum EscalationLevel {
  /// Base model result is trustworthy — use it directly.
  base,

  /// Escalate to on-device MiniGen LLM for deeper analysis.
  /// NOTE: logic may be incorrect -- this is replacing our old version.
  onDevice,

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
