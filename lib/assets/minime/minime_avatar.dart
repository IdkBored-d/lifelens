import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cartoon_face.dart';

class MiniMeAvatar extends StatefulWidget {
  const MiniMeAvatar({
    super.key,
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    this.moodLabel,
    this.moodEmoji,
    this.glow,
    this.size = 320,
    this.onAvatarTap,
    this.onRotate,
    this.enableAutoRotate = true,
  });

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String? moodLabel;
  final String? moodEmoji;
  final Color? glow;
  final double size;
  final VoidCallback? onAvatarTap;
  final ValueChanged<double>? onRotate;
  final bool enableAutoRotate;

  @override
  State<MiniMeAvatar> createState() => _MiniMeAvatarState();
}

class _MiniMeAvatarState extends State<MiniMeAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(
      widget.bodyModel,
      widget.hairModel,
      widget.shirtModel,
    );
    final expression = _resolveExpression(widget.moodLabel);
    final clampedSize = widget.size.clamp(160.0, 720.0);

    return GestureDetector(
      onTap: widget.onAvatarTap,
      child: SizedBox(
        width: clampedSize,
        height: clampedSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final motion = _motionForExpression(expression, _controller.value);
            final blink = _blinkValue(_controller.value);

            if (widget.onRotate != null) {
              widget.onRotate!(motion.sway);
            }

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _AmbientHalo(
                  size: clampedSize,
                  color: widget.glow ?? palette.primary,
                  shimmer: motion.shimmer,
                ),
                Positioned(
                  bottom: clampedSize * 0.075,
                  child: Transform.scale(
                    scaleX: motion.shadowScale,
                    scaleY: 1,
                    child: Container(
                      width: clampedSize * 0.5,
                      height: clampedSize * 0.085,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: RadialGradient(
                          colors: [
                            palette.eye.withValues(alpha: 0.18),
                            palette.eye.withValues(alpha: 0.03),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.68, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(motion.offsetX, motion.bobOffset),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateZ(motion.sway)
                      ..rotateX(motion.tiltX)
                      ..rotateY(motion.tiltY),
                    child: Transform.scale(
                      scaleY: motion.bodyScaleY,
                      scaleX: motion.bodyScaleX,
                      child: _MascotBody(
                        palette: palette,
                        expression: expression,
                        accessory: _resolveAccessory(widget.shirtModel),
                        crest: _resolveCrest(widget.hairModel),
                        bodyWidthScale: widget.bodyWidthScale,
                        size: clampedSize,
                        blink: blink,
                        bodyLean: motion.bodyLean,
                        headOffsetY: motion.headOffsetY,
                        wingLift: motion.wingLift,
                        accessoryLift: motion.accessoryLift,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _blinkValue(double t) {
    final windows = <double>[0.17, 0.51, 0.86];
    var best = 0.0;
    for (final center in windows) {
      final distance = (t - center).abs();
      if (distance < 0.045) {
        final normalized = 1 - (distance / 0.045);
        best = math.max(best, Curves.easeInOut.transform(normalized));
      }
    }
    return best;
  }
}

class _MascotBody extends StatelessWidget {
  const _MascotBody({
    required this.palette,
    required this.expression,
    required this.accessory,
    required this.crest,
    required this.bodyWidthScale,
    required this.size,
    required this.blink,
    required this.bodyLean,
    required this.headOffsetY,
    required this.wingLift,
    required this.accessoryLift,
  });

  final MiniMeFacePalette palette;
  final String expression;
  final _MiniMeAccessory accessory;
  final _MiniMeCrest crest;
  final double bodyWidthScale;
  final double size;
  final double blink;
  final double bodyLean;
  final double headOffsetY;
  final double wingLift;
  final double accessoryLift;

  @override
  Widget build(BuildContext context) {
    final bodyWidth = size * 0.56 * bodyWidthScale.clamp(0.82, 1.18);
    final bodyHeight = size * 0.68;
    final headSize = size * 0.41;
    final shellWidth = size * 0.72;
    final shellHeight = size * 0.78;
    final shellTop = size * 0.12 + headOffsetY * 0.08;
    final headCenterY = shellTop + shellHeight * 0.24;
    final headDiameter = shellWidth * 0.57;
    final headLeft = (size - headDiameter) / 2;
    final faceSize = headDiameter * 0.9;
    final faceTop = headCenterY - (faceSize / 2);
    final crestTop = shellTop - size * 0.01;
    final wingBaseY = size * 0.18 + wingLift;
    final footOffsetX = bodyWidth * 0.16;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: shellTop,
            child: CustomPaint(
              size: Size(shellWidth, shellHeight),
              painter: _CharacterShellPainter(
                palette: palette,
                bodyWidthScale: bodyWidthScale,
              ),
            ),
          ),
          Positioned(
            left: (size / 2) - bodyWidth * 0.46,
            top: wingBaseY,
            child: Transform.rotate(
              angle: -0.34 - bodyLean * 0.16,
              child: _Wing(
                width: size * 0.17,
                height: size * 0.27,
                color: palette.secondary.withValues(alpha: 0.92),
                accent: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: (size / 2) - bodyWidth * 0.46,
            top: wingBaseY + wingLift * 0.08,
            child: Transform.rotate(
              angle: 0.34 + bodyLean * 0.16,
              child: _Wing(
                width: size * 0.17,
                height: size * 0.27,
                color: palette.secondary.withValues(alpha: 0.96),
                accent: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.2,
            left: headLeft + headDiameter * 0.04,
            child: Transform.rotate(
              angle: -0.24,
              child: Container(
                width: bodyWidth * 0.14,
                height: bodyHeight * 0.42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(bodyWidth),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: crestTop,
            child: _Crest(
              crest: crest,
              palette: palette,
              size: headSize * 0.34,
            ),
          ),
          Positioned(
            top: shellTop + shellHeight * 0.08,
            left: headLeft + headDiameter * 0.12 + bodyLean * size * 0.012,
            child: Container(
              width: headSize * 0.28,
              height: headSize * 0.17,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(headSize),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.36),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: faceTop,
            child: CartoonFace(
              expression: expression,
              palette: palette,
              size: faceSize,
              blink: blink,
            ),
          ),
          Positioned(
            bottom: size * 0.245 + accessoryLift,
            child: _AccessoryBadge(
              palette: palette,
              accessory: accessory,
              size: size * 0.19,
            ),
          ),
          Positioned(
            bottom: size * 0.08,
            left: (size / 2) - footOffsetX - size * 0.04,
            child: _Foot(color: palette.beak, flip: false, size: size * 0.08),
          ),
          Positioned(
            bottom: size * 0.08,
            right: (size / 2) - footOffsetX - size * 0.04,
            child: _Foot(color: palette.beak, flip: true, size: size * 0.08),
          ),
        ],
      ),
    );
  }
}

class _AmbientHalo extends StatelessWidget {
  const _AmbientHalo({
    required this.size,
    required this.color,
    required this.shimmer,
  });

  final double size;
  final Color color;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(shimmer * size * 0.03, size * 0.03),
          child: Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18 + shimmer * 0.03),
                  blurRadius: size * (0.12 + shimmer * 0.015),
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),
        ),
        Container(
          width: size * (0.64 + shimmer * 0.015),
          height: size * (0.64 + shimmer * 0.015),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.15 + shimmer * 0.12, -0.2),
              radius: 0.88,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              stops: const [0, 0.48, 1],
            ),
          ),
        ),
        Positioned(
          top: size * 0.12,
          child: Container(
            width: size * 0.22,
            height: size * 0.08,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }
}

class _CharacterShellPainter extends CustomPainter {
  const _CharacterShellPainter({
    required this.palette,
    required this.bodyWidthScale,
  });

  final MiniMeFacePalette palette;
  final double bodyWidthScale;

  @override
  void paint(Canvas canvas, Size size) {
    final headRadius = size.width * 0.285;
    final headCenter = Offset(size.width * 0.5, size.height * 0.24);
    final bodyWidth = size.width * 0.56 * bodyWidthScale.clamp(0.82, 1.18);
    final bodyLeft = (size.width - bodyWidth) / 2;
    final bodyTop = size.height * 0.33;
    final bodyRect = Rect.fromLTWH(
      bodyLeft,
      bodyTop,
      bodyWidth,
      size.height * 0.5,
    );

    final bodyPath = Path()
      ..moveTo(bodyRect.left + bodyWidth * 0.2, bodyRect.top)
      ..quadraticBezierTo(
        bodyRect.left + bodyWidth * 0.02,
        bodyRect.top + bodyRect.height * 0.12,
        bodyRect.left + bodyWidth * 0.08,
        bodyRect.bottom - bodyRect.height * 0.2,
      )
      ..quadraticBezierTo(
        bodyRect.left + bodyWidth * 0.18,
        bodyRect.bottom,
        bodyRect.center.dx,
        bodyRect.bottom,
      )
      ..quadraticBezierTo(
        bodyRect.right - bodyWidth * 0.18,
        bodyRect.bottom,
        bodyRect.right - bodyWidth * 0.08,
        bodyRect.bottom - bodyRect.height * 0.2,
      )
      ..quadraticBezierTo(
        bodyRect.right - bodyWidth * 0.02,
        bodyRect.top + bodyRect.height * 0.12,
        bodyRect.right - bodyWidth * 0.2,
        bodyRect.top,
      )
      ..close();

    final bodyShadow = bodyPath.shift(const Offset(0, 8));
    canvas.drawPath(
      bodyShadow,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawCircle(
      headCenter.translate(0, 4),
      headRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.22, -0.28),
        radius: 1.02,
        colors: [
          Colors.white.withValues(alpha: 0.15),
          palette.primary,
          palette.secondary,
        ],
        stops: const [0, 0.36, 1],
      ).createShader(bodyRect.inflate(bodyWidth * 0.05));
    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.008,
    );

    final bodyGloss = Path()
      ..moveTo(
        bodyRect.left + bodyWidth * 0.2,
        bodyRect.top + bodyRect.height * 0.06,
      )
      ..quadraticBezierTo(
        bodyRect.left + bodyWidth * 0.34,
        bodyRect.top + bodyRect.height * 0.14,
        bodyRect.left + bodyWidth * 0.28,
        bodyRect.bottom - bodyRect.height * 0.3,
      )
      ..quadraticBezierTo(
        bodyRect.left + bodyWidth * 0.22,
        bodyRect.bottom - bodyRect.height * 0.18,
        bodyRect.left + bodyWidth * 0.14,
        bodyRect.bottom - bodyRect.height * 0.36,
      )
      ..quadraticBezierTo(
        bodyRect.left + bodyWidth * 0.12,
        bodyRect.top + bodyRect.height * 0.16,
        bodyRect.left + bodyWidth * 0.2,
        bodyRect.top + bodyRect.height * 0.06,
      )
      ..close();
    canvas.drawPath(
      bodyGloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(bodyRect),
    );

    final bellyRect = Rect.fromCenter(
      center: Offset(bodyRect.center.dx, bodyRect.top + bodyRect.height * 0.56),
      width: bodyWidth * 0.56,
      height: bodyRect.height * 0.35,
    );
    final bellyPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          bellyRect,
          Radius.circular(bellyRect.width * 0.5),
        ),
      );
    canvas.drawPath(
      bellyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.16), palette.belly],
        ).createShader(bellyRect),
    );

    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.18, -0.24),
          radius: 0.92,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            palette.primary,
            palette.secondary,
          ],
          stops: const [0, 0.44, 1],
        ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius)),
    );
    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.009,
    );

    final headHighlight = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: headCenter.translate(-headRadius * 0.22, -headRadius * 0.2),
        width: headRadius * 0.55,
        height: headRadius * 0.28,
      ),
      Radius.circular(headRadius),
    );
    canvas.drawRRect(
      headHighlight,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(headHighlight.outerRect),
    );
  }

  @override
  bool shouldRepaint(covariant _CharacterShellPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.bodyWidthScale != bodyWidthScale;
  }
}

