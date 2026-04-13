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
  });

  final String expression;
  final MiniMeFacePalette palette;
  final double size;
  final double blink;
  final double degradationLevel;
  final double headDip;
  final bool wateryEyes;
  final double puffiness;

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
  });

  final String expression;
  final MiniMeFacePalette palette;
  final double blink;
  final double degradationLevel;
  final double headDip;
  final bool wateryEyes;
  final double puffiness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final blinkScale = 1 - (blink * 0.92);
    final eyeSpread = size.width * 0.19;
    final eyeY =
        size.height * (0.39 + degradationLevel * 0.014) + headDip * 0.01;
    final eyeWidth = size.width * 0.12;
    final eyeHeight = math.max(
      size.height * 0.018,
      size.height * 0.15 * blinkScale,
    );
    final underEyeStrength = math.min(
      1.0,
      degradationLevel * 1.08 + puffiness * 0.18,
    );

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

    if (blink < 0.5) {
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

    if (wateryEyes && blink < 0.82) {
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
      case 'angry':
        canvas.drawLine(
          Offset(
            center.dx - size.width * 0.08,
            mouthCenter.dy + size.height * 0.01,
          ),
          Offset(
            center.dx + size.width * 0.08,
            mouthCenter.dy - size.height * 0.01,
          ),
          mouthPaint,
        );
        _drawBrows(canvas, size, center, intensity: 1);
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

  void _drawBrows(
    Canvas canvas,
    Size size,
    Offset center, {
    required double intensity,
  }) {
    final browPaint = Paint()
      ..color = palette.eye
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.024;

    canvas.drawLine(
      Offset(
        center.dx - size.width * 0.27,
        size.height * 0.29 + intensity * size.height * 0.015,
      ),
      Offset(center.dx - size.width * 0.15, size.height * 0.25),
      browPaint,
    );
    canvas.drawLine(
      Offset(center.dx + size.width * 0.15, size.height * 0.25),
      Offset(
        center.dx + size.width * 0.27,
        size.height * 0.29 + intensity * size.height * 0.015,
      ),
      browPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CartoonFacePainter oldDelegate) {
    return oldDelegate.expression != expression ||
        oldDelegate.palette != palette ||
        oldDelegate.blink != blink ||
        oldDelegate.degradationLevel != degradationLevel ||
        oldDelegate.headDip != headDip ||
        oldDelegate.wateryEyes != wateryEyes ||
        oldDelegate.puffiness != puffiness;
  }
}
