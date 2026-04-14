import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/services/minime_backend_service.dart';

/// Generates Mini-Me suggestions from persisted mood logs and chat history.
///
/// The primary path uses the backend LLM so each suggestion can be written
/// fresh from the user's actual context. A small local fallback remains so
/// the UI still has something helpful to show if the backend is unavailable.
class MiniMeSuggestionAggregator {
  static Future<List<DailySuggestion>> generateDailySuggestions({
    int days = 7,
  }) async {
    await IsarService.instance.init();

    final recentEntries = await IsarService.instance.getRecentMoodEntries(
      days: days,
    );

    // ── Quick-track plaintext summaries ──────────────────────────────────────
    final moodSummary = await AppServices.quickTrack.buildMoodContext();
    final symptomSummary = await AppServices.quickTrack.buildSymptomContext();
    final conversationSummary = await AppServices.quickTrack
        .buildConversationContext();
    final summaryContext = <String>[
      if (moodSummary.trim().isNotEmpty) 'Mood summary:\n$moodSummary',
      if (symptomSummary.trim().isNotEmpty) 'Symptom summary:\n$symptomSummary',
      if (conversationSummary.trim().isNotEmpty)
        'Conversation summary:\n$conversationSummary',
    ].join('\n\n');

    // ── Recent ISAR chat history (last session, up to 20 messages) ───────────
    final recentSessions = await IsarService.instance.getRecentChatSessions(
      limit: 1,
    );
    final List<MiniMeChatTurn> history;
    if (recentSessions.isNotEmpty) {
      final msgs = await IsarService.instance
          .getMessagesForSession(recentSessions.first.sessionId);
      final recent = msgs.length <= 20 ? msgs : msgs.sublist(msgs.length - 20);
      history = recent
          .map((m) => MiniMeChatTurn(role: m.role, text: m.text))
          .toList(growable: false);
    } else {
      history = const [];
    }
    final chatMessages = await _loadRecentChatMessages();
    final activeSymptoms = await IsarService.instance.getActiveSymptomEntries();
    final moodEntries = recentEntries
        .where((entry) => entry.resolvedBy != 'minime')
        .toList(growable: false);

    if (moodEntries.isEmpty && chatMessages.isEmpty && activeSymptoms.isEmpty) {
      return const [
        DailySuggestion(
          title: '',
          reason:
              'Once you log a mood or chat with Mini-Me, this space will adapt to you.',
          action:
              'Start with one quick check-in so Mini-Me has something real to learn from.',
        ),
      ];
    }

    final latestMoodEntry = moodEntries.isEmpty ? null : moodEntries.first;
    final latestMoodLabel = latestMoodEntry?.resolvedMood ?? '';
    final latestMoodIntensity = latestMoodEntry == null
        ? 3
        : _extractIntensity(latestMoodEntry);
    final latestMoodNotes = latestMoodEntry?.rawLog ?? '';
    final recentMoods = moodEntries
        .take(8)
        .map((entry) => '${entry.resolvedMood} (${_extractIntensity(entry)}/5)')
        .toList(growable: false);
    final recentLogs = moodEntries
        .take(10)
        .map((entry) => _trim(entry.rawLog, 220))
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final symptomLabels = _flattenSymptoms(activeSymptoms);
    final recentChatMessages = chatMessages.length <= 20
        ? chatMessages
        : chatMessages.sublist(chatMessages.length - 20);
    final backendHistory = recentChatMessages
        .map(
          (message) => MiniMeChatTurn(role: message.role, text: message.text),
        )
        .toList(growable: false);

    try {
      final reply = await MiniMeBackendService.instance.suggestions(
        latestMoodLabel: latestMoodLabel,
        latestMoodIntensity: latestMoodIntensity,
        latestMoodNotes: latestMoodNotes,
        recentMoods: recentMoods,
        recentLogs: recentLogs,
        activeSymptoms: symptomLabels,
        history: backendHistory.isNotEmpty ? backendHistory : history,
        summaryContext: summaryContext,
      );

      final suggestions = reply.suggestions
          .map(
            (item) => DailySuggestion(
              title: '',
              action: item.action,
              reason: item.reason,
            ),
          )
          .where((item) => item.action.trim().isNotEmpty)
          .take(3)
          .toList(growable: false);

      if (suggestions.isNotEmpty) {
        return suggestions;
      }
    } catch (_) {
      // Fall through to the local fallback below.
    }

    return _buildFallbackSuggestions(
      moodEntries: moodEntries,
      summaryContext: summaryContext,
      chatMessages: chatMessages
          .map((item) => item.text)
          .toList(growable: false),
    );
  }

