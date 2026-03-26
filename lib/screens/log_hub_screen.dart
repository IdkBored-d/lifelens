import 'package:flutter/material.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/screens/sleep_screen.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/screens/symptoms_screen.dart';
import 'package:provider/provider.dart';

class LogHubScreen extends StatelessWidget {
  const LogHubScreen({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Center'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $userName',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Track what matters in one place with structured logs.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              _SectionLabel(title: 'Trackers'),
              const SizedBox(height: 10),
              _LogTile(
                icon: Icons.emoji_emotions_outlined,
                title: 'Mood Log',
                subtitle: 'Capture mood, intensity, and context',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MoodLogScreen(source: LogSource.tab),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _LogTile(
                icon: Icons.nightlight_round,
                title: 'Sleep Tracking',
                subtitle: 'Record sleep and view your sleep insights',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SleepScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _LogTile(
                icon: Icons.fitness_center_outlined,
                title: 'Exercise Log',
                subtitle: 'Plan workouts and manage exercise favorites',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExerciseScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _LogTile(
                icon: Icons.healing_outlined,
                title: 'Symptom Log',
                subtitle: 'Track symptom patterns and summaries',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SymptomsScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),

              _SectionLabel(title: 'Daily Suggestions'),
              const SizedBox(height: 10),
              Consumer<MoodLogStore>(
                builder: (context, store, _) {
                  return FutureBuilder<List<DailySuggestion>>(
                    future: DailySuggestionsService.instance.getDailySuggestions(
                      moodLogs: store.items,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _LoadingSuggestionCard();
                      }

                      if (snapshot.hasError) {
                        return _EmptyStateCard(
                          title: 'Suggestions unavailable',
                          subtitle:
                              'Could not generate suggestions right now. Try again after your next log.',
                        );
                      }

                      final suggestions = snapshot.data ?? const <DailySuggestion>[];
                      if (suggestions.isEmpty) {
                        return _EmptyStateCard(
                          title: 'No suggestions yet',
                          subtitle: 'Log one update to generate your daily guidance.',
                        );
                      }

                      return Column(
                        children: suggestions.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SuggestionCard(item: item),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 10),

              _SectionLabel(title: 'Recent Mood Entries'),
              const SizedBox(height: 10),
              Consumer<MoodLogStore>(
                builder: (context, store, _) {
                  if (store.items.isEmpty) {
                    return _EmptyStateCard(
                      title: 'No logs yet',
                      subtitle: 'Start with a mood entry to build your timeline.',
                    );
                  }

                  final recent = store.items.take(5).toList();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: recent.map((entry) {
                          final tags = entry.tags.isEmpty
                              ? 'No tags'
                              : entry.tags.take(2).join(' • ');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(
                                  entry.emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.moodLabel,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Intensity ${entry.intensity}/5 • $tags',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.onPrimaryContainer),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.item});

  final DailySuggestion item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.action,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSuggestionCard extends StatelessWidget {
  const _LoadingSuggestionCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text('Building your daily suggestions...'),
          ),
        ],
      ),
    );
  }
}