import 'dart:math' as math;

import 'package:flutter/material.dart';

class MiniMeFacePalette {
  const MiniMeFacePalette({
    required this.primary,
    required this.secondary,
    required this.belly,
    required this.beak,
    required this.cheek,
    required this.eye,
    required this.accessory,
  });

  final Color primary;
  final Color secondary;
  final Color belly;
  final Color beak;
  final Color cheek;
  final Color eye;
  final Color accessory;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MiniMeFacePalette &&
            other.primary == primary &&
            other.secondary == secondary &&
            other.belly == belly &&
            other.beak == beak &&
            other.cheek == cheek &&
            other.eye == eye &&
            other.accessory == accessory;
  }

  @override
  int get hashCode =>
      Object.hash(primary, secondary, belly, beak, cheek, eye, accessory);
}

class CartoonFace extends StatelessWidget {
  const CartoonFace({
    super.key,
    required this.expression,
    required this.palette,
    this.size = 80,
    this.blink = 0,
    this.degradationLevel = 0,
    this.headDip = 0,
    this.wateryEyes = false,
    this.puffiness = 0,
    this.sickLevel = 0,
    this.coughOpen = 0,
    this.cryingLevel = 0,
  });

  final String expression;
  final MiniMeFacePalette palette;
  final double size;
  final double blink;
  final double degradationLevel;
  final double headDip;
  final bool wateryEyes;
  final double puffiness;
  final double sickLevel;
  final double coughOpen;
  final double cryingLevel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CartoonFacePainter(
          expression: expression,
          palette: palette,
          blink: blink.clamp(0.0, 1.0),
          degradationLevel: degradationLevel.clamp(0.0, 1.0),
          headDip: headDip,
          wateryEyes: wateryEyes,
          puffiness: puffiness.clamp(0.0, 1.0),
          sickLevel: sickLevel.clamp(0.0, 1.0),
          coughOpen: coughOpen.clamp(0.0, 1.0),
          cryingLevel: cryingLevel.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

class _CartoonFacePainter extends CustomPainter {
  const _CartoonFacePainter({
    required this.expression,
    required this.palette,
    required this.blink,
    required this.degradationLevel,
    required this.headDip,
    required this.wateryEyes,
    required this.puffiness,
    required this.sickLevel,
    required this.coughOpen,
    required this.cryingLevel,
  });

  final String expression;
  final MiniMeFacePalette palette;
  final double blink;
  final double degradationLevel;
  final double headDip;
  final bool wateryEyes;
  final double puffiness;
  final double sickLevel;
  final double coughOpen;
  final double cryingLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final isCoughing = coughOpen > 0.08;
    final isCrying = cryingLevel > 0.05 && !isCoughing;
    final isAngry = expression == 'angry' && !isCoughing;
    final blinkScale = 1 - (blink * 0.92);
    final eyeSpread = size.width * 0.19;
    final eyeY =
        size.height * (0.39 + degradationLevel * 0.014) + headDip * 0.01;
    final eyeWidth = size.width * 0.12;
    final eyeHeight = math.max(
      size.height * 0.018,
      size.height *
          (isAngry
              ? 0.105
              : isCoughing
              ? 0.105
              : isCrying
              ? 0.115
              : 0.15) *
          blinkScale,
    );
    final underEyeStrengthRaw = math.min(
      1.0,
      degradationLevel * 1.08 + puffiness * 0.18 + sickLevel * 0.34,
    );
    final underEyeStrength = isAngry ? 0.0 : underEyeStrengthRaw;

    final cheekPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              palette.cheek.withValues(alpha: 0.35 - degradationLevel * 0.18),
              palette.cheek.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(center.dx - size.width * 0.24, size.height * 0.54),
              radius: size.width * 0.12,
            ),
          );

