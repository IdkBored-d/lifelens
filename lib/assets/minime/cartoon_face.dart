import 'package:flutter/material.dart';

/// Draws a cartoon face for the MiniMe avatar, with different expressions.
/// Usage: CartoonFace(expression: 'happy', size: 80)
class CartoonFace extends StatelessWidget {
  final String expression; // e.g. 'happy', 'sad', 'neutral', 'angry', 'calm'
  final double size;

  const CartoonFace({
    super.key,
    required this.expression,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CartoonFacePainter(expression),
      ),
    );
  }
}

class _CartoonFacePainter extends CustomPainter {
  final String expression;
  _CartoonFacePainter(this.expression);

  @override
  void paint(Canvas canvas, Size size) {
    // Head base color (slightly more saturated, matches typical 3D skin)
    final headColor = const Color(0xFFFFE0B2);
    final outlineColor = Colors.brown.shade300;
    final shadowPaint = Paint()
      ..color = Colors.brown.withOpacity(0.10)
      ..style = PaintingStyle.fill;
    // Head shadow (bottom)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.98),
        width: size.width * 0.82,
        height: size.height * 0.22,
      ),
      shadowPaint,
    );
    // Head
    final headPaint = Paint()
      ..color = headColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(0, 0, size.width, size.height),
      headPaint,
    );
    // Head outline
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04;
    canvas.drawOval(
      Rect.fromLTWH(0, 0, size.width, size.height),
      outlinePaint,
    );
    // Eyes
    final eyeY = size.height * 0.42;
    final eyeXOffset = size.width * 0.22;
    final eyeRadius = size.width * 0.09;
    final irisRadius = size.width * 0.045;
    final eyeWhitePaint = Paint()..color = Colors.white;
    final irisPaint = Paint()..color = Colors.brown.shade700;
    final pupilPaint = Paint()..color = Colors.black;
    // Left eye
    final leftEye = Offset(size.width * 0.5 - eyeXOffset, eyeY);
    canvas.drawCircle(leftEye, eyeRadius, eyeWhitePaint);
    canvas.drawCircle(leftEye, irisRadius, irisPaint);
    canvas.drawCircle(leftEye, irisRadius * 0.45, pupilPaint);
    // Right eye
    final rightEye = Offset(size.width * 0.5 + eyeXOffset, eyeY);
    canvas.drawCircle(rightEye, eyeRadius, eyeWhitePaint);
    canvas.drawCircle(rightEye, irisRadius, irisPaint);
    canvas.drawCircle(rightEye, irisRadius * 0.45, pupilPaint);
    // Eye highlights
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.7);
    canvas.drawCircle(leftEye.translate(-eyeRadius * 0.2, -eyeRadius * 0.2), eyeRadius * 0.18, highlightPaint);
    canvas.drawCircle(rightEye.translate(-eyeRadius * 0.2, -eyeRadius * 0.2), eyeRadius * 0.18, highlightPaint);
    // Blush
    final blushPaint = Paint()..color = Colors.pinkAccent.withOpacity(0.18);
    canvas.drawOval(
      Rect.fromCenter(center: leftEye.translate(0, eyeRadius * 1.1), width: eyeRadius * 1.5, height: eyeRadius * 0.7),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightEye.translate(0, eyeRadius * 1.1), width: eyeRadius * 1.5, height: eyeRadius * 0.7),
      blushPaint,
    );
    // Mouth
    final mouthPaint = Paint()
      ..color = Colors.brown.shade700
      ..strokeWidth = size.width * 0.045
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mouthWidth = size.width * 0.32;
    final mouthY = size.height * 0.62;
    switch (expression) {
      case 'happy':
        canvas.drawArc(
          Rect.fromCenter(center: Offset(size.width / 2, mouthY), width: mouthWidth, height: mouthWidth * 0.7),
          0.1,
          3.0,
          false,
          mouthPaint,
        );
        break;
      case 'sad':
        canvas.drawArc(
          Rect.fromCenter(center: Offset(size.width / 2, mouthY + 8), width: mouthWidth, height: mouthWidth * 0.7),
          3.2,
          -3.0,
          false,
          mouthPaint,
        );
        break;
      case 'angry':
        // Frown
        canvas.drawArc(
          Rect.fromCenter(center: Offset(size.width / 2, mouthY + 4), width: mouthWidth, height: mouthWidth * 0.5),
          3.2,
          -3.0,
          false,
          mouthPaint,
        );
        // Eyebrows
        final browPaint = Paint()
          ..color = Colors.brown.shade700
          ..strokeWidth = size.width * 0.035
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(size.width * 0.5 - eyeXOffset - 6, eyeY - 10),
          Offset(size.width * 0.5 - eyeXOffset + 8, eyeY - 14),
          browPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.5 + eyeXOffset - 8, eyeY - 14),
          Offset(size.width * 0.5 + eyeXOffset + 6, eyeY - 10),
          browPaint,
        );
        break;
      case 'calm':
        // Flat mouth
        canvas.drawLine(
          Offset(size.width * 0.5 - mouthWidth / 2, mouthY),
          Offset(size.width * 0.5 + mouthWidth / 2, mouthY),
          mouthPaint,
        );
        break;
      case 'neutral':
      default:
        // Slight smile
        canvas.drawArc(
          Rect.fromCenter(center: Offset(size.width / 2, mouthY), width: mouthWidth, height: mouthWidth * 0.5),
          0.1,
          3.0,
          false,
          mouthPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
