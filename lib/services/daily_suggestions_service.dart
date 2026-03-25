import 'package:lifelens/moodlog_store.dart';

class DailySuggestion {
  const DailySuggestion({
    required this.title,
    required this.reason,
    required this.action,
  });

  final String title;
  final String reason;
  final String action;
}

class DailySuggestionsRequest {
  const DailySuggestionsRequest({
    required this.moodLogs,
    required this.generatedAt,
  });

  final List<MoodCheckIn> moodLogs;
  final DateTime generatedAt;
}

abstract class DailySuggestionsModelClient {
  Future<List<DailySuggestion>> generate(DailySuggestionsRequest request);
}

class DailySuggestionsService {
  DailySuggestionsService({DailySuggestionsModelClient? modelClient})
    : _modelClient = modelClient ?? LocalHeuristicSuggestionsClient();

  final DailySuggestionsModelClient _modelClient;

  static final DailySuggestionsService instance = DailySuggestionsService();

  Future<List<DailySuggestion>> getDailySuggestions({
    required List<MoodCheckIn> moodLogs,
  }) {
    final request = DailySuggestionsRequest(
      moodLogs: moodLogs,
      generatedAt: DateTime.now(),
    );

    return _modelClient.generate(request);
  }
}

class LocalHeuristicSuggestionsClient implements DailySuggestionsModelClient {
  @override
  Future<List<DailySuggestion>> generate(DailySuggestionsRequest request) async {
    final logs = request.moodLogs;

    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (logs.isEmpty) {
      return const [
        DailySuggestion(
          title: 'Start with one mood check-in',
          reason: 'There is not enough log data yet to personalize suggestions.',
          action: 'Log your current mood and one short note to unlock smarter daily guidance.',
        ),
      ];
    }

    final latest = logs.first;
    final averageIntensity = logs
            .take(7)
            .map((item) => item.intensity)
            .fold<int>(0, (sum, value) => sum + value) /
        logs.take(7).length;

    final tags = logs.take(7).expand((item) => item.tags).toList();
    final hasSleepTag = tags.map((t) => t.toLowerCase()).contains('sleep');
    final hasWorkTag = tags.map((t) => t.toLowerCase()).contains('work');

    final suggestions = <DailySuggestion>[
      DailySuggestion(
        title: 'Anchor your day with one guided check-in',
        reason: 'Your latest mood is ${latest.moodLabel} at intensity ${latest.intensity}/5.',
        action: 'Set one reminder for midday and log mood + one trigger to improve pattern detection.',
      ),
    ];

    if (averageIntensity >= 4) {
      suggestions.add(
        const DailySuggestion(
          title: 'Lower intensity with a short reset block',
          reason: 'Your recent logs show elevated emotional intensity.',
          action: 'Do a 3-minute breath or stretch reset before your next major task.',
        ),
      );
    } else {
      suggestions.add(
        const DailySuggestion(
          title: 'Keep momentum with a consistency habit',
          reason: 'Your recent intensity trend looks stable enough to build routine.',
          action: 'Repeat yesterday\'s best small habit at the same time today.',
        ),
      );
    }

    if (hasSleepTag) {
      suggestions.add(
        const DailySuggestion(
          title: 'Protect tonight\'s sleep window',
          reason: 'Sleep appears frequently in your recent check-in context.',
          action: 'Plan a fixed wind-down start time and avoid screens in the last 20 minutes.',
        ),
      );
    } else if (hasWorkTag) {
      suggestions.add(
        const DailySuggestion(
          title: 'Add a transition between work blocks',
          reason: 'Work context appears in your recent logs.',
          action: 'Take a 2-minute decompression break after each focused session.',
        ),
      );
    } else {
      suggestions.add(
        const DailySuggestion(
          title: 'Improve signal quality in your logs',
          reason: 'More context tags will improve recommendation quality.',
          action: 'Add at least one context tag to each check-in this week.',
        ),
      );
    }

    return suggestions;
  }
}
