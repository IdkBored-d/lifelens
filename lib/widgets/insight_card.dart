import 'package:flutter/material.dart';

class InsightCard extends StatelessWidget {

  const InsightCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container (
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration (
        color: cs.secondaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      
      child: Row (
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container (
            width: 42,
            height: 42,
            decoration: BoxDecoration (
              color: cs.primaryContainer.withOpacity(0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
            ),
            child: Icon(Icons.lightbulb_outline_rounded, color: cs.primary),
          ),

          const SizedBox(width: 12),
          Expanded (
            child: Column (
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text (
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),

                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
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