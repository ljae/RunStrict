import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class EnergyHoldButton extends StatefulWidget {
  final IconData icon; // Removed label
  final VoidCallback onComplete;
  final Color baseColor;
  final Color fillColor;
  final Color iconColor;
  final Duration duration;
  final bool isHoldRequired;
  final double height;
  final double borderRadius;
  final String? label; // Made label optional

  const EnergyHoldButton({
    super.key,
    required this.icon,
    required this.onComplete,
    required this.baseColor,
    required this.fillColor,
    required this.iconColor,
    this.label, // Optional
    this.duration = const Duration(milliseconds: 1500),
    this.isHoldRequired = true,
    this.height = 80.0,
    this.borderRadius = 40.0, // More rounded by default
  });

  @override
  State<EnergyHoldButton> createState() => _EnergyHoldButtonState();
}

class _EnergyHoldButtonState extends State<EnergyHoldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        debugPrint(
          '>>> EnergyHoldButton: Animation COMPLETED, _isCompleted=$_isCompleted',
        );
        if (!_isCompleted) {
          // Trigger rebuild to lock visual state
          setState(() {
            _isCompleted = true;
          });
          debugPrint(
            '>>> EnergyHoldButton: Set _isCompleted=true, calling onComplete',
          );
          HapticFeedback.heavyImpact();
          widget.onComplete();
          // Button stays filled (locked) to prevent double-trigger.
          // Parent widget is expected to replace this button or navigate away.
        } else {
          debugPrint('>>> EnergyHoldButton: BLOCKED (already completed)');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    debugPrint(
      '>>> EnergyHoldButton._handleTapDown: _isCompleted=$_isCompleted',
    );
    if (_isCompleted) {
      debugPrint('>>> EnergyHoldButton._handleTapDown: BLOCKED (completed)');
      return;
    }

    if (widget.isHoldRequired) {
      _controller.forward();
      HapticFeedback.selectionClick();
    } else {
      // Visual tap effect
      _controller.animateTo(0.1, duration: const Duration(milliseconds: 100));
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isCompleted) return;

    if (widget.isHoldRequired) {
      if (!_controller.isCompleted) {
        _controller.reverse();
      }
    } else {
      _controller.reverse();
      HapticFeedback.mediumImpact();
      widget.onComplete();
    }
  }

  void _handleTapCancel() {
    if (_isCompleted) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // When completed, wrap in IgnorePointer to block ALL touch events
    return IgnorePointer(
      ignoring: _isCompleted,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.baseColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.fillColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Background Fill Animation
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Force full width if completed to visually lock it
                  final value = _isCompleted ? 1.0 : _controller.value;
                  return FractionallySizedBox(
                    widthFactor: value,
                    alignment: Alignment.centerLeft,
                    child: Container(color: widget.fillColor.withOpacity(0.8)),
                  );
                },
              ),

              // Content
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 32,
                    ), // Larger icon
                    if (widget.label != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        widget.label!,
                        style: GoogleFonts.outfit(
                          color: widget.iconColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Hold Hint (Only visible when not holding and required)
              if (widget.isHoldRequired)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: (1.0 - _controller.value * 2).clamp(0.0, 1.0),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12.0,
                          ), // More padding
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: widget.iconColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
