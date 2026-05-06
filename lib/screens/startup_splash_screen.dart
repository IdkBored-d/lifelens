import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/signup_login.dart';

class StartupSplashScreen extends StatefulWidget {
  const StartupSplashScreen({super.key});

  @override
  State<StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<StartupSplashScreen>
    with TickerProviderStateMixin {
  // Continuous ambient loop — drives orbs + logo float + glow pulse
  late final AnimationController _ambientCtrl;

  // Single entrance controller — all elements animate in together
  late final AnimationController _entranceCtrl;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _buttonsOpacity;
  late final Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();

    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    // 460ms entrance — started synchronously so frame 1 is already animating
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutBack),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.10, 0.65, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.10, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.22, 0.78, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.22, 0.78, curve: Curves.easeOutCubic),
          ),
        );
    _buttonsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.38, 1.0, curve: Curves.easeOut),
      ),
    );
    _buttonsSlide =
        Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.38, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    // Start synchronously — animation is already ticking on the very first frame
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _goTo({required bool isLogin}) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, _) =>
            SignupLogin(initialIsLogin: isLogin),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.018),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final logoBg = isDark ? const Color(0xFF1C1830) : const Color(0xFFF8FAFC);
    final accent = colorScheme.primary;
    final mutedText = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.45 : 0.56,
    );
    final logoSize = isDark ? 108.0 : 98.0;
    final logoIconSize = isDark ? 54.0 : 48.0;
    final logoRadius = isDark ? 34.0 : 30.0;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!isDark)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(accent.withValues(alpha: 0.045), bg),
                    bg,
                    Color.alphaBlend(
                      colorScheme.secondary.withValues(alpha: 0.035),
                      bg,
                    ),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
          // ── Ambient orb background ───────────────────────────────────────
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (context, _) => CustomPaint(
              painter: _OrbPainter(
                t: _ambientCtrl.value,
                primary: accent,
                secondary: colorScheme.secondary,
                tertiary: isDark
                    ? const Color(0xFFBFA5FF)
                    : const Color(0xFF8B5CF6),
                alphaScale: isDark ? 1.0 : 0.58,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 5),

                  // ── Logo ─────────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_entranceCtrl, _ambientCtrl]),
                    builder: (context, _) {
                      final floatY =
                          math.sin(_ambientCtrl.value * 2 * math.pi) * 7.0;
                      final glow =
                          0.5 +
                          0.5 * math.sin(_ambientCtrl.value * 2 * math.pi);
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Transform.translate(
                            offset: Offset(0, floatY),
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              decoration: BoxDecoration(
                                color: logoBg,
                                borderRadius: BorderRadius.circular(logoRadius),
                                border: Border.all(
                                  color: accent.withValues(
                                    alpha: (isDark ? 0.30 : 0.22) + 0.10 * glow,
                                  ),
                                  width: isDark ? 1.5 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha:
                                          (isDark ? 0.28 : 0.11) + 0.08 * glow,
                                    ),
                                    blurRadius: isDark
                                        ? 36 + 20 * glow
                                        : 32 + 16 * glow,
                                    offset: Offset(0, isDark ? 10 : 8),
                                  ),
                                  BoxShadow(
                                    color: colorScheme.outlineVariant
                                        .withValues(
                                          alpha: isDark ? 0.08 : 0.38,
                                        ),
                                    blurRadius: isDark ? 8 : 12,
                                    offset: Offset(0, isDark ? 2 : 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.spa_rounded,
                                size: logoIconSize,
                                color: accent.withValues(
                                  alpha: isDark
                                      ? 0.75 + 0.25 * glow
                                      : 0.86 + 0.10 * glow,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: isDark ? 42 : 38),

                  // ── Title ────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: Text(
                        'Welcome to\nLifeLens',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: isDark ? 38 : 35,
                          fontWeight: isDark
                              ? FontWeight.w900
                              : FontWeight.w800,
                          letterSpacing: 0,
                          height: isDark ? 1.08 : 1.12,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isDark ? 13 : 15),

                  // ── Subtitle ─────────────────────────────────────────────
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: Text(
                        'Your personal space for your health\n'
                        'and guided wellbeing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mutedText,
                          fontSize: isDark ? 14.5 : 15,
                          fontWeight: isDark
                              ? FontWeight.w400
                              : FontWeight.w500,
                          height: isDark ? 1.6 : 1.45,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 5),

                  // ── Buttons ──────────────────────────────────────────────
                  FadeTransition(
                    opacity: _buttonsOpacity,
                    child: SlideTransition(
                      position: _buttonsSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SplashButton(
                            label: 'Create account',
                            icon: Icons.person_add_rounded,
                            onPressed: () => _goTo(isLogin: false),
                            filled: true,
                            accent: accent,
                          ),
                          const SizedBox(height: 12),
                          _SplashButton(
                            label: 'Log in',
                            icon: Icons.login_rounded,
                            onPressed: () => _goTo(isLogin: true),
                            filled: false,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 42),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

class _SplashButton extends StatelessWidget {
  const _SplashButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.filled,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final filledBackground = isDark ? accent.withValues(alpha: 0.14) : accent;
    final filledForeground = isDark ? accent : colorScheme.onPrimary;
    final verticalPadding = isDark ? 16.0 : 15.0;
    final radius = isDark ? 18.0 : 16.0;
    final iconSize = isDark ? 20.0 : 19.0;
    final fontSize = isDark ? 16.0 : 15.5;

    if (filled) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark
                    ? accent.withValues(alpha: 0.38)
                    : Colors.transparent,
                width: isDark ? 1.5 : 0,
              ),
              color: filledBackground,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: filledForeground, size: iconSize),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: TextStyle(
                    color: filledForeground,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        splashColor: accent.withValues(alpha: 0.08),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: isDark ? 0.70 : 1.0,
              ),
            ),
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.18 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: colorScheme.onSurface.withValues(alpha: 0.82),
                size: iconSize,
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orb background
// ─────────────────────────────────────────────────────────────────────────────

class _OrbPainter extends CustomPainter {
  const _OrbPainter({
    required this.t,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.alphaScale,
  });
  final double t;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final double alphaScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s1 = math.sin(t * 2 * math.pi);
    final c1 = math.cos(t * 2 * math.pi);

    _orb(
      canvas,
      center: Offset(
        size.width * (0.12 + 0.07 * s1),
        size.height * (0.10 + 0.04 * c1),
      ),
      radius: size.width * 0.55,
      color: primary,
      alpha: 0.10 * alphaScale,
    );
    _orb(
      canvas,
      center: Offset(
        size.width * (0.88 - 0.06 * c1),
        size.height * (0.78 + 0.04 * s1),
      ),
      radius: size.width * 0.48,
      color: secondary,
      alpha: 0.08 * alphaScale,
    );
    _orb(
      canvas,
      center: Offset(
        size.width * (0.80 - 0.04 * s1),
        size.height * (0.32 + 0.05 * c1),
      ),
      radius: size.width * 0.28,
      color: tertiary,
      alpha: 0.06 * alphaScale,
    );
  }

  void _orb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t ||
      old.primary != primary ||
      old.secondary != secondary ||
      old.tertiary != tertiary ||
      old.alphaScale != alphaScale;
}
