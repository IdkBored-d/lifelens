import 'escalation_level.dart';

/// Raw output from DisEmbed inference.
class DisEmbedResult {
  final double cosineScore;
  final String prediction; // "similar" or "dissimilar"
  final bool confidenceOk;
  final String confidenceLevel; // "high", "medium", "uncertain"
  final EscalationLevel escalation;
  final String reason;

  const DisEmbedResult({
    required this.cosineScore,
    required this.prediction,
    required this.confidenceOk,
    required this.confidenceLevel,
    required this.escalation,
    required this.reason,
  });
}