  static List<DailySuggestion> _buildFallbackSuggestions({
    required List<MoodEntry> moodEntries,
    required String summaryContext,
    required List<String> chatMessages,
  }) {
    final latestMood = moodEntries.isEmpty
        ? 'your recent pattern'
        : moodEntries.first.resolvedMood.toLowerCase();
    final latestNote = moodEntries.isEmpty
        ? ''
        : moodEntries.first.rawLog.trim();
    final hasHighIntensity = moodEntries
        .take(4)
        .any((entry) => _extractIntensity(entry) >= 4);
    final symptomText = _extractSymptomText(summaryContext);
    final lastChat = chatMessages.isEmpty ? '' : chatMessages.last.trim();

    return [
      DailySuggestion(
        title: '',
        action: hasHighIntensity
            ? 'Keep today smaller than usual and protect one calm pocket of time.'
            : 'Build on what is already steady and repeat one small habit that helps.',
        reason: hasHighIntensity
            ? 'Your recent check-ins look emotionally heavy, so a gentler plan is more likely to stick.'
            : 'Your recent pattern looks stable enough to grow through consistency, not pressure.',
      ),
      DailySuggestion(
        title: '',
        action: symptomText.isEmpty
            ? 'When your mood shifts next, add one short note about what happened right before it.'
            : 'Work around $symptomText today by choosing the easiest version of your next task.',
        reason: symptomText.isEmpty
            ? 'That one detail gives Mini-Me a clearer signal than a mood label alone.'
            : 'Your suggestions get more useful when they respect what your body is already dealing with.',
      ),
      DailySuggestion(
        title: '',
        action: lastChat.isNotEmpty
            ? 'Come back to the idea you and Mini-Me touched on last and try it in the smallest possible way.'
            : _buildNoteBasedFallbackAction(latestMood, latestNote),
        reason: lastChat.isNotEmpty
            ? 'A small follow-through is usually more helpful than starting over with a brand-new plan.'
            : 'This keeps the guidance tied to your real pattern instead of generic advice.',
      ),
    ];
  }

  static String _buildNoteBasedFallbackAction(
    String latestMood,
    String latestNote,
  ) {
    final note = latestNote.toLowerCase();
    if (note.contains('sleep') || note.contains('tired')) {
      return 'Aim for a quieter evening tonight and make your wind-down easier to start.';
    }
    if (note.contains('work') || note.contains('school')) {
      return 'Give yourself a reset between work blocks so the day does not keep stacking up on you.';
    }
    if (note.contains('anxious') ||
        note.contains('stress') ||
        note.contains('overwhelmed')) {
      return 'Pick one grounding step you can do in under two minutes before the next wave builds.';
    }
    return 'Check in with what usually helps when you feel $latestMood, and choose the easiest version of that today.';
  }

  static String _extractSymptomText(String summaryContext) {
    if (summaryContext.trim().isEmpty) {
      return '';
    }

    for (final line in summaryContext.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('symptom summary:')) {
        return trimmed.substring('Symptom summary:'.length).trim();
      }
    }

    return summaryContext.trim();
  }

  static int _extractIntensity(MoodEntry entry) {
    final match = RegExp(r'([1-5])\/5').firstMatch(entry.condensedLog);
    if (match == null) return 3;
    return int.tryParse(match.group(1) ?? '') ?? 3;
  }

  static String _trim(String value, int maxLength) {
    final text = value.trim();
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - 3).trimRight()}...';
  }

  static List<String> _flattenSymptoms(List<dynamic> activeSymptoms) {
    final values = <String>{};
    for (final entry in activeSymptoms) {
      final dynamic symptomList = (entry as dynamic).symptomList;
      if (symptomList is Iterable) {
        for (final symptom in symptomList) {
          final text = symptom.toString().trim();
          if (text.isNotEmpty) {
            values.add(text);
          }
        }
      }
    }
    return values.toList(growable: false);
  }

  static Future<List<_ChatMessageView>> _loadRecentChatMessages() async {
    final sessions = await IsarService.instance.getRecentChatSessions(limit: 8);
    if (sessions.isEmpty) return const [];

    final collected = <_ChatMessageView>[];
    for (final session in sessions.reversed) {
      final messages = await IsarService.instance.getMessagesForSession(
        session.sessionId,
      );
      collected.addAll(
        messages.map(
          (message) => _ChatMessageView(role: message.role, text: message.text),
        ),
      );
    }
    return collected;
  }
}

class _ChatMessageView {
  const _ChatMessageView({required this.role, required this.text});

  final String role;
  final String text;
}
