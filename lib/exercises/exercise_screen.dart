import 'package:flutter/material.dart';

import 'package:lifelens/models/exercise_model.dart';
import 'package:lifelens/shared_widgets/log_button_content.dart';
import 'package:lifelens/services/exercise_service.dart';
import 'package:lifelens/services/exercise_store.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  static const List<int> _durationOptions = <int>[5, 10, 15, 20, 30, 45, 60];

  final TextEditingController _searchController = TextEditingController();
  final ExerciseService _service = ExerciseService();
  final ExerciseStore _exerciseStore = ExerciseStore();

  late Future<void> _future;
  List<ExerciseModel> _exercises = const <ExerciseModel>[];
  List<Map<String, String>> _history = const <Map<String, String>>[];
  String _searchQuery = '';
  String? _selectedExerciseId;
  int _selectedDuration = 30;
  int _loggedToday = 0;
  int _loggedWeek = 0;
  LogButtonVisualState _logButtonState = LogButtonVisualState.idle;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _exerciseStore.ensureReady();
    await _exerciseStore.refreshFromCloud();
    List<ExerciseModel> exercises = const <ExerciseModel>[];
    try {
      exercises = await _service.fetchExercises();
    } catch (_) {
      exercises = const <ExerciseModel>[];
    }

    _exerciseStore.exercises = exercises;
    final activity = _exerciseStore.getRecentExerciseActivity(days: 7);
    final history = _exerciseStore.getRecentExerciseHistory(limit: 20);

    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _history = history;
      _loggedToday = activity.isEmpty ? 0 : activity.first;
      _loggedWeek = activity.fold(0, (sum, value) => sum + value);
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  ExerciseModel? get _selectedExercise {
    for (final exercise in _exercises) {
      if (exercise.id == _selectedExerciseId) return exercise;
    }
    return null;
  }

  List<ExerciseModel> get _filteredExercises {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const <ExerciseModel>[];

    return _exercises
        .where((exercise) {
          return exercise.name.toLowerCase().contains(query) ||
              exercise.type.toLowerCase().contains(query) ||
              exercise.muscle.toLowerCase().contains(query);
        })
        .take(6)
        .toList(growable: false);
  }

  Future<void> _logSelectedExercise() async {
    final exercise = _selectedExercise;
    if (exercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an exercise first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _logButtonState = LogButtonVisualState.loading);

    final syncMessage = await _exerciseStore.logExercise(
      exercise.id,
      exerciseName: exercise.name,
      durationMinutes: _selectedDuration,
    );

    final activity = _exerciseStore.getRecentExerciseActivity(days: 7);
    final history = _exerciseStore.getRecentExerciseHistory(limit: 20);

    if (!mounted) return;
    setState(() {
      _history = history;
      _loggedToday = activity.isEmpty ? 0 : activity.first;
      _loggedWeek = activity.fold(0, (sum, value) => sum + value);
      _logButtonState = LogButtonVisualState.success;
      _selectedExerciseId = null;
      _selectedDuration = 30;
      _searchQuery = '';
      _searchController.clear();
    });

    if (syncMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _logButtonState = LogButtonVisualState.idle);
  }

  void _selectExercise(ExerciseModel exercise) {
    _searchController.text = exercise.name;
    setState(() {
      _selectedExerciseId = exercise.id;
      _searchQuery = exercise.name;
    });
  }

  String _exerciseNameForId(String id) {
    for (final exercise in _exercises) {
      if (exercise.id == id) return exercise.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text('Exercise'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<void>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _exercises.isEmpty &&
                  _history.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _TrackerSummary(
                    loggedToday: _loggedToday,
                    loggedWeek: _loggedWeek,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search exercise',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedExerciseId = null;
                                      });
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(
                              alpha: 0.28,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (_filteredExercises.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: 0.35,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _filteredExercises.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: cs.outlineVariant.withValues(alpha: 0.2),
                              ),
                              itemBuilder: (context, index) {
                                final exercise = _filteredExercises[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(exercise.name),
                                  subtitle: Text(
                                    '${exercise.type} • ${exercise.muscle}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectExercise(exercise),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedExerciseId,
                          items: _exercises
                              .map(
                                (exercise) => DropdownMenuItem<String>(
                                  value: exercise.id,
                                  child: Text(
                                    exercise.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            final exercise = _exercises.firstWhere(
                              (item) => item.id == value,
                            );
                            _selectExercise(exercise);
                          },
                          decoration: const InputDecoration(
                            hintText: 'Choose exercise',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedDuration,
                          items: _durationOptions
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value min'),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedDuration = value);
                          },
                          decoration: const InputDecoration(
                            hintText: 'Duration',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                _selectedExerciseId == null ||
                                    _logButtonState ==
                                        LogButtonVisualState.loading
                                ? null
                                : _logSelectedExercise,
                            child: LogButtonContent(
                              state: _logButtonState,
                              idleLabel: 'Log',
                              loadingLabel: 'Logging',
                              successLabel: 'Logged',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Recent',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const _EmptyExerciseState()
                  else
                    ..._history.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExerciseHistoryCard(
                          record: record,
                          fallbackName: _exerciseNameForId(
                            record['exerciseId'] ?? '',
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrackerSummary extends StatelessWidget {
  const _TrackerSummary({required this.loggedToday, required this.loggedWeek});

  final int loggedToday;
  final int loggedWeek;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryPill(label: 'Today', value: '$loggedToday'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryPill(label: 'Week', value: '$loggedWeek'),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseHistoryCard extends StatelessWidget {
  const _ExerciseHistoryCard({
    required this.record,
    required this.fallbackName,
  });

  final Map<String, String> record;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = (record['exerciseName'] ?? '').trim().isNotEmpty
        ? record['exerciseName']!.trim()
        : fallbackName;
    final duration = (record['durationMinutes'] ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (duration.isNotEmpty) '$duration min',
                    if ((record['timestamp'] ?? '').isNotEmpty)
                      _formatTimestamp(record['timestamp']!),
                  ].join(' • '),
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

class _EmptyExerciseState extends StatelessWidget {
  const _EmptyExerciseState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: const Text('No logs yet.'),
    );
  }
}

String _formatTimestamp(String raw) {
  final timestamp = DateTime.tryParse(raw);
  if (timestamp == null) return raw;
  final local = timestamp.toLocal();
  final month = switch (local.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day} • $hour:$minute $suffix';
}
