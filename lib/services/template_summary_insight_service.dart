/// Generates template-based summary insights for quick-track files.
///
/// Replaces Gemma's `generateSummaryInsight()` with deterministic,
/// rule-based interpretive sentences derived from the structured template data.
///
/// Each pipeline's summary file consists of:
///   1. A structured template block (deterministic, built by QuickTrackService)
///   2. An insight block (2-3 interpretive sentences — previously Gemma, now this service)
class TemplateSummaryInsightService {
  const TemplateSummaryInsightService();

  /// Generate a mood insight from the structured mood template.
  ///
  /// Parses the template for mood streaks, transitions, and fitness trends,
  /// then selects appropriate interpretive sentences.
  String generateMoodInsight(String template) {
    if (template.isEmpty || template.startsWith('No mood history')) {
      return 'Start logging your mood to see patterns and insights here.';
    }

    final parts = <String>[];

    // Parse current mood and streak length
    final moodMatch = RegExp(r'Mood:\s*(\w+)\s*\((\d+)\s*days?\)').firstMatch(template);
    if (moodMatch != null) {
      final mood = moodMatch.group(1)!.toLowerCase();
      final days = int.parse(moodMatch.group(2)!);

      if (days >= 5) {
        if (_isPositiveMood(mood)) {
          parts.add("You've been in a steady $mood streak for $days days — that's a great sign of emotional stability.");
        } else {
          parts.add("Your mood has been $mood for $days days now. It might help to try something different today, even something small.");
        }
      } else if (days >= 2) {
        if (_isPositiveMood(mood)) {
          parts.add('Your $mood mood has been consistent lately — keep doing what works for you.');
        } else {
          parts.add("You've been feeling $mood for a couple of days. Be gentle with yourself and consider what might help shift things.");
        }
      } else {
        parts.add('Your current mood is $mood.');
      }
    }

    // Parse mood transitions (Previously: ...)
    if (template.contains('Previously:')) {
      final prevMatch = RegExp(r'Previously:\s*(\w+)').firstMatch(template);
      if (prevMatch != null && moodMatch != null) {
        final prevMood = prevMatch.group(1)!.toLowerCase();
        final currentMood = moodMatch.group(1)!.toLowerCase();
        if (_isPositiveMood(currentMood) && !_isPositiveMood(prevMood)) {
          parts.add('Nice to see your mood improving from $prevMood — whatever you changed seems to be helping.');
        } else if (!_isPositiveMood(currentMood) && _isPositiveMood(prevMood)) {
          parts.add("Your mood shifted from $prevMood recently. That's okay — moods naturally fluctuate.");
        }
      }
    }

    // Parse fitness trend
    final fitnessMatch = RegExp(r'Fitness:\s*(up|down|stable)\s*(\d+)?\s*pts?').firstMatch(template);
    if (fitnessMatch != null) {
      final direction = fitnessMatch.group(1)!;
      if (direction == 'up') {
        parts.add('Your fitness trend is heading upward, which often supports better mood over time.');
      } else if (direction == 'down') {
        parts.add('Your fitness has dipped a bit — even a short walk today could help both body and mind.');
      }
    }

    if (parts.isEmpty) {
      parts.add('Keep logging to build a clearer picture of your mood patterns.');
    }

    return parts.take(3).join(' ');
  }

  /// Generate a symptom insight from the structured symptom template.
  String generateSymptomInsight(String template) {
    if (template.isEmpty || template.contains('None active')) {
      return 'No active symptoms to track right now. Keep monitoring and log anything new.';
    }

    final parts = <String>[];

    // Count active symptoms
    final symptomMatches = RegExp(r'(\w[\w\s]*?)\s*\((active|monitoring),\s*(\d+)\s*days?\)');
    final matches = symptomMatches.allMatches(template).toList();

    if (matches.isEmpty) {
      return 'Keep tracking your symptoms so we can identify patterns over time.';
    }

    // Check for persistent symptoms (3+ days)
    final persistent = matches.where((m) => int.parse(m.group(3)!) >= 3).toList();
    final recent = matches.where((m) => int.parse(m.group(3)!) < 3).toList();

    if (persistent.isNotEmpty) {
      final names = persistent.map((m) => m.group(1)!.trim().toLowerCase()).join(' and ');
      parts.add('Your $names ${persistent.length == 1 ? 'has' : 'have'} been active for several days. '
          'If symptoms persist, consider consulting a healthcare professional.');
    }

    if (recent.isNotEmpty && persistent.isNotEmpty) {
      parts.add('You also have newer symptoms to keep an eye on.');
    } else if (recent.isNotEmpty && persistent.isEmpty) {
      parts.add('Your symptoms are relatively new. Monitor them over the next few days and note any changes.');
    }

    if (matches.length >= 3) {
      parts.add('Multiple active symptoms may be related — mention all of them if you visit a healthcare provider.');
    }

    if (parts.isEmpty) {
      parts.add('Keep tracking your symptoms so we can spot patterns early.');
    }

    return parts.take(3).join(' ');
  }

  /// Generate a conversation insight from the structured conversation template.
  String generateConversationInsight(String template) {
    if (template.isEmpty || template.contains('None.')) {
      return "You haven't chatted with Mini-Me recently. Check in when you're ready — even a quick hello helps build your wellness picture.";
    }

    final sessionMatch = RegExp(r'(\d+)\s*sessions?').firstMatch(template);
    final messageMatch = RegExp(r'(\d+)\s*messages?').firstMatch(template);

    final sessions = sessionMatch != null ? int.parse(sessionMatch.group(1)!) : 0;
    final messages = messageMatch != null ? int.parse(messageMatch.group(1)!) : 0;

    if (sessions >= 5) {
      return "You've been checking in regularly — $sessions sessions this week shows great consistency. "
          'Regular check-ins help us give you better, more personalized support.';
    } else if (sessions >= 2) {
      return "You've had $sessions sessions recently with $messages messages. "
          'Consistent check-ins help build a clearer picture of your wellbeing.';
    } else if (sessions == 1) {
      if (messages >= 5) {
        return 'Your last session was a good deep conversation. '
            'Try checking in more often — even brief sessions help track your progress.';
      }
      return 'You had one session recently. Try to check in a few times a week for better insights.';
    }

    return 'Keep chatting with Mini-Me to build up your wellness picture over time.';
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  bool _isPositiveMood(String mood) {
    const positive = {'joy', 'love', 'content', 'surprise'};
    return positive.contains(mood.toLowerCase());
  }
}
