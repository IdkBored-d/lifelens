import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/database/eod_entry.dart';
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
    this.refreshOnInitialLoad = true,
  });

  final DateTime? initialDate;
  final bool showCalendar;
  final bool refreshOnInitialLoad;

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
    this.refreshOnInitialLoad = true,
  });

  final bool showIntro;
  final bool embedded;
  final bool showDetails;
  final bool showCalendar;
  final DateTime? initialDate;
  final ValueChanged<DateTime>? onDateSelected;
  final bool refreshOnInitialLoad;

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
          refreshOnInitialLoad: widget.refreshOnInitialLoad,
        ),
      ),
    );
  }
}

class _HistoryCalendarViewState extends State<HistoryCalendarView> {
  final ExerciseStore _exerciseStore = ExerciseStore();
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  _HistoryDayData? _dayData;
  bool _isLoading = true;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = _startOfDay(widget.initialDate ?? DateTime.now());
    _visibleMonth = _monthStart(_selectedDate);
    if (!widget.showDetails) {
      _isLoading = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoad();
    });
  }

  Future<void> _initializeAndLoad() async {
    await AppServices.isar.init();
    await _exerciseStore.ensureReady();
    await _loadDayData(refreshStores: widget.refreshOnInitialLoad);
  }

  Future<void> _loadDayData({bool refreshStores = false}) async {
    final requestId = ++_loadRequestId;
    final selectedDate = _selectedDate;
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();

    if (mounted) {
      setState(() => _isLoading = true);
    }

    if (refreshStores) {
      await Future.wait<void>([
        moodStore.refreshFromPersistence(),
        sleepStore.refresh(),
        _exerciseStore.refreshFromCloud(),
      ]);
    }

    final dateKey = _dateKey(selectedDate);

    final results = await Future.wait<Object?>([
      AppServices.isar.getMoodEntriesForDate(dateKey),
      AppServices.isar.getSymptomEntriesForDate(dateKey),
      AppServices.isar.getEodEntry(dateKey),
    ]);

    final moods = results[0] as List<MoodEntry>;
    final symptoms = results[1] as List<SymptomEntry>;
    final eod = results[2] as EodEntry?;

    final sleeps =
        sleepStore.items
            .where((item) => _matchesSleepDate(item, selectedDate))
            .toList(growable: false)
          ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));

    final exercises = _exerciseStore
        .getRecentExerciseHistory(limit: 365)
        .where((item) {
          final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
          return timestamp != null && _isSameDay(timestamp, selectedDate);
        })
        .toList(growable: false);

    if (!mounted || requestId != _loadRequestId) return;
    setState(() {
      _dayData = _HistoryDayData(
        date: selectedDate,
        moods: moods,
        sleeps: sleeps,
        symptoms: symptoms,
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
      unawaited(_loadDayData());
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
      if (widget.showCalendar) ...[
        _CalendarCard(
          visibleMonth: _visibleMonth,
          selectedDate: _selectedDate,
          compact: widget.embedded,
          onPreviousMonth: () => _shiftMonth(-1),
          onNextMonth: () => _shiftMonth(1),
          onDateSelected: _selectDate,
        ),
        const SizedBox(height: 16),
      ],
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.38,
          ),
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
        const SizedBox.shrink()
      else if (_isLoading)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_dayData != null) ...[
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
      onRefresh: () => _loadDayData(refreshStores: true),
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
            subtitle: _timeLabel(entry.timestamp),
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
            subtitle: _timeLabel(entry.timestamp),
            body: entry.rawSymptoms.trim().isEmpty
                ? null
                : entry.rawSymptoms.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildExerciseTiles(List<Map<String, String>> exercises) {
    return exercises
        .map((entry) {
          final noExercise = (entry['noExercise'] ?? '').trim() == 'true';
          final sets = (entry['sets'] ?? '').trim();
          final reps = (entry['reps'] ?? '').trim();
          final duration = (entry['durationMinutes'] ?? '').trim();
          final detail = noExercise
              ? 'No exercise'
              : sets.isNotEmpty && reps.isNotEmpty
              ? '$sets sets • $reps reps'
              : duration.isNotEmpty
              ? '$duration min'
              : 'Exercise logged';

          return _InfoTile(
            title: (entry['exerciseName'] ?? '').trim().isEmpty
                ? 'Exercise session'
                : entry['exerciseName']!.trim(),
            subtitle:
                '$detail  •  ${_timeLabel(DateTime.tryParse(entry['timestamp'] ?? '') ?? DateTime.now())}',
          );
        })
        .toList(growable: false);
  }
}

class _HistoryDayData {
  const _HistoryDayData({
    required this.date,
    required this.moods,
    required this.sleeps,
    required this.symptoms,
    required this.exercises,
    required this.eod,
  });

  final DateTime date;
  final List<MoodEntry> moods;
  final List<Sleep> sleeps;
  final List<SymptomEntry> symptoms;
  final List<Map<String, String>> exercises;
  final EodEntry? eod;
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    this.compact = false,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final bool compact;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final days = _calendarDaysForMonth(visibleMonth);
    final today = _startOfDay(DateTime.now());
    final cardPadding = compact ? 10.0 : 16.0;
    final headerButtonConstraints = BoxConstraints.tightFor(
      width: compact ? 32 : 44,
      height: compact ? 32 : 44,
    );
    final weekdayGap = compact ? 4.0 : 8.0;
    final dayGridAspectRatio = compact ? 1.6 : 1.0;
    final dayCornerRadius = compact ? 10.0 : 14.0;

    return Container(
      padding: EdgeInsets.all(cardPadding),
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
                constraints: headerButtonConstraints,
                padding: EdgeInsets.zero,
                iconSize: compact ? 20 : 24,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _monthLabel(visibleMonth),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 16 : null,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    _monthStart(visibleMonth).isBefore(_monthStart(today))
                    ? onNextMonth
                    : null,
                constraints: headerButtonConstraints,
                padding: EdgeInsets.zero,
                iconSize: compact ? 20 : 24,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 10),
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
          SizedBox(height: weekdayGap),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: weekdayGap,
              crossAxisSpacing: weekdayGap,
              childAspectRatio: dayGridAspectRatio,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == visibleMonth.month;
              final isSelected = _isSameDay(day, selectedDate);
              final isToday = _isSameDay(day, today);
              final isFutureDay = day.isAfter(today);
              final isEnabled = inMonth && !isFutureDay;

              return InkWell(
                borderRadius: BorderRadius.circular(dayCornerRadius),
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
                    borderRadius: BorderRadius.circular(dayCornerRadius),
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
                        fontSize: compact ? 12 : null,
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
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
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
          else
            ..._spacedChildren(children),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.subtitle, this.body});

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
        color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
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

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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
