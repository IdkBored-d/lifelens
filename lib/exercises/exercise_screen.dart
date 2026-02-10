import 'package:flutter/material.dart';
import '../widgets/_SectionTitle.dart';
import 'breathing_screen.dart';
import 'walk_screen.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise'),
        centerTitle: false,
        backgroundColor: cs.surface,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniMeExerciseBanner(),
            const SizedBox(height: 18),

            SectionTitle(title: 'Recommended for you'),
            const SizedBox(height: 12),
            _ExerciseList(),

            const SizedBox(height: 22),
            SectionTitle(title: 'Browse by type'),
            const SizedBox(height: 12),
            _ExerciseCategoryRow(),
          ],
        ),
      ),
    );
  }
}

class _MiniMeExerciseBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),

      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surface,
            ),
            child: Icon(Icons.person_rounded, color: cs.primary),
          ),

          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Based on your recent mood and energy, here are some gentle movements that may help today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  final exercises = const [
    _ExerciseItem(
      icon: Icons.self_improvement_rounded,
      title: 'Gentle Stretch',
      duration: '5 min',
      description: 'Loosen tension and reset your body',
      type: ExerciseType.stretch,
    ),

    _ExerciseItem(
      icon: Icons.directions_walk_rounded,
      title: 'Slow Walk',
      duration: '10 min',
      description: 'Light movement to support your mood',
      type: ExerciseType.walk,
    ),

    _ExerciseItem(
      icon: Icons.air_rounded,
      title: 'Breathing Flow',
      duration: '3 min',
      description: 'Calm your nervous system',
      type: ExerciseType.breathing,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: exercises
        .map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ExerciseCard(item: e),
        ))
        .toList(),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.item});
  final _ExerciseItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (item.type == ExerciseType.breathing) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BreathingScreen(),
            ),
          );
        }

        else if(item.type == ExerciseType.walk) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const WalkScreen(),
            ),
          );
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} (UI ONLY)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },

      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),

        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: cs.primary),
            ),

            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            Text(
              item.duration,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCategoryRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final categories = const [
      ('Stretch', Icons.self_improvement_rounded),
      ('Walk', Icons.directions_walk_rounded),
      ('Breathing', Icons.air_rounded),
    ];

    return Row(
      children: categories.map((c) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),

              child: Column(
                children: [
                  Icon(c.$2, color: cs.primary),
                  const SizedBox(height: 6),
                  Text(
                    c.$1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

enum ExerciseType{breathing, walk, stretch}

class _ExerciseItem {
  const _ExerciseItem({
    required this.icon,
    required this.title,
    required this.duration,
    required this.description,
    required this.type,
  });
  final IconData icon;
  final String title;
  final String duration;
  final String description;
  final ExerciseType type;
}