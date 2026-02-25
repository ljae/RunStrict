import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart' as geo;
import '../../../data/models/location_point.dart';
import '../../../app/neon_theme.dart';
import '../../../core/services/hex_service.dart';
import '../providers/hex_data_provider.dart';
import 'glowing_location_marker.dart';
import 'smooth_camera_controller.dart';
import '../../../core/utils/route_optimizer.dart';

/// Widget for displaying running routes on Mapbox with car navigation-style chase camera.
///
/// ## Navigation Mode Rendering Flow:
///
/// 1. RunProvider receives location update from LocationService
/// 2. RunProvider increments routeVersion and calls notifyListeners()
/// 3. RunningScreen rebuilds, passes new route + routeVersion to RouteMap
/// 4. RouteMap.didUpdateWidget detects routeVersion change
/// 5. _handleRouteUpdate() is called:
///    a. Camera updates FIRST (bearing rotation + position)
///    b. Route line updates (polyline geometry)
///    c. Hexagons update (throttled)
///    d. Marker overlay repositions via pixelForCoordinate
///
/// ## Chase Camera Effect:
/// - Camera positioned BEHIND the user (via padding.top)
/// - Map rotates so "up" = direction of travel (via bearing)
/// - Tilted 3D perspective (via pitch)
/// - Zoomed in for immersion (zoom 18)
class RouteMap extends ConsumerStatefulWidget {
  final List<LocationPoint> route;
  final int routeVersion;
  final latlong.LatLng? liveLocation;
  final double? liveHeading;
  final bool showLiveLocation;
  final double aspectRatio;
  final bool interactive;
  final bool showHexGrid;
  final bool navigationMode;
  final Color? teamColor;
  final bool isRedTeam;
  final bool isRunning;
  final String? flashHexId;

  const RouteMap({
    super.key,
    required this.route,
    this.routeVersion = 0,
    this.liveLocation,
    this.liveHeading,
    this.showLiveLocation = false,
    this.aspectRatio = 16 / 9,
    this.interactive = true,
    this.showHexGrid = false,
    this.navigationMode = false,
    this.teamColor,
    this.isRedTeam = true,
    this.isRunning = false,
    this.flashHexId,
  });

  @override
  ConsumerState<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<RouteMap> with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  PolygonAnnotationManager? _polygonManager;
  PolylineAnnotationManager? _hexBorderManager;
  PointAnnotationManager? _labelManager;
  PolygonAnnotation? _currentHexAnnotation;
  PolylineAnnotation? _routeAnnotation;
  late AnimationController _pulseController;

  // Smooth camera controller for 60fps interpolation during navigation mode
  SmoothCameraController? _smoothCamera;

  bool _isMapReady = false;
  bool _isDrawingHexagons = false;
  DateTime? _lastHexDrawTime;
  latlong.LatLng? _currentUserLocation;
  int _cameraChangeCounter = 0;
  int _lastRouteLength = 0;

  // ===== NAVIGATION MODE STATE =====
  bool _isProcessingRouteUpdate = false; // Prevent overlapping route+camera updates
  bool _isDrawingHexagonsAsync = false; // Separate guard for hex drawing
  double _currentBearing = 0.0; // Current map rotation (degrees, 0 = North)
  Size? _mapWidgetSize; // Actual size of the map widget (from LayoutBuilder)
  bool _pendingHexRedraw = false; // Flag to redraw hexes after current draw completes
  bool _pendingRouteUpdate = false; // Flag: route update queued while processing

  // Navigation mode camera settings
  // These values create the "car navigation" chase camera effect:
  // - Zoom 17 provides ~100m view radius for better "road ahead" visibility
  // - 50° pitch for 3D perspective without disorientation
  // - Padding ratio pushes user position down, so "forward" is visible
  static const double _navZoom = 17.0;
  static const double _navPitch = 50.0;
  static const double _navPaddingRatio = 0.35; // User appears at ~65% of screen

  // Bearing calculation settings
  static const int _bearingLookbackPoints =
      5; // Use last N points for direction
  static const double _bearingMinDistance =
      3.0; // Minimum meters to update bearing

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseController.addListener(_onPulseAnimation);
  }

  @override
  void dispose() {
    _smoothCamera?.dispose();
    _smoothCamera = null;
    _pulseController.removeListener(_onPulseAnimation);
    _pulseController.dispose();
    _polylineManager = null;
    _polygonManager = null;
    _hexBorderManager = null;
    _labelManager = null;
    _mapboxMap = null;
    super.dispose();
  }

  void _onPulseAnimation() {
    if (_isDrawingHexagons) return;
    if (_currentHexAnnotation != null &&
        _polygonManager != null &&
        widget.isRunning) {
      try {
        final opacity = 0.3 + (_pulseController.value * 0.4);
        _currentHexAnnotation!.fillOpacity = opacity;
        _polygonManager!.update(_currentHexAnnotation!);
      } catch (e) {
        // Annotation may have been deleted
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.route.isEmpty && !widget.showLiveLocation) {
      return _buildEmptyState(context);
    }

    // Use LayoutBuilder to get actual widget dimensions
    // This is critical for navigation mode where marker must align with camera center
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get actual widget size from constraints
        // Handle unbounded constraints by falling back to reasonable defaults
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
        final mapSize = Size(width, height);

        // Store for use in camera updates (no setState needed - just direct assignment)
        _mapWidgetSize = mapSize;

        Widget mapContent = Stack(
          children: [
            // Mapbox Map
            // Use manual camera control for navigation mode to calculate bearing from movement
            // This gives true "car navigation" feel where forward = direction of travel
            Positioned.fill(
              child: MapWidget(
                key: ValueKey(
                  widget.navigationMode ? 'nav_map' : 'overview_map',
                ),
                cameraOptions: _getInitialCameraOptions(),
                styleUri: MapboxStyles.DARK,
                onMapCreated: _onMapCreated,
                onCameraChangeListener: _onCameraChange,
              ),
            ),

            // Glowing location marker overlay
            // Position is calculated from geo coordinates using pixelForCoordinate
            // This ensures marker aligns perfectly with the route line endpoint
            // Show marker immediately using _currentUserLocation if route is empty
            if (_isMapReady &&
                widget.showLiveLocation &&
                (widget.liveLocation != null || widget.route.isNotEmpty || _currentUserLocation != null))
              _NavigationMarkerOverlay(
                key: ValueKey(
                  'nav_marker_${widget.routeVersion}_${widget.liveLocation.hashCode}_$_cameraChangeCounter',
                ),
                mapboxMap: _mapboxMap!,
                userLocation: widget.liveLocation ??
                    (widget.route.isNotEmpty
                        ? latlong.LatLng(
                            widget.route.last.latitude,
                            widget.route.last.longitude,
                          )
                        : _currentUserLocation!),
                teamColor: widget.teamColor ?? NeonTheme.neonCyan,
                navigationMode: widget.navigationMode,
                mapSize: mapSize, // Use actual map widget size
                routeVersion: widget.routeVersion,
                cameraVersion: _cameraChangeCounter,
              ),
          ],
        );

        // In navigation mode, return full-size content without aspect ratio
        if (widget.navigationMode) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: mapContent,
          );
        }

        // For non-navigation mode, use aspect ratio
        return AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: mapContent,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NeonTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NeonTheme.neonCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: NeonTheme.neonCyan.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No route data',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Camera options for both navigation and overview modes.
  /// Navigation mode: centers on last point with pitch, bearing, and padding
  /// Overview mode: fits all route points in view
  CameraOptions _getInitialCameraOptions() {
    // Navigation mode: ALWAYS use chase camera params (pitch/zoom/padding),
    // even when route is empty. This prevents the flat/north-up camera that
    // occurs when MapWidget applies these options before GPS data arrives.
    if (widget.navigationMode) {
      final lat = widget.liveLocation?.latitude ??
          (widget.route.isNotEmpty ? widget.route.last.latitude : null) ??
          _currentUserLocation?.latitude ??
          37.5;
      final lng = widget.liveLocation?.longitude ??
          (widget.route.isNotEmpty ? widget.route.last.longitude : null) ??
          _currentUserLocation?.longitude ??
          127.0;
      final mapHeight =
          _mapWidgetSize?.height ?? MediaQuery.of(context).size.height;
      final paddingTop = mapHeight * _navPaddingRatio;

      return CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: _navZoom,
        pitch: _navPitch,
        bearing: _currentBearing,
        padding: MbxEdgeInsets(top: paddingTop, left: 0, bottom: 0, right: 0),
      );
    }

    if (widget.route.isEmpty) {
      return CameraOptions(
        center: Point(coordinates: Position(127.0, 37.5)),
        zoom: 15.0,
      );
    }

    // Overview mode: fit all route points in view
    double minLat = widget.route.first.latitude;
    double maxLat = widget.route.first.latitude;
    double minLng = widget.route.first.longitude;
    double maxLng = widget.route.first.longitude;

    for (final point in widget.route) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    return CameraOptions(
      center: Point(coordinates: Position(centerLng, centerLat)),
      zoom: _calculateZoomForBounds(minLat, maxLat, minLng, maxLng),
    );
  }

  double _calculateZoomForBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    if (maxDiff > 0.05) return 12.0;
    if (maxDiff > 0.02) return 14.0;
    if (maxDiff > 0.01) return 15.0;
    if (maxDiff > 0.005) return 16.0;
    return 17.0;
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Disable Mapbox's built-in location puck - we use our own GlowingLocationMarker
    try {
      await mapboxMap.location.updateSettings(
        LocationComponentSettings(
          enabled: false,
          pulsingEnabled: false,
          showAccuracyRing: false,
        ),
      );
    } catch (e) {
      debugPrint('Error disabling location component: $e');
    }

    // Configure gestures based on mode
    if (widget.navigationMode) {
      // Navigation mode: disable user gestures (camera is controlled programmatically)
      try {
        await mapboxMap.gestures.updateSettings(
          GesturesSettings(
            rotateEnabled: false,
            scrollEnabled: false,
            pitchEnabled: false,
            doubleTapToZoomInEnabled: false,
            doubleTouchToZoomOutEnabled: false,
            pinchToZoomEnabled: false,
          ),
        );
      } catch (e) {
        debugPrint('Error configuring gesture settings: $e');
      }

      // Hide the compass during navigation
      try {
        await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
      } catch (e) {
        debugPrint('Error hiding compass: $e');
      }
    }

    // Create annotation managers (order = z-index)
    _polygonManager = await _mapboxMap!.annotations
        .createPolygonAnnotationManager();
    _hexBorderManager = await _mapboxMap!.annotations
        .createPolylineAnnotationManager();
    _polylineManager = await _mapboxMap!.annotations
        .createPolylineAnnotationManager();
    _labelManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();

    // Initialize smooth camera controller for navigation mode
    if (widget.navigationMode) {
      _smoothCamera = SmoothCameraController(
        mapboxMap: mapboxMap,
        tickerProvider: this,
        zoom: _navZoom,
        pitch: _navPitch,
        padding: EdgeInsets.only(
          top:
              (_mapWidgetSize?.height ?? MediaQuery.of(context).size.height) *
              _navPaddingRatio,
        ),
        animationDuration: const Duration(milliseconds: 1800),
      );
    }

    // Handle case where route is empty but we show live location
    if (widget.route.isEmpty && widget.showLiveLocation) {
      await _initializeWithCurrentLocation();
    }

    // Draw initial route
    await _drawRoute(forceRedraw: true);

    // NOTE: In navigation mode, FollowPuckViewportState handles camera automatically
    // No need for manual _updateNavigationCamera() call

    // Draw hexagons if enabled
    if (widget.showHexGrid && widget.route.isNotEmpty) {
      final last = widget.route.last;
      await _drawHexagonsAround(latlong.LatLng(last.latitude, last.longitude));
    }

    if (mounted) {
      setState(() => _isMapReady = true);
    }
  }

  Future<void> _initializeWithCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentUserLocation = latlong.LatLng(
          position.latitude,
          position.longitude,
        );
      });
      if (!mounted || _mapboxMap == null) return;

      // In navigation mode, use SmoothCamera to snap (preserves pitch/zoom/bearing).
      // This prevents the flat/north-up camera that occurs when setCamera is called
      // without navigation parameters.
      if (widget.navigationMode && _smoothCamera != null) {
        _smoothCamera!.snapTo(
          latitude: position.latitude,
          longitude: position.longitude,
          bearing: _currentBearing,
        );
      } else {
        await _mapboxMap!.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(position.longitude, position.latitude),
            ),
            zoom: 16.0,
          ),
        );
      }

      if (mounted && widget.showHexGrid) {
        await _drawHexagonsAround(
          latlong.LatLng(position.latitude, position.longitude),
        );
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _onCameraChange(CameraChangedEventData event) {
    if (!mounted) return;

    // In navigation mode, marker is at a fixed screen position — no setState needed
    // for camera-driven repositioning. Only non-navigation mode needs pixel updates.
    if (!widget.navigationMode) {
      setState(() {
        _cameraChangeCounter++;
      });

      // Redraw hexagons for manual camera changes in non-navigation mode
      if (widget.showHexGrid && _isMapReady) {
        _drawHexagonsForCurrentView();
      }
    }
  }

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle running state changes
    if (oldWidget.isRunning && !widget.isRunning) {
      _resetHexPulse();
    }

    // Immediately show location marker when run starts (before first GPS point)
    // This eliminates the lag between pressing start and seeing the glowing ball
    if (widget.showLiveLocation &&
        widget.route.isEmpty &&
        _currentUserLocation == null &&
        _isMapReady) {
      _initializeWithCurrentLocation();
    }

    // Handle navigation mode toggle
    if (widget.navigationMode != oldWidget.navigationMode) {
      if (!widget.navigationMode) {
        // Exiting navigation mode: dispose smooth camera
        _currentBearing = 0.0;
        _smoothCamera?.dispose();
        _smoothCamera = null;
      } else if (_mapboxMap != null) {
        // Entering navigation mode: create smooth camera
        _smoothCamera = SmoothCameraController(
          mapboxMap: _mapboxMap!,
          tickerProvider: this,
          zoom: _navZoom,
          pitch: _navPitch,
          padding: EdgeInsets.only(
            top:
                (_mapWidgetSize?.height ?? MediaQuery.of(context).size.height) *
                _navPaddingRatio,
          ),
          animationDuration: const Duration(milliseconds: 1800),
        );
      }
    }

    // Handle team color changes
    if (widget.teamColor != oldWidget.teamColor && widget.route.isNotEmpty) {
      _drawRoute(forceRedraw: true);
    }

    // Handle route updates (the main rendering trigger)
    // CRITICAL: Process ANY routeVersion change - this is how GPS updates flow through
    if (widget.routeVersion != oldWidget.routeVersion) {
      _processRouteUpdate();
    }

    // Handle live location changes (marker + hex highlight follow raw GPS)
    if (widget.liveLocation != oldWidget.liveLocation &&
        widget.routeVersion == oldWidget.routeVersion) {
      // In navigation mode, update camera to follow live location
      if (widget.navigationMode) {
        _updateCameraForLiveLocation();
      }
      // In non-navigation mode, update marker position via pixelForCoordinate
      if (!widget.navigationMode && mounted) {
        setState(() {
          _cameraChangeCounter++;
        });
      }
      // Redraw hexes using latest GPS position so current hex highlight stays accurate
      if (mounted && widget.showHexGrid) {
        _scheduleHexRedraw();
      }
    }

    // Handle hex flash changes
    if (widget.flashHexId != oldWidget.flashHexId && widget.showHexGrid) {
      _drawHexagons();
    }
  }

  void _resetHexPulse() {
    if (_currentHexAnnotation != null && _polygonManager != null) {
      _currentHexAnnotation!.fillOpacity = 0.3;
      _polygonManager!.update(_currentHexAnnotation!);
    }
  }

  /// Main entry point for processing route updates.
  /// Called when routeVersion changes (new GPS point received).
  ///
  /// Camera + route line are processed immediately (fast path).
  /// Hex drawing is fire-and-forget (slow path) so it never blocks
  /// the next GPS update from rendering.
  Future<void> _processRouteUpdate() async {
    if (!mounted || !_isMapReady || _mapboxMap == null || widget.route.isEmpty) {
      return;
    }

    // Guard only the fast path (camera + route line).
    // If a previous fast-path update is still running, queue one more.
    if (_isProcessingRouteUpdate) {
      _pendingRouteUpdate = true;
      return;
    }
    _isProcessingRouteUpdate = true;
    try {
      // 1. Update camera (navigation mode only) — synchronous, non-blocking
      if (widget.navigationMode && widget.route.isNotEmpty) {
        _updateNavigationCamera();
      }
      // 2. Update route line (the tracing path) — fast polyline update
      if (mounted) await _drawRoute();
      if (mounted) {
        setState(() {
          _cameraChangeCounter++;
        });
      }
    } finally {
      _isProcessingRouteUpdate = false;
    }

    // Process pending update if one was queued while we were busy
    if (_pendingRouteUpdate && mounted) {
      _pendingRouteUpdate = false;
      _processRouteUpdate();
      return; // hex redraw will be handled by the recursive call
    }
    // 4. Hex drawing — fire-and-forget, never blocks the next GPS update
    if (mounted && widget.showHexGrid) {
      _scheduleHexRedraw();
    }
  }

  /// Schedules a hex redraw without blocking the route update pipeline.
  /// If a hex draw is already in progress, queues one redraw for when it finishes.
  /// After hex drawing, redraws the route line on top to prevent z-order issues
  /// where recreated hex fill annotations cover the older route polyline.
  void _scheduleHexRedraw() {
    if (_isDrawingHexagonsAsync) {
      _pendingHexRedraw = true;
      return;
    }
    _isDrawingHexagonsAsync = true;
    _drawHexagons().whenComplete(() async {
      _isDrawingHexagonsAsync = false;
      // Redraw route line AFTER hexes to ensure it renders on top.
      // Hex deleteAll()+createMulti() makes hex annotations "fresher" than
      // the route polyline, causing Mapbox to render hexes above the route.
      // Forcing a route redraw restores correct z-order.
      if (mounted && widget.route.length >= 2) {
        await _drawRoute(forceRedraw: true);
      }
      if (_pendingHexRedraw && mounted) {
        _pendingHexRedraw = false;
        _scheduleHexRedraw();
      }
    });
  }

  // ========== NAVIGATION CAMERA CONTROL ==========

  /// Updates camera for navigation mode using SmoothCameraController.
  /// Calculates bearing from recent route points (movement direction).
  /// The SmoothCameraController handles 60fps interpolation between GPS updates,
  /// creating buttery-smooth movement instead of jumping between positions.
  void _updateNavigationCamera() {
    if (_mapboxMap == null || widget.route.isEmpty) return;
    final last = widget.route.last;

    // For the first point (length == 1), snap to position.
    // Use GPS heading if available, otherwise keep current bearing.
    if (widget.route.length == 1) {
      final initialBearing = widget.liveHeading ?? _currentBearing;
      if (_smoothCamera != null) {
        _smoothCamera!.snapTo(
          latitude: last.latitude,
          longitude: last.longitude,
          bearing: initialBearing,
        );
      }
      _currentBearing = initialBearing;
      return;
    }

    // Primary: use GPS heading from device sensor
    // Fallback: calculate bearing from recent route points
    double targetBearing = _currentBearing;
    if (widget.liveHeading != null) {
      targetBearing = widget.liveHeading!;
    } else {
      final newBearing = _calculateBearingFromRoute();
      if (newBearing != null) {
        targetBearing = newBearing;
      }
    }
    _currentBearing = targetBearing;
    // Use SmoothCameraController for 60fps interpolated movement
    if (_smoothCamera != null) {
      _smoothCamera!.updateTarget(
        latitude: last.latitude,
        longitude: last.longitude,
        bearing: targetBearing,
      );
    } else {
      // Fallback: direct setCamera if smooth controller not available
      final mapHeight =
          _mapWidgetSize?.height ?? MediaQuery.of(context).size.height;
      final paddingTop = mapHeight * _navPaddingRatio;
      try {
        _mapboxMap!.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(last.longitude, last.latitude)),
            zoom: _navZoom,
            pitch: _navPitch,
            bearing: _currentBearing,
            padding: MbxEdgeInsets(
              top: paddingTop,
              left: 0,
              bottom: 0,
              right: 0,
            ),
          ),
        );
      } catch (_) {}
    }
  }

  /// Updates camera when liveLocation changes but route doesn't grow.
  /// This handles GPS points that were rejected by RunTracker (invalid pace/accuracy)
  /// but should still move the camera to the user's real position.
  void _updateCameraForLiveLocation() {
    if (_smoothCamera == null || widget.liveLocation == null) return;
    final bearing = widget.liveHeading ?? _currentBearing;
    _currentBearing = bearing;
    _smoothCamera!.updateTarget(
      latitude: widget.liveLocation!.latitude,
      longitude: widget.liveLocation!.longitude,
      bearing: bearing,
    );
    if (mounted) {
      setState(() => _cameraChangeCounter++);
    }
  }

  /// Calculates bearing (direction) from recent route points.
  /// Uses proper geodetic formula that accounts for Earth's curvature.
  /// Returns null if insufficient data or movement.
  double? _calculateBearingFromRoute() {
    if (widget.route.length < 2) return null;

    // Get last N points for bearing calculation
    final lookback = math.min(_bearingLookbackPoints, widget.route.length);
    final recentPoints = widget.route.sublist(widget.route.length - lookback);

    // Find first and last point with sufficient distance
    final first = recentPoints.first;
    final last = recentPoints.last;

    // Calculate approximate distance using Haversine
    final lat1Rad = first.latitude * math.pi / 180;
    final lat2Rad = last.latitude * math.pi / 180;
    final dLatRad = (last.latitude - first.latitude) * math.pi / 180;
    final dLngRad = (last.longitude - first.longitude) * math.pi / 180;

    final a =
        math.sin(dLatRad / 2) * math.sin(dLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLngRad / 2) *
            math.sin(dLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = 6371000 * c; // Earth radius in meters

    // Only calculate bearing if we've moved enough
    if (distance < _bearingMinDistance) return null;

    // Calculate bearing using proper geodetic formula
    // Formula: θ = atan2(sin(Δλ)·cos(φ2), cos(φ1)·sin(φ2) − sin(φ1)·cos(φ2)·cos(Δλ))
    final y = math.sin(dLngRad) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLngRad);
    final bearing = math.atan2(y, x) * 180 / math.pi;

    // Normalize to 0-360
    return (bearing + 360) % 360;
  }

  // Bearing smoothing is now handled by SmoothCameraController's
  // internal shortest-path rotation logic at 60fps.

  // ========== ROUTE LINE RENDERING ==========

  Future<void> _drawRoute({bool forceRedraw = false}) async {
    if (_mapboxMap == null ||
        widget.route.isEmpty ||
        _polylineManager == null) {
      return;
    }

    try {
      // Use all points - isValid defaults to true and is set by LocationService
      final validPoints = widget.route.where((p) => p.isValid).toList();
      if (validPoints.isEmpty) return;

      // Optimize for large routes
      List<LocationPoint> renderPoints;
      if (validPoints.length > RouteOptimizer.renderMaxPoints) {
        final optimizer = RouteOptimizer();
        for (final point in validPoints) {
          optimizer.addPoint(point);
        }
        renderPoints = optimizer.getOptimizedForRendering();
      } else {
        renderPoints = validPoints;
      }

      final coordinates = renderPoints
          .map((p) => Position(p.longitude, p.latitude))
          .toList();

      // Allow single point routes - just don't draw line yet
      if (coordinates.isEmpty) return;

      // Determine if we need to update the route line
      // CRITICAL: Always update during active running to ensure line stays current
      final hasNewPoints = widget.route.length > _lastRouteLength;
      final isActiveRun = widget.navigationMode && widget.isRunning;
      final needsUpdate =
          _routeAnnotation == null ||
          forceRedraw ||
          hasNewPoints ||
          isActiveRun;

      if (needsUpdate && coordinates.length >= 2) {
        // In navigation mode: thicker, more visible line
        // The line shows the path traveled (trail behind the runner)
        final lineWidth = widget.navigationMode ? 10.0 : 6.0;
        final lineColor = widget.teamColor ?? Colors.cyan;

        // For active runs, always recreate annotation for reliable updates
        // The update() method can silently fail on some Mapbox versions
        bool shouldRecreate = forceRedraw || _routeAnnotation == null;

        // Try to update existing annotation first (faster, no flicker)
        if (_routeAnnotation != null && !shouldRecreate) {
          try {
            // Update geometry on existing annotation
            _routeAnnotation!.geometry = LineString(coordinates: coordinates);
            await _polylineManager!.update(_routeAnnotation!);
            _lastRouteLength = widget.route.length;
            return; // Success - exit early
          } catch (e) {
            // Update failed - will recreate below
            _routeAnnotation = null;
          }
        }

        // Create new annotation (update failed or doesn't exist)
        // Delete existing annotations first
        try {
          await _polylineManager!.deleteAll();
        } catch (_) {}
        _routeAnnotation = null;

        // Create fresh annotation
        // In navigation mode, use higher opacity for better trail visibility
        final opacity = widget.navigationMode ? 1.0 : 0.9;
        _routeAnnotation = await _polylineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coordinates),
            lineColor: lineColor.toARGB32(),
            lineWidth: lineWidth,
            lineJoin: LineJoin.ROUND,
            lineOpacity: opacity,
          ),
        );
        _lastRouteLength = widget.route.length;
      } else if (needsUpdate && coordinates.length == 1) {
        // Single point - clear any existing line, will draw once we have 2+ points
        try {
          await _polylineManager!.deleteAll();
        } catch (_) {}
        _routeAnnotation = null;
        _lastRouteLength = widget.route.length;
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
      _routeAnnotation = null;
      _lastRouteLength = 0;
    }
  }

  // ========== HEXAGON RENDERING ==========

  Future<void> _drawHexagonsForCurrentView() async {
    if (_mapboxMap == null) return;
    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center;
      await _drawHexagonsAround(
        latlong.LatLng(
          center.coordinates.lat.toDouble(),
          center.coordinates.lng.toDouble(),
        ),
      );
    } catch (e) {
      debugPrint('Error getting camera state: $e');
    }
  }

  Future<void> _drawHexagons() async {
    // Prefer liveLocation for hex center — it's the most recent GPS position
    // and ensures the "current hex" highlight matches where the user actually is,
    // even when the GPS validator hasn't accepted the point into the route yet.
    if (widget.liveLocation != null) {
      await _drawHexagonsAround(
        latlong.LatLng(widget.liveLocation!.latitude, widget.liveLocation!.longitude),
      );
    } else if (widget.route.isNotEmpty) {
      final last = widget.route.last;
      await _drawHexagonsAround(latlong.LatLng(last.latitude, last.longitude));
    } else if (widget.showLiveLocation) {
      try {
        final position = await geo.Geolocator.getCurrentPosition();
        await _drawHexagonsAround(
          latlong.LatLng(position.latitude, position.longitude),
        );
      } catch (_) {}
    }
  }

  Future<void> _drawHexagonsAround(latlong.LatLng center) async {
    if (_mapboxMap == null || _polygonManager == null) return;
    if (_isDrawingHexagons) return;

    // Throttle: 200ms minimum between redraws during active running
    // This is faster than before (500ms) to ensure hex color changes are visible
    final now = DateTime.now();
    final throttleMs = widget.isRunning ? 200 : 500;
    if (_lastHexDrawTime != null &&
        now.difference(_lastHexDrawTime!).inMilliseconds < throttleMs) {
      return;
    }
    _lastHexDrawTime = now;
    _isDrawingHexagons = true;

    try {
      await _polygonManager!.deleteAll();
      await _hexBorderManager?.deleteAll();
      await _labelManager?.deleteAll();

      final optionsList = <PolygonAnnotationOptions>[];
      final borderOptions = <PolylineAnnotationOptions>[];
      final labelOptions = <PointAnnotationOptions>[];
      int? currentHexIndex;

      const resolution = 9;
      final teamColor = widget.teamColor ?? NeonTheme.neonCyan;
      final currentHexId = HexService().getHexId(center, resolution);
      final hexIds = HexService().getHexagonsInArea(center, resolution, 8);

      for (int i = 0; i < hexIds.length; i++) {
        final hexId = hexIds[i];
        final boundary = HexService().getHexBoundary(hexId);
        if (boundary.isEmpty) continue;

        final coordinates = boundary
            .map((p) => Position(p.longitude, p.latitude))
            .toList();
        coordinates.add(coordinates.first);

        final isCurrent = hexId == currentHexId;
        if (isCurrent) currentHexIndex = optionsList.length;

        final isFlipped = hexId == widget.flashHexId;

        // Calculate hex center for data lookup
        double avgLat = 0, avgLng = 0;
        for (final p in boundary) {
          avgLat += p.latitude;
          avgLng += p.longitude;
        }
        avgLat /= boundary.length;
        avgLng /= boundary.length;
        final hexCenter = latlong.LatLng(avgLat, avgLng);
        final hex = ref.read(hexDataProvider.notifier).getHex(hexId, hexCenter);

        // Determine styling
        double fillOpacity;
        int fillColor;
        int borderColor;
        double borderWidth;

        if (isFlipped) {
          fillOpacity = 0.7;
          fillColor = Colors.white.toARGB32();
          borderColor = teamColor.toARGB32();
          borderWidth = 3.0;
        } else if (isCurrent) {
          fillOpacity = 0.5;
          fillColor = teamColor.toARGB32();
          borderColor = teamColor.toARGB32();
          borderWidth = 2.5;
        } else if (!hex.isNeutral) {
          fillOpacity = 0.3;
          fillColor = hex.hexLightColor.toARGB32();
          borderColor = hex.hexColor.toARGB32();
          borderWidth = 1.5;
        } else {
          fillOpacity = 0.15;
          fillColor = const Color(0xFF2A3550).toARGB32();
          borderColor = const Color(0xFF6B7280).toARGB32();
          borderWidth = 1.0;
        }

        optionsList.add(
          PolygonAnnotationOptions(
            geometry: Polygon(coordinates: [coordinates]),
            fillColor: fillColor,
            fillOpacity: fillOpacity,
          ),
        );

        borderOptions.add(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coordinates),
            lineColor: borderColor,
            lineWidth: borderWidth,
            lineOpacity: isCurrent || isFlipped ? 1.0 : 0.6,
          ),
        );

        if (!hex.isNeutral || isCurrent) {
          labelOptions.add(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(hexCenter.longitude, hexCenter.latitude),
              ),
              textField: hex.emoji,
              textSize: 14.0,
              textColor: isCurrent
                  ? teamColor.toARGB32()
                  : hex.hexColor.toARGB32(),
              textHaloColor: Colors.black.toARGB32(),
              textHaloWidth: 2.0,
              textAnchor: TextAnchor.CENTER,
            ),
          );
        }
      }

      if (optionsList.isNotEmpty) {
        final annotations = await _polygonManager!.createMulti(optionsList);
        if (currentHexIndex != null && annotations.length > currentHexIndex) {
          _currentHexAnnotation = annotations[currentHexIndex];
        } else {
          _currentHexAnnotation = null;
        }
      }

      if (borderOptions.isNotEmpty && _hexBorderManager != null) {
        await _hexBorderManager!.createMulti(borderOptions);
      }

      if (labelOptions.isNotEmpty && _labelManager != null) {
        await _labelManager!.createMulti(labelOptions);
      }
    } catch (e) {
      debugPrint('Error drawing hexagons: $e');
    } finally {
      _isDrawingHexagons = false;
    }
  }
}

/// Overlay widget that positions the glowing location marker.
///
/// ## Navigation Mode (Car Navigation Style):
/// - Ball is at a FIXED screen position (65% down, horizontally centered)
/// - Map rotates and moves around the ball
/// - Ball appears to "always move forward" because map rotates
/// - Shows momentum trail effect
///
/// ## Normal Mode:
/// - Uses pixelForCoordinate to position marker at geo coordinates
/// - Shows smaller marker without trail
class _NavigationMarkerOverlay extends StatelessWidget {
  final MapboxMap mapboxMap;
  final latlong.LatLng userLocation;
  final Color teamColor;
  final bool navigationMode;
  final Size mapSize; // Actual map widget size (not screen size)
  final int routeVersion;
  final int cameraVersion;

  // The marker position must match where the camera padding places the GPS coordinates
  // With padding.top = P, the center point appears at: P + (height - P) / 2
  // For padding.top = 35% of height:
  //   position = 0.35 + (1.0 - 0.35) / 2 = 0.35 + 0.325 = 0.675 (67.5% from top)
  // This places the ball in the lower third of map, with "forward" visible above
  static const double _markerPositionRatio = 0.675;

  const _NavigationMarkerOverlay({
    super.key,
    required this.mapboxMap,
    required this.userLocation,
    required this.teamColor,
    required this.mapSize,
    this.navigationMode = false,
    this.routeVersion = 0,
    this.cameraVersion = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Marker size - larger in navigation mode for visibility
    final markerSize = navigationMode ? 44.0 : 24.0;
    final totalSize = markerSize * 3;

    // ========== NAVIGATION MODE: FIXED POSITION ==========
    // In car navigation, the "car" (glowing ball) stays at a fixed position
    // and the map rotates/moves around it. This creates the illusion that
    // the ball is "always moving forward".
    //
    // The position is calculated to match the camera padding:
    // - Camera padding.top = mapHeight * 0.35
    // - This means the camera center appears at 67.5% from top
    // - So the ball should be at that same position within the map widget
    if (navigationMode) {
      // Fixed position: horizontally centered, 67.5% from top of MAP widget
      final fixedX = mapSize.width / 2;
      final fixedY = mapSize.height * _markerPositionRatio;

      return Positioned(
        left: fixedX - (totalSize / 2),
        top: fixedY - (totalSize / 2),
        child: GlowingLocationMarker(
          accentColor: teamColor,
          size: markerSize,
          enablePulse: true,
          showMomentumTrail: true, // Momentum trail in navigation mode
        ),
      );
    }

    // ========== NORMAL MODE: GEO-POSITIONED ==========
    // Use pixelForCoordinate to position marker at actual geo coordinates
    return FutureBuilder<ScreenCoordinate>(
      future: mapboxMap.pixelForCoordinate(
        Point(
          coordinates: Position(userLocation.longitude, userLocation.latitude),
        ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final screenCoord = snapshot.data!;
        final x = screenCoord.x.toDouble();
        final y = screenCoord.y.toDouble();

        // Validate position is within map bounds
        if (x < -100 ||
            x > mapSize.width + 100 ||
            y < -100 ||
            y > mapSize.height + 100) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: x - (totalSize / 2),
          top: y - (totalSize / 2),
          child: GlowingLocationMarker(
            accentColor: teamColor,
            size: markerSize,
            enablePulse: true,
          ),
        );
      },
    );
  }
}