class _Wing extends StatelessWidget {
  const _Wing({
    required this.width,
    required this.height,
    required this.color,
    required this.accent,
  });

  final double width;
  final double height;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _WingPainter(color: color, accent: accent),
      ),
    );
  }
}

class _WingPainter extends CustomPainter {
  const _WingPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.72, size.height * 0.04)
      ..quadraticBezierTo(
        size.width * 0.08,
        size.height * 0.14,
        size.width * 0.1,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.92,
        size.width * 0.58,
        size.height * 0.98,
      )
      ..quadraticBezierTo(
        size.width * 0.94,
        size.height * 0.88,
        size.width * 0.94,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.18,
        size.width * 0.72,
        size.height * 0.04,
      )
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, color, color.withValues(alpha: 0.92)],
        stops: const [0, 0.36, 1],
      ).createShader(Offset.zero & size);
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final featherPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.22),
      Offset(size.width * 0.36, size.height * 0.76),
      featherPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.34),
      Offset(size.width * 0.5, size.height * 0.84),
      featherPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.accent != accent;
  }
}

_MotionProfile _motionForExpression(String expression, double t) {
  final wave = math.sin(t * math.pi * 2);
  final fastWave = math.sin(t * math.pi * 4);
  final slowWave = math.cos(t * math.pi * 2);

  switch (expression) {
    case 'happy':
      return _MotionProfile(
        bobOffset: wave * 7 + math.max(0, fastWave) * 2.2,
        sway: wave * 0.035,
        tiltX: fastWave * 0.018,
        tiltY: slowWave * 0.06,
        bodyScaleX: 1 - math.max(0, wave) * 0.015,
        bodyScaleY: 1 + math.max(0, wave) * 0.018,
        shadowScale: 1 - math.max(0, wave) * 0.08,
        shimmer: (slowWave + 1) / 2,
        wingLift: math.max(0, fastWave) * 4.5,
        headOffsetY: math.max(0, wave) * -3.5,
        bodyLean: wave * 0.12,
        accessoryLift: math.max(0, fastWave) * 2,
        offsetX: wave * 1.8,
      );
    case 'calm':
      return _MotionProfile(
        bobOffset: wave * 3.5,
        sway: wave * 0.018,
        tiltX: slowWave * 0.012,
        tiltY: wave * 0.03,
        bodyScaleX: 1,
        bodyScaleY: 1,
        shadowScale: 1,
        shimmer: (slowWave + 1) / 2,
        wingLift: math.max(0, slowWave) * 1.2,
        headOffsetY: slowWave * -1.6,
        bodyLean: wave * 0.05,
        accessoryLift: 0.8,
        offsetX: wave * 0.6,
      );
    case 'sad':
      return _MotionProfile(
        bobOffset: wave * 2.2 + 3,
        sway: wave * 0.012,
        tiltX: -0.015 + slowWave * 0.006,
        tiltY: wave * 0.016,
        bodyScaleX: 1.01,
        bodyScaleY: 0.99,
        shadowScale: 1.03,
        shimmer: 0.2 + (slowWave + 1) / 2 * 0.2,
        wingLift: 0.2,
        headOffsetY: 5 + math.max(0, wave) * 1.2,
        bodyLean: -0.03,
        accessoryLift: 0,
        offsetX: 0,
      );
    case 'angry':
      return _MotionProfile(
        bobOffset: wave * 2.8,
        sway: wave * 0.028,
        tiltX: fastWave * 0.012,
        tiltY: slowWave * 0.038,
        bodyScaleX: 1.015,
        bodyScaleY: 1,
        shadowScale: 0.98,
        shimmer: 0.35,
        wingLift: math.max(0, fastWave) * 1.8,
        headOffsetY: -1.2,
        bodyLean: wave * 0.08,
        accessoryLift: 0.6,
        offsetX: wave * 1.2,
      );
    default:
      return _MotionProfile(
        bobOffset: wave * 4.5,
        sway: wave * 0.022,
        tiltX: fastWave * 0.012,
        tiltY: slowWave * 0.04,
        bodyScaleX: 1,
        bodyScaleY: 1,
        shadowScale: 1,
        shimmer: (slowWave + 1) / 2 * 0.7,
        wingLift: math.max(0, fastWave) * 1.5,
        headOffsetY: slowWave * -1.5,
        bodyLean: wave * 0.06,
        accessoryLift: 0.8,
        offsetX: wave * 0.9,
      );
  }
}

