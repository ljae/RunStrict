import 'package:flutter/foundation.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../config/h3_config.dart';

class HexService {
  late H3 h3;
  bool _isInitialized = false;

  // Singleton
  static final HexService _instance = HexService._internal();
  factory HexService() => _instance;
  HexService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    h3 = const H3Factory().load();
    _isInitialized = true;
  }

  // Get Hex Index (String) from coordinates
  String getHexId(LatLng point, int resolution) {
    _checkInit();
    final h3Index = h3.geoToCell(
      GeoCoord(lat: point.latitude, lon: point.longitude),
      resolution,
    );
    return h3Index.toRadixString(16);
  }

  // Get Hex Boundary (Polygon)
  List<LatLng> getHexBoundary(String hexId) {
    _checkInit();
    // Hex ID is a hex string, convert to BigInt (H3Index)
    final h3Index = BigInt.parse(hexId, radix: 16);
    final boundary = h3.cellToBoundary(h3Index);
    return boundary.map((c) => LatLng(c.lat, c.lon)).toList();
  }

  // Get K-Ring (Neighbors)
  List<String> getHexagonsInArea(LatLng center, int resolution, int k) {
    _checkInit();
    final centerHex = h3.geoToCell(
      GeoCoord(lat: center.latitude, lon: center.longitude),
      resolution,
    );
    final neighbors = h3.gridDisk(centerHex, k);
    return neighbors.map((n) => n.toRadixString(16)).toList();
  }

  // Get all hexagons covering a rectangular area (viewport)
  // This uses polygonToCells
  List<String> getHexagonsInBounds(
    LatLng southWest,
    LatLng northEast,
    int resolution,
  ) {
    _checkInit();

    // Create a polygon for the bounds
    final polygon = [
      GeoCoord(lat: southWest.latitude, lon: southWest.longitude),
      GeoCoord(lat: northEast.latitude, lon: southWest.longitude),
      GeoCoord(lat: northEast.latitude, lon: northEast.longitude),
      GeoCoord(lat: southWest.latitude, lon: northEast.longitude),
      GeoCoord(lat: southWest.latitude, lon: southWest.longitude), // Close loop
    ];

    try {
      final hexIndices = h3.polygonToCells(
        perimeter: polygon,
        resolution: resolution,
      );
      return hexIndices.map((n) => n.toRadixString(16)).toList();
    } catch (e) {
      debugPrint('Error in polygonToCells: $e');
      return [];
    }
  }

  /// Get the parent hex ID (one resolution lower)
  String getParentHexId(String hexId, int parentResolution) {
    _checkInit();
    final h3Index = BigInt.parse(hexId, radix: 16);
    final parentIndex = h3.cellToParent(h3Index, parentResolution);
    return parentIndex.toRadixString(16);
  }

  /// Get all 7 children hex IDs (one resolution higher)
  List<String> getChildHexIds(String hexId, int childResolution) {
    _checkInit();
    final h3Index = BigInt.parse(hexId, radix: 16);
    final children = h3.cellToChildren(h3Index, childResolution);
    return children.map((c) => c.toRadixString(16)).toList();
  }

  /// Get the resolution of a hex
  int getHexResolution(String hexId) {
    _checkInit();
    final h3Index = BigInt.parse(hexId, radix: 16);
    return h3.getResolution(h3Index);
  }

  /// Get hex center point
  LatLng getHexCenter(String hexId) {
    _checkInit();
    final h3Index = BigInt.parse(hexId, radix: 16);
    final center = h3.cellToGeo(h3Index);
    return LatLng(center.lat, center.lon);
  }

  void _checkInit() {
    if (!_isInitialized) {
      throw Exception('HexService not initialized. Call initialize() first.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Geographic Scope Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Get hex ID at base resolution (9) from coordinates
  /// This is the standard resolution for all gameplay hexes
  String getBaseHexId(LatLng point) {
    return getHexId(point, H3Config.baseResolution);
  }

  /// Get the scope hex ID for a given base hex
  ///
  /// Converts a base resolution hex (Res 9) to its parent at the scope's
  /// resolution level. Used for geographic filtering in leaderboards.
  ///
  /// Example:
  /// - baseHexId at Res 9 -> GeographicScope.zone returns Res 8 parent
  /// - baseHexId at Res 9 -> GeographicScope.city returns Res 6 parent
  String getScopeHexId(String baseHexId, GeographicScope scope) {
    if (scope == GeographicScope.all) {
      // ALL scope uses Res 4 parent
      return getParentHexId(baseHexId, scope.resolution);
    }
    return getParentHexId(baseHexId, scope.resolution);
  }

  /// Check if two base hexes are in the same geographic scope
  ///
  /// Two hexes are in the same scope if they share the same parent
  /// at the scope's resolution level.
  bool inSameScope(String hexId1, String hexId2, GeographicScope scope) {
    return getScopeHexId(hexId1, scope) == getScopeHexId(hexId2, scope);
  }

  /// Get all base hexes that belong to a scope hex
  ///
  /// Expands a parent hex at scope resolution to all its children
  /// at the base resolution. Useful for highlighting a region on the map.
  ///
  /// Note: This can return many hexes for large scopes:
  /// - ZONE (Res 8 -> 9): ~7 hexes
  /// - CITY (Res 6 -> 9): ~343 hexes
  /// - ALL (Res 4 -> 9): ~16,807 hexes
  List<String> getBaseHexesInScope(String scopeHexId) {
    return getChildHexIds(scopeHexId, H3Config.baseResolution);
  }

  /// Get scope hex ID directly from coordinates
  ///
  /// Convenience method that combines getBaseHexId and getScopeHexId.
  String getScopeHexIdFromCoords(LatLng point, GeographicScope scope) {
    final baseHexId = getBaseHexId(point);
    return getScopeHexId(baseHexId, scope);
  }

  /// Calculate approximate distance between hex centers in meters
  ///
  /// Uses the haversine formula for accuracy.
  double hexDistance(String hexId1, String hexId2) {
    final center1 = getHexCenter(hexId1);
    final center2 = getHexCenter(hexId2);
    const distance = Distance();
    return distance.as(LengthUnit.Meter, center1, center2);
  }
}
