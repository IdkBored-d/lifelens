import 'package:flutter/foundation.dart' show debugPrint;

import '../app_services.dart';
import 'crisis_regex_net.dart';
import 'minigen_prompt.dart' as prompt;
import 'minigen_service.dart';
import 'model_lifecycle_service.dart';

/// High-level chat interface wrapping [MiniGenService].
///
/// Integrates:
///   • Prompt building (context blocks, sliding-window history)
///   • Dual-tier [CrisisRegexNet] (pre-flight input scan + rolling output scan)
///   • Stop-token detection (<|endoftext|>, <|user|>)
///   • Clean-history crisis handling: crisis-triggered turns are never appended
///
/// NOTE: logic may be incorrect -- this is replacing our old version.
class MiniGenChat {
  final MiniGenService _service;

  MiniGenChat(this._service);

  bool get isLoaded => _service.isLoaded;

  // Stop sequences that indicate end of companion turn
  static const _stopSequences = ['<|endoftext|>', '<|user|>'];

  /// One-shot (non-streaming) reply for the MiniMe chat.
  ///
  /// Throws [CrisisInterventionException] if crisis content is detected
  /// in the input prompt.
  Future<String> generateMiniMeReply({
    required String userMessage,
    required String moodLabel,
    String? user,
    String? moodLog,
    String? symptoms,
    String? conditions,
    String? trends,
    String? intelligenceSummary,
    List<String>? chatHistory,
  }) async {
    final fullPrompt = _buildMiniMePrompt(
      userMessage: userMessage,
      moodLabel: moodLabel,
      user: user,
      moodLog: moodLog,
      symptoms: symptoms,
      conditions: conditions,
      trends: trends,
      intelligenceSummary: intelligenceSummary,
      chatHistory: chatHistory,
    );

    // Pre-flight crisis scan on input
    CrisisRegexNet.guard(fullPrompt, context: 'prompt');

    final raw = await _service.generateFull(fullPrompt);
    final cleaned = _cleanOutput(raw);

    // Post-flight crisis scan on output
    CrisisRegexNet.guard(cleaned, context: 'model output');

    return cleaned;
  }

  /// Streaming variant — yields token deltas live.
  ///
  /// Throws [CrisisInterventionException] if crisis content is detected
  /// in the input prompt or in the rolling output.
  ///
  /// The caller must handle the exception per the clean-history contract:
  /// ```dart
  /// try {
  ///   await for (final token in chat.generateMiniMeReplyStream(...)) {
  ///     buffer.write(token);
  ///     yield token;
  ///   }
  ///   // Only append to history on clean completion
  ///   history.add((user: userMessage, companion: buffer.toString()));
  /// } on CrisisInterventionException catch (e) {
  ///   buffer.clear();
  ///   _routeToCrisisOverlay(e.type);
  /// }
  /// ```
  Stream<String> generateMiniMeReplyStream({
    required String userMessage,
    required String moodLabel,
    String? user,
    String? moodLog,
    String? symptoms,
    String? conditions,
    String? trends,
    String? intelligenceSummary,
    List<String>? chatHistory,
  }) async* {
    final fullPrompt = _buildMiniMePrompt(
      userMessage: userMessage,
      moodLabel: moodLabel,
      user: user,
      moodLog: moodLog,
      symptoms: symptoms,
      conditions: conditions,
      trends: trends,
      intelligenceSummary: intelligenceSummary,
      chatHistory: chatHistory,
    );

    // Pre-flight crisis scan on input
    CrisisRegexNet.guard(fullPrompt, context: 'prompt');

    final accumulated = StringBuffer();

    await for (final token in _service.generate(fullPrompt)) {
      accumulated.write(token);

      // Check for stop sequences
      final accStr = accumulated.toString();
      var hitStop = false;
      for (final stop in _stopSequences) {
        if (accStr.contains(stop)) {
          hitStop = true;
          break;
        }
      }

      if (hitStop) {
        debugPrint('[MiniGenChat] stop sequence detected, ending generation');
        break;
      }

      // Rolling crisis scan on accumulated output
      if (CrisisRegexNet.matches(accStr)) {
        throw CrisisInterventionException(
          CrisisRegexNet.check(accStr),
          'Crisis content in model output — routing',
        );
      }

      yield token;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  String _buildMiniMePrompt({
    required String userMessage,
    required String moodLabel,
    String? user,
    String? moodLog,
    String? symptoms,
    String? conditions,
    String? trends,
    String? intelligenceSummary,
    List<String>? chatHistory,
  }) {
    return prompt.buildPrompt(
      contextEntries: {
        'USER':          user,
        'MOOD_LOG':      moodLog ?? moodLabel,
        'SYMPTOMS':      symptoms,
        'CONDITIONS':    conditions,
        'TRENDS':        trends ?? intelligenceSummary,
        'LATEST_ACTION': 'Chat',
      },
      chatHistory: chatHistory,
      userMessage: userMessage,
    );
  }

  // ── Mood log reply ───────────────────────────────────────────────────────

  static const _toneLabels = ['sadness', 'joy', 'love', 'anger', 'fear', 'surprise'];
  static const _neutralThreshold = 0.45;
  static const _intensityLabels = ['very low', 'low', 'moderate', 'high', 'very high'];

  String _predictTone(List<double> probs) {
    final maxProb = probs.reduce((a, b) => a > b ? a : b);
    if (maxProb < _neutralThreshold) return 'neutral';
    return _toneLabels[probs.indexOf(maxProb)];
  }

  /// One-shot reply acknowledging a mood log. Runs MobileBERT on the note
  /// text (if provided) to derive CURRENT_TONE; falls back to omitting the
  /// field when note is empty.
  Future<String> generateMoodLogReply({
    required String mood,
    required int intensity,
    required Set<String> tags,
    required String? note,
    required String userName,
  }) async {
    final intensityLabel = _intensityLabels[intensity.clamp(1, 5) - 1];

    String? tone;
    if (note != null && note.isNotEmpty) {
      await ModelLifecycleService.instance.ensureLoaded([ModelType.mobileBert]);
      final probs = await AppServices.mobileBert.classify(
        note,
        AppServices.mobileBertTokenize,
      );
      tone = _predictTone(probs);
    }

    var moodLog = '$intensityLabel $mood';
    if (tags.isNotEmpty) moodLog += '. Tags: ${tags.join(', ')}';
    if (note != null && note.isNotEmpty) moodLog += '. Note: $note';

    final userMessage =
        (note != null && note.isNotEmpty) ? note : 'I feel $mood';

    final fullPrompt = prompt.buildPrompt(
      contextEntries: {
        'USER': userName,
        'MOOD_LOG': moodLog,
        if (tone != null) 'CURRENT_TONE': tone,
        'LATEST_ACTION': 'Mood Log',
      },
      userMessage: userMessage,
    );

    CrisisRegexNet.guard(fullPrompt, context: 'mood log prompt');

    await ModelLifecycleService.instance.ensureLoaded([ModelType.miniGen]);
    final raw = await _service.generateFull(fullPrompt);
    final reply = _cleanOutput(raw);

    CrisisRegexNet.guard(reply, context: 'mood log output');

    return reply;
  }

  /// Strip stop sequences and trailing whitespace from model output.
  String _cleanOutput(String raw) {
    var result = raw;
    for (final stop in _stopSequences) {
      final idx = result.indexOf(stop);
      if (idx != -1) {
        result = result.substring(0, idx);
      }
    }
    return result.trim();
  }
}
