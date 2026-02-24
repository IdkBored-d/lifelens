import 'package:flutter/material.dart';
import 'package:lifelens/widgets/exercise_detail_sheet.dart';
import 'package:lifelens/widgets/exercise_hero.dart';
import 'package:lifelens/widgets/filter_chips.dart';
import 'package:lifelens/widgets/premium_exercise_card.dart';
import '../models/exercise_model.dart';
import '../services/exercise_service.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
      String _selectedMuscle = '';
      String _selectedType = '';
      String _selectedDifficulty = '';
    String _searchQuery = '';
    TextEditingController _searchController = TextEditingController();
  final ExerciseService _service = ExerciseService();
  late Future<List<ExerciseModel>> _futureExercises;

  void _openExerciseDetails(ExerciseModel exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseDetailSheet(exercise: exercise),
    );
  }

  @override
  void initState() {
    super.initState();
    _futureExercises = _service.fetchExercises();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureExercises = _service.fetchExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
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
                return Center(
                  child: Text(
                    'Failed to load exercises.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }

              final exercises = snapshot.data ?? [];
              final filteredExercises = exercises.where((e) {
                final matchesSearch = _searchQuery.isEmpty || e.name.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchesMuscle = _selectedMuscle.isEmpty || e.muscle.toLowerCase() == _selectedMuscle;
                final matchesType = _selectedType.isEmpty || e.type.toLowerCase() == _selectedType;
                final matchesDifficulty = _selectedDifficulty.isEmpty || e.difficulty.toLowerCase() == _selectedDifficulty;
                return matchesSearch && matchesMuscle && matchesType && matchesDifficulty;
              }).toList();
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: ExerciseHero()),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search exercises',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              FilterChip(
                                label: const Text('Chest'),
                                selected: _selectedMuscle == 'chest',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedMuscle = selected ? 'chest' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Back'),
                                selected: _selectedMuscle == 'back',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedMuscle = selected ? 'back' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Legs'),
                                selected: _selectedMuscle == 'legs',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedMuscle = selected ? 'legs' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Shoulders'),
                                selected: _selectedMuscle == 'shoulders',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedMuscle = selected ? 'shoulders' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Core'),
                                selected: _selectedMuscle == 'core',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedMuscle = selected ? 'core' : '';
                                  });
                                },
                              ),
                              // Type filters
                              FilterChip(
                                label: const Text('Strength'),
                                selected: _selectedType == 'strength',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedType = selected ? 'strength' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Cardio'),
                                selected: _selectedType == 'cardio',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedType = selected ? 'cardio' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Mobility'),
                                selected: _selectedType == 'mobility',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedType = selected ? 'mobility' : '';
                                  });
                                },
                              ),
                              // Difficulty filters
                              FilterChip(
                                label: const Text('Beginner'),
                                selected: _selectedDifficulty == 'beginner',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedDifficulty = selected ? 'beginner' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Intermediate'),
                                selected: _selectedDifficulty == 'intermediate',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedDifficulty = selected ? 'intermediate' : '';
                                  });
                                },
                              ),
                              FilterChip(
                                label: const Text('Advanced'),
                                selected: _selectedDifficulty == 'advanced',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedDifficulty = selected ? 'advanced' : '';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final e = filteredExercises[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: PremiumExerciseCard(
                          exercise: e,
                          onTap: () => _openExerciseDetails(e),
                        ),
                      );
                    }, childCount: filteredExercises.length),
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