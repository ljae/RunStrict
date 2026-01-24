import 'package:flutter/material.dart';

/// Pulsing animation overlay for hexes that can be captured.
///
/// Animates scale from 1.0x to 1.2x with a 2-second period
/// using ease-in-out curve. Used on the map to highlight
/// hexes within capture range.
class CapturableHexPulse extends StatefulWidget {
  /// The color of the pulse (typically the runner's team color).
  final Color color;

  /// Size of the hex indicator.
  final double size;

  /// Child widget to wrap with the pulse effect.
  final Widget? child;

  const CapturableHexPulse({
    super.key,
    required this.color,
    this.size = 40.0,
    this.child,
  });

  @override
  State<CapturableHexPulse> createState() => _CapturableHexPulseState();
}

class _CapturableHexPulseState extends State<CapturableHexPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child:
          widget.child ??
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(0.3),
              border: Border.all(
                color: widget.color.withOpacity(0.7),
                width: 2.0,
              ),
            ),
          ),
    );
  }
}
