import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart' as geo;
import '../services/hex_service.dart';
import '../services/prefetch_service.dart';
import '../config/h3_config.dart';
import '../models/location_point.dart';
import '../models/team.dart';
import '../services/local_storage_service.dart';
import '../theme/app_theme.dart';
import '../providers/hex_data_provider.dart';
import '../widgets/glowing_location_marker.dart';
import '../services/remote_config_service.dart';

class HexagonMap extends StatefulWidget {
  final latlong.LatLng? initialCenter;
  final bool showScoreLabels;
  final Function(HexAggregatedStats)? onScoresUpdated;
  final Function(MapboxMap)? onMapCreated; // Expose controller
  final Color? teamColor;
  final Team? userTeam; // User's team for capturable hex detection
  final bool showUserLocation;
  final List<LocationPoint>? route; // Route for tracking line

  const HexagonMap({
    super.key,
    this.initialCenter,
    this.showScoreLabels = true,
    this.onScoresUpdated,
    this.onMapCreated,
    this.teamColor,
    this.userTeam,
    this.showUserLocation = true,
    this.route,
  });

  @override
  State<HexagonMap> createState() => _HexagonMapState();
}

class _HexagonMapState extends State<HexagonMap> {
  static const String _hexSourceId = 'hex-polygons-source';
  static const String _hexLayerId = 'hex-polygons-fill';
  static const String _boundarySourceId = 'scope-boundary-source';
  static const String _boundaryLayerId = 'scope-boundary-line';

  MapboxMap? _mapboxMap;
  // PolygonAnnotationManager? _polygonManager; // Removed for GeoJSON migration
  PointAnnotationManager? _labelManager;
  PolylineAnnotationManager? _polylineManager; // For route tracking line
  bool _isMapReady = false;
  List<String> _visibleHexIds = [];
  double _currentZoom = 14.0;
  String? _currentUserHexId;
  latlong.LatLng? _userLocation;
  int _cameraChangeCounter = 0; // For forcing overlay updates
  int _lastRouteLength = 0; // Track route changes
  Timer? _debounceTimer; // Debounce for camera updates
  GeographicScope? _lastBoundaryScope; // Track scope for boundary updates

  final HexDataProvider _hexProvider = HexDataProvider();
  StreamSubscription<latlong.LatLng>? _locationSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for hex updates to redraw map
    _hexProvider.addListener(_onHexDataChanged);
    // Subscribe to location stream for real-time sync during active runs
    _locationSubscription = _hexProvider.locationStream.listen(
      _onLocationUpdate,
    );
  }

  void _onLocationUpdate(latlong.LatLng location) {
    // Guard: widget must still be mounted
    if (!mounted) return;

    // Update user location from shared stream (during active runs)
    if (widget.showUserLocation) {
      setState(() {
        _userLocation = location;
        _currentUserHexId = _hexProvider.currentUserHexId;
        _cameraChangeCounter++; // Force overlay update
      });
      // Also refresh hexagons to show the updated colors
      if (_isMapReady) {
        _updateHexagons();
      }
    }
  }

  void _onHexDataChanged() {
    // Guard: widget must still be mounted
    if (!mounted) return;

    // When hex data changes (e.g., during a run), refresh the hexagon display
    // Sync user location - including clearing it when run ends
    final newLocation = _hexProvider.userLocation;
    final locationChanged = _userLocation != newLocation;

    _userLocation = newLocation;
    _currentUserHexId = _hexProvider.currentUserHexId;

    if (_isMapReady) {
      _updateHexagons();
    }

    // Force rebuild if location changed (including becoming null)
    if (locationChanged) {
      setState(() {
        _cameraChangeCounter++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate initial center: use provided center, then user location
    // Map loads immediately - no blocking on location fetch
    Point? initialCameraCenter;
    if (widget.initialCenter != null) {
      initialCameraCenter = Point(
        coordinates: Position(
          widget.initialCenter!.longitude,
          widget.initialCenter!.latitude,
        ),
      );
    } else if (_userLocation != null) {
      initialCameraCenter = Point(
        coordinates: Position(
          _userLocation!.longitude,
          _userLocation!.latitude,
        ),
      );
    }

    return Stack(
      children: [
        MapWidget(
          cameraOptions: CameraOptions(center: initialCameraCenter, zoom: 14.0),
          styleUri: MapboxStyles.DARK,
          onMapCreated: _onMapCreated,
          onCameraChangeListener: _onCameraChangeListener,
        ),
        // Custom glowing location marker overlay
        if (_isMapReady && _userLocation != null && widget.showUserLocation)
          _UserLocationOverlay(
            key: ValueKey(_cameraChangeCounter),
            mapboxMap: _mapboxMap!,
            userLocation: _userLocation!,
            teamColor: widget.teamColor ?? AppTheme.electricBlue,
          ),
        if (!_isMapReady)
          Container(
            color: AppTheme.backgroundStart,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.electricBlue),
            ),
          ),
      ],
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    if (widget.onMapCreated != null) {
      widget.onMapCreated!(mapboxMap);
    }
    // _polygonManager = await _mapboxMap!.annotations.createPolygonAnnotationManager(); // Removed
    _labelManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();
    _polylineManager = await _mapboxMap!.annotations
        .createPolylineAnnotationManager();

    // Add GeoJSON source for hex polygons (enables atomic updates without flash)
    await mapboxMap.style.addSource(
      GeoJsonSource(
        id: _hexSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ),
    );

    // Add fill layer for hex polygons with data-driven styling
    // Create layer with default values first, then apply expressions via setStyleLayerProperty
    await mapboxMap.style.addLayer(
      FillLayer(
        id: _hexLayerId,
        sourceId: _hexSourceId,
        // Placeholder values - will be overridden by expressions below
        fillColor: Colors.grey.toARGB32(),
        fillOpacity: 0.3,
        fillOutlineColor: Colors.grey.toARGB32(),
        fillAntialias: true,
      ),
    );

    // Apply data-driven expressions to read colors from GeoJSON feature properties
    // setStyleLayerProperty accepts Dart Lists that map to Mapbox GL expressions
    await mapboxMap.style.setStyleLayerProperty(_hexLayerId, 'fill-color', [
      'to-color',
      ['get', 'fill-color'],
    ]);
    await mapboxMap.style.setStyleLayerProperty(_hexLayerId, 'fill-opacity', [
      'get',
      'fill-opacity',
    ]);
    await mapboxMap.style.setStyleLayerProperty(
      _hexLayerId,
      'fill-outline-color',
      [
        'to-color',
        ['get', 'fill-outline-color'],
      ],
    );

    // Add GeoJSON source for scope boundary line (CITY/ALL view boundary)
    await mapboxMap.style.addSource(
      GeoJsonSource(
        id: _boundarySourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ),
    );

    // Add line layer for scope boundary with soft/blurred styling
    // Wide line with low opacity creates a blur-like effect to indicate range
    await mapboxMap.style.addLayer(
      LineLayer(
        id: _boundaryLayerId,
        sourceId: _boundarySourceId,
        lineColor: Colors.white.toARGB32(),
        lineWidth: 8.0, // Wide line for blur effect
        lineOpacity: 0.15, // Low opacity for soft appearance
        lineBlur: 4.0, // Blur the line edges
      ),
    );

    // Enable location component if requested
    if (widget.showUserLocation) {
      await _enableLocationComponent();
    }

    // Get user location and center map
    await _centerOnUserLocation();

    if (mounted) {
      setState(() {
        _isMapReady = true;
      });
      _updateHexagons();
    }

    // Draw initial route if available
    if (widget.route != null && widget.route!.isNotEmpty) {
      await _drawRoute();
    }
  }

  Future<void> _enableLocationComponent() async {
    if (_mapboxMap == null) return;

    try {
      // Disable default Mapbox location component (blue/white circles)
      await _mapboxMap!.location.updateSettings(
        LocationComponentSettings(
          enabled: false,
          pulsingEnabled: false,
          showAccuracyRing: false,
        ),
      );
    } catch (e) {
      debugPrint('Error disabling default location component: $e');
    }
  }

  Future<void> _centerOnUserLocation() async {
    if (_mapboxMap == null) return;

    // Use already prefetched location if available
    if (_userLocation != null) {
      _currentUserHexId = HexService().getHexId(_userLocation!, 9);

      // Use setCamera instead of flyTo to avoid timeout issues
      // Wrap in try-catch as map channel may not be ready
      try {
        _mapboxMap!.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(
                _userLocation!.longitude,
                _userLocation!.latitude,
              ),
            ),
            zoom: 15.0,
          ),
        );
      } catch (e) {
        debugPrint('setCamera failed (map not ready): $e');
      }
      return;
    }

    // Fallback: fetch location if not already available
    try {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return;
      }

      // Try persisted location first
      final savedLocation = await LocalStorageService().getLastLocation();

      // Default fallback
      const defaultLat = 37.5665;
      const defaultLng = 126.9780;

      double targetLat = defaultLat;
      double targetLng = defaultLng;

      if (savedLocation != null) {
        targetLat = savedLocation['latitude']!;
        targetLng = savedLocation['longitude']!;
      } else {
        // Try system last known
        final lastPosition = await geo.Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          targetLat = lastPosition.latitude;
          targetLng = lastPosition.longitude;
        }
      }

      if (mounted) {
        setState(() {
          _userLocation = latlong.LatLng(targetLat, targetLng);
        });

        _currentUserHexId = HexService().getHexId(_userLocation!, 9);

        // Instant set camera - wrap in try-catch as map may not be ready
        try {
          _mapboxMap!.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(targetLng, targetLat)),
              zoom: 15.0,
            ),
          );
        } catch (e) {
          debugPrint('setCamera failed: $e');
        }

        // Render hexagons immediately
        _updateHexagons();
      }

      // Then fetch fresh
      final position = await geo.Geolocator.getCurrentPosition();

      // Save it
      LocalStorageService().saveLastLocation(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _userLocation = latlong.LatLng(position.latitude, position.longitude);
      });

      _currentUserHexId = HexService().getHexId(_userLocation!, 9);

      // Use setCamera instead of flyTo to avoid timeout issues
      // Don't await - fire and forget, wrap in try-catch
      if (_mapboxMap != null) {
        try {
          _mapboxMap!.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(position.longitude, position.latitude),
              ),
              zoom: 15.0,
            ),
          );
        } catch (e) {
          debugPrint('setCamera failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Error centering on user location: $e');
    }
  }

  void _onCameraChangeListener(CameraChangedEventData event) {
    // Check mounted to avoid setState after dispose
    if (!mounted) return;

    setState(() {
      _cameraChangeCounter++;
    });

    // Debounce hex updates - wait for camera to settle
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        _updateHexagons();
      }
    });
  }

  /// Draw the tracking route line on the map
  Future<void> _drawRoute() async {
    if (_mapboxMap == null || _polylineManager == null) return;
    if (widget.route == null || widget.route!.isEmpty) return;

    try {
      // Clear existing route line
      await _polylineManager!.deleteAll();

      final coordinates = widget.route!
          .map((point) => Position(point.longitude, point.latitude))
          .toList();

      final teamColor = widget.teamColor ?? AppTheme.electricBlue;

      final polylineOptions = PolylineAnnotationOptions(
        geometry: LineString(coordinates: coordinates),
        lineColor: teamColor.toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.9,
      );

      await _polylineManager!.create(polylineOptions);
      _lastRouteLength = widget.route!.length;
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  /// Update scope boundary line for CITY/ALL views
  /// Shows a soft blurred line around the parent hex boundary to indicate range
  /// [parentHexId] - The parent hex at scope resolution (used to get H3 boundary)
  Future<void> _updateScopeBoundary(
    GeographicScope scope, {
    String? parentHexId,
  }) async {
    if (_mapboxMap == null) return;

    // Only show boundary for CITY and ALL scopes (not ZONE)
    if (scope == GeographicScope.zone || parentHexId == null) {
      // Clear boundary for ZONE view or when no parent hex
      if (_lastBoundaryScope != GeographicScope.zone) {
        try {
          final source = await _mapboxMap!.style.getSource(_boundarySourceId);
          if (source is GeoJsonSource) {
            await source.updateGeoJSON(
              '{"type":"FeatureCollection","features":[]}',
            );
          }
          _lastBoundaryScope = GeographicScope.zone;
        } catch (e) {
          debugPrint('Error clearing scope boundary: $e');
        }
      }
      return;
    }

    // Always update boundary when we have valid parentHexId
    _lastBoundaryScope = scope;

    try {
      // Get the H3 parent hex's geometric boundary
      final boundary = HexService().getHexBoundary(parentHexId);
      if (boundary.isEmpty) return;

      // Build GeoJSON LineString from parent hex boundary (closed polygon)
      final coordinates = boundary
          .map((p) => [p.longitude, p.latitude])
          .toList();
      coordinates.add(coordinates.first); // Close the loop

      final geoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {'type': 'LineString', 'coordinates': coordinates},
            'properties': {},
          },
        ],
      });

      // Update the boundary source
      final source = await _mapboxMap!.style.getSource(_boundarySourceId);
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geoJson);
      }
    } catch (e) {
      debugPrint('Error updating scope boundary: $e');
    }
  }

  // Fixed resolution from remote config for consistent hex display across all screens and zoom levels
  static int get _fixedResolution =>
      RemoteConfigService().config.hexConfig.baseResolution;

  /// Determine current geographic scope based on zoom level
  /// Aligned with GeographicScope zoom levels from h3_config.dart:
  /// - ZONE: zoom >= 14 → neighborhood view
  /// - CITY: zoom >= 12 → district view
  /// - ALL: zoom < 12 → metro/region view
  GeographicScope get _currentScope {
    if (_currentZoom >= 14) {
      return GeographicScope.zone;
    } else if (_currentZoom >= 12) {
      return GeographicScope.city;
    } else {
      return GeographicScope.all;
    }
  }

  /// Builds GeoJSON FeatureCollection for hex polygons with data-driven styling
  String _buildHexGeoJson(List<String> hexIds) {
    final features = <Map<String, dynamic>>[];

    for (final hexId in hexIds) {
      final boundary = HexService().getHexBoundary(hexId);
      if (boundary.isEmpty) continue;

      // Calculate hex center
      double avgLat = 0, avgLng = 0;
      for (final p in boundary) {
        avgLat += p.latitude;
        avgLng += p.longitude;
      }
      avgLat /= boundary.length;
      avgLng /= boundary.length;

      final hexCenter = latlong.LatLng(avgLat, avgLng);
      final hex = _hexProvider.getHex(hexId, hexCenter);

      // Build coordinates (GeoJSON uses [lng, lat] order)
      final coordinates = boundary
          .map((p) => [p.longitude, p.latitude])
          .toList();
      coordinates.add(coordinates.first); // Close the polygon

      // Determine colors and opacity (same logic as before)
      final isUserHex = hexId == _currentUserHexId;
      final teamColor = widget.teamColor ?? AppTheme.electricBlue;

      // Check if hex is within home scope range (based on current zoom/scope)
      // ZONE view: no limit (all hexes colored)
      // CITY/ALL views: hexes are generated from home hex center, so all in-range
      final prefetch = PrefetchService();
      final currentScope = _currentScope;
      // When we have a home hex, CITY/ALL hexes are generated from home center
      // so they're all in-range by definition. Only check scope if no home hex.
      final bool inRange =
          currentScope == GeographicScope.zone ||
          !prefetch.isInitialized ||
          prefetch.homeHex != null;

      // Out-of-range hexes shown as gray/disabled
      final Color fillColor;
      final Color outlineColor;
      final double opacity;

      if (!inRange) {
        // Gray styling for out-of-range hexes
        fillColor = const Color(0xFF333333);
        outlineColor = const Color(0xFF444444);
        opacity = 0.2;
      } else if (isUserHex) {
        fillColor = teamColor;
        outlineColor = teamColor;
        opacity = 0.5;
      } else {
        fillColor = hex.hexLightColor;
        outlineColor = hex.hexColor;
        opacity = hex.isNeutral ? 0.15 : 0.3;
      }

      // Convert color to hex string for GeoJSON
      String colorToHex(Color c) =>
          '#${c.toARGB32().toRadixString(16).substring(2)}';

      features.add({
        'type': 'Feature',
        'id': hexId,
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coordinates],
        },
        'properties': {
          'fill-color': colorToHex(fillColor),
          'fill-opacity': opacity,
          'fill-outline-color': colorToHex(outlineColor),
          'in-range': inRange,
        },
      });
    }

    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  // Re-implementing _updateHexagons to fix the mapping logic
  Future<void> _updateHexagons() async {
    // Guard: all required objects must be ready and widget is mounted
    if (!mounted ||
        _mapboxMap == null ||
        // _polygonManager == null || // Removed
        !_isMapReady) {
      return;
    }

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center;
      final zoom = cameraState.zoom;

      _currentZoom = zoom;

      // Use fixed resolution - hexagons maintain same size regardless of zoom
      final int resolution = _fixedResolution;

      // Determine current scope based on zoom level
      final currentScope = _currentScope;

      // Generate hex IDs based on scope:
      // - ZONE: camera-following k-ring (dynamic)
      // - CITY/ALL: strict parent cell boundary (fixed)
      List<String> hexIds;
      String? parentHexForBoundary; // Track parent hex for boundary rendering

      if (currentScope == GeographicScope.zone) {
        // ZONE: camera-following k-ring (no boundary needed)
        final lat = center.coordinates.lat;
        final lng = center.coordinates.lng;
        final zoneCenter = latlong.LatLng(lat.toDouble(), lng.toDouble());
        hexIds = HexService().getHexagonsInArea(zoneCenter, resolution, 5);
      } else {
        // CITY/ALL: strict parent cell boundary
        final homeHex = PrefetchService().homeHex;
        if (homeHex == null) {
          // Fallback to camera center with k-ring if no home hex
          final lat = center.coordinates.lat;
          final lng = center.coordinates.lng;
          final fallbackCenter = latlong.LatLng(lat.toDouble(), lng.toDouble());
          hexIds = HexService().getHexagonsInArea(
            fallbackCenter,
            resolution,
            10,
          );
        } else {
          // Get parent cell at scope resolution, then expand to base resolution
          final scopeResolution = currentScope.resolution;
          parentHexForBoundary = HexService().getParentHexId(
            homeHex,
            scopeResolution,
          );
          hexIds = HexService().getAllChildrenAtResolution(
            parentHexForBoundary,
            resolution,
          );
        }
      }

      // Update scope boundary line (CITY/ALL views only)
      // Pass the parent hex ID to draw H3's geometric boundary (soft blur line)
      _updateScopeBoundary(currentScope, parentHexId: parentHexForBoundary);

      _visibleHexIds = hexIds;

      // Re-check after async operations - state may have changed
      if (!mounted) return;

      // Build GeoJSON and update source atomically (no flash!)
      final geoJson = _buildHexGeoJson(hexIds);
      try {
        final source = await _mapboxMap!.style.getSource(_hexSourceId);
        if (source is GeoJsonSource) {
          await source.updateGeoJSON(geoJson);
        }
      } catch (e) {
        debugPrint('Error updating hex GeoJSON: $e');
      }

      await _labelManager?.deleteAll();

      // Add score labels if zoom is high enough
      if (widget.showScoreLabels && _currentZoom >= 13) {
        final labelOptions = <PointAnnotationOptions>[];

        for (final hexId in hexIds) {
          final boundary = HexService().getHexBoundary(hexId);
          if (boundary.isEmpty) continue;

          double avgLat = 0, avgLng = 0;
          for (final p in boundary) {
            avgLat += p.latitude;
            avgLng += p.longitude;
          }
          avgLat /= boundary.length;
          avgLng /= boundary.length;

          final hexCenter = latlong.LatLng(avgLat, avgLng);
          final hex = _hexProvider.getCachedHex(
            hexId,
          ); // Already cached from previous loop

          if (hex != null && !hex.isNeutral) {
            labelOptions.add(
              PointAnnotationOptions(
                geometry: Point(
                  coordinates: Position(
                    hexCenter.longitude,
                    hexCenter.latitude,
                  ),
                ),
                textField: hex.emoji, // Show Emoji for last runner's team
                textSize: 16.0,
                textAnchor: TextAnchor.CENTER,
              ),
            );
          }
        }

        if (labelOptions.isNotEmpty) {
          await _labelManager!.createMulti(labelOptions);
        }
      }

      // Update aggregated scores callback
      if (widget.onScoresUpdated != null) {
        final stats = _hexProvider.getAggregatedStats(_visibleHexIds);
        widget.onScoresUpdated!(stats);
      }

      // Trigger UI update for score bar
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error updating hexagons: $e');
    }
  }

  @override
  void didUpdateWidget(HexagonMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if route changed and needs redrawing
    if (widget.route != null && widget.route!.isNotEmpty) {
      final routeLength = widget.route!.length;
      if (routeLength != _lastRouteLength) {
        _drawRoute();
      }
    } else if (oldWidget.route != null &&
        oldWidget.route!.isNotEmpty &&
        (widget.route == null || widget.route!.isEmpty)) {
      // Route was cleared - remove the line
      _polylineManager?.deleteAll();
      _lastRouteLength = 0;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationSubscription?.cancel();
    _hexProvider.removeListener(_onHexDataChanged);
    _labelManager = null;
    _polylineManager = null;

    // Clean up GeoJSON source and layer (fire and forget - don't block dispose)
    final mapboxMap = _mapboxMap;
    if (mapboxMap != null) {
      Future.microtask(() async {
        try {
          await mapboxMap.style.removeStyleLayer(_hexLayerId);
          await mapboxMap.style.removeStyleSource(_hexSourceId);
          await mapboxMap.style.removeStyleLayer(_boundaryLayerId);
          await mapboxMap.style.removeStyleSource(_boundarySourceId);
        } catch (e) {
          debugPrint('Error cleaning up hex layer/source: $e');
        }
      });
    }

    _mapboxMap = null;
    super.dispose();
  }
}

