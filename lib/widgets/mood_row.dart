import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/models/mood.dart';

class MoodRow extends StatelessWidget {
  const MoodRow({super.key, required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha:0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(moods.length, (i) {
          final mood = moods[i];
          final isSelected = i == selected;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.mediumImpact();
                onSelect(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                transform: isSelected
                    ? (Matrix4.diagonal3Values(1.05, 1.05, 1.0))
                    : Matrix4.identity(),
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primaryContainer.withValues(alpha:0.75)
                      : cs.surface.withValues(alpha:0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? cs.primary.withValues(alpha:0.55)
                        : cs.outlineVariant.withValues(alpha:0.6),
                  ),
                ),
                child: Column(
                  children: [
                    Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(
                      mood.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}