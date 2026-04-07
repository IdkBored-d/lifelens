import 'package:flutter/material.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/screens/sleep_screen.dart';
import 'package:lifelens/screens/symptoms_screen.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/services/mini_me_suggestion_aggregator.dart';
import 'package:provider/provider.dart';

class LogHubScreen extends StatelessWidget {
  const LogHubScreen({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Log Center'), centerTitle: false),
      body: SafeArea(
        child: Consumer<MoodLogStore>(
          builder: (context, store, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
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
                    'Track what matters in one place with simple logs and Mini-Me suggestions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeader(title: 'Trackers'),
                  const SizedBox(height: 12),
                  _TrackerListCard(
                    children: [
                      _TrackerRow(
                        icon: Icons.emoji_emotions_outlined,
                        title: 'Mood Log',
                        subtitle: 'Capture mood, intensity, and context',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const MoodLogScreen(source: LogSource.tab),
                            ),
                          );
                        },
                      ),
                      _TrackerRow(
                        icon: Icons.nightlight_round,
                        title: 'Sleep Tracking',
                        subtitle: 'Record sleep and review patterns',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SleepScreen(),
                            ),
                          );
                        },
                      ),
                      _TrackerRow(
                        icon: Icons.fitness_center_outlined,
                        title: 'Exercise Log',
                        subtitle: 'Open workouts and favorites',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExerciseScreen(),
                            ),
                          );
                        },
                      ),
                      _TrackerRow(
                        icon: Icons.healing_outlined,
                        title: 'Symptom Log',
                        subtitle: 'Track symptom changes and summaries',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SymptomsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeader(title: 'Daily Suggestions'),
                  const SizedBox(height: 12),
                  _MiniMeSuggestionPanel(moodLogs: store.items),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _TrackerListCard extends StatelessWidget {
  const _TrackerListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(children: children),
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: cs.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
    );
  }
}

class _MiniMeSuggestionPanel extends StatefulWidget {
  const _MiniMeSuggestionPanel({required this.moodLogs});

  final List<MoodCheckIn> moodLogs;

  @override
  State<_MiniMeSuggestionPanel> createState() => _MiniMeSuggestionPanelState();
}

class _MiniMeSuggestionPanelState extends State<_MiniMeSuggestionPanel> {
  late Future<List<DailySuggestion>> _future;
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _signature = _buildSignature(widget.moodLogs);
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _MiniMeSuggestionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _buildSignature(widget.moodLogs);
    if (nextSignature != _signature) {
      _signature = nextSignature;
      _future = _load();
    }
  }

  Future<List<DailySuggestion>> _load() {
    return MiniMeSuggestionAggregator.generateDailySuggestions(days: 7);
  }

  String _buildSignature(List<MoodCheckIn> logs) {
    final latest = logs.isEmpty ? '' : logs.first.createdAt.toIso8601String();
    return '${logs.length}|$latest';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: FutureBuilder<List<DailySuggestion>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingSuggestionPanel();
          }

          if (snapshot.hasError) {
            return const _EmptyStateCard(
              title: 'Suggestions unavailable',
              subtitle:
                  'Could not generate suggestions right now. Try again after your next log.',
            );
          }

          final suggestions = snapshot.data ?? const <DailySuggestion>[];
          if (suggestions.isEmpty) {
            return const _EmptyStateCard(
              title: 'No suggestions yet',
              subtitle:
                  'Log one update to generate a cleaner daily guidance feed from Mini-Me.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...suggestions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SimpleSuggestionCard(item: item),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SimpleSuggestionCard extends StatelessWidget {
  const _SimpleSuggestionCard({required this.item});

  final DailySuggestion item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.action,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSuggestionPanel extends StatelessWidget {
  const _LoadingSuggestionPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Mini-Me is shaping your daily suggestions...')),
        ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
