import 'package:flutter/material.dart';
import 'package:safedrive/core/theme/theme_service.dart';

class FaceGuidePainter extends CustomPainter {
  final bool isActive;

  const FaceGuidePainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final faceWidth = (size.width * 0.72).clamp(230.0, 340.0).toDouble();
    final faceHeight = (size.height * 0.37).clamp(265.0, 355.0).toDouble();
    final faceLeft = (size.width - faceWidth) / 2;
    final faceTop = size.height * 0.45 - faceHeight / 2;
    final faceRight = faceLeft + faceWidth;
    final faceBottom = faceTop + faceHeight;
    final centerX = size.width / 2;

    final facePath = Path()
      ..moveTo(centerX, faceTop)
      ..cubicTo(
        faceLeft + faceWidth * 0.18,
        faceTop,
        faceLeft + faceWidth * 0.09,
        faceTop + faceHeight * 0.17,
        faceLeft + faceWidth * 0.12,
        faceTop + faceHeight * 0.4,
      )
      ..cubicTo(
        faceLeft + faceWidth * 0.15,
        faceTop + faceHeight * 0.73,
        faceLeft + faceWidth * 0.29,
        faceBottom - faceHeight * 0.08,
        centerX - faceWidth * 0.16,
        faceBottom - faceHeight * 0.04,
      )
      ..cubicTo(
        centerX - faceWidth * 0.08,
        faceBottom + faceHeight * 0.005,
        centerX + faceWidth * 0.08,
        faceBottom + faceHeight * 0.005,
        centerX + faceWidth * 0.16,
        faceBottom - faceHeight * 0.04,
      )
      ..cubicTo(
        faceRight - faceWidth * 0.29,
        faceBottom - faceHeight * 0.08,
        faceRight - faceWidth * 0.15,
        faceTop + faceHeight * 0.73,
        faceRight - faceWidth * 0.12,
        faceTop + faceHeight * 0.48,
      )
      ..cubicTo(
        faceRight - faceWidth * 0.09,
        faceTop + faceHeight * 0.17,
        faceRight - faceWidth * 0.18,
        faceTop,
        centerX,
        faceTop,
      )
      ..close();

    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(facePath, Offset.zero);
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    final guidePaint = Paint()
      ..color = isActive ? AppColors.brand : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(facePath, guidePaint);
  }

  @override
  bool shouldRepaint(covariant FaceGuidePainter oldDelegate) =>
      oldDelegate.isActive != isActive;
}