class _MotionProfile {
  const _MotionProfile({
    required this.bobOffset,
    required this.sway,
    required this.tiltX,
    required this.tiltY,
    required this.bodyScaleX,
    required this.bodyScaleY,
    required this.shadowScale,
    required this.shimmer,
    required this.wingLift,
    required this.headOffsetY,
    required this.bodyLean,
    required this.accessoryLift,
    required this.offsetX,
  });

  final double bobOffset;
  final double sway;
  final double tiltX;
  final double tiltY;
  final double bodyScaleX;
  final double bodyScaleY;
  final double shadowScale;
  final double shimmer;
  final double wingLift;
  final double headOffsetY;
  final double bodyLean;
  final double accessoryLift;
  final double offsetX;
}

class _AccessoryBadge extends StatelessWidget {
  const _AccessoryBadge({
    required this.palette,
    required this.accessory,
    required this.size,
  });

  final MiniMeFacePalette palette;
  final _MiniMeAccessory accessory;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (accessory == _MiniMeAccessory.none) {
      return const SizedBox.shrink();
    }

    if (accessory == _MiniMeAccessory.tie) {
      return SizedBox(
        width: size,
        height: size * 0.9,
        child: CustomPaint(painter: _TiePainter(color: palette.accessory)),
      );
    }

