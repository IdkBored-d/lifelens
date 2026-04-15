import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/eod_entry.dart';
import 'package:lifelens/database/fitness_entry.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/database/symptom_entry.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:provider/provider.dart';

import '../models/sleep.dart';

class HistoryCalendarScreen extends StatefulWidget {
  const HistoryCalendarScreen({
    super.key,
    this.initialDate,
    this.showCalendar = true,
  });

  final DateTime? initialDate;
  final bool showCalendar;

  @override
  State<HistoryCalendarScreen> createState() => _HistoryCalendarScreenState();
}

class HistoryCalendarView extends StatefulWidget {
  const HistoryCalendarView({
    super.key,
    this.showIntro = true,
    this.embedded = false,
    this.showDetails = true,
    this.showCalendar = true,
    this.initialDate,
    this.onDateSelected,
  });

  final bool showIntro;
  final bool embedded;
  final bool showDetails;
  final bool showCalendar;
  final DateTime? initialDate;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  State<HistoryCalendarView> createState() => _HistoryCalendarViewState();
}

class _HistoryCalendarScreenState extends State<HistoryCalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text('Logs'),
      ),
      body: SafeArea(
        child: HistoryCalendarView(
          initialDate: widget.initialDate,
          showCalendar: widget.showCalendar,
        ),
      ),
    );
  }
}

