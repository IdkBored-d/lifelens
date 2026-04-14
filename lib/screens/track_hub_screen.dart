import 'package:flutter/material.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/models/quick_action.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/screens/sleep_screen.dart';
import 'package:lifelens/screens/suggestions_screen.dart';
import 'package:lifelens/screens/symptoms_screen.dart';
import 'package:lifelens/shared_widgets/section_title.dart';
import 'package:lifelens/widgets/quick_actions_grid.dart';
import 'package:provider/provider.dart';

class TrackHubScreen extends StatelessWidget {
  const TrackHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Text(
                'What do you want to log today?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Keep entries short. The app turns them into weekly patterns.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              QuickActionsGrid(
                actions: [
                  Quickaction(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Mood',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MoodLogScreen(
                            source: LogSource.tab,
                          ),
                        ),
                      );
                    },
                  ),
                  Quickaction(
                    icon: Icons.nightlight_round,
                    label: 'Sleep',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SleepScreen()),
                      );
                    },
                  ),
                  Quickaction(
                    icon: Icons.fitness_center_outlined,
                    label: 'Exercise',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExerciseScreen(),
                        ),
                      );
                    },
                  ),
                  Quickaction(
                    icon: Icons.healing_outlined,
                    label: 'Symptoms',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SymptomsScreen(),
                        ),
                      );
                    },
                  ),
                  Quickaction(
                    icon: Icons.tips_and_updates_outlined,
                    label: 'Suggestions',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SuggestionsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionTitle(title: 'Recent Mood Check-Ins'),
              const SizedBox(height: 10),
              Consumer<MoodLogStore>(
                builder: (context, store, _) {
                  if (store.items.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha:0.55),
                        ),
                      ),
                      child: Text(
                        'No check-ins yet. Start with a mood log above.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  final recent = store.items.take(3).toList();
                  return Column(
                    children: recent
                        .map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(alpha:0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  item.emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${item.moodLabel} • ${item.intensity}/5',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