    return Container(
      width: size,
      height: size * 0.34,
      decoration: BoxDecoration(
        color: palette.accessory,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Container(
          width: size * 0.16,
          height: size * 0.16,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TiePainter extends CustomPainter {
  const _TiePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final knot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.22),
        width: size.width * 0.25,
        height: size.height * 0.18,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(knot, paint);

    final leftWing = Path()
      ..moveTo(size.width * 0.18, size.height * 0.16)
      ..lineTo(size.width * 0.42, size.height * 0.1)
      ..lineTo(size.width * 0.39, size.height * 0.36)
      ..close();
    canvas.drawPath(leftWing, paint);

    final rightWing = Path()
      ..moveTo(size.width * 0.82, size.height * 0.16)
      ..lineTo(size.width * 0.58, size.height * 0.1)
      ..lineTo(size.width * 0.61, size.height * 0.36)
      ..close();
    canvas.drawPath(rightWing, paint);

    final tail = Path()
      ..moveTo(size.width * 0.5, size.height * 0.3)
      ..lineTo(size.width * 0.37, size.height * 0.9)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.98,
        size.width * 0.63,
        size.height * 0.9,
      )
      ..lineTo(size.width * 0.5, size.height * 0.3)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _TiePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _Crest extends StatelessWidget {
  const _Crest({
    required this.crest,
    required this.palette,
    required this.size,
  });

  final _MiniMeCrest crest;
  final MiniMeFacePalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (crest == _MiniMeCrest.none) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: size * 1.9,
      height: size * 1.4,
      child: CustomPaint(
        painter: _CrestPainter(
          crest: crest,
          color: palette.accessory,
          secondary: palette.secondary,
        ),
      ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  const _CrestPainter({
    required this.crest,
    required this.color,
    required this.secondary,
  });

  final _MiniMeCrest crest;
  final Color color;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = secondary.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    void drawLeaf(double startX, double peakX, double peakY, double endX) {
      final path = Path()
        ..moveTo(startX, size.height)
        ..quadraticBezierTo(peakX, peakY, endX, size.height * 0.92)
        ..quadraticBezierTo(
          (startX + endX) / 2,
          size.height * 0.78,
          startX,
          size.height,
        )
        ..close();
      canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);
      canvas.drawPath(path, paint);
    }

    switch (crest) {
      case _MiniMeCrest.fluff:
        drawLeaf(
          size.width * 0.2,
          size.width * 0.36,
          size.height * 0.02,
          size.width * 0.44,
        );
        drawLeaf(size.width * 0.4, size.width * 0.52, 0, size.width * 0.64);
        drawLeaf(
          size.width * 0.58,
          size.width * 0.74,
          size.height * 0.08,
          size.width * 0.8,
        );
        break;
      case _MiniMeCrest.sprout:
        drawLeaf(
          size.width * 0.26,
          size.width * 0.38,
          size.height * 0.08,
          size.width * 0.5,
        );
        drawLeaf(
          size.width * 0.5,
          size.width * 0.62,
          size.height * 0.02,
          size.width * 0.74,
        );
        break;
      case _MiniMeCrest.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CrestPainter oldDelegate) {
    return oldDelegate.crest != crest ||
        oldDelegate.color != color ||
        oldDelegate.secondary != secondary;
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.color, required this.flip, required this.size});

  final Color color;
  final bool flip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flip,
      child: SizedBox(
        width: size,
        height: size * 0.44,
        child: CustomPaint(painter: _FootPainter(color: color)),
      ),
    );
  }
}

