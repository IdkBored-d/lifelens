import 'package:flutter/foundation.dart' show debugPrint;

import '../app_services.dart';
import 'context_builder_service.dart';
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
    required LifeLensContext context,
    List<String>? chatHistory,
  }) async {
    final fullPrompt = _buildMiniMePrompt(
      userMessage: userMessage,
      context: context,
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
    required LifeLensContext context,
    List<String>? chatHistory,
  }) async* {
    final fullPrompt = _buildMiniMePrompt(
      userMessage: userMessage,
      context: context,
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
    required LifeLensContext context,
    List<String>? chatHistory,
  }) {
    return prompt.buildPrompt(
      contextEntries: toMiniGenEntries(context),
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

  /// Generate a JSON string of wellness suggestions via MiniGen.
  Future<String> generateMiniMeSuggestionsJson({
    required String summaryContext,
    required String latestMoodLabel,
    required int latestMoodIntensity,
    required List<String> recentMoods,
    required List<String> recentLogs,
    required List<String> activeSymptoms,
    String? latestLogFocus,
    String? latestLogKind,
    String? latestLogContext,
    String? contextPriority,
    String? variationCue,
    List<String> avoidedSuggestions = const <String>[],
    required int targetCount,
    String? suggestionWindow,
    String? triggerReason,
  }) async {
    final fullPrompt = _buildMiniMeSuggestionsPrompt(
      summaryContext: summaryContext,
      latestMoodLabel: latestMoodLabel,
      latestMoodIntensity: latestMoodIntensity,
      recentMoods: recentMoods,
      recentLogs: recentLogs,
      activeSymptoms: activeSymptoms,
      latestLogFocus: latestLogFocus,
      latestLogKind: latestLogKind,
      latestLogContext: latestLogContext,
      contextPriority: contextPriority,
      variationCue: variationCue,
      avoidedSuggestions: avoidedSuggestions,
      targetCount: targetCount,
      suggestionWindow: suggestionWindow,
      triggerReason: triggerReason,
    );

    CrisisRegexNet.guard(fullPrompt, context: 'suggestions prompt');

    final normalizedWindow = (suggestionWindow ?? '').trim().toLowerCase();
    final raw = await _service.generateFull(
      fullPrompt,
      maxTokens: 420,
      temperature: normalizedWindow == 'log_update' ? 0.35 : 0.2,
      topK: 40,
      repetitionPenalty: 1.08,
    );
    final cleaned = _cleanOutput(raw);

    CrisisRegexNet.guard(cleaned, context: 'suggestions output');

    return cleaned;
  }

  String _buildMiniMeSuggestionsPrompt({
    required String summaryContext,
    required String latestMoodLabel,
    required int latestMoodIntensity,
    required List<String> recentMoods,
    required List<String> recentLogs,
    required List<String> activeSymptoms,
    String? latestLogFocus,
    String? latestLogKind,
    String? latestLogContext,
    String? contextPriority,
    String? variationCue,
    List<String> avoidedSuggestions = const <String>[],
    required int targetCount,
    String? suggestionWindow,
    String? triggerReason,
  }) {
    final window = (suggestionWindow ?? '').trim().isEmpty
        ? 'general'
        : suggestionWindow!.trim();
    final trigger = (triggerReason ?? '').trim().isEmpty
        ? 'regular refresh'
        : triggerReason!.trim();
    final symptoms = activeSymptoms.isEmpty
        ? 'none reported currently'
        : _compactList(activeSymptoms, limit: 5, itemChars: 34, separator: ', ');
    final moods = recentMoods.isEmpty
        ? latestMoodLabel
        : _compactList(recentMoods, limit: 5, itemChars: 18, separator: ' | ');
    final timeline = recentLogs.isEmpty
        ? 'No recent log timeline provided.'
        : _compactList(recentLogs, limit: 10, itemChars: 150, separator: '\n');
    final latestFocus = (latestLogFocus ?? '').trim().isEmpty
        ? 'No single latest log focus.'
        : _compactText(latestLogFocus!.trim(), 240);
    final focusKind = (latestLogKind ?? '').trim().isEmpty
        ? 'unknown'
        : latestLogKind!.trim();
    final focusContext = (latestLogContext ?? '').trim().isEmpty
        ? 'No specific latest-log context.'
        : _compactText(latestLogContext!.trim(), 180);
    final priority = (contextPriority ?? '').trim().isEmpty
        ? 'Use the latest real health log as the main source of truth.'
        : _compactText(contextPriority!.trim(), 180);
    final variation = (variationCue ?? '').trim().isEmpty
        ? 'Pick a fresh angle instead of repeating the last suggestion.'
        : _compactText(variationCue!.trim(), 180);
    final avoidList = avoidedSuggestions.isEmpty
        ? 'No recent suggestions to avoid.'
        : _compactList(avoidedSuggestions, limit: 4, itemChars: 90, separator: '\n');
    final summary = _compactText(summaryContext, 1100);

    return prompt.buildPrompt(
      contextEntries: {
        'TASK': 'Mini-Me suggestion JSON generation',
        'LATEST_MOOD': '$latestMoodLabel ($latestMoodIntensity/5)',
        'RECENT_MOODS': moods,
        'ACTIVE_SYMPTOMS': symptoms,
        'WINDOW': window,
        'TRIGGER': trigger,
        'LATEST_LOG_KIND': focusKind,
        'LATEST_LOG_FOCUS': latestFocus,
        'LATEST_LOG_CONTEXT': focusContext,
        'CONTEXT_PRIORITY': priority,
        'VARIATION_CUE': variation,
        'RECENT_SUGGESTIONS_TO_AVOID': avoidList,
        'SUMMARY': summary,
        'TIMELINE': timeline,
      },
      userMessage:
          '''Return valid JSON only.
Create exactly $targetCount grounded wellness suggestion${targetCount == 1 ? '' : 's'}.
First suggestion must answer LATEST_LOG_FOCUS and respect CONTEXT_PRIORITY. Avoid RECENT_SUGGESTIONS_TO_AVOID.
Use real logged signals only. Choose a fresh angle: trigger, pacing, recovery, timing, environment, boundary, support, or follow-through.
Use LATEST_LOG_KIND and LATEST_LOG_CONTEXT to decide what kind of advice fits the log.
Use VARIATION_CUE to avoid repeating the same suggestion pattern across similar days.
If the latest log includes notes, tags, workout details, sleep notes, or symptom context, use that context but paraphrase it naturally. Do not quote or repeat the user's logged words verbatim.
Do not give category-only advice like "log mood", "sleep earlier", "rest more", or "take a walk" when a specific note/context is available.
If logs look similar to previous days, change the angle rather than the data: focus on trigger, friction, timing, environment, recovery cost, or what to protect next.
Action: one realistic step for today. Reason: cite the matching log signal. Do not diagnose. Keep fields short.
Use this exact shape:
{"suggestions":[{"action":"One specific next step.","reason":"Why this fits the user's logs."}]}''',
    );
  }

  String _compactList(
    List<String> items, {
    required int limit,
    required int itemChars,
    required String separator,
  }) {
    return items
        .map((item) => _compactText(item, itemChars))
        .where((item) => item.isNotEmpty)
        .take(limit)
        .join(separator);
  }

  String _compactText(String value, int maxChars) {
    final clean = prompt
        .sanitizeInput(value)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars).trimRight()}...';
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