    canvas.drawCircle(
      Offset(center.dx - size.width * 0.24, size.height * 0.54),
      size.width * 0.12,
      cheekPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.24, size.height * 0.54),
      size.width * 0.12,
      cheekPaint,
    );

    if (sickLevel > 0.04) {
      final sickWashPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF9CCDB0).withValues(alpha: sickLevel * 0.22),
                const Color(0xFF9CCDB0).withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * 0.48),
            );
      canvas.drawCircle(
        center.translate(0, size.height * 0.03),
        size.width * 0.46,
        sickWashPaint,
      );
    }

    final underEyePaint = Paint()
      ..color = const Color(
        0xFF53617F,
      ).withValues(alpha: 0.08 + underEyeStrength * 0.3)
      ..style = PaintingStyle.fill;
    final underEyeDeepPaint = Paint()
      ..color = const Color(
        0xFF34405A,
      ).withValues(alpha: underEyeStrength * 0.16)
      ..style = PaintingStyle.fill;
    if (underEyeStrength > 0.02) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx - eyeSpread, eyeY + size.height * 0.07),
          width: size.width * (0.16 + degradationLevel * 0.03),
          height:
              size.height *
              (0.055 + degradationLevel * 0.05 + puffiness * 0.02),
        ),
        underEyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + eyeSpread, eyeY + size.height * 0.07),
          width: size.width * (0.16 + degradationLevel * 0.03),
          height:
              size.height *
              (0.055 + degradationLevel * 0.05 + puffiness * 0.02),
        ),
        underEyePaint,
      );
      if (underEyeStrength > 0.18) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx - eyeSpread, eyeY + size.height * 0.074),
            width: size.width * (0.11 + degradationLevel * 0.02),
            height: size.height * (0.026 + degradationLevel * 0.03),
          ),
          underEyeDeepPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx + eyeSpread, eyeY + size.height * 0.074),
            width: size.width * (0.11 + degradationLevel * 0.02),
            height: size.height * (0.026 + degradationLevel * 0.03),
          ),
          underEyeDeepPaint,
        );
      }
    }

    final eyePaint = Paint()
      ..color = palette.eye
      ..style = PaintingStyle.fill;
    final eyeOutlinePaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.01;
    final eyeHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    final leftEyeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - eyeSpread, eyeY),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(size.width * 0.08),
    );
    final rightEyeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + eyeSpread, eyeY),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(size.width * 0.08),
    );

    canvas.drawRRect(leftEyeRect, eyePaint);
    canvas.drawRRect(rightEyeRect, eyePaint);
    canvas.drawRRect(leftEyeRect, eyeOutlinePaint);
    canvas.drawRRect(rightEyeRect, eyeOutlinePaint);

    if (blink < 0.5 && !isAngry && !isCoughing && !isCrying) {
      canvas.drawCircle(
        Offset(
          center.dx - eyeSpread - size.width * 0.014,
          eyeY - size.height * 0.03,
        ),
        size.width * 0.015,
        eyeHighlightPaint,
      );
      canvas.drawCircle(
        Offset(
          center.dx + eyeSpread - size.width * 0.014,
          eyeY - size.height * 0.03,
        ),
        size.width * 0.015,
        eyeHighlightPaint,
      );
    }

    if (wateryEyes && blink < 0.82 && !isAngry) {
      final tearPaint = Paint()
        ..color = const Color(0xFF79B9E8).withValues(alpha: 0.44)
        ..style = PaintingStyle.fill;
      final leftTear = Path()
        ..moveTo(center.dx - eyeSpread, eyeY + size.height * 0.055)
        ..quadraticBezierTo(
          center.dx - eyeSpread + size.width * 0.02,
          eyeY + size.height * 0.11,
          center.dx - eyeSpread - size.width * 0.004,
          eyeY + size.height * 0.132,
        )
        ..quadraticBezierTo(
          center.dx - eyeSpread - size.width * 0.03,
          eyeY + size.height * 0.1,
          center.dx - eyeSpread,
          eyeY + size.height * 0.055,
        )
        ..close();
      final rightTear = Path()
        ..moveTo(center.dx + eyeSpread, eyeY + size.height * 0.055)
        ..quadraticBezierTo(
          center.dx + eyeSpread + size.width * 0.02,
          eyeY + size.height * 0.11,
          center.dx + eyeSpread - size.width * 0.004,
          eyeY + size.height * 0.132,
        )
        ..quadraticBezierTo(
          center.dx + eyeSpread - size.width * 0.03,
          eyeY + size.height * 0.1,
          center.dx + eyeSpread,
          eyeY + size.height * 0.055,
        )
        ..close();
      canvas.drawPath(leftTear, tearPaint);
      canvas.drawPath(rightTear, tearPaint);
    }

    if (isCrying && blink < 0.86) {
      _drawCryingStreams(canvas, size, center, eyeSpread, eyeY, cryingLevel);
    }

    final muzzleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          center.dx,
          size.height * (0.6 + degradationLevel * 0.016),
        ),
        width: size.width * 0.42,
        height: size.height * 0.23,
      ),
      Radius.circular(size.width * 0.18),
    );
    final muzzlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.94), palette.belly],
      ).createShader(muzzleRect.outerRect);
    canvas.drawRRect(muzzleRect, muzzlePaint);

    final nosePaint = Paint()
      ..color = palette.eye
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, size.height * 0.55),
          width: size.width * 0.12,
          height: size.height * 0.08,
        ),
        Radius.circular(size.width * 0.05),
      ),
      nosePaint,
    );

    final mouthPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.024;

    canvas.drawLine(
      Offset(center.dx, size.height * 0.59),
      Offset(center.dx, size.height * 0.64),
      mouthPaint,
    );

    final mouthCenter = Offset(
      center.dx,
      size.height * (0.69 + degradationLevel * 0.02),
    );
    if (isCoughing) {
      final coughT = Curves.easeOutCubic.transform(coughOpen);
      final coughMouthPaint = Paint()
        ..color = palette.eye.withValues(alpha: 0.94)
        ..style = PaintingStyle.fill;
      final coughMouthStroke = Paint()
        ..color = palette.eye.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018
        ..strokeCap = StrokeCap.round;
      final mouthRect = Rect.fromCenter(
        center: mouthCenter.translate(size.width * 0.012, size.height * 0.018),
        width: size.width * (0.12 + coughT * 0.12),
        height: size.height * (0.08 + coughT * 0.12),
      );
      canvas.drawOval(mouthRect, coughMouthPaint);
      canvas.drawArc(
        Rect.fromCenter(
          center: mouthRect.center.translate(0, -mouthRect.height * 0.14),
          width: mouthRect.width * 0.72,
          height: mouthRect.height * 0.36,
        ),
        math.pi * 0.08,
        math.pi * 0.84,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.01
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(
          center.dx - size.width * 0.12,
          mouthCenter.dy - size.height * 0.08,
        ),
        Offset(
          center.dx - size.width * 0.03,
          mouthCenter.dy - size.height * 0.04,
        ),
        coughMouthStroke,
      );
      canvas.drawLine(
        Offset(
          center.dx + size.width * 0.12,
          mouthCenter.dy - size.height * 0.07,
        ),
        Offset(
          center.dx + size.width * 0.03,
          mouthCenter.dy - size.height * 0.035,
        ),
        coughMouthStroke,
      );
      _drawScaredBrows(canvas, size, center.translate(0, size.height * 0.01));
      return;
    }
    if (isCrying) {
      final cryT = cryingLevel.clamp(0.0, 1.0);
      final sobPaint = Paint()
        ..color = palette.eye.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..strokeCap = StrokeCap.round;
      final softMouthPaint = Paint()
        ..color = palette.eye.withValues(alpha: 0.66)
        ..style = PaintingStyle.fill;
      final mouthRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: mouthCenter.translate(0, size.height * (0.024 + cryT * 0.01)),
          width: size.width * (0.11 + cryT * 0.035),
          height: size.height * (0.034 + cryT * 0.026),
        ),
        Radius.circular(size.width * 0.04),
      );
      canvas.drawRRect(mouthRect, softMouthPaint);
      canvas.drawArc(
        Rect.fromCenter(
          center: mouthCenter.translate(0, size.height * 0.04),
          width: size.width * (0.2 + cryT * 0.025),
          height: size.height * 0.1,
        ),
        math.pi + 0.26,
        math.pi - 0.52,
        false,
        sobPaint,
      );
      _drawSadBrows(canvas, size, center);
      return;
    }
    switch (expression) {
      case 'happy':
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter,
            width: size.width * 0.2,
            height: size.height * 0.12,
          ),
          0.15,
          math.pi - 0.3,
          false,
          mouthPaint,
        );
        break;
      case 'affectionate':
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter.translate(0, -size.height * 0.012),
            width: size.width * 0.2,
            height: size.height * 0.11,
          ),
          0.12,
          math.pi - 0.24,
          false,
          mouthPaint,
        );
        _drawSoftBrows(canvas, size, center);
        _drawAffectionAccent(canvas, size, center);
        break;
      case 'surprised':
        final surprisedPaint = Paint()
          ..color = palette.eye.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.022;
        canvas.drawOval(
          Rect.fromCenter(
            center: mouthCenter.translate(0, -size.height * 0.005),
            width: size.width * 0.1,
            height: size.height * 0.15,
          ),
          surprisedPaint,
        );
        _drawRaisedBrows(canvas, size, center);
        break;
      case 'scared':
        final scaredPaint = Paint()
          ..color = palette.eye.withValues(alpha: 0.94)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.02;
        final scaredCenter = mouthCenter.translate(0, size.height * 0.012);
        final grimacePath = Path()
          ..moveTo(center.dx - size.width * 0.085, scaredCenter.dy)
          ..quadraticBezierTo(
            center.dx - size.width * 0.043,
            scaredCenter.dy - size.height * 0.024,
            center.dx,
            scaredCenter.dy,
          )
          ..quadraticBezierTo(
            center.dx + size.width * 0.043,
            scaredCenter.dy - size.height * 0.024,
            center.dx + size.width * 0.085,
            scaredCenter.dy,
          );
        canvas.drawPath(grimacePath, scaredPaint);
        final clenchPaint = Paint()
          ..color = palette.eye.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = size.width * 0.012;
        for (var i = -2; i <= 2; i++) {
          final x = center.dx + i * size.width * 0.028;
          canvas.drawLine(
            Offset(x, scaredCenter.dy - size.height * 0.013),
            Offset(x, scaredCenter.dy + size.height * 0.013),
            clenchPaint,
          );
        }
        _drawScaredStressMarks(canvas, size, center);
        _drawScaredBrows(canvas, size, center);
        break;
      case 'sad':
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter.translate(0, size.height * 0.05),
            width: size.width * 0.22,
            height: size.height * 0.11,
          ),
          math.pi + 0.28,
          math.pi - 0.56,
          false,
          mouthPaint,
        );
        break;
      case 'neutral':
        canvas.drawLine(
          Offset(center.dx - size.width * 0.075, mouthCenter.dy),
          Offset(center.dx + size.width * 0.075, mouthCenter.dy),
          mouthPaint,
        );
        break;
      case 'angry':
        final snarlY = mouthCenter.dy + size.height * 0.008;
        final left = center.dx - size.width * 0.1;
        final right = center.dx + size.width * 0.1;
        final top = snarlY - size.height * 0.018;
        final bottom = snarlY + size.height * 0.018;
        // Tight clenched shape avoids reading as sad while still feeling furious.
        final snarlBox = RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          Radius.circular(size.width * 0.012),
        );
        canvas.drawRRect(snarlBox, mouthPaint);
        final gritPaint = Paint()
          ..color = palette.eye.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = size.width * 0.011;
        for (var i = -2; i <= 2; i++) {
          final x = center.dx + i * size.width * 0.034;
          canvas.drawLine(Offset(x, top), Offset(x, bottom), gritPaint);
        }
        // Small downward-angled corners read as irritation.
        canvas.drawLine(
          Offset(left - size.width * 0.012, snarlY - size.height * 0.002),
          Offset(left + size.width * 0.01, snarlY + size.height * 0.01),
          mouthPaint,
        );
        canvas.drawLine(
          Offset(right + size.width * 0.012, snarlY - size.height * 0.002),
          Offset(right - size.width * 0.01, snarlY + size.height * 0.01),
          mouthPaint,
        );
        _drawAngryLids(canvas, size, center);
        _drawFurrowedBrows(canvas, size, center);
        break;
      case 'calm':
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter,
            width: size.width * 0.18,
            height: size.height * 0.08,
          ),
          0.28,
          math.pi - 0.58,
          false,
          mouthPaint,
        );
        break;
      default:
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter,
            width: size.width * 0.16,
            height: size.height * 0.05,
          ),
          0.24,
          math.pi - 0.5,
          false,
          mouthPaint,
        );
        break;
    }

    if (degradationLevel > 0.16) {
      final wrinklePaint = Paint()
        ..color = palette.eye.withValues(alpha: degradationLevel * 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx - eyeSpread, eyeY + size.height * 0.08),
          width: size.width * 0.14,
          height: size.height * 0.05,
        ),
        0.2,
        math.pi - 0.4,
        false,
        wrinklePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx + eyeSpread, eyeY + size.height * 0.08),
          width: size.width * 0.14,
          height: size.height * 0.05,
        ),
        0.2,
        math.pi - 0.4,
        false,
        wrinklePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx, size.height * 0.48),
          width: size.width * 0.18,
          height: size.height * 0.05,
        ),
        math.pi + 0.18,
        math.pi - 0.36,
        false,
        wrinklePaint,
      );
    }

    if (degradationLevel > 0.34) {
      final fatigueLinePaint = Paint()
        ..color = const Color(
          0xFF34405A,
        ).withValues(alpha: degradationLevel * 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.01
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx - eyeSpread, eyeY + size.height * 0.095),
          width: size.width * 0.16,
          height: size.height * 0.042,
        ),
        0.22,
        math.pi - 0.44,
        false,
        fatigueLinePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx + eyeSpread, eyeY + size.height * 0.095),
          width: size.width * 0.16,
          height: size.height * 0.042,
        ),
        0.22,
        math.pi - 0.44,
        false,
        fatigueLinePaint,
      );
    }
  }

  void _drawRaisedBrows(Canvas canvas, Size size, Offset center) {
    final browPaint = Paint()
      ..color = palette.eye
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.02;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx - size.width * 0.19, size.height * 0.22),
        width: size.width * 0.16,
        height: size.height * 0.06,
      ),
      math.pi + 0.2,
      math.pi - 0.4,
      false,
      browPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + size.width * 0.19, size.height * 0.22),
        width: size.width * 0.16,
        height: size.height * 0.06,
      ),
      math.pi + 0.2,
      math.pi - 0.4,
      false,
      browPaint,
    );
  }

  void _drawCryingStreams(
    Canvas canvas,
    Size size,
    Offset center,
    double eyeSpread,
    double eyeY,
    double progress,
  ) {
    final cryT = progress.clamp(0.0, 1.0);
    final streamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * (0.018 + cryT * 0.008)
      ..color = const Color(0xFF6AB7E8).withValues(alpha: 0.24 + cryT * 0.28);
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.006
      ..color = Colors.white.withValues(alpha: 0.2 + cryT * 0.18);
    final dropPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF7CC4EC).withValues(alpha: 0.3 + cryT * 0.24);
    final shinePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.38);

    void stream({required double side, required double phase}) {
      final x = center.dx + side * eyeSpread;
      final wobble =
          math.sin((cryT + phase) * math.pi * 2) * size.width * 0.006;
      final path = Path()
        ..moveTo(x + side * size.width * 0.006, eyeY + size.height * 0.045)
        ..cubicTo(
          x + side * size.width * 0.032 + wobble,
          eyeY + size.height * 0.13,
          x + side * size.width * 0.024 - wobble,
          eyeY + size.height * 0.22,
          x + side * size.width * 0.032,
          eyeY + size.height * (0.3 + cryT * 0.04),
        );
      canvas.drawPath(path, streamPaint);
      canvas.drawPath(path, highlightPaint);

      for (var i = 0; i < 2; i++) {
        final fall = ((cryT * 1.05 + phase + i * 0.43) % 1.0);
        final dropY = eyeY + size.height * (0.09 + fall * 0.34);
        final dropX =
            x +
            side * size.width * (0.026 + math.sin(fall * math.pi * 2) * 0.008);
        final radius = size.width * (0.012 + (1 - fall) * 0.005);
        final tear = Path()
          ..moveTo(dropX, dropY - radius * 1.35)
          ..quadraticBezierTo(
            dropX + side * radius * 1.05,
            dropY - radius * 0.2,
            dropX,
            dropY + radius * 1.2,
          )
          ..quadraticBezierTo(
            dropX - side * radius * 1.05,
            dropY - radius * 0.2,
            dropX,
            dropY - radius * 1.35,
          )
          ..close();
        canvas.drawPath(tear, dropPaint);
        canvas.drawCircle(
          Offset(dropX - side * radius * 0.28, dropY - radius * 0.28),
          radius * 0.22,
          shinePaint,
        );
      }
    }

    stream(side: -1, phase: 0.08);
    stream(side: 1, phase: 0.42);

    final splashPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF7CC4EC).withValues(alpha: cryT * 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - size.width * 0.18, size.height * 0.78),
        width: size.width * (0.08 + cryT * 0.028),
        height: size.height * 0.018,
      ),
      splashPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + size.width * 0.18, size.height * 0.78),
        width: size.width * (0.08 + cryT * 0.028),
        height: size.height * 0.018,
      ),
      splashPaint,
    );
  }

  void _drawSadBrows(Canvas canvas, Size size, Offset center) {
    final browPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.74)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.018;

    canvas.drawLine(
      Offset(center.dx - size.width * 0.27, size.height * 0.265),
      Offset(center.dx - size.width * 0.13, size.height * 0.292),
      browPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.27, size.height * 0.265),
      Offset(center.dx + size.width * 0.13, size.height * 0.292),
      browPaint,
    );
  }

  void _drawScaredBrows(Canvas canvas, Size size, Offset center) {
    final browPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.96)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.021;

    // Inner corners lift to read as fear/worry rather than surprise.
    canvas.drawLine(
      Offset(center.dx - size.width * 0.275, size.height * 0.258),
      Offset(center.dx - size.width * 0.13, size.height * 0.224),
      browPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.275, size.height * 0.258),
      Offset(center.dx + size.width * 0.13, size.height * 0.224),
      browPaint,
    );

    final worryPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.013;
    canvas.drawLine(
      Offset(center.dx - size.width * 0.022, size.height * 0.275),
      Offset(center.dx - size.width * 0.01, size.height * 0.31),
      worryPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.022, size.height * 0.275),
      Offset(center.dx + size.width * 0.01, size.height * 0.31),
      worryPaint,
    );
  }

  void _drawScaredStressMarks(Canvas canvas, Size size, Offset center) {
    final stressPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.012;

    canvas.drawLine(
      Offset(center.dx - size.width * 0.275, size.height * 0.42),
      Offset(center.dx - size.width * 0.245, size.height * 0.47),
      stressPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.275, size.height * 0.42),
      Offset(center.dx + size.width * 0.245, size.height * 0.47),
      stressPaint,
    );
  }

  void _drawAngryLids(Canvas canvas, Size size, Offset center) {
    final lidPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.024;

    canvas.drawLine(
      Offset(center.dx - size.width * 0.285, size.height * 0.305),
      Offset(center.dx - size.width * 0.12, size.height * 0.347),
      lidPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.285, size.height * 0.305),
      Offset(center.dx + size.width * 0.12, size.height * 0.347),
      lidPaint,
    );
  }

  void _drawSoftBrows(Canvas canvas, Size size, Offset center) {
    final browPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.018;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx - size.width * 0.19, size.height * 0.275),
        width: size.width * 0.14,
        height: size.height * 0.05,
      ),
      math.pi + 0.35,
      math.pi - 0.7,
      false,
      browPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + size.width * 0.19, size.height * 0.275),
        width: size.width * 0.14,
        height: size.height * 0.05,
      ),
      math.pi + 0.35,
      math.pi - 0.7,
      false,
      browPaint,
    );
  }

  void _drawFurrowedBrows(Canvas canvas, Size size, Offset center) {
    final browPaint = Paint()
      ..color = palette.eye
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.028;

    canvas.drawLine(
      Offset(center.dx - size.width * 0.295, size.height * 0.235),
      Offset(center.dx - size.width * 0.14, size.height * 0.302),
      browPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.14, size.height * 0.302),
      Offset(center.dx + size.width * 0.295, size.height * 0.235),
      browPaint,
    );

    final furrowPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.016;
    canvas.drawLine(
      Offset(center.dx - size.width * 0.03, size.height * 0.304),
      Offset(center.dx, size.height * 0.352),
      furrowPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.03, size.height * 0.304),
      Offset(center.dx, size.height * 0.352),
      furrowPaint,
    );
  }

  void _drawAffectionAccent(Canvas canvas, Size size, Offset center) {
    final accentPaint = Paint()
      ..color = palette.cheek.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - size.width * 0.18, size.height * 0.57),
      size.width * 0.028,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.18, size.height * 0.57),
      size.width * 0.028,
      accentPaint,
    );

    final heartPath = Path();
    final heartCenter = Offset(
      center.dx + size.width * 0.21,
      size.height * 0.46,
    );
    final heartSize = size.width * 0.04;
    heartPath
      ..moveTo(heartCenter.dx, heartCenter.dy + heartSize * 0.8)
      ..cubicTo(
        heartCenter.dx - heartSize * 1.2,
        heartCenter.dy + heartSize * 0.15,
        heartCenter.dx - heartSize * 0.9,
        heartCenter.dy - heartSize * 0.8,
        heartCenter.dx,
        heartCenter.dy - heartSize * 0.15,
      )
      ..cubicTo(
        heartCenter.dx + heartSize * 0.9,
        heartCenter.dy - heartSize * 0.8,
        heartCenter.dx + heartSize * 1.2,
        heartCenter.dy + heartSize * 0.15,
        heartCenter.dx,
        heartCenter.dy + heartSize * 0.8,
      )
      ..close();
    canvas.drawPath(heartPath, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _CartoonFacePainter oldDelegate) {
    return oldDelegate.expression != expression ||
        oldDelegate.palette != palette ||
        oldDelegate.blink != blink ||
        oldDelegate.degradationLevel != degradationLevel ||
        oldDelegate.headDip != headDip ||
        oldDelegate.wateryEyes != wateryEyes ||
        oldDelegate.puffiness != puffiness ||
        oldDelegate.sickLevel != sickLevel ||
        oldDelegate.coughOpen != coughOpen ||
        oldDelegate.cryingLevel != cryingLevel;
  }
}
