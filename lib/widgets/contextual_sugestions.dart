import 'package:flutter/material.dart';
import 'package:lifelens/models/suggestion.dart';
import 'package:lifelens/shared_widgets/suggestion_tile.dart';

class ContextualSuggestions extends StatelessWidget {
  const ContextualSuggestions({required this.moodLabel});
  final String moodLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final suggestions = _suggestionsForMood(moodLabel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Suggested for you",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SuggestionTile(
                icon: s.icon,
                text: s.text,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${s.text} (UI Only)"),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(milliseconds: 900),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Suggestion> _suggestionsForMood(String mood) {
    final m = mood.toLowerCase();

    if (m.contains("calm")) {
      return const [
        Suggestion(
          icon: Icons.self_improvement_rounded,
          text: "Maintain your calm with a 2-minute breathing exercise",
        ),

        Suggestion(
          icon: Icons.bookmark_border_rounded,
          text: "Reflect briefly on what's helping you feel balanced",
        ),
      ];
    }

    if (m.contains("anxious") || m.contains("stress")) {
      return const [
        Suggestion(
          icon: Icons.air_rounded,
          text: "Try a short grounding breathing exercise",
        ),
      ];
    }

    if (m.contains("sad")) {
      return const [
        Suggestion(
          icon: Icons.favorite_border_rounded,
          text: "Be a little kinder to yourself - take it one day at a time",
        ),
      ];
    }

    if (m.contains("happy")) {
      return const [
        Suggestion(
          icon: Icons.thumbs_up_down,
          text: "Glad to know your feeling well today!",
        ),
      ];
    }
    return const [
      Suggestion(
        icon: Icons.track_changes_rounded,
        text: "Check in later for any changes",
      ),
      Suggestion(
        icon: Icons.insights_outlined,
        text: "Make sure you log everyday to understand your patterns",
      ),
    ];
  }
}