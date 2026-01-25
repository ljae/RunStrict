import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart' as geo;
import '../services/hex_service.dart';
import '../models/location_point.dart';
import '../models/team.dart';
import '../services/local_storage_service.dart';
import '../theme/app_theme.dart';
import '../providers/hex_data_provider.dart';
import '../widgets/glowing_location_marker.dart';

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
  MapboxMap? _mapboxMap;
  PolygonAnnotationManager? _polygonManager;
  PointAnnotationManager? _labelManager;
  PolylineAnnotationManager? _polylineManager; // For route tracking line
  bool _isMapReady = false;
  List<String> _visibleHexIds = [];
  double _currentZoom = 14.0;
  String? _currentUserHexId;
  latlong.LatLng? _userLocation;
  int _cameraChangeCounter = 0; // For forcing overlay updates
  int _lastRouteLength = 0; // Track route changes

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
    // Also sync user location if available
    if (_hexProvider.userLocation != null) {
      _userLocation = _hexProvider.userLocation;
      _currentUserHexId = _hexProvider.currentUserHexId;
    }
    if (_isMapReady) {
      _updateHexagons();
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
    _polygonManager = await _mapboxMap!.annotations
        .createPolygonAnnotationManager();
    _labelManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();
    _polylineManager = await _mapboxMap!.annotations
        .createPolylineAnnotationManager();

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
    _updateHexagons();
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
        lineColor: teamColor.value,
        lineWidth: 5.0,
        lineOpacity: 0.9,
      );

      await _polylineManager!.create(polylineOptions);
      _lastRouteLength = widget.route!.length;
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  // Fixed resolution 9 for consistent hex display across all screens and zoom levels
  static const int _fixedResolution = 9;

  // Re-implementing _updateHexagons to fix the mapping logic
  Future<void> _updateHexagons() async {
    // Guard: all required objects must be ready and widget is mounted
    if (!mounted ||
        _mapboxMap == null ||
        _polygonManager == null ||
        !_isMapReady) {
      return;
    }

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center;
      final zoom = cameraState.zoom;

      _currentZoom = zoom;

      // Use fixed resolution 9 - hexagons maintain same size regardless of zoom
      // Only adjust k-ring radius to show more/fewer hexagons based on viewport
      const int resolution = _fixedResolution;

      // Calculate k-ring radius based on zoom to cover visible viewport
      // Aligned with GeographicScope zoom levels from h3_config.dart:
      // - ZONE: zoom 15.0 → neighborhood view
      // - CITY: zoom 12.0 → district view
      // - ALL: zoom 10.0 → metro view
      //
      // k-ring formula: hexes = 1 + 3*k*(k+1)
      // Gap designed for clear visual differentiation between scopes
      int kRing;
      if (zoom >= 14) {
        kRing = 5; // ZONE view: ~91 hexes (neighborhood)
      } else if (zoom >= 12) {
        kRing = 10; // CITY view: ~331 hexes (district)
      } else if (zoom >= 10) {
        kRing = 35; // ALL view: ~3,711 hexes (metro area) - 10x CITY gap
      } else if (zoom >= 8) {
        kRing = 50; // Very zoomed out: ~7,651 hexes
      } else {
        kRing = 70; // Maximum coverage: ~14,911 hexes
      }

      // Safely extract coordinates
      final lat = center.coordinates.lat;
      final lng = center.coordinates.lng;
      if (lat == null || lng == null) {
        debugPrint('_updateHexagons: center coordinates are null');
        return;
      }
      final centerLatLng = latlong.LatLng(lat.toDouble(), lng.toDouble());

      final hexIds = HexService().getHexagonsInArea(
        centerLatLng,
        resolution,
        kRing,
      );

      _visibleHexIds = hexIds;

      // Re-check after async operations - state may have changed
      if (!mounted || _polygonManager == null) return;

      await _polygonManager!.deleteAll();
      if (_labelManager != null) {
        await _labelManager!.deleteAll();
      }

      final polygonOptions = <PolygonAnnotationOptions>[];

      for (final hexId in hexIds) {
        final boundary = HexService().getHexBoundary(hexId);
        if (boundary.isEmpty) continue;

        // Calculate center for label
        double avgLat = 0, avgLng = 0;
        for (final p in boundary) {
          avgLat += p.latitude;
          avgLng += p.longitude;
        }
        avgLat /= boundary.length;
        avgLng /= boundary.length;

        final hexCenter = latlong.LatLng(avgLat, avgLng);
        final hex = _hexProvider.getHex(hexId, hexCenter);

        final coordinates = boundary
            .map((p) => Position(p.longitude, p.latitude))
            .toList();

        if (coordinates.isNotEmpty) {
          coordinates.add(coordinates.first); // Close loop
        }

        // Highlight user's current hex
        final isUserHex = hexId == _currentUserHexId;
        final teamColor = widget.teamColor ?? AppTheme.electricBlue;

        final fillColor = isUserHex ? teamColor : hex.hexLightColor;
        final outlineColor = isUserHex ? teamColor : hex.hexColor;

        // Static opacity: user hex brighter, neutral subtle, colored moderate
        final double opacity = isUserHex
            ? 0.5
            : hex.isNeutral
            ? 0.15
            : 0.3;

        polygonOptions.add(
          PolygonAnnotationOptions(
            geometry: Polygon(coordinates: [coordinates]),
            fillColor: fillColor.toARGB32(),
            fillOutlineColor: outlineColor.toARGB32(),
            fillOpacity: opacity,
          ),
        );
      }

      // Re-check before createMulti - state may have changed during loop
      if (!mounted || _polygonManager == null) return;

      await _polygonManager!.createMulti(polygonOptions);

      // Add score labels if zoom is high enough
      if (widget.showScoreLabels &&
          _currentZoom >= 13 &&
          _labelManager != null) {
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
    _locationSubscription?.cancel();
    _hexProvider.removeListener(_onHexDataChanged);
    _polygonManager = null;
    _labelManager = null;
    _polylineManager = null;
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

class _UserLocationOverlayState extends State<_UserLocationOverlay> {
  Offset? _screenPosition;

  @override
  void initState() {
    super.initState();
    _updateScreenPosition();
  }

  @override
  void didUpdateWidget(_UserLocationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLocation != widget.userLocation) {
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

      if (mounted) {
        setState(() {
          _screenPosition = Offset(
            screenCoordinate.x.toDouble(),
            screenCoordinate.y.toDouble(),
          );
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

    return Positioned(
      left: _screenPosition!.dx - 36, // Center the 72px marker
      top: _screenPosition!.dy - 36,
      child: GlowingLocationMarker(
        accentColor: widget.teamColor,
        size: 24.0,
        enablePulse: true,
      ),
    );
  }
}
