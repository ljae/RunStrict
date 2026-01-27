import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/sponsor.dart';

class SponsorLogoPainter extends CustomPainter {
  final Sponsor sponsor;
  final bool isSelected;

  SponsorLogoPainter({required this.sponsor, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final Paint bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [sponsor.primaryColor, sponsor.secondaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3.0 : 1.0;

    // Draw Shape based on Tier
    Path path = Path();
    switch (sponsor.tier) {
      case SponsorTier.legendary:
        _drawHexagon(path, center, radius * 0.9);
        // Add glow for legendary
        if (isSelected) {
          canvas.drawPath(
            path,
            Paint()
              ..color = sponsor.primaryColor.withValues(alpha: 0.6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
        }
        break;
      case SponsorTier.epic:
        _drawShield(path, center, radius * 0.9);
        break;
      case SponsorTier.rare:
        _drawDiamond(path, center, radius * 0.9);
        break;
      case SponsorTier.common:
        _drawCircle(path, center, radius * 0.9);
        break;
    }

    canvas.drawPath(path, bgPaint);
    canvas.drawPath(path, borderPaint);

    // Draw Icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: sponsor.logoIcon,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius, // Scale icon to radius
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 2,
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawHexagon(Path path, Offset center, double radius) {
    for (int i = 0; i < 6; i++) {
      double angle = (math.pi / 3) * i;
      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }

  void _drawShield(Path path, Offset center, double radius) {
    path.moveTo(center.dx - radius * 0.8, center.dy - radius * 0.8);
    path.lineTo(center.dx + radius * 0.8, center.dy - radius * 0.8);
    path.lineTo(center.dx + radius * 0.8, center.dy);
    path.quadraticBezierTo(
      center.dx,
      center.dy + radius * 1.2,
      center.dx,
      center.dy + radius * 1.2,
    );
    path.quadraticBezierTo(
      center.dx - radius * 0.8,
      center.dy,
      center.dx - radius * 0.8,
      center.dy,
    );
    path.close();
  }

  void _drawDiamond(Path path, Offset center, double radius) {
    path.moveTo(center.dx, center.dy - radius);
    path.lineTo(center.dx + radius, center.dy);
    path.lineTo(center.dx, center.dy + radius);
    path.lineTo(center.dx - radius, center.dy);
    path.close();
  }

  void _drawCircle(Path path, Offset center, double radius) {
    path.addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldRepaint(covariant SponsorLogoPainter oldDelegate) {
    return oldDelegate.sponsor != sponsor ||
        oldDelegate.isSelected != isSelected;
  }
}
