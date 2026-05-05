import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/exercises/exercise_screen.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/screens/history_calendar_screen.dart';
import 'package:lifelens/screens/sleep_screen.dart';
import 'package:lifelens/screens/symptoms_screen.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogHubScreen extends StatefulWidget {
  const LogHubScreen({super.key, required this.userName, this.onOpenMiniMe});

  final String userName;
  final VoidCallback? onOpenMiniMe;

  @override
  State<LogHubScreen> createState() => _LogHubScreenState();
}

class _LogHubScreenState extends State<LogHubScreen> {
  int _dashboardRefreshTick = 0;
  DateTime _selectedHistoryDate = DateTime.now();
  final ExerciseStore _exerciseStore = ExerciseStore();
  bool _isTrackersExpanded = false;
  Future<bool>? _hasAnyExerciseLogsTodayFuture;
  Future<bool>? _isReturningUserFuture;
  String? _asyncStateSignature;

  @override
  void initState() {
    super.initState();
    _isReturningUserFuture = _checkAndMarkReturningUser();
    _refreshAsyncState(
      moodSelection: const _MoodLogSnapshot.empty(),
      sleepSelection: const _SleepLogSnapshot.empty(),
    );
  }

  void _refreshAsyncState({
    required _MoodLogSnapshot moodSelection,
    required _SleepLogSnapshot sleepSelection,
  }) {
    _hasAnyExerciseLogsTodayFuture = _hasAnyExerciseLogsToday();
  }

  void _ensureAsyncState({
    required _MoodLogSnapshot moodSelection,
    required _SleepLogSnapshot sleepSelection,
  }) {
    final nextSignature =
        '${moodSelection.signature}::${sleepSelection.signature}';
    if (_asyncStateSignature == nextSignature &&
        _hasAnyExerciseLogsTodayFuture != null) {
      return;
    }
    _asyncStateSignature = nextSignature;
    _refreshAsyncState(
      moodSelection: moodSelection,
      sleepSelection: sleepSelection,
    );
  }

  Future<void> _openTracker(Widget screen) async {
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await moodStore.refreshFromPersistence();
    await sleepStore.refresh();
    if (!mounted) return;
    setState(() {
      _dashboardRefreshTick += 1;
      _refreshAsyncState(
        moodSelection: _MoodLogSnapshot.fromItems(moodStore.items),
        sleepSelection: _SleepLogSnapshot.fromItems(sleepStore.items),
      );
    });
  }

  Future<void> _openSelectedDayLogs(DateTime date) async {
    setState(() {
      _selectedHistoryDate = date;
    });
    await _openTracker(
      HistoryCalendarScreen(initialDate: date, showCalendar: false),
    );
    if (!mounted) return;
    setState(() {
      _selectedHistoryDate = DateTime.now();
    });
  }

  /// Returns true if the user has opened Log Hub before (returning user).
  /// On first call per account it stores the flag so subsequent opens return true.
  Future<bool> _checkAndMarkReturningUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true; // fallback: treat as returning
    final key = 'log_hub_seen_$uid';
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(key) ?? false;
    if (!alreadySeen) {
      await prefs.setBool(key, true);
    }
    return alreadySeen;
  }

  Future<bool> _hasAnyExerciseLogsToday() async {
    await _exerciseStore.ensureReady();
    final today = DateTime.now();
    return _exerciseStore.getRecentExerciseHistory(limit: 30).any((item) {
      final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
      return timestamp != null && _isSameDay(timestamp, today);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userName = widget.userName.trim().isEmpty
        ? 'Friend'
        : widget.userName.trim();
    final moodSelection = context.select<MoodLogStore, _MoodLogSnapshot>(
      (moodStore) => _MoodLogSnapshot.fromItems(moodStore.items),
    );
    final sleepSelection = context.select<SleepStore, _SleepLogSnapshot>(
      (sleepStore) => _SleepLogSnapshot.fromItems(sleepStore.items),
    );
    _ensureAsyncState(
      moodSelection: moodSelection,
      sleepSelection: sleepSelection,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Log Center'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<bool>(
                future: _isReturningUserFuture,
                builder: (context, snapshot) {
                  final isReturning = snapshot.data ?? true;
                  final greeting = isReturning
                      ? 'Welcome back, $userName'
                      : 'Welcome to LifeLens, $userName';
                  return Text(
                    greeting,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Track your signals here. Get guidance in Mini-Me chat.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'Calendar'),
              const SizedBox(height: 12),
              HistoryCalendarView(
                showIntro: false,
                embedded: true,
                showDetails: false,
                initialDate: _selectedHistoryDate,
                onDateSelected: _openSelectedDayLogs,
              ),
              const SizedBox(height: 18),
              _TrackersDropdownCard(
                isExpanded: _isTrackersExpanded,
                onToggle: () {
                  setState(() => _isTrackersExpanded = !_isTrackersExpanded);
                },
                children: [
                  _TrackerShortcutTile(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Mood Log',
                    onTap: () => _openTracker(
                      const MoodLogScreen(source: LogSource.tab),
                    ),
                  ),
                  _TrackerShortcutTile(
                    icon: Icons.nightlight_round,
                    label: 'Sleep Log',
                    onTap: () => _openTracker(const SleepScreen()),
                  ),
                  _TrackerShortcutTile(
                    icon: Icons.fitness_center_outlined,
                    label: 'Exercise Log',
                    onTap: () => _openTracker(const ExerciseScreen()),
                  ),
                  _TrackerShortcutTile(
                    icon: Icons.healing_outlined,
                    label: 'Symptom Log',
                    onTap: () => _openTracker(const SymptomsScreen()),
                  ),
                ],
              ),
              _DashboardVisibilityGate(
                refreshKey: ValueKey(_dashboardRefreshTick),
                moodSelection: moodSelection,
                sleepSelection: sleepSelection,
                hasAnyExerciseLogsTodayFuture:
                    _hasAnyExerciseLogsTodayFuture ?? Future.value(false),
                refreshTick: _dashboardRefreshTick,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardVisibilityGate extends StatelessWidget {
  const _DashboardVisibilityGate({
    required this.refreshKey,
    required this.moodSelection,
    required this.sleepSelection,
    required this.hasAnyExerciseLogsTodayFuture,
    required this.refreshTick,
  });

  final Key refreshKey;
  final _MoodLogSnapshot moodSelection;
  final _SleepLogSnapshot sleepSelection;
  final Future<bool> hasAnyExerciseLogsTodayFuture;
  final int refreshTick;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SymptomEntry>>(
      stream: AppServices.isar.watchRecentSymptomEntries(limit: 1),
      builder: (context, symptomSnapshot) {
        return FutureBuilder<bool>(
          future: hasAnyExerciseLogsTodayFuture,
          builder: (context, exerciseSnapshot) {
            final now = DateTime.now();
            final hasSymptomLogs =
                (symptomSnapshot.data ?? const <SymptomEntry>[]).any(
                  (entry) => _isSameDay(entry.timestamp, now),
                );
            final hasExerciseLogs = exerciseSnapshot.data ?? false;
            final hasAnyLogsToday =
                moodSelection.hasEntryToday ||
                sleepSelection.hasEntryToday ||
                hasSymptomLogs ||
                hasExerciseLogs;

            if (!hasAnyLogsToday) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 18),
              child: _TodayDashboard(key: refreshKey, refreshTick: refreshTick),
            );
          },
        );
      },
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
  late Future<int> _todayExerciseCountFuture;

  @override
  void initState() {
    super.initState();
    _todayExerciseCountFuture = _loadTodayExerciseCount();
  }

  @override
  void didUpdateWidget(covariant _TodayDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _todayExerciseCountFuture = _loadTodayExerciseCount();
    }
  }

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
    final moodSelection = context.select<MoodLogStore, _MoodLogSnapshot>(
      (moodStore) => _MoodLogSnapshot.fromItems(moodStore.items),
    );
    final sleepSelection = context.select<SleepStore, _SleepLogSnapshot>(
      (sleepStore) => _SleepLogSnapshot.fromItems(sleepStore.items),
    );
    final now = DateTime.now();
    final latestMood = moodSelection.latest;
    final latestSleep = sleepSelection.latest;

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
          future: _todayExerciseCountFuture,
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
                        value: moodSelection.hasEntryToday && latestMood != null
                            ? latestMood.moodLabel
                            : 'Not logged',
                      ),
                      _TodayMetricTile(
                        icon: Icons.nightlight_round,
                        label: 'Sleep',
                        value:
                            sleepSelection.hasEntryToday && latestSleep != null
                            ? latestSleep.durationFormatted
                            : 'Not logged',
                        detail:
                            sleepSelection.hasEntryToday && latestSleep != null
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
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
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

class _TrackersDropdownCard extends StatelessWidget {
  const _TrackersDropdownCard({
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Trackers +',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in children) ...[
                  child,
                  if (child != children.last) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

class _TrackerShortcutTile extends StatelessWidget {
  const _TrackerShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodLogSnapshot {
  const _MoodLogSnapshot({
    required this.items,
    required this.signature,
    required this.latest,
    required this.hasEntryToday,
  });

  const _MoodLogSnapshot.empty()
    : items = const <MoodCheckIn>[],
      signature = 'empty',
      latest = null,
      hasEntryToday = false;

  factory _MoodLogSnapshot.fromItems(List<MoodCheckIn> items) {
    final latest = items.isEmpty ? null : items.first;
    final now = DateTime.now();
    final hasEntryToday = items.any((item) => _isSameDay(item.createdAt, now));
    final signature = items
        .take(20)
        .map(
          (item) =>
              '${item.createdAt.microsecondsSinceEpoch}:${item.intensity}:${item.moodLabel}:${item.emoji}',
        )
        .join('|');
    return _MoodLogSnapshot(
      items: items,
      signature: '${items.length}::$hasEntryToday::$signature',
      latest: latest,
      hasEntryToday: hasEntryToday,
    );
  }

  final List<MoodCheckIn> items;
  final String signature;
  final MoodCheckIn? latest;
  final bool hasEntryToday;

  @override
  bool operator ==(Object other) =>
      other is _MoodLogSnapshot && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}

class _SleepLogSnapshot {
  const _SleepLogSnapshot({
    required this.items,
    required this.signature,
    required this.latest,
    required this.hasEntryToday,
  });

  const _SleepLogSnapshot.empty()
    : items = const <Sleep>[],
      signature = 'empty',
      latest = null,
      hasEntryToday = false;

  factory _SleepLogSnapshot.fromItems(List<Sleep> items) {
    final latest = items.isEmpty ? null : items.first;
    final now = DateTime.now();
    final hasEntryToday = items.any(
      (item) => _isSameDay(item.date, now) || _isSameDay(item.wakeTime, now),
    );
    final signature = items
        .take(20)
        .map(
          (item) =>
              '${item.date.microsecondsSinceEpoch}:${item.wakeTime.microsecondsSinceEpoch}:${item.duration.inMinutes}:${item.quality.name}',
        )
        .join('|');
    return _SleepLogSnapshot(
      items: items,
      signature: '${items.length}::$hasEntryToday::$signature',
      latest: latest,
      hasEntryToday: hasEntryToday,
    );
  }

  final List<Sleep> items;
  final String signature;
  final Sleep? latest;
  final bool hasEntryToday;

  @override
  bool operator ==(Object other) =>
      other is _SleepLogSnapshot && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
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