class _FootPainter extends CustomPainter {
  const _FootPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * 0.18;

    final baseY = size.height * 0.55;
    canvas.drawLine(
      Offset(size.width * 0.12, baseY),
      Offset(size.width * 0.42, size.height * 0.24),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.32, baseY),
      Offset(size.width * 0.56, size.height * 0.22),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.52, baseY),
      Offset(size.width * 0.82, size.height * 0.3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FootPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

MiniMeFacePalette _resolvePalette(
  String bodyModel,
  String hairModel,
  String shirtModel,
) {
  final source = [bodyModel, hairModel, shirtModel].join('|').toLowerCase();
  final index = source.hashCode.abs() % _palettes.length;
  return _palettes[index];
}

String _resolveExpression(String? moodLabel) {
  switch ((moodLabel ?? '').trim().toLowerCase()) {
    case 'happy':
    case 'excited':
    case 'joyful':
      return 'happy';
    case 'calm':
    case 'peaceful':
      return 'calm';
    case 'anxious':
    case 'sad':
    case 'tired':
    case 'low':
      return 'sad';
    case 'angry':
    case 'frustrated':
      return 'angry';
    default:
      return 'neutral';
  }
}

_MiniMeCrest _resolveCrest(String hairModel) {
  final key = hairModel.toLowerCase();
  if (key.contains('male')) {
    return _MiniMeCrest.sprout;
  }
  if (key.contains('hair')) {
    return _MiniMeCrest.fluff;
  }
  return _MiniMeCrest.none;
}

_MiniMeAccessory _resolveAccessory(String shirtModel) {
  final key = shirtModel.toLowerCase();
  if (key.contains('tie')) {
    return _MiniMeAccessory.tie;
  }
  if (key.isNotEmpty) {
    return _MiniMeAccessory.band;
  }
  return _MiniMeAccessory.none;
}

enum _MiniMeAccessory { none, band, tie }

enum _MiniMeCrest { none, fluff, sprout }

const List<MiniMeFacePalette> _palettes = [
  MiniMeFacePalette(
    primary: Color(0xFF69C4B6),
    secondary: Color(0xFF4AA597),
    belly: Color(0xFFF7F2E7),
    beak: Color(0xFFF6AE45),
    cheek: Color(0xFFF7B6B2),
    eye: Color(0xFF18323A),
    accessory: Color(0xFFEF6F6C),
  ),
  MiniMeFacePalette(
    primary: Color(0xFFF7B267),
    secondary: Color(0xFFE59644),
    belly: Color(0xFFFFF2DD),
    beak: Color(0xFFEE8B2B),
    cheek: Color(0xFFF7B0A3),
    eye: Color(0xFF432818),
    accessory: Color(0xFF7F95D1),
  ),
  MiniMeFacePalette(
    primary: Color(0xFF8FCB9B),
    secondary: Color(0xFF5FAE74),
    belly: Color(0xFFF7F5E8),
    beak: Color(0xFFE8A04F),
    cheek: Color(0xFFF2B7C6),
    eye: Color(0xFF233127),
    accessory: Color(0xFF5B7DB1),
  ),
  MiniMeFacePalette(
    primary: Color(0xFF9DB4F0),
    secondary: Color(0xFF6E86D6),
    belly: Color(0xFFF8F7FF),
    beak: Color(0xFFF3B55B),
    cheek: Color(0xFFF1B4C8),
    eye: Color(0xFF22304F),
    accessory: Color(0xFFE87461),
  ),
];
