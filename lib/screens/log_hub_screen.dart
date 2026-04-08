import 'package:flutter/material.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/screens/sleep_screen.dart';
import 'package:lifelens/screens/symptoms_screen.dart';

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
        child: SingleChildScrollView(
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
                'Track your signals here. Get guidance in Mini-Me chat.',
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
                        MaterialPageRoute(builder: (_) => const SleepScreen()),
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
                        MaterialPageRoute(builder: (_) => const SymptomsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
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
