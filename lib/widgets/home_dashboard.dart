import 'package:flutter/material.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/models/mood.dart';
import 'package:lifelens/models/quick_action.dart';
import 'package:lifelens/models/summary_item.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/shared_widgets/section_title.dart';
import 'package:lifelens/widgets/contextual_sugestions.dart';
import 'package:lifelens/widgets/continue_card.dart';
import 'package:lifelens/widgets/greeting_header.dart';
import 'package:lifelens/widgets/insight_card.dart';
import 'package:lifelens/widgets/mini_me_hero_card.dart';
import 'package:lifelens/widgets/mood_row.dart';
import 'package:lifelens/widgets/quick_actions_grid.dart';
import 'package:lifelens/widgets/summary_strip.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    required this.selectedMood,
    required this.onMoodSelected,
    required this.onOpenMiniMe,
    required this.userName,
  });

  final int selectedMood;
  final ValueChanged<int> onMoodSelected;
  final VoidCallback onOpenMiniMe;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GreetingHeader(
            name: "Matthew", // UI-only: replace with user profile later
            subtitle: "How are you feeling today?",
          ),
          const SizedBox(height: 14),

          InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: onOpenMiniMe,
            child: MiniMeHeroCard(
              title: "Mini-Me",
              moodLabel: selectedMood == -1
                  ? "Tap an emotion to check-in"
                  : moods[selectedMood].label,
              statusLine: selectedMood == -1 ? "Energy: —" : "Energy: Balanced",
            ),
          ),
          const SizedBox(height: 14),

          // Emotion check-in
          SectionTitle(title: "Emotion check-in", trailing: "Today"),
          const SizedBox(height: 10),
          MoodRow(selected: selectedMood, onSelect: onMoodSelected),
          const SizedBox(height: 18),

          // Quick actions
          SectionTitle(title: "Quick actions"),
          const SizedBox(height: 10),
          QuickActionsGrid(
            actions: [
              Quickaction(
               icon: Icons.emoji_emotions_outlined,
                label: "Mood Log",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MoodLogScreen()),
                  );
                },
              ),
              Quickaction(
                icon: Icons.nightlight_round,
                label: "Sleep",
                onTap: () => _toast(context, "Sleep (UI only)"),
              ),
              Quickaction(
                icon: Icons.fitness_center_outlined,
                label: "Exercise",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExerciseScreen()),
                  );
                }
              ),
              Quickaction(
                icon: Icons.healing_outlined,
                label: "Symptoms",
                onTap: () => _toast(context, "Symptoms (UI only)"),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Insights preview
          SectionTitle(title: "Today’s insight", trailing: "Preview"),
          const SizedBox(height: 10),
          InsightCard(
            title: "You’re building consistency 🌿",
            body:
                "On days you sleep 7+ hours, your mood trends more positive. Try a 10-minute wind-down tonight.",
          ),

          const SizedBox(height: 16),

          ContextualSuggestions(
            moodLabel: selectedMood == -1
                ? "Neutral"
                : moods[selectedMood].label,
          ),
          const SizedBox(height: 16),

          // Optional: streak / summary strip
          SummaryStrip(
            items: const [
              Summaryitem(
                title: "Check-ins",
                value: "3",
                icon: Icons.favorite_rounded,
              ),
              Summaryitem(
                title: "Sleep",
                value: "6h 40m",
                icon: Icons.nightlight_round,
              ),
              Summaryitem(
                title: "Steps",
                value: "4,821",
                icon: Icons.directions_walk_rounded,
              ),
            ],
          ),

          const SizedBox(height: 8),
          Divider(color: cs.outlineVariant.withOpacity(0.7)),
          const SizedBox(height: 10),

          // Small “continue” card
          ContinueCard(
            title: "Continue where you left off",
            subtitle: "Review your week’s mood trend",
            onTap: () => _toast(context, "Trends (UI only)"),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }
}