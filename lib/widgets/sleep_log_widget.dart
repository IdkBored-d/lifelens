import 'package:flutter/material.dart';
import 'package:lifelens/models/sleep.dart';

class SleepLogWidget extends StatelessWidget {
  const SleepLogWidget({super.key, required this.sleepData});

  final List<Sleep> sleepData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (sleepData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.bedtime_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),

            const SizedBox(height: 12),
            Text(
              'No sleep entries yet',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),
            Text(
              'Start tracking your sleep to see insights',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: sleepData.map((sleep) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SleepEntryCard(sleep: sleep),
        ),
        ).toList(),
    );
  }
}

class _SleepEntryCard extends StatelessWidget {
  const _SleepEntryCard({required this.sleep});

  final Sleep sleep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                _formatDate(sleep.date),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getQualityColor(sleep.quality, cs).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sleep.quality.emoji} ${sleep.quality.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getQualityColor(sleep.quality, cs),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeInfo(
                  icon: Icons.nightlight_round,
                  label: 'Bedtime',
                  time: _formatTime(sleep.bedTime),
                ),
              ),
              Expanded(
                child: _TimeInfo(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Wake up',
                  time: _formatTime(sleep.wakeTime),
                ),
              ),
              Expanded(
                child: _TimeInfo(
                  icon: Icons.schedule,
                  label: 'Duration',
                  time: sleep.durationFormatted,
                ),
              ),
            ],
          ),

          if (sleep.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sleep.notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference} days ago';;

    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12: hour);
    return '${displayHour}:${minute.toString().padLeft(2, '0')} $amPm';
  }

  Color _getQualityColor(SleepQuality quality, ColorScheme cs) {
    switch (quality) {
      case SleepQuality.poor:
        return Colors.red;
      case SleepQuality.fair:
        return Colors.orange;
      case SleepQuality.good:
        return cs.primary;
      case SleepQuality.excellent:
        return Colors.green;
    }
  }
}

class _TimeInfo extends StatelessWidget {
  const _TimeInfo({
    required this.icon,
    required this.label,
    required this.time,
  });

  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 2),
        Text(
          time,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}