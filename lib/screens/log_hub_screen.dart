import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/screens/sleep_screen.dart';
import 'package:lifelens/screens/suggestions_screen.dart';
import 'package:lifelens/screens/symptoms_screen.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:provider/provider.dart';

class LogHubScreen extends StatefulWidget {
  const LogHubScreen({super.key, required this.userName});

  final String userName;

  @override
  State<LogHubScreen> createState() => _LogHubScreenState();
}

class _LogHubScreenState extends State<LogHubScreen> {
  int _dashboardRefreshTick = 0;

  Future<void> _openTracker(Widget screen) async {
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    await moodStore.refreshFromPersistence();
    await sleepStore.refresh();
    if (!mounted) return;
    setState(() => _dashboardRefreshTick += 1);
  }

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
                'Welcome back, ${widget.userName}',
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
              _TodayDashboard(
                key: ValueKey(_dashboardRefreshTick),
                refreshTick: _dashboardRefreshTick,
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
                    onTap: () => _openTracker(
                      const MoodLogScreen(source: LogSource.tab),
                    ),
                  ),
                  _TrackerRow(
                    icon: Icons.nightlight_round,
                    title: 'Sleep Tracking',
                    subtitle: 'Record sleep and review patterns',
                    onTap: () => _openTracker(const SleepScreen()),
                  ),
                  _TrackerRow(
                    icon: Icons.fitness_center_outlined,
                    title: 'Exercise Log',
                    subtitle: 'Open workouts and favorites',
                    onTap: () => _openTracker(const ExerciseScreen()),
                  ),
                  _TrackerRow(
                    icon: Icons.healing_outlined,
                    title: 'Symptom Log',
                    subtitle: 'Track symptom changes and summaries',
                    onTap: () => _openTracker(const SymptomsScreen()),
                  ),
                  _TrackerRow(
                    icon: Icons.tips_and_updates_outlined,
                    title: 'Suggestions',
                    subtitle: 'See guidance based on your real recent data',
                    onTap: () => _openTracker(const SuggestionsScreen()),
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

class _TodayDashboard extends StatefulWidget {
  const _TodayDashboard({super.key, required this.refreshTick});

  final int refreshTick;

  @override
  State<_TodayDashboard> createState() => _TodayDashboardState();
}

class _TodayDashboardState extends State<_TodayDashboard> {
  final ExerciseStore _exerciseStore = ExerciseStore();

  Future<int> _loadTodayExerciseCount() async {
    await _exerciseStore.ensureReady();
    final history = _exerciseStore.getRecentExerciseHistory(limit: 30);
    final today = DateTime.now();
    return history.where((item) {
      final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
      return timestamp != null && _isSameDay(timestamp, today);
    }).length;
  }

  String _buildNextStep({
    required MoodCheckIn? latestMood,
    required Sleep? latestSleep,
    required int todaySymptoms,
    required int todayExerciseCount,
  }) {
    final now = DateTime.now();
    final hasMoodToday =
        latestMood != null && _isSameDay(latestMood.createdAt, now);
    final hasSleepToday =
        latestSleep != null &&
        (_isSameDay(latestSleep.date, now) ||
            _isSameDay(latestSleep.wakeTime, now));

    if (!hasMoodToday) {
      return 'Next: log your mood so Mini-Me has a fresh signal today.';
    }
    if (!hasSleepToday) {
      return 'Next: add last night\'s sleep to make today\'s picture more complete.';
    }
    if (todaySymptoms > 0) {
      return 'Next: open symptoms if anything changed, then generate a summary if you need one.';
    }
    if (todayExerciseCount == 0) {
      return 'Next: add movement later if you want a fuller daily picture.';
    }
    return 'Today looks covered across your core trackers.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer2<MoodLogStore, SleepStore>(
      builder: (context, moodStore, sleepStore, _) {
        final now = DateTime.now();
        final latestMood = moodStore.items.isEmpty ? null : moodStore.items.first;
        final latestSleep = sleepStore.items.isEmpty ? null : sleepStore.items.first;

        return StreamBuilder<List<SymptomEntry>>(
          stream: AppServices.isar.watchRecentSymptomEntries(limit: 60),
          builder: (context, symptomSnapshot) {
            final symptomEntries = symptomSnapshot.data ?? const <SymptomEntry>[];
            final todaySymptoms = symptomEntries
                .where((entry) => _isSameDay(entry.timestamp, now))
                .length;
            final latestSymptom = symptomEntries.isEmpty
                ? null
                : symptomEntries.first;

            return FutureBuilder<int>(
              future: _loadTodayExerciseCount(),
              builder: (context, exerciseSnapshot) {
                final todayExerciseCount = exerciseSnapshot.data ?? 0;
                final nextStep = _buildNextStep(
                  latestMood: latestMood,
                  latestSleep: latestSleep,
                  todaySymptoms: todaySymptoms,
                  todayExerciseCount: todayExerciseCount,
                );

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Today',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatCompactDate(now),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.7,
                        children: [
                          _TodayMetricTile(
                            icon: Icons.emoji_emotions_outlined,
                            label: 'Mood',
                            value: latestMood != null &&
                                    _isSameDay(latestMood.createdAt, now)
                                ? latestMood.moodLabel
                                : 'Not logged',
                            detail: latestMood != null &&
                                    _isSameDay(latestMood.createdAt, now)
                                ? '${latestMood.intensity}/5'
                                : null,
                          ),
                          _TodayMetricTile(
                            icon: Icons.nightlight_round,
                            label: 'Sleep',
                            value: latestSleep != null &&
                                    (_isSameDay(latestSleep.date, now) ||
                                        _isSameDay(latestSleep.wakeTime, now))
                                ? latestSleep.durationFormatted
                                : 'Not logged',
                            detail: latestSleep != null &&
                                    (_isSameDay(latestSleep.date, now) ||
                                        _isSameDay(latestSleep.wakeTime, now))
                                ? latestSleep.quality.label
                                : null,
                          ),
                          _TodayMetricTile(
                            icon: Icons.healing_outlined,
                            label: 'Symptoms',
                            value: todaySymptoms == 0
                                ? 'None logged'
                                : '$todaySymptoms entr${todaySymptoms == 1 ? 'y' : 'ies'}',
                            detail: todaySymptoms > 0 && latestSymptom != null
                                ? _formatSymptomPreview(latestSymptom)
                                : null,
                          ),
                          _TodayMetricTile(
                            icon: Icons.fitness_center_outlined,
                            label: 'Exercise',
                            value: todayExerciseCount == 0
                                ? 'Not logged'
                                : '$todayExerciseCount session${todayExerciseCount == 1 ? '' : 's'}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          nextStep,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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

class _TodayMetricTile extends StatelessWidget {
  const _TodayMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail != null && detail!.trim().isNotEmpty)
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatCompactDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _formatSymptomPreview(SymptomEntry entry) {
  if (entry.symptomList.isEmpty) {
    return 'Latest symptom entry';
  }
  final symptoms = entry.symptomList.take(2).map(_titleCaseWords).join(', ');
  if (entry.symptomList.length <= 2) {
    return symptoms;
  }
  return '$symptoms +${entry.symptomList.length - 2}';
}

String _titleCaseWords(String text) {
  return text
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
