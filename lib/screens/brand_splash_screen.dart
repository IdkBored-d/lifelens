import 'package:flutter/material.dart';

class BrandSplashScreen extends StatelessWidget {
  const BrandSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = theme.scaffoldBackgroundColor;
    final isDark = colorScheme.brightness == Brightness.dark;
    final logoBg = isDark
        ? const Color(0xFF1C1830)
        : colorScheme.surfaceContainerHighest;
    final wordmarkColor = colorScheme.onSurface;
    final accent = colorScheme.primary;

    return ColoredBox(
      color: bg,
      child: SafeArea(
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final logoSize = constraints.maxHeight < 620 ? 84.0 : 96.0;
              final iconSize = constraints.maxHeight < 620 ? 42.0 : 48.0;
              final spacing = constraints.maxHeight < 620 ? 14.0 : 20.0;

              return Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(
                        child: Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: logoBg,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: accent.withValues(
                                alpha: isDark ? 0.35 : 0.45,
                              ),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(
                                  alpha: isDark ? 0.30 : 0.18,
                                ),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.spa_rounded,
                            size: iconSize,
                            color: accent,
                          ),
                        ),
                      ),
                      SizedBox(height: spacing),
                      SizedBox(
                        width: 132,
                        height: 34,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _LifeLensWordmarkPainter(wordmarkColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LifeLensWordmarkPainter extends CustomPainter {
  const _LifeLensWordmarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'LifeLens',
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LifeLensWordmarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
