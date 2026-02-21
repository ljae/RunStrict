import 'package:flutter/material.dart';

/// A minimal, professional glowing location marker for maps
/// Features a bright central point with pulsing glow rings
/// In navigation mode, shows a directional momentum trail behind the ball
class GlowingLocationMarker extends StatefulWidget {
  final Color accentColor;
  final double size;
  final bool enablePulse;
  final bool showMomentumTrail; // Shows directional glow effect

  const GlowingLocationMarker({
    super.key,
    required this.accentColor,
    this.size = 24.0,
    this.enablePulse = true,
    this.showMomentumTrail = false,
  });

  @override
  State<GlowingLocationMarker> createState() => _GlowingLocationMarkerState();
}

class _GlowingLocationMarkerState extends State<GlowingLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Smooth pulsing scale animation
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Fade out as it expands
    _opacityAnimation = Tween<double>(
      begin: 0.8,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.enablePulse) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 3,
      height: widget.size * 3,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _GlowingLocationPainter(
              accentColor: widget.accentColor,
              pulseScale: _pulseAnimation.value,
              pulseOpacity: _opacityAnimation.value,
              showMomentumTrail: widget.showMomentumTrail,
            ),
          );
        },
      ),
    );
  }
}

class _GlowingLocationPainter extends CustomPainter {
  final Color accentColor;
  final double pulseScale;
  final double pulseOpacity;
  final bool showMomentumTrail;

  _GlowingLocationPainter({
    required this.accentColor,
    required this.pulseScale,
    required this.pulseOpacity,
    this.showMomentumTrail = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 6;

    // Draw momentum trail (extends downward/behind the ball in navigation mode)
    // Since the map rotates so forward is UP, the trail should extend DOWN
    if (showMomentumTrail) {
      // Create a gradient trail extending downward (behind the moving ball)
      final trailLength = baseRadius * 4.0;
      final trailWidth = baseRadius * 1.8;

      // Multiple fading ovals to create smooth trail effect
      for (int i = 0; i < 5; i++) {
        final progress = i / 5.0;
        final yOffset = trailLength * progress * 0.8;
        final scale = 1.0 - (progress * 0.6); // Shrink as it goes back
        final opacity = 0.3 * (1.0 - progress); // Fade out

        final trailPaint = Paint()
          ..color = accentColor.withValues(alpha: opacity)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + (progress * 8));

        final trailCenter = Offset(center.dx, center.dy + yOffset);
        canvas.drawOval(
          Rect.fromCenter(
            center: trailCenter,
            width: trailWidth * scale,
            height: baseRadius * scale * 1.5,
          ),
          trailPaint,
        );
      }

      // Add a subtle "speed lines" effect - soft streaks
      final speedLinePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      for (int i = -1; i <= 1; i++) {
        final xOffset = i * baseRadius * 0.8;
        final path = Path()
          ..moveTo(center.dx + xOffset, center.dy + baseRadius * 0.5)
          ..lineTo(center.dx + xOffset * 0.8, center.dy + trailLength * 0.6);
        canvas.drawPath(path, speedLinePaint);
      }
    }

    // Draw expanding pulse ring
    if (pulseOpacity > 0) {
      final pulsePaint = Paint()
        ..color = accentColor.withValues(alpha: pulseOpacity * 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, baseRadius * pulseScale * 2.5, pulsePaint);
    }

    // Draw outer glow ring (static)
    final outerGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, baseRadius * 2.2, outerGlowPaint);

    // Draw middle glow ring
    final middleGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, baseRadius * 1.5, middleGlowPaint);

    // Draw inner colored ring
    final innerRingPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, baseRadius * 1.2, innerRingPaint);

    // Draw bright white core with subtle shadow
    final coreShadowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(center, baseRadius * 0.9, coreShadowPaint);

    // Draw bright white core
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, baseRadius * 0.7, corePaint);

    // Add subtle highlight for depth (moved up for "forward" feel in nav mode)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final highlightOffset = Offset(
      center.dx - baseRadius * 0.15,
      center.dy - baseRadius * 0.25, // Slightly more up for forward momentum
    );

    canvas.drawCircle(highlightOffset, baseRadius * 0.3, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowingLocationPainter oldDelegate) {
    return oldDelegate.pulseScale != pulseScale ||
        oldDelegate.pulseOpacity != pulseOpacity ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.showMomentumTrail != showMomentumTrail;
  }
}
