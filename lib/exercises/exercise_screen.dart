import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(
    text: '3',
  );
  final TextEditingController _repsController = TextEditingController(
    text: '10',
  );
  final ExerciseService _service = ExerciseService();
  final ExerciseStore _exerciseStore = ExerciseStore();

  late Future<void> _future;
  List<ExerciseModel> _exercises = const <ExerciseModel>[];
  List<Map<String, String>> _history = const <Map<String, String>>[];
  Map<String, ExerciseModel> _exerciseById = const <String, ExerciseModel>{};
  String _lastFilterQuery = '';
  List<ExerciseModel> _cachedFilteredExercises = const <ExerciseModel>[];
  String _searchQuery = '';
  String? _selectedExerciseId;
  bool _noExercise = false;
  bool _showPreviousLogs = false;
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
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  int? get _parsedSets => int.tryParse(_setsController.text.trim());

  int? get _parsedReps => int.tryParse(_repsController.text.trim());

  bool get _canLogExercise {
    if (_noExercise) return true;
    final sets = _parsedSets;
    final reps = _parsedReps;
    return _selectedExerciseId != null &&
        sets != null &&
        reps != null &&
        sets > 0 &&
        reps > 0;
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
      _exerciseById = {for (final exercise in exercises) exercise.id: exercise};
      _lastFilterQuery = '';
      _cachedFilteredExercises = const <ExerciseModel>[];
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
    final selectedExerciseId = _selectedExerciseId;
    if (selectedExerciseId == null) return null;
    return _exerciseById[selectedExerciseId];
  }

  List<ExerciseModel> get _filteredExercises {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const <ExerciseModel>[];
    if (_lastFilterQuery == query) {
      return _cachedFilteredExercises;
    }

    final filtered = _exercises
        .where((exercise) {
          return exercise.name.toLowerCase().contains(query) ||
              exercise.type.toLowerCase().contains(query) ||
              exercise.muscle.toLowerCase().contains(query);
        })
        .take(6)
        .toList(growable: false);
    _lastFilterQuery = query;
    _cachedFilteredExercises = filtered;
    return filtered;
  }

  Future<void> _logSelectedExercise() async {
    final exercise = _selectedExercise;
    if (!_noExercise && exercise == null) {
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
      _noExercise ? 'no_exercise' : exercise!.id,
      exerciseName: _noExercise ? 'No exercise' : exercise!.name,
      sets: _noExercise ? 0 : _parsedSets!,
      reps: _noExercise ? 0 : _parsedReps!,
      noExercise: _noExercise,
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
      _noExercise = false;
      _searchQuery = '';
      _lastFilterQuery = '';
      _cachedFilteredExercises = const <ExerciseModel>[];
      _searchController.clear();
      _setsController.text = '3';
      _repsController.text = '10';
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
      _noExercise = false;
      _lastFilterQuery = '';
      _cachedFilteredExercises = const <ExerciseModel>[];
    });
  }

  String _exerciseNameForId(String id) {
    return _exerciseById[id]?.name ?? id;
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
        title: const Text('Exercise Log'),
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
                          enabled: !_noExercise,
                          onChanged: (value) {
                            if (value == _searchQuery) return;
                            setState(() {
                              _searchQuery = value;
                              if (_lastFilterQuery !=
                                  value.trim().toLowerCase()) {
                                _cachedFilteredExercises =
                                    const <ExerciseModel>[];
                              }
                            });
                          },
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
                                        _lastFilterQuery = '';
                                        _cachedFilteredExercises =
                                            const <ExerciseModel>[];
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
                          _ExercisePickerSection(
                            title: 'Search results',
                            subtitle: 'Tap one to add it to this log.',
                            child: Column(
                              children: _filteredExercises
                                  .map(
                                    (exercise) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _ExerciseOptionCard(
                                        exercise: exercise,
                                        selected:
                                            _selectedExerciseId == exercise.id,
                                        onTap: () => _selectExercise(exercise),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          if (_selectedExercise != null)
                            _ExercisePickerSection(
                              title: 'Selected exercise',
                              subtitle: 'You can change this any time.',
                              child: _SelectedExerciseCard(
                                exercise: _selectedExercise!,
                                onClear: _noExercise
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedExerciseId = null;
                                          _searchQuery = '';
                                          _lastFilterQuery = '';
                                          _cachedFilteredExercises =
                                              const <ExerciseModel>[];
                                          _searchController.clear();
                                        });
                                      },
                              ),
                            )
                          else
                            _ExercisePickerSection(
                              title: 'Choose an exercise',
                              subtitle:
                                  'Start typing above to search for an exercise.',
                              child: const SizedBox.shrink(),
                            ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.28,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: CheckboxListTile(
                            value: _noExercise,
                            onChanged: (value) {
                              setState(() {
                                _noExercise = value ?? false;
                                if (_noExercise) {
                                  _selectedExerciseId = null;
                                  _searchQuery = '';
                                  _lastFilterQuery = '';
                                  _cachedFilteredExercises =
                                      const <ExerciseModel>[];
                                  _searchController.clear();
                                }
                              });
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: const Text('No exercise'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _setsController,
                                enabled: !_noExercise,
                                keyboardType: TextInputType.number,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Sets',
                                  labelText: 'Sets',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _repsController,
                                enabled: !_noExercise,
                                keyboardType: TextInputType.number,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Reps',
                                  labelText: 'Reps',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                !_canLogExercise ||
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
                  _HistoryDisclosureButton(
                    expanded: _showPreviousLogs,
                    onTap: () {
                      setState(() => _showPreviousLogs = !_showPreviousLogs);
                    },
                  ),
                  if (_showPreviousLogs) ...[
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryDisclosureButton extends StatelessWidget {
  const _HistoryDisclosureButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                expanded ? 'Hide previous logs' : 'View previous logs',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: cs.onSurfaceVariant,
            ),
          ],
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

class _ExercisePickerSection extends StatelessWidget {
  const _ExercisePickerSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.24)),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SelectedExerciseCard extends StatelessWidget {
  const _SelectedExerciseCard({required this.exercise, this.onClear});

  final ExerciseModel exercise;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.fitness_center_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.type} • ${exercise.muscle} • ${exercise.difficulty}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Clear selection',
            ),
        ],
      ),
    );
  }
}

class _ExerciseOptionCard extends StatelessWidget {
  const _ExerciseOptionCard({
    required this.exercise,
    required this.selected,
    required this.onTap,
  });

  final ExerciseModel exercise;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.52)
          : cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.6)
                  : cs.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercise.type} • ${exercise.muscle}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: cs.primary),
            ],
          ),
        ),
      ),
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
    final noExercise = (record['noExercise'] ?? '').trim() == 'true';
    final sets = (record['sets'] ?? '').trim();
    final reps = (record['reps'] ?? '').trim();
    final duration = (record['durationMinutes'] ?? '').trim();
    final detail = noExercise
        ? 'No exercise'
        : sets.isNotEmpty && reps.isNotEmpty
        ? '$sets sets • $reps reps'
        : duration.isNotEmpty
        ? '$duration min'
        : 'Exercise logged';

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
                    detail,
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
