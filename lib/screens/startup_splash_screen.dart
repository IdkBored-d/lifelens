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
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
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
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
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
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
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
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1014);
    const primaryDeep = Color(0xFF6D4CFF);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient orb background ───────────────────────────────────────
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (context, _) =>
                CustomPaint(painter: _OrbPainter(t: _ambientCtrl.value)),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 5),

                  // ── Logo ─────────────────────────────────────────────────
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_entranceCtrl, _ambientCtrl]),
                    builder: (context, _) {
                      final floatY =
                          math.sin(_ambientCtrl.value * 2 * math.pi) * 7.0;
                      final glow =
                          0.5 +
                          0.5 *
                              math.sin(_ambientCtrl.value * 2 * math.pi);
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Transform.translate(
                            offset: Offset(0, floatY),
                            child: Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1830),
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(
                                  color: primaryDeep.withValues(
                                    alpha: 0.30 + 0.20 * glow,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryDeep.withValues(
                                      alpha: 0.28 + 0.18 * glow,
                                    ),
                                    blurRadius: 36 + 20 * glow,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFBFA5FF)
                                        .withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.spa_rounded,
                                size: 54,
                                color: const Color(0xFFBFA5FF).withValues(
                                  alpha: 0.75 + 0.25 * glow,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 42),

                  // ── Title ────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const Text(
                        'Welcome to\nLifeLens',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          height: 1.08,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 13),

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
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 14.5,
                          height: 1.6,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

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
                          ),
                          const SizedBox(height: 11),
                          _SplashButton(
                            label: 'Log in',
                            icon: Icons.login_rounded,
                            onPressed: () => _goTo(isLogin: true),
                            filled: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const primaryDeep = Color(0xFF6D4CFF);

    if (filled) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          splashColor: primaryDeep.withValues(alpha: 0.12),
          highlightColor: primaryDeep.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFBFA5FF).withValues(alpha: 0.38),
                width: 1.5,
              ),
              color: primaryDeep.withValues(alpha: 0.14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFBFA5FF),
                  size: 20,
                ),
                const SizedBox(width: 9),
                const Text(
                  'Create account',
                  style: TextStyle(
                    color: Color(0xFFBFA5FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.1,
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0xFFBFA5FF).withValues(alpha: 0.08),
        highlightColor: const Color(0xFFBFA5FF).withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.1,
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
  const _OrbPainter({required this.t});
  final double t;

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
      color: const Color(0xFF6D4CFF),
      alpha: 0.10,
    );
    _orb(
      canvas,
      center: Offset(
        size.width * (0.88 - 0.06 * c1),
        size.height * (0.78 + 0.04 * s1),
      ),
      radius: size.width * 0.48,
      color: const Color(0xFF4B2DFF),
      alpha: 0.08,
    );
    _orb(
      canvas,
      center: Offset(
        size.width * (0.80 - 0.04 * s1),
        size.height * (0.32 + 0.05 * c1),
      ),
      radius: size.width * 0.28,
      color: const Color(0xFFBFA5FF),
      alpha: 0.06,
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
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}