/// Widget overlay that positions the glowing location marker on the map
class _UserLocationOverlay extends StatefulWidget {
  final MapboxMap mapboxMap;
  final latlong.LatLng userLocation;
  final Color teamColor;

  const _UserLocationOverlay({
    super.key,
    required this.mapboxMap,
    required this.userLocation,
    required this.teamColor,
  });

  @override
  State<_UserLocationOverlay> createState() => _UserLocationOverlayState();
}

class _UserLocationOverlayState extends State<_UserLocationOverlay>
    with SingleTickerProviderStateMixin {
  Offset? _screenPosition;
  Offset? _previousPosition;
  late AnimationController _animationController;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _updateScreenPosition();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_UserLocationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLocation != widget.userLocation) {
      _previousPosition = _screenPosition;
      _updateScreenPosition();
    }
  }

  Future<void> _updateScreenPosition() async {
    try {
      final point = Point(
        coordinates: Position(
          widget.userLocation.longitude,
          widget.userLocation.latitude,
        ),
      );

      final screenCoordinate = await widget.mapboxMap.pixelForCoordinate(point);
      final newPosition = Offset(
        screenCoordinate.x.toDouble(),
        screenCoordinate.y.toDouble(),
      );

      if (mounted) {
        final startPosition = _previousPosition ?? newPosition;

        _positionAnimation =
            Tween<Offset>(begin: startPosition, end: newPosition).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOutCubic,
              ),
            );

        _animationController.forward(from: 0.0);

        setState(() {
          _screenPosition = newPosition;
        });
      }
    } catch (e) {
      debugPrint('Error calculating screen position: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_screenPosition == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // If animation hasn't started or is invalid, use current position
        final position = _animationController.isAnimating
            ? _positionAnimation.value
            : _screenPosition!;

        return Positioned(
          left: position.dx - 36, // Center the 72px marker
          top: position.dy - 36,
          child: child!,
        );
      },
      child: GlowingLocationMarker(
        accentColor: widget.teamColor,
        size: 24.0,
        enablePulse: true,
      ),
    );
  }
}
