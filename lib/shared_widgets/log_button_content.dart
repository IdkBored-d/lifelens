import 'package:flutter/material.dart';

enum LogButtonVisualState { idle, loading, success }

class LogButtonContent extends StatelessWidget {
  const LogButtonContent({
    super.key,
    required this.state,
    required this.idleLabel,
    this.loadingLabel = 'Saving',
    this.successLabel = 'Saved',
  });

  final LogButtonVisualState state;
  final String idleLabel;
  final String loadingLabel;
  final String successLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: switch (state) {
        LogButtonVisualState.loading => Row(
          key: const ValueKey('loading'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(loadingLabel),
          ],
        ),
        LogButtonVisualState.success => Row(
          key: const ValueKey('success'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 18),
            const SizedBox(width: 8),
            Text(successLabel),
          ],
        ),
        LogButtonVisualState.idle => Text(
          idleLabel,
          key: const ValueKey('idle'),
        ),
      },
    );
  }
}
