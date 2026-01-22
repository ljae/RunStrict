import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Smooth camera controller with Flutter-level interpolation for car navigation-style tracking.
///
/// ## Key Design:
/// Uses AnimationController at 60fps for buttery-smooth camera movement.
/// This solves three critical problems with Mapbox's built-in animations:
///
/// 1. **Stuttering**: GPS arrives every ~1 second. Instead of jumping between
///    positions, we interpolate at 60fps for smooth gliding.
///
/// 2. **Spinning (Rotation)**: When bearing crosses 360°→0° boundary,
///    we use shortest-path rotation to prevent 340° reverse spins.
///
/// 3. **Rubber-band (Lag)**: Mapbox's easeTo uses easing curves that cause
///    acceleration/deceleration "jelly" effect. We use Curves.linear for
///    constant velocity movement.
///
/// ## Camera Effect:
/// - Map rotates so "forward" points UP on screen
/// - User appears in lower portion (chase camera view)
/// - 3D pitch creates depth perception
class SmoothCameraController {
  final MapboxMap mapboxMap;
  final TickerProvider? tickerProvider;

  // Camera parameters
  final double zoom;
  final double pitch;
  final EdgeInsets padding;
  final Duration animationDuration;

  // Animation controller for smooth interpolation
  AnimationController? _animController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _bearingAnimation;

  // Current state (actual values being rendered)
  double _currentLat = 0;
  double _currentLng = 0;
  double _currentBearing = 0;

  // Target state (where we're animating to)
  double _targetLat = 0;
  double _targetLng = 0;
  double _targetBearing = 0;

  bool _initialized = false;
  bool _isDisposed = false;
  bool _isAnimating = false;

  // Callback for debugging
  final void Function(String)? onDebug;

  SmoothCameraController({
    required this.mapboxMap,
    this.tickerProvider,
    this.zoom = 18.0,
    this.pitch = 60.0,
    this.padding = EdgeInsets.zero,
    this.animationDuration = const Duration(milliseconds: 800),
    this.onDebug,
  });

  /// Updates camera target. Called on each GPS update.
  /// Starts smooth interpolation from current position to new target.
  void updateTarget({
    required double latitude,
    required double longitude,
    required double bearing,
  }) {
    if (_isDisposed) {
      onDebug?.call('SmoothCamera: WARN - updateTarget called after dispose');
      return;
    }

    final normalizedBearing = _normalizeBearing(bearing);

    // First position - snap immediately (no animation)
    if (!_initialized) {
      _currentLat = latitude;
      _currentLng = longitude;
      _currentBearing = normalizedBearing;
      _targetLat = latitude;
      _targetLng = longitude;
      _targetBearing = normalizedBearing;
      _initialized = true;

      _applyCamera();
      onDebug?.call(
        'SmoothCamera: INIT at ($latitude, $longitude) bearing=${normalizedBearing.toStringAsFixed(1)}°',
      );
      return;
    }

    // Update target
    _targetLat = latitude;
    _targetLng = longitude;

    // Calculate shortest rotation path for bearing
    // Example: current=350°, target=10° → adjustedTarget=370° (20° clockwise)
    double bearingDiff = normalizedBearing - _currentBearing;
    if (bearingDiff > 180) bearingDiff -= 360;
    if (bearingDiff < -180) bearingDiff += 360;
    _targetBearing = _currentBearing + bearingDiff;

    onDebug?.call(
      'SmoothCamera: TARGET ($latitude, $longitude) bearing=${normalizedBearing.toStringAsFixed(1)}° '
      '(adjusted=${_targetBearing.toStringAsFixed(1)}°, diff=${bearingDiff.toStringAsFixed(1)}°)',
    );

    // Start interpolation animation
    _startInterpolation();
  }

  /// Starts the interpolation animation from current to target.
  void _startInterpolation() {
    if (_isDisposed) return;

    // If no ticker provider, fall back to direct camera update
    if (tickerProvider == null) {
      _currentLat = _targetLat;
      _currentLng = _targetLng;
      _currentBearing = _normalizeBearing(_targetBearing);
      _applyCamera();
      return;
    }

    // Stop any existing animation
    _animController?.stop();
    _animController?.dispose();

    // Create new animation controller
    _animController = AnimationController(
      vsync: tickerProvider!,
      duration: animationDuration,
    );

    // Create linear animations for lat, lng, bearing
    // Using Curves.linear for constant velocity (no rubber-band effect)
    _latAnimation = Tween<double>(
      begin: _currentLat,
      end: _targetLat,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.linear,
    ));

    _lngAnimation = Tween<double>(
      begin: _currentLng,
      end: _targetLng,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.linear,
    ));

    _bearingAnimation = Tween<double>(
      begin: _currentBearing,
      end: _targetBearing,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.linear,
    ));

    // Listen to animation updates (called at ~60fps)
    _animController!.addListener(_onAnimationTick);

    // Track animation completion
    _animController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isAnimating = false;
        // Ensure final position is exact
        _currentLat = _targetLat;
        _currentLng = _targetLng;
        _currentBearing = _normalizeBearing(_targetBearing);
      }
    });

    // Start the animation
    _isAnimating = true;
    _animController!.forward();
  }

  /// Called at ~60fps during animation to update camera position.
  void _onAnimationTick() {
    if (_isDisposed) return;
    if (_latAnimation == null || _lngAnimation == null || _bearingAnimation == null) return;

    // Update current position from animation values
    _currentLat = _latAnimation!.value;
    _currentLng = _lngAnimation!.value;
    _currentBearing = _normalizeBearing(_bearingAnimation!.value);

    // Apply to Mapbox (instant - no animation, we're doing the animation ourselves)
    _applyCamera();
  }

  /// Applies current position to Mapbox camera (instant, no animation).
  void _applyCamera() {
    if (_isDisposed) return;

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(_currentLng, _currentLat)),
      zoom: zoom,
      bearing: _currentBearing,
      pitch: pitch,
      padding: MbxEdgeInsets(
        top: padding.top,
        left: padding.left,
        bottom: padding.bottom,
        right: padding.right,
      ),
    );

    // Use setCamera for instant update (we handle animation ourselves)
    mapboxMap.setCamera(cameraOptions);
  }

  /// Normalizes bearing to 0-360 range.
  double _normalizeBearing(double bearing) {
    double result = bearing % 360;
    if (result < 0) result += 360;
    return result;
  }

  /// Snap camera immediately without animation.
  void snapTo({
    required double latitude,
    required double longitude,
    required double bearing,
  }) {
    if (_isDisposed) return;

    // Stop any running animation
    _animController?.stop();

    _currentLat = latitude;
    _currentLng = longitude;
    _currentBearing = _normalizeBearing(bearing);
    _targetLat = latitude;
    _targetLng = longitude;
    _targetBearing = _normalizeBearing(bearing);
    _initialized = true;

    _applyCamera();
    onDebug?.call(
      'SmoothCamera: SNAP to ($latitude, $longitude) bearing=$bearing',
    );
  }

  ({double latitude, double longitude, double bearing}) get currentPosition => (
    latitude: _currentLat,
    longitude: _currentLng,
    bearing: _currentBearing,
  );

  bool get isInitialized => _initialized;
  bool get isAnimating => _isAnimating;

  void dispose() {
    _isDisposed = true;
    _animController?.stop();
    _animController?.dispose();
    _animController = null;
    _latAnimation = null;
    _lngAnimation = null;
    _bearingAnimation = null;
    onDebug?.call('SmoothCamera: DISPOSED');
  }
}
