import 'package:flutter/material.dart';
import 'package:lifelens/models/sleep.dart';

class SleepInsightsWidget extends StatelessWidget {
  const SleepInsightsWidget({super.key, required this.sleepData});

  final List<Sleep> sleepData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (sleepData.isEmpty) {
      return const SizedBox.shrink();
    }

    final averageDuration = _calculateAverageDuration();
    final averageQuality = _calculateAverageQuality();
    final sleepGoalHours = 8.0;
    final goalDifference = averageDuration.inMinutes / 60 - sleepGoalHours;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: cs.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Sleep Insights',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _InsightCard(
                  icon: Icons.schedule,
                  title: 'Avg Duration',
                  value: _formatDuration(averageDuration),
                  subtitle: goalDifference >= 0
                    ? '+${goalDifference.toStringAsFixed(1)}h from goal'
                    : '${goalDifference.toStringAsFixed(1)}h from goal',
                  color: goalDifference >= 0 ? Colors.green : Colors.orange,
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: _InsightCard(
                  icon: Icons.start_rounded,
                  title: 'Avg Quality',
                  value: '${averageQuality.toStringAsFixed(1)}/4',
                  subtitle: _getQualityDescription(averageQuality),
                  color: _getQualityColor(averageQuality),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InsightCard(
                  icon: Icons.trending_up,
                  title: 'Streak',
                  value: '${sleepData.length}',
                  subtitle: 'nights tracked',
                  color: cs.primary,
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: _InsightCard(
                  icon: Icons.bedtime,
                  title: 'Best Night',
                  value: _getBestNightDuration(),
                  subtitle: 'your longest sleep',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _SleepTip(
            tip: _generateTip(averageDuration, averageQuality, goalDifference),
          ),
        ],
      ),
    );
  }

  Duration _calculateAverageDuration() {
    if (sleepData.isEmpty) return Duration.zero;

    final totalMinutes = sleepData
      .map((sleep) => sleep.duration.inMinutes)
      .reduce((a, b) => a + b);
    return Duration(minutes: totalMinutes ~/ sleepData.length);
  }

  double _calculateAverageQuality() {
    if (sleepData.isEmpty) return 0.0;

    final totalQuality = sleepData
      .map((sleep) => sleep.quality.value)
      .reduce((a, b) => a + b);
    return totalQuality / sleepData.length;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String _getBestNightDuration() {
    if (sleepData.isEmpty) return '0h 0m';

    Sleep longestSleep = sleepData.first;
    for (final sleep in sleepData) {
      if (sleep.duration > longestSleep.duration) {
        longestSleep = sleep;
      }
    }
    return _formatDuration(longestSleep.duration);
  }

  String _getQualityDescription(double quality) {
    if (quality >= 3.5) return 'Excellent';
    if (quality >= 2.5) return 'Good';
    if (quality >= 1.5) return 'Fair';
    return 'Poor';
  }

  Color _getQualityColor(double quality) {
    if (quality >= 3.5) return Colors.green;
    if (quality >= 2.5) return Colors.blue;
    if (quality >= 1.5) return Colors.orange;
    return Colors.red;
  }

  String _generateTip(Duration avgDuration, double avgQuality, double goalDiff) {
    if (goalDiff < -1) {
      return 'Try going to bed 30 minutes earlier to reach your 8-hour goal.';
    } else if (avgQuality < 2) {
      return 'Consider creating a bedtime routine to improve sleep quality.';
    } else if (goalDiff > 1) {
      return 'Great job! You are consistently getting enough sleep.';
    } else if (goalDiff > 1) {
      return 'Great job exceeding your sleep goal! Keep it up!';
    } else {
      return 'Keep tracking to maintain healthy sleep patterns.';
    }
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepTip extends StatelessWidget {
  const _SleepTip({required this.tip});
  final String tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: cs.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}