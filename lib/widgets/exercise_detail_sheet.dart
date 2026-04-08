import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/models/exercise_model.dart';

class ExerciseDetailSheet extends StatelessWidget {
  const ExerciseDetailSheet({super.key, required this.exercise});

  final ExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final links = _instructionLinksFor(exercise);

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(label: _titleCase(exercise.type)),
                        _MetaChip(label: _titleCase(exercise.difficulty)),
                        _MetaChip(label: _titleCase(exercise.muscle)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _iconForExercise(exercise),
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _SectionCard(
                  title: 'Overview',
                  child: Text(
                    (exercise.description ?? '').trim().isNotEmpty
                        ? exercise.description!.trim()
                        : '${exercise.name} is a ${exercise.difficulty.toLowerCase()} ${exercise.type.toLowerCase()} exercise for ${exercise.muscle.toLowerCase()}.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'How To Do It',
                  child: Text(
                    _instructionsText(exercise),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
                if (exercise.equipment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Equipment',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: exercise.equipment
                          .map((item) => _MetaChip(label: _titleCase(item)))
                          .toList(growable: false),
                    ),
                  ),
                ],
                if (exercise.benefits.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Why It Helps',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: exercise.benefits
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item)),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Instruction Links',
                  child: Column(
                    children: links
                        .map(
                          (link) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InstructionLinkTile(link: link),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _instructionsText(ExerciseModel exercise) {
    final text = (exercise.instructions ?? '').trim();
    if (text.isNotEmpty) {
      return text;
    }

    return 'Move in a slow, controlled way, keep your posture steady, and stop if your form breaks down. Use the links below for a step-by-step guide for ${exercise.name.toLowerCase()}.';
  }

  List<_InstructionLink> _instructionLinksFor(ExerciseModel exercise) {
    final encodedName = Uri.encodeComponent(exercise.name);
    final links = <_InstructionLink>[
      if ((exercise.videoUrl ?? '').trim().isNotEmpty)
        _InstructionLink(
          label: 'Video guide',
          subtitle: 'Copy a direct how-to video link',
          url: exercise.videoUrl!.trim(),
        ),
      if ((exercise.instructionUrl ?? '').trim().isNotEmpty)
        _InstructionLink(
          label: 'Written guide',
          subtitle: 'Copy a direct step-by-step link',
          url: exercise.instructionUrl!.trim(),
        ),
      _InstructionLink(
        label: 'YouTube search',
        subtitle: 'Copy a quick search link for demos',
        url:
            'https://www.youtube.com/results?search_query=$encodedName+exercise',
      ),
      _InstructionLink(
        label: 'Web search',
        subtitle: 'Copy a search link for form tips',
        url: 'https://www.google.com/search?q=$encodedName+exercise+form',
      ),
    ];

    final seen = <String>{};
    return links.where((item) => seen.add(item.url)).toList(growable: false);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InstructionLinkTile extends StatelessWidget {
  const _InstructionLinkTile({required this.link});

  final _InstructionLink link;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: link.url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${link.label} copied'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.link_rounded, color: cs.onTertiaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    link.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LinkActionChip(
                        icon: Icons.copy_rounded,
                        label: 'Copy Link',
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: link.url),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${link.label} copied'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      _LinkActionChip(
                        icon: Icons.open_in_new_rounded,
                        label: 'Use Guide',
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: link.url),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${link.label} copied so you can open it anywhere',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkActionChip extends StatelessWidget {
  const _LinkActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionLink {
  const _InstructionLink({
    required this.label,
    required this.subtitle,
    required this.url,
  });

  final String label;
  final String subtitle;
  final String url;
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
      return Icons.fitness_center_rounded;
  }
}
