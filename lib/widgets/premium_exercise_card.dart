import 'package:flutter/material.dart';
import 'package:lifelens/models/exercise_model.dart';
import 'package:lifelens/widgets/tag.dart';

class PremiumExerciseCard extends StatelessWidget {
  final ExerciseModel exercise;
  final VoidCallback onTap;

  const PremiumExerciseCard({
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(28),

          // modern soft shadow
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// LEFT ICON ACCENT
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                _iconForMuscle(exercise.muscle),
                color: cs.primary,
                size: 26,
              ),
            ),

            const SizedBox(width: 16),

            /// TEXT CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE
                  Text(
                    exercise.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 6),

                  /// TAGS ROW
                  Wrap(
                    spacing: 6,
                    runSpacing: -8,
                    children: [
                      Tag(label: exercise.type),
                      Tag(label: exercise.difficulty),
                      Tag(label: exercise.muscle),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// DESCRIPTION
                  //Text(
                    //exercise.instructions,
                    //maxLines: 2,
                    //overflow: TextOverflow.ellipsis,
                    //style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          //color: cs.onSurfaceVariant,
                        //),
                  //),
                ],
              ),
            ),

            /// CHEVRON ICON
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: cs.outline, size: 28),
          ],
        ),
      ),
    );
  }
}

IconData _iconForMuscle(String muscle) {
  switch (muscle.toLowerCase()) {
    case 'chest':
      return Icons.favorite_rounded;
    case 'back':
      return Icons.accessibility_new_rounded;
    case 'legs':
      return Icons.directions_run_rounded;
    case 'shoulders':
      return Icons.fitness_center_rounded;
    case 'core':
      return Icons.self_improvement_rounded;
    default:
      return Icons.fitness_center_rounded;
  }
}