class _HistoryCalendarViewState extends State<HistoryCalendarView> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  _HistoryDayData? _dayData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = _startOfDay(widget.initialDate ?? DateTime.now());
    _visibleMonth = _monthStart(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDayData();
    });
  }

  Future<void> _loadDayData() async {
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();

    setState(() => _isLoading = true);

    await moodStore.refreshFromPersistence();
    await sleepStore.refresh();
    await AppServices.isar.init();

    final dateKey = _dateKey(_selectedDate);
    final exerciseStore = ExerciseStore();
    await exerciseStore.ensureReady();
    await exerciseStore.refreshFromCloud();

    final moods = await AppServices.isar.getMoodEntriesForDate(dateKey);
    final symptoms = await AppServices.isar.getSymptomEntriesForDate(dateKey);
    final fitnessEntries = await AppServices.isar.getRecentFitnessEntries(days: 365);
    final eod = await AppServices.isar.getEodEntry(dateKey);

    final sleeps = sleepStore.items
        .where((item) => _matchesSleepDate(item, _selectedDate))
        .toList(growable: false)
      ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));

    final exercises = exerciseStore
        .getRecentExerciseHistory(limit: 365)
        .where((item) {
          final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
          return timestamp != null && _isSameDay(timestamp, _selectedDate);
        })
        .toList(growable: false);

    final fitness = fitnessEntries
        .where((entry) => entry.date == dateKey)
        .toList(growable: false)
      ..sort((a, b) => b.inferenceTimestamp.compareTo(a.inferenceTimestamp));

    if (!mounted) return;
    setState(() {
      _dayData = _HistoryDayData(
        date: _selectedDate,
        moods: moods,
        sleeps: sleeps,
        symptoms: symptoms,
        fitnessEntries: fitness,
        exercises: exercises,
        eod: eod,
      );
      _isLoading = false;
    });
  }

  void _selectDate(DateTime value) {
    final normalized = _startOfDay(value);
    widget.onDateSelected?.call(normalized);
    setState(() {
      _selectedDate = normalized;
      _visibleMonth = _monthStart(normalized);
    });
    if (widget.showDetails) {
      _loadDayData();
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = <Widget>[
      if (widget.showIntro) ...[
        Text(
          'Look back at previous days',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (widget.showCalendar) ...[
        _CalendarCard(
          visibleMonth: _visibleMonth,
          selectedDate: _selectedDate,
          onPreviousMonth: () => _shiftMonth(-1),
          onNextMonth: () => _shiftMonth(1),
          onDateSelected: _selectDate,
        ),
        const SizedBox(height: 16),
      ],
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          _longDateLabel(_selectedDate),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!widget.showDetails)
        Text(
          'Choose a day to view that day\'s logs.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else if (_isLoading)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_dayData != null) ...[
        _OverviewGrid(data: _dayData!),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Mood',
          emptyLabel: 'No mood logs for this day.',
          children: _buildMoodTiles(_dayData!.moods),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Sleep',
          emptyLabel: 'No sleep logs for this day.',
          children: _buildSleepTiles(_dayData!.sleeps),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Symptoms',
          emptyLabel: 'No symptom logs for this day.',
          children: _buildSymptomTiles(_dayData!.symptoms),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Exercise',
          emptyLabel: 'No exercise logs for this day.',
          children: _buildExerciseTiles(_dayData!.exercises),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Fitness',
          emptyLabel: 'No fitness score for this day.',
          children: _buildFitnessTiles(_dayData!.fitnessEntries),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Day Summary',
          emptyLabel: 'No end-of-day summary for this day.',
          children: _buildEodTiles(_dayData!.eod),
        ),
      ],
    ];

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDayData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: content,
      ),
    );
  }

  List<Widget> _buildMoodTiles(List<MoodEntry> moods) {
    return moods
        .map(
          (entry) => _InfoTile(
            title: _titleCase(entry.resolvedMood),
            subtitle:
                '${_timeLabel(entry.timestamp)}${entry.condensedLog.trim().isEmpty ? '' : '  •  ${entry.condensedLog.trim()}'}',
            body: entry.rawLog.trim().isEmpty ? null : entry.rawLog.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildSleepTiles(List<Sleep> sleeps) {
    return sleeps
        .map(
          (entry) => _InfoTile(
            title: '${entry.durationFormatted} sleep',
            subtitle:
                '${entry.quality.label}  •  ${_clockLabel(entry.bedTime)} - ${_clockLabel(entry.wakeTime)}',
            body: entry.notes.trim().isEmpty ? null : entry.notes.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildSymptomTiles(List<SymptomEntry> symptoms) {
    return symptoms
        .map(
          (entry) => _InfoTile(
            title: entry.symptomList.isEmpty
                ? 'Symptom entry'
                : entry.symptomList.map(_titleCase).join(', '),
            subtitle: '${_timeLabel(entry.timestamp)}  •  ${_titleCase(entry.status)}',
            body: entry.rawSymptoms.trim().isEmpty ? null : entry.rawSymptoms.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildExerciseTiles(List<Map<String, String>> exercises) {
    return exercises
        .map(
          (entry) => _InfoTile(
            title: (entry['exerciseName'] ?? '').trim().isEmpty
                ? 'Exercise session'
                : entry['exerciseName']!.trim(),
            subtitle:
                '${entry['durationMinutes']?.trim().isEmpty ?? true ? 'Duration not logged' : '${entry['durationMinutes']} min'}  •  ${_timeLabel(DateTime.tryParse(entry['timestamp'] ?? '') ?? DateTime.now())}',
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildFitnessTiles(List<FitnessEntry> fitnessEntries) {
    return fitnessEntries
        .map(
          (entry) => _InfoTile(
            title: '${entry.fitnessScore.toStringAsFixed(0)}/100 fitness score',
            subtitle:
                '${entry.sleepHours.toStringAsFixed(1)}h sleep  •  ${entry.activityIndex.toStringAsFixed(1)} activity',
            body: 'Heart rate ${entry.heartRate.toStringAsFixed(0)}  •  Nutrition ${entry.nutritionQuality.toStringAsFixed(1)}',
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildEodTiles(EodEntry? eod) {
    if (eod == null) return const <Widget>[];
    return [
      _InfoTile(
        title: eod.flagged ? 'Flagged day summary' : 'Daily summary',
        subtitle:
            '${eod.fitnessScore.toStringAsFixed(0)}/100 fitness  •  ${eod.moodEntryCount} mood entr${eod.moodEntryCount == 1 ? 'y' : 'ies'}',
        body: eod.summaryText.trim(),
      ),
    ];
  }
}

class _HistoryDayData {
  const _HistoryDayData({
    required this.date,
    required this.moods,
    required this.sleeps,
    required this.symptoms,
    required this.fitnessEntries,
    required this.exercises,
    required this.eod,
  });

  final DateTime date;
  final List<MoodEntry> moods;
  final List<Sleep> sleeps;
  final List<SymptomEntry> symptoms;
  final List<FitnessEntry> fitnessEntries;
  final List<Map<String, String>> exercises;
  final EodEntry? eod;
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final days = _calendarDaysForMonth(visibleMonth);
    final today = _startOfDay(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _monthLabel(visibleMonth),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _monthStart(visibleMonth).isBefore(_monthStart(today))
                    ? onNextMonth
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _WeekLabel('Sun'),
              _WeekLabel('Mon'),
              _WeekLabel('Tue'),
              _WeekLabel('Wed'),
              _WeekLabel('Thu'),
              _WeekLabel('Fri'),
              _WeekLabel('Sat'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == visibleMonth.month;
              final isSelected = _isSameDay(day, selectedDate);
              final isToday = _isSameDay(day, today);
              final isFutureDay = day.isAfter(today);
              final isEnabled = inMonth && !isFutureDay;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isEnabled ? () => onDateSelected(day) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primaryContainer
                        : isToday
                            ? cs.secondaryContainer.withValues(alpha: 0.45)
                            : cs.surfaceContainerHighest.withValues(
                                alpha: isEnabled ? 0.25 : 0.08,
                              ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary
                          : isToday
                              ? cs.secondary
                              : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isEnabled
                            ? cs.onSurface
                            : cs.onSurfaceVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.data});

  final _HistoryDayData data;

  @override
  Widget build(BuildContext context) {
    final fitness = data.fitnessEntries.isEmpty
        ? null
        : data.fitnessEntries.first.fitnessScore.toStringAsFixed(0);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _OverviewTile(
          icon: Icons.emoji_emotions_outlined,
          label: 'Mood',
          value: '${data.moods.length}',
        ),
        _OverviewTile(
          icon: Icons.nightlight_round,
          label: 'Sleep',
          value: '${data.sleeps.length}',
        ),
        _OverviewTile(
          icon: Icons.healing_outlined,
          label: 'Symptoms',
          value: '${data.symptoms.length}',
        ),
        _OverviewTile(
          icon: Icons.fitness_center_outlined,
          label: 'Exercise',
          value: '${data.exercises.length}',
        ),
        _OverviewTile(
          icon: Icons.monitor_heart_outlined,
          label: 'Fitness',
          value: fitness == null ? '—' : '$fitness/100',
        ),
        _OverviewTile(
          icon: Icons.notes_rounded,
          label: 'Summary',
          value: data.eod == null ? '—' : 'Saved',
        ),
      ],
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else ..._spacedChildren(children),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.subtitle,
    this.body,
  });

  final String title;
  final String subtitle;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (body != null && body!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<DateTime> _calendarDaysForMonth(DateTime month) {
  final first = _monthStart(month);
  final start = first.subtract(Duration(days: first.weekday % 7));
  return List<DateTime>.generate(
    42,
    (index) => start.add(Duration(days: index)),
    growable: false,
  );
}

DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _matchesSleepDate(Sleep sleep, DateTime target) {
  return _isSameDay(sleep.date, target) || _isSameDay(sleep.wakeTime, target);
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _longDateLabel(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _clockLabel(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _timeLabel(DateTime value) => _clockLabel(value);

String _titleCase(String text) {
  return text
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

List<Widget> _spacedChildren(List<Widget> children) {
  final items = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    items.add(children[i]);
    if (i != children.length - 1) {
      items.add(const SizedBox(height: 10));
    }
  }
  return items;
}
