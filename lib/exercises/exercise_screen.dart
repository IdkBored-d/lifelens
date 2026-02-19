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
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: ExerciseHero()),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  SliverToBoxAdapter(child: FilterChips()),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final e = exercises[index];
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
                    }, childCount: exercises.length),
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