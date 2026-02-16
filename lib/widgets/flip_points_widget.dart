import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/points_service.dart';

/// A mechanical flip counter widget displaying accumulated flip points.
///
/// Features:
/// - Airport departure board style flip animation for each digit
/// - Staggered animation when multiple digits change
/// - Settlement animation at 12:00 PM with all pending points
/// - Subtle "+" indicator during point additions
class FlipPointsWidget extends StatefulWidget {
  /// The points service providing point data.
  final PointsService pointsService;

  /// Team color for accent
  final Color accentColor;

  /// Whether to show compact version
  final bool compact;

  const FlipPointsWidget({
    super.key,
    required this.pointsService,
    this.accentColor = AppTheme.electricBlue,
    this.compact = true,
  });

  @override
  State<FlipPointsWidget> createState() => _FlipPointsWidgetState();
}

class _FlipPointsWidgetState extends State<FlipPointsWidget>
    with TickerProviderStateMixin {
  late int _displayedPoints;
  late int _targetPoints;
  bool _isAnimating = false;

  // Animation controllers for each digit position (max 6 digits = 999,999)
  final List<AnimationController> _digitControllers = [];
  final List<Animation<double>> _digitAnimations = [];

  // Plus indicator animation
  late AnimationController _plusController;
  late Animation<double> _plusAnimation;

  // Scale bounce animation
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _displayedPoints = widget.pointsService.todayFlipPoints;
    _targetPoints = _displayedPoints;

    // Initialize digit controllers (6 digits max)
    for (int i = 0; i < 6; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _digitControllers.add(controller);
      _digitAnimations.add(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
      );
    }

    // Plus indicator animation
    _plusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _plusAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_plusController);

    // Scale bounce: 1.0 → 1.12 → 1.0 with elasticOut
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 30),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_scaleController);

    // Listen for point changes
    widget.pointsService.addListener(_onPointsChanged);

    // Check for pending settlement points
    _checkPendingPoints();
  }

  @override
  void dispose() {
    widget.pointsService.removeListener(_onPointsChanged);
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    _plusController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _checkPendingPoints() {
    final newPoints = widget.pointsService.todayFlipPoints;
    if (newPoints != _displayedPoints) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _animateToPoints(newPoints);
        }
      });
    }
  }

  void _onPointsChanged() {
    final newPoints = widget.pointsService.todayFlipPoints;
    if (newPoints != _displayedPoints) {
      _targetPoints = newPoints;
      if (!_isAnimating) {
        _animateToPoints(newPoints);
      }
    }
  }

  void _animateToPoints(int newPoints) {
    if (_isAnimating) return;

    _targetPoints = newPoints;

    setState(() {
      _isAnimating = true;
    });

    // Show plus indicator
    _plusController.forward(from: 0);

    // Trigger scale bounce
    _scaleController.forward(from: 0);

    // Calculate which digits need to change
    final oldDigits = _getDigits(_displayedPoints);
    final newDigits = _getDigits(_targetPoints);

    // Stagger the digit animations from right to left
    int delay = 0;
    for (int i = newDigits.length - 1; i >= 0; i--) {
      final oldDigit = i < oldDigits.length ? oldDigits[i] : 0;
      final newDigit = newDigits[i];

      if (oldDigit != newDigit || i >= oldDigits.length) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted && i < _digitControllers.length) {
            _digitControllers[i].forward(from: 0);
          }
        });
        delay += 80; // Stagger by 80ms
      }
    }

    // Complete animation after all digits have flipped
    Future.delayed(Duration(milliseconds: delay + 400), () {
      if (mounted) {
        setState(() {
          _displayedPoints = _targetPoints;
          _isAnimating = false;
        });

        // Check if more points arrived during animation (via _onPointsChanged updating _targetPoints)
        final latestPoints = widget.pointsService.todayFlipPoints;
        if (latestPoints != _displayedPoints) {
          _targetPoints = latestPoints;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && !_isAnimating) {
              _animateToPoints(_targetPoints);
            }
          });
        }
      }
    });
  }

  List<int> _getDigits(int value) {
    if (value == 0) return [0];
    final digits = <int>[];
    var remaining = value;
    while (remaining > 0) {
      digits.insert(0, remaining % 10);
      remaining ~/= 10;
    }
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final displayDigits = _getDigits(_displayedPoints);
    final targetDigits = _isAnimating
        ? _getDigits(_targetPoints)
        : displayDigits;

    // Ensure both have same length for animation
    final maxLen = math.max(displayDigits.length, targetDigits.length);
    while (displayDigits.length < maxLen) {
      displayDigits.insert(0, 0);
    }
    while (targetDigits.length < maxLen) {
      targetDigits.insert(0, 0);
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        final scaleValue = _scaleAnimation.value;

        return Transform.scale(
          scale: scaleValue,
          child: Container(
            height: widget.compact ? 32 : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 4 : 10,
              vertical: widget.compact ? 0 : 6,
            ),
            // Removed outer decoration for minimal look
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hex icon instead of "FP" text
          SizedBox(
            width: widget.compact ? 14 : 16,
            height: widget.compact ? 14 : 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Filled background (semi-transparent)
                Icon(
                  Icons.hexagon,
                  size: widget.compact ? 14 : 16,
                  color: widget.accentColor.withValues(alpha: 0.3),
                ),
                // Outline border (more opaque)
                Icon(
                  Icons.hexagon_outlined,
                  size: widget.compact ? 14 : 16,
                  color: widget.accentColor.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Animated digits
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(maxLen, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _FlipDigit(
                  currentDigit: displayDigits[index],
                  nextDigit: targetDigits[index],
                  animation: index < _digitAnimations.length
                      ? _digitAnimations[index]
                      : null,
                  isAnimating: _isAnimating,
                  compact: widget.compact,
                  accentColor: widget.accentColor,
                ),
              );
            }),
          ),

          // Plus indicator (animated)
          AnimatedBuilder(
            animation: _plusAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _plusAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, -4 * (1 - _plusAnimation.value)),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '+',
                      style: GoogleFonts.bebasNeue(
                        fontSize: widget.compact ? 12 : 14,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Individual flip digit with mechanical animation.
class _FlipDigit extends StatelessWidget {
  final int currentDigit;
  final int nextDigit;
  final Animation<double>? animation;
  final bool isAnimating;
  final bool compact;
  final Color accentColor;

  const _FlipDigit({
    required this.currentDigit,
    required this.nextDigit,
    this.animation,
    required this.isAnimating,
    required this.compact,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 14.0 : 16.0;
    final digitWidth = compact ? 10.0 : 12.0;
    final digitHeight = compact ? 18.0 : 22.0;

    if (animation == null || !isAnimating || currentDigit == nextDigit) {
      // Static digit
      return _buildDigitContainer(
        digit: isAnimating ? nextDigit : currentDigit,
        fontSize: fontSize,
        width: digitWidth,
        height: digitHeight,
      );
    }

    // Animated flip digit
    return AnimatedBuilder(
      animation: animation!,
      builder: (context, child) {
        final progress = animation!.value;

        return SizedBox(
          width: digitWidth,
          height: digitHeight,
          child: Stack(
            children: [
              // Bottom half (next digit) - always visible
              Positioned.fill(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 0.5,
                    child: _buildDigitText(nextDigit, fontSize),
                  ),
                ),
              ),

              // Top half flipping
              if (progress < 0.5)
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX(progress * math.pi),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.5,
                        child: _buildDigitText(currentDigit, fontSize),
                      ),
                    ),
                  ),
                ),

              // Bottom half flipping (appears after halfway)
              if (progress >= 0.5)
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX((1 - progress) * math.pi),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: 0.5,
                        child: _buildDigitText(nextDigit, fontSize),
                      ),
                    ),
                  ),
                ),

              // Top half (current digit) - always visible until flip completes
              if (progress < 0.5)
                Positioned.fill(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.5,
                      child: Opacity(
                        opacity: (1 - (progress * 2)).clamp(0.0, 1.0),
                        child: _buildDigitText(currentDigit, fontSize),
                      ),
                    ),
                  ),
                ),

              // Horizontal line (split effect)
              Positioned(
                left: 0,
                right: 0,
                top: digitHeight / 2 - 0.5,
                child: Container(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDigitContainer({
    required int digit,
    required double fontSize,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: _buildDigitText(digit, fontSize),
    );
  }

  Widget _buildDigitText(int digit, double fontSize) {
    return Text(
      digit.toString(),
      style: GoogleFonts.bebasNeue(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: AppTheme.textPrimary,
        height: 1.0,
      ),
    );
  }
}

/// Compact version showing just the number with flip icon
class FlipPointsCompact extends StatelessWidget {
  final int points;
  final Color accentColor;

  const FlipPointsCompact({
    super.key,
    required this.points,
    this.accentColor = AppTheme.electricBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.flip_rounded,
          size: 12,
          color: accentColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          PointsService.formatPoints(points),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
