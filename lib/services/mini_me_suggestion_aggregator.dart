import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/database/mood_entry.dart';

/// Aggregates recent Mini-Me suggestions and synthesizes new daily suggestions.
class MiniMeSuggestionAggregator {
  /// Returns synthesized daily suggestions based on recent Mini-Me responses.
  static Future<List<DailySuggestion>> generateDailySuggestions({int days = 7}) async {
    final recentEntries = await IsarService.instance.getRecentMoodEntries(days: days);
    if (recentEntries.isEmpty) {
      return const [
        DailySuggestion(
          title: 'Start with one mood check-in',
          reason: 'There is not enough log data yet to personalize suggestions.',
          action: 'Log your current mood and one short note to unlock smarter daily guidance.',
        ),
      ];
    }

    // Collect all Mini-Me suggestions (responseText) from recent entries
    final suggestions = recentEntries
        .map((e) => e.responseText.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Analyze for repeated advice, trends, or missed actions
    final Map<String, int> freq = {};
    for (final s in suggestions) {
      freq[s] = (freq[s] ?? 0) + 1;
    }
    final mostCommon = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Synthesize new suggestions
    final List<DailySuggestion> daily = [];
    if (mostCommon.isNotEmpty) {
      daily.add(DailySuggestion(
        title: 'Act on repeated advice',
        reason: 'Mini-Me has suggested this multiple times recently.',
        action: mostCommon.first.key,
      ));
    }
    if (suggestions.length > 1) {
      daily.add(DailySuggestion(
        title: 'Try something new',
        reason: 'You have received a variety of suggestions. Consider acting on one you haven\'t tried yet.',
        action: suggestions.last,
      ));
    }
    if (daily.isEmpty) {
      daily.add(DailySuggestion(
        title: 'Reflect on your progress',
        reason: 'Mini-Me\'s advice is evolving. Review your logs and see what\'s working.',
        action: 'Pick one suggestion from your recent chat history to focus on today.',
      ));
    }
    return daily;
  }
}
