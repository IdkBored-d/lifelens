import 'package:flutter/material.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/models/exercise_model.dart';
import 'package:lifelens/services/exercise_service.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/services/minime_backend_service.dart';
import 'package:lifelens/services/minime_chat_storage_service.dart';
import 'package:lifelens/widgets/exercise_detail_sheet.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ExerciseService _service = ExerciseService();
  final ExerciseStore _exerciseStore = ExerciseStore();

  late Future<List<ExerciseModel>> _futureExercises;
  Future<_ExerciseRecommendationsState>? _recommendationsFuture;
  Set<String> _favoriteIds = <String>{};
  String _searchQuery = '';
  String _selectedMuscle = 'all';
  String _selectedType = 'all';
  String _selectedDifficulty = 'all';

  @override
  void initState() {
    super.initState();
    _futureExercises = _loadExercises();
  }

  Future<List<ExerciseModel>> _loadExercises() async {
    await _exerciseStore.ensureReady();
    final exercises = await _service.fetchExercises();
    _exerciseStore.exercises = exercises;
    _recommendationsFuture = _loadRecommendations(exercises);
    if (mounted) {
      setState(() {
        _favoriteIds = _exerciseStore.getFavoriteIds().toSet();
      });
    }
    return exercises;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureExercises = _loadExercises();
    });
  }

  Future<void> _toggleFavorite(ExerciseModel exercise) async {
    final isFavorite = _favoriteIds.contains(exercise.id);
    if (isFavorite) {
      await _exerciseStore.unfavoriteExercise(exercise.id);
    } else {
      await _exerciseStore.favoriteExercise(exercise.id);
    }

    if (!mounted) return;
    setState(() {
      if (isFavorite) {
        _favoriteIds.remove(exercise.id);
      } else {
        _favoriteIds.add(exercise.id);
      }
    });
  }

  Future<void> _saveExercise(ExerciseModel exercise) async {
    await _exerciseStore.saveExercise(exercise.id, 'calm');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${exercise.name} saved to your exercise history'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openExerciseDetails(ExerciseModel exercise) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseDetailSheet(exercise: exercise),
    );
  }

  Future<_ExerciseRecommendationsState> _loadRecommendations(
    List<ExerciseModel> exercises,
  ) async {
    if (exercises.isEmpty) {
      return const _ExerciseRecommendationsState(
        headline: '',
        items: <_RecommendedExercise>[],
      );
    }

    await IsarService.instance.init();
    final recentEntries = await IsarService.instance.getRecentMoodEntries(
      days: 7,
    );
    final moodEntries = recentEntries
        .where((entry) => entry.resolvedBy != 'minime')
        .toList(growable: false);
    final activeSymptomsEntries = await IsarService.instance
        .getActiveSymptomEntries();
    final chatMessages = await MiniMeChatStorageService.instance.loadMessages();
    final latestMood = moodEntries.isEmpty ? null : moodEntries.first;
    final recentChatMessages = chatMessages.length <= 20
        ? chatMessages
        : chatMessages.sublist(chatMessages.length - 20);

    try {
      final reply = await MiniMeBackendService.instance.exerciseRecommendations(
        latestMoodLabel: latestMood?.resolvedMood ?? 'Neutral',
        latestMoodIntensity: latestMood == null
            ? 3
            : _extractIntensity(latestMood),
        latestMoodNotes: latestMood?.rawLog ?? '',
        recentMoods: moodEntries
            .take(8)
            .map(
              (entry) =>
                  '${entry.resolvedMood} (${_extractIntensity(entry)}/5)',
            )
            .toList(growable: false),
        recentLogs: moodEntries
            .take(10)
            .map((entry) => entry.rawLog.trim())
            .where((text) => text.isNotEmpty)
            .toList(growable: false),
        activeSymptoms: activeSymptomsEntries
            .expand((entry) => entry.symptomList)
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(12)
            .toList(growable: false),
        history: recentChatMessages
            .map(
              (message) =>
                  MiniMeChatTurn(role: message.role, text: message.text),
            )
            .toList(growable: false),
        exercises: exercises
            .map(
              (exercise) => MiniMeExerciseCandidate(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                muscle: exercise.muscle,
                difficulty: exercise.difficulty,
                description: exercise.description,
              ),
            )
            .toList(growable: false),
      );

      final exerciseById = {for (final item in exercises) item.id: item};
      final items = reply.recommendations
          .map((item) {
            final exercise = exerciseById[item.exerciseId];
            if (exercise == null) return null;
            return _RecommendedExercise(
              exercise: exercise,
              focus: item.focus,
              reason: item.reason,
            );
          })
          .whereType<_RecommendedExercise>()
          .toList(growable: false);

      if (items.isNotEmpty) {
        return _ExerciseRecommendationsState(
          headline: reply.headline.isEmpty
              ? 'Mini-Me picked a few exercises based on how you have been feeling.'
              : reply.headline,
          items: items,
        );
      }
    } catch (_) {
      // fall through to the local fallback below
    }

    return _fallbackRecommendations(exercises, moodEntries);
  }

  _ExerciseRecommendationsState _fallbackRecommendations(
    List<ExerciseModel> exercises,
    List<dynamic> moodEntries,
  ) {
    final latestMood = moodEntries.isEmpty
        ? 'neutral'
        : (moodEntries.first.resolvedMood as String).toLowerCase();

    int scoreExercise(ExerciseModel exercise) {
      final type = exercise.type.toLowerCase();
      final difficulty = exercise.difficulty.toLowerCase();
      var score = 0;
      if (latestMood.contains('anx') || latestMood.contains('stress')) {
        if (type == 'mobility' || type == 'stretching') score += 4;
        if (difficulty == 'beginner') score += 2;
      } else if (latestMood.contains('sad') || latestMood.contains('low')) {
        if (type == 'cardio' || type == 'strength') score += 4;
      } else {
        if (type == 'strength' || type == 'cardio' || type == 'mobility') {
          score += 3;
        }
      }
      return score;
    }

    final top = [...exercises]
      ..sort((a, b) => scoreExercise(b).compareTo(scoreExercise(a)));
    final items = top
        .take(3)
        .map((exercise) {
          return _RecommendedExercise(
            exercise: exercise,
            focus: 'Good next step',
            reason:
                'This is a simple fit for how you have been feeling lately.',
          );
        })
        .toList(growable: false);

    return _ExerciseRecommendationsState(
      headline:
          'Mini-Me picked a few exercises that should feel realistic right now.',
      items: items,
    );
  }

  List<ExerciseModel> _filteredExercises(List<ExerciseModel> exercises) {
    return exercises
        .where((exercise) {
          final query = _searchQuery.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              exercise.name.toLowerCase().contains(query) ||
              (exercise.description ?? '').toLowerCase().contains(query) ||
              exercise.muscle.toLowerCase().contains(query) ||
              exercise.type.toLowerCase().contains(query);
          final matchesMuscle =
              _selectedMuscle == 'all' ||
              exercise.muscle.toLowerCase() == _selectedMuscle;
          final matchesType =
              _selectedType == 'all' ||
              exercise.type.toLowerCase() == _selectedType;
          final matchesDifficulty =
              _selectedDifficulty == 'all' ||
              exercise.difficulty.toLowerCase() == _selectedDifficulty;
          return matchesSearch &&
              matchesMuscle &&
              matchesType &&
              matchesDifficulty;
        })
        .toList(growable: false);
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
          child: FutureBuilder<List<ExerciseModel>>(
            future: _futureExercises,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Could not load exercises right now.')),
                  ],
                );
              }

              final exercises = snapshot.data ?? const <ExerciseModel>[];
              final filtered = _filteredExercises(exercises);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _ExerciseHeroCard(
                    totalCount: exercises.length,
                    favoriteCount: _favoriteIds.length,
                  ),
                  const SizedBox(height: 16),
                  if (_recommendationsFuture != null)
                    FutureBuilder<_ExerciseRecommendationsState>(
                      future: _recommendationsFuture,
                      builder: (context, recommendationSnapshot) {
                        if (recommendationSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _RecommendationLoadingCard();
                        }

                        final recommendationState = recommendationSnapshot.data;
                        if (recommendationState == null ||
                            recommendationState.items.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _RecommendationPanel(
                            state: recommendationState,
                            favoriteIds: _favoriteIds,
                            onOpen: _openExerciseDetails,
                            onFavoriteToggle: _toggleFavorite,
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search exercises, muscles, or types',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
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
                  const SizedBox(height: 16),
                  _CompactFilterBar(
                    muscleLabel: _selectedMuscle,
                    typeLabel: _selectedType,
                    difficultyLabel: _selectedDifficulty,
                    onMuscleTap: () => _showFilterPicker(
                      title: 'Muscle',
                      options: _buildFilterOptions(
                        exercises.map((item) => item.muscle),
                      ),
                      selected: _selectedMuscle,
                      onSelected: (value) {
                        setState(() => _selectedMuscle = value);
                      },
                    ),
                    onTypeTap: () => _showFilterPicker(
                      title: 'Type',
                      options: _buildFilterOptions(
                        exercises.map((item) => item.type),
                      ),
                      selected: _selectedType,
                      onSelected: (value) {
                        setState(() => _selectedType = value);
                      },
                    ),
                    onDifficultyTap: () => _showFilterPicker(
                      title: 'Difficulty',
                      options: _buildFilterOptions(
                        exercises.map((item) => item.difficulty),
                      ),
                      selected: _selectedDifficulty,
                      onSelected: (value) {
                        setState(() => _selectedDifficulty = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ResultSummary(
                    totalCount: filtered.length,
                    hasFilters:
                        _selectedMuscle != 'all' ||
                        _selectedType != 'all' ||
                        _selectedDifficulty != 'all' ||
                        _searchQuery.isNotEmpty,
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedMuscle = 'all';
                        _selectedType = 'all';
                        _selectedDifficulty = 'all';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const _EmptyExerciseState()
                  else
                    ...filtered.map(
                      (exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExerciseCard(
                          exercise: exercise,
                          isFavorite: _favoriteIds.contains(exercise.id),
                          onFavorite: () => _toggleFavorite(exercise),
                          onOpen: () => _openExerciseDetails(exercise),
                          onSave: () => _saveExercise(exercise),
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

  List<String> _buildFilterOptions(Iterable<String> values) {
    final unique =
        values
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['all', ...unique];
  }

  int _extractIntensity(dynamic entry) {
    final condensedLog = entry.condensedLog as String? ?? '';
    final match = RegExp(r'([1-5])\/5').firstMatch(condensedLog);
    if (match == null) return 3;
    return int.tryParse(match.group(1) ?? '') ?? 3;
  }

  void _showFilterPicker({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options
                      .map(
                        (option) => ChoiceChip(
                          label: Text(
                            option == 'all' ? 'All' : _titleCase(option),
                          ),
                          selected: selected == option,
                          onSelected: (_) {
                            Navigator.pop(context);
                            onSelected(option);
                          },
                          showCheckmark: false,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseRecommendationsState {
  const _ExerciseRecommendationsState({
    required this.headline,
    required this.items,
  });

  final String headline;
  final List<_RecommendedExercise> items;
}

class _RecommendedExercise {
  const _RecommendedExercise({
    required this.exercise,
    required this.focus,
    required this.reason,
  });

  final ExerciseModel exercise;
  final String focus;
  final String reason;
}

class _ExerciseHeroCard extends StatelessWidget {
  const _ExerciseHeroCard({
    required this.totalCount,
    required this.favoriteCount,
  });

  final int totalCount;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.85),
            cs.secondaryContainer.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exercise Library',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simple filters, cleaner cards, and better exercise details.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(label: 'Exercises', value: '$totalCount'),
              const SizedBox(width: 10),
              _HeroStat(label: 'Favorites', value: '$favoriteCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactFilterBar extends StatelessWidget {
  const _CompactFilterBar({
    required this.muscleLabel,
    required this.typeLabel,
    required this.difficultyLabel,
    required this.onMuscleTap,
    required this.onTypeTap,
    required this.onDifficultyTap,
  });

  final String muscleLabel;
  final String typeLabel;
  final String difficultyLabel;
  final VoidCallback onMuscleTap;
  final VoidCallback onTypeTap;
  final VoidCallback onDifficultyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filters',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterPill(
                label: 'Muscle',
                value: muscleLabel,
                onTap: onMuscleTap,
              ),
              const SizedBox(width: 8),
              _FilterPill(label: 'Type', value: typeLabel, onTap: onTypeTap),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Difficulty',
                value: difficultyLabel,
                onTap: onDifficultyTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = value != 'all';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? cs.primary.withValues(alpha: 0.25)
                : cs.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${value == 'all' ? 'All' : _titleCase(value)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: active ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.totalCount,
    required this.hasFilters,
    required this.onClear,
  });

  final int totalCount;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$totalCount exercise${totalCount == 1 ? '' : 's'}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (hasFilters)
          TextButton(
            onPressed: onClear,
            child: Text('Clear filters', style: TextStyle(color: cs.primary)),
          ),
      ],
    );
  }
}

class _RecommendationLoadingCard extends StatelessWidget {
  const _RecommendationLoadingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mini-Me is choosing exercises for your current mood...',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({
    required this.state,
    required this.favoriteIds,
    required this.onOpen,
    required this.onFavoriteToggle,
  });

  final _ExerciseRecommendationsState state;
  final Set<String> favoriteIds;
  final ValueChanged<ExerciseModel> onOpen;
  final ValueChanged<ExerciseModel> onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recommended By Mini-Me',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.headline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ...state.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendedExerciseTile(
                item: item,
                isFavorite: favoriteIds.contains(item.exercise.id),
                onOpen: () => onOpen(item.exercise),
                onFavoriteToggle: () => onFavoriteToggle(item.exercise),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedExerciseTile extends StatelessWidget {
  const _RecommendedExerciseTile({
    required this.item,
    required this.isFavorite,
    required this.onOpen,
    required this.onFavoriteToggle,
  });

  final _RecommendedExercise item;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exercise = item.exercise;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onFavoriteToggle,
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
                    color: isFavorite ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.focus,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CardTag(label: _titleCase(exercise.type)),
                _CardTag(label: _titleCase(exercise.difficulty)),
                _CardTag(label: _titleCase(exercise.muscle)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.isFavorite,
    required this.onFavorite,
    required this.onOpen,
    required this.onSave,
  });

  final ExerciseModel exercise;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _iconForExercise(exercise),
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _exerciseSummary(exercise),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
                    color: isFavorite ? cs.primary : cs.onSurfaceVariant,
                  ),
                  tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CardTag(label: _titleCase(exercise.type)),
                _CardTag(label: _titleCase(exercise.muscle)),
                _CardTag(label: _titleCase(exercise.difficulty)),
                if (exercise.equipment.isNotEmpty)
                  _CardTag(label: '${exercise.equipment.length} equipment'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpen,
                    child: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _exerciseSummary(ExerciseModel exercise) {
    final description = (exercise.description ?? '').trim();
    if (description.isNotEmpty) {
      return description;
    }
    return 'A ${exercise.difficulty.toLowerCase()} ${exercise.type.toLowerCase()} movement focused on ${exercise.muscle.toLowerCase()}.';
  }
}

class _CardTag extends StatelessWidget {
  const _CardTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
        ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: cs.primary),
          const SizedBox(height: 12),
          Text(
            'No exercises match those filters',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Try clearing one filter or searching with a simpler word.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

IconData _iconForExercise(ExerciseModel exercise) {
  switch (exercise.type.toLowerCase()) {
    case 'cardio':
      return Icons.directions_run_rounded;
    case 'mobility':
      return Icons.self_improvement_rounded;
    case 'stretching':
      return Icons.accessibility_new_rounded;
    default:
      switch (exercise.muscle.toLowerCase()) {
        case 'legs':
          return Icons.directions_run_rounded;
        case 'core':
          return Icons.airline_seat_flat_angled_rounded;
        case 'back':
          return Icons.accessibility_new_rounded;
        default:
          return Icons.fitness_center_rounded;
      }
  }
}
