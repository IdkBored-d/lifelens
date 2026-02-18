import 'package:flutter/material.dart';
import 'package:lifelens/models/exercise_model.dart';
import 'package:lifelens/widgets/tag.dart';

class ExerciseDetailSheet extends StatelessWidget {
  final ExerciseModel exercise;

  const ExerciseDetailSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Text(
            exercise.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              Tag(label: exercise.type),
              Tag(label: exercise.difficulty),
              Tag(label: exercise.muscle),
            ],
          ),

          const SizedBox(height: 20),
          Text(
            'Instruction',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                exercise.instructions,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}