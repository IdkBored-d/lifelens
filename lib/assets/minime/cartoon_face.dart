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
}

/// Draws a mascot-style Mini-Me face that feels more like a companion than a
/// human head. The surrounding body and accessories are rendered in the avatar.
class CartoonFace extends StatelessWidget {
  const CartoonFace({
    super.key,
    required this.expression,
    required this.palette,
    this.size = 80,
    this.blink = 0,
  });

  final String expression;
  final MiniMeFacePalette palette;
  final double size;
  final double blink;

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
  });

  final String expression;
  final MiniMeFacePalette palette;
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeY = size.height * 0.385;
    final eyeSpread = size.width * 0.195;
    final eyeWidth = size.width * 0.16;
    final eyeRadius = size.width * 0.07;
    final cheekRadius = size.width * 0.09;
    final blinkScale = 1 - (blink * 0.92);
    final eyeHeight = math.max(
      size.height * 0.012,
      eyeRadius * 2.05 * blinkScale,
    );

    final cheekPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              palette.cheek.withValues(alpha: 0.46),
              palette.cheek.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(center.dx - size.width * 0.26, size.height * 0.5),
              radius: cheekRadius,
            ),
          )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - size.width * 0.26, size.height * 0.5),
      cheekRadius,
      cheekPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.26, size.height * 0.5),
      cheekRadius,
      cheekPaint,
    );

    final eyeSocketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final eyePaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.eye.withValues(alpha: 0.96), palette.eye],
          ).createShader(
            Rect.fromLTWH(0, eyeY - eyeRadius, size.width, eyeRadius * 2.4),
          )
      ..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final eyeOutlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.01;

    final leftEyeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - eyeSpread, eyeY),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(eyeRadius * 1.2),
    );
    final rightEyeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + eyeSpread, eyeY),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Radius.circular(eyeRadius * 1.2),
    );

    canvas.drawRRect(leftEyeRect.inflate(size.width * 0.02), eyeSocketPaint);
    canvas.drawRRect(rightEyeRect.inflate(size.width * 0.02), eyeSocketPaint);
    canvas.drawRRect(leftEyeRect, eyePaint);
    canvas.drawRRect(rightEyeRect, eyePaint);
    canvas.drawRRect(leftEyeRect, eyeOutlinePaint);
    canvas.drawRRect(rightEyeRect, eyeOutlinePaint);

    if (blink < 0.45) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            center.dx - eyeSpread - eyeRadius * 0.15,
            eyeY - eyeRadius * 0.18,
          ),
          width: eyeRadius * 0.4,
          height: eyeRadius * 0.28,
        ),
        highlightPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            center.dx + eyeSpread - eyeRadius * 0.15,
            eyeY - eyeRadius * 0.18,
          ),
          width: eyeRadius * 0.4,
          height: eyeRadius * 0.28,
        ),
        highlightPaint,
      );
    }

    final beakPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.18),
              palette.beak,
              palette.beak.withValues(alpha: 0.96),
            ],
          ).createShader(
            Rect.fromLTWH(
              center.dx - size.width * 0.1,
              size.height * 0.46,
              size.width * 0.2,
              size.height * 0.16,
            ),
          )
      ..style = PaintingStyle.fill;
    final beakLinePaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.012;
    final beakPath = Path()
      ..moveTo(center.dx, size.height * 0.46)
      ..lineTo(center.dx - size.width * 0.092, size.height * 0.555)
      ..quadraticBezierTo(
        center.dx,
        size.height * 0.61,
        center.dx + size.width * 0.092,
        size.height * 0.555,
      )
      ..close();
    canvas.drawPath(beakPath, beakPaint);
    canvas.drawLine(
      Offset(center.dx, size.height * 0.49),
      Offset(center.dx, size.height * 0.575),
      beakLinePaint,
    );

    final mouthPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.03;

    final mouthCenter = Offset(center.dx, size.height * 0.635);
    final mouthWidth = size.width * 0.22;
    switch (expression) {
      case 'happy':
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter,
            width: mouthWidth * 0.96,
            height: mouthWidth * 0.72,
          ),
          0.2,
          math.pi - 0.4,
          false,
          mouthPaint,
        );
        break;
      case 'sad':
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter.translate(0, size.height * 0.04),
            width: mouthWidth,
            height: mouthWidth * 0.58,
          ),
          math.pi + 0.3,
          math.pi - 0.6,
          false,
          mouthPaint,
        );
        break;
      case 'angry':
        canvas.drawLine(
          Offset(
            center.dx - mouthWidth * 0.36,
            mouthCenter.dy + size.height * 0.02,
          ),
          Offset(
            center.dx + mouthWidth * 0.36,
            mouthCenter.dy - size.height * 0.01,
          ),
          mouthPaint,
        );
        _drawBrows(canvas, size, center, tilt: 1);
        break;
      case 'calm':
        canvas.drawArc(
          Rect.fromCenter(
            center: mouthCenter.translate(0, size.height * 0.01),
            width: mouthWidth * 0.9,
            height: mouthWidth * 0.36,
          ),
          0.35,
          math.pi - 0.72,
          false,
          mouthPaint,
        );
        break;
      default:
        canvas.drawLine(
          Offset(center.dx - mouthWidth * 0.28, mouthCenter.dy),
          Offset(center.dx + mouthWidth * 0.28, mouthCenter.dy),
          mouthPaint,
        );
        break;
    }
  }

  void _drawBrows(
    Canvas canvas,
    Size size,
    Offset center, {
    required double tilt,
  }) {
    final browPaint = Paint()
      ..color = palette.eye.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..strokeCap = StrokeCap.round;

    final browY = size.height * 0.27;
    final spread = size.width * 0.19;
    canvas.drawLine(
      Offset(
        center.dx - spread - size.width * 0.05,
        browY + size.height * 0.015 * tilt,
      ),
      Offset(
        center.dx - spread + size.width * 0.045,
        browY - size.height * 0.015 * tilt,
      ),
      browPaint,
    );
    canvas.drawLine(
      Offset(
        center.dx + spread - size.width * 0.045,
        browY - size.height * 0.015 * tilt,
      ),
      Offset(
        center.dx + spread + size.width * 0.05,
        browY + size.height * 0.015 * tilt,
      ),
      browPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CartoonFacePainter oldDelegate) {
    return oldDelegate.expression != expression ||
        oldDelegate.palette != palette ||
        oldDelegate.blink != blink;
  }
}
