import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/database/symptom_entry.dart';
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
    final history = recentChatMessages
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
        history: history,
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
      activeSymptoms: symptomLabels,
      chatMessages: chatMessages
          .map((item) => item.text)
          .toList(growable: false),
    );
  }

  static List<DailySuggestion> _buildFallbackSuggestions({
    required List<MoodEntry> moodEntries,
    required List<String> activeSymptoms,
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
    final symptomText = activeSymptoms.take(2).join(', ');
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

  static List<String> _flattenSymptoms(List<SymptomEntry> entries) {
    final seen = <String>{};
    final flattened = <String>[];
    for (final entry in entries) {
      for (final symptom in entry.symptomList) {
        final trimmed = symptom.trim();
        final key = trimmed.toLowerCase();
        if (trimmed.isNotEmpty && seen.add(key)) {
          flattened.add(trimmed);
        }
      }
    }
    return flattened.take(12).toList(growable: false);
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
