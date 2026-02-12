import 'package:flutter/foundation.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../config/h3_config.dart';
import '../utils/lru_cache.dart';

class HexService {
  late H3 h3;
  bool _isInitialized = false;

  /// LRU cache for hex boundaries to avoid repeated H3 computations.
  /// Province scope has ~2,401 hexes - cache prevents recomputing boundaries.
  final LruCache<String, List<LatLng>> _boundaryCache =
      LruCache<String, List<LatLng>>(maxSize: 3000);

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

  /// Get Hex Boundary (Polygon) with LRU caching.
  ///
  /// Caches boundary coordinates to avoid repeated H3 computations.
  /// Critical for Province scope (~2,401 hexes).
  List<LatLng> getHexBoundary(String hexId) {
    _checkInit();

    // Check cache first
    final cached = _boundaryCache.get(hexId);
    if (cached != null) return cached;

    // Compute boundary
    final h3Index = BigInt.parse(hexId, radix: 16);
    final boundary = h3.cellToBoundary(h3Index);
    final result = boundary.map((c) => LatLng(c.lat, c.lon)).toList();

    // Cache for future use
    _boundaryCache.put(hexId, result);
    return result;
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

  /// Get all descendant hex IDs from parent resolution to target resolution.
  ///
  /// Recursively expands children until target resolution is reached.
  /// Useful for getting all base hexes within a parent cell boundary.
  ///
  /// Example counts (H3 has 7 children per parent):
  /// - Res 8 → Res 9: 7 hexes (ZONE)
  /// - Res 6 → Res 9: 343 hexes (CITY)
  /// - Res 5 → Res 9: 2,401 hexes (ALL)
  List<String> getAllChildrenAtResolution(
    String parentHexId,
    int targetResolution,
  ) {
    _checkInit();

    final parentIndex = BigInt.parse(parentHexId, radix: 16);
    final parentRes = h3.getResolution(parentIndex);

    // If already at target resolution, return the hex itself
    if (parentRes >= targetResolution) {
      return [parentHexId];
    }

    // Iteratively expand children until target resolution
    List<BigInt> currentLevel = [parentIndex];

    for (int res = parentRes + 1; res <= targetResolution; res++) {
      final List<BigInt> nextLevel = [];
      for (final hex in currentLevel) {
        nextLevel.addAll(h3.cellToChildren(hex, res));
      }
      currentLevel = nextLevel;
    }

    // Convert to hex strings
    return currentLevel.map((h) => h.toRadixString(16)).toList();
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
  /// - baseHexId at Res 9 -> GeographicScope.all returns Res 5 parent
  String getScopeHexId(String baseHexId, GeographicScope scope) {
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
  /// - ALL (Res 5 -> 9): ~2,401 hexes
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

  // ─────────────────────────────────────────────────────────────────────────
  // Territory Naming Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Word lists for generating human-friendly territory names.
  /// Each territory gets a unique "Adjective + Noun" combination.
  static const _territoryAdjectives = [
    'Amber',
    'Azure',
    'Coral',
    'Crystal',
    'Dawn',
    'Dusk',
    'Echo',
    'Ember',
    'Frost',
    'Golden',
    'Iron',
    'Jade',
    'Luna',
    'Maple',
    'Misty',
    'Nova',
    'Oak',
    'Pearl',
    'Pine',
    'Raven',
    'River',
    'Ruby',
    'Shadow',
    'Silver',
    'Solar',
    'Stone',
    'Storm',
    'Swift',
    'Thunder',
    'Velvet',
    'Violet',
    'Wild',
    'Crimson',
    'Cobalt',
    'Scarlet',
    'Sage',
    'Onyx',
    'Ivory',
    'Rustic',
    'Zenith',
  ];

  static const _territoryNouns = [
    'Ridge',
    'Vale',
    'Peak',
    'Hollow',
    'Grove',
    'Reach',
    'Bluff',
    'Crest',
    'Dell',
    'Glen',
    'Haven',
    'Heights',
    'Hills',
    'Knoll',
    'Landing',
    'Meadow',
    'Pass',
    'Point',
    'Shore',
    'Summit',
    'Terrace',
    'Trail',
    'View',
    'Woods',
    'Basin',
    'Canyon',
    'Cliff',
    'Field',
    'Harbor',
    'Island',
    'Lake',
    'Mesa',
    'Oasis',
    'Plains',
    'Ravine',
    'Springs',
    'Valley',
    'Crossing',
    'Bend',
    'Run',
  ];

  /// Get a user-friendly territory name from hex ID.
  ///
  /// Uses a deterministic algorithm to convert hex ID into a memorable
  /// "Adjective + Noun" combination like "Amber Ridge" or "Crystal Vale".
  /// Avoids confusing alphanumeric identifiers.
  String getTerritoryName(String baseHexId) {
    final res5Parent = getParentHexId(baseHexId, H3Config.allResolution);

    // Use last 8 characters of hex ID to generate indices
    final hashPart = res5Parent.length >= 8
        ? res5Parent.substring(res5Parent.length - 8)
        : res5Parent.padLeft(8, '0');

    // Parse as hex and use modulo to get indices
    final hashValue = int.tryParse(hashPart, radix: 16) ?? 0;
    final adjIndex = hashValue % _territoryAdjectives.length;
    final nounIndex =
        (hashValue ~/ _territoryAdjectives.length) % _territoryNouns.length;

    return '${_territoryAdjectives[adjIndex]} ${_territoryNouns[nounIndex]}';
  }

  /// Get the raw Territory ID (4-digit hex string) for internal use.
  ///
  /// Returns the last 4 characters of the Res 5 (ALL scope) parent hex ID.
  /// For display purposes, use [getTerritoryName] instead.
  String getTerritoryId(String baseHexId) {
    final res5Parent = getParentHexId(baseHexId, H3Config.allResolution);
    // Take last 4 hex characters, uppercase for display
    final last4 = res5Parent.length >= 4
        ? res5Parent.substring(res5Parent.length - 4)
        : res5Parent;
    return last4.toUpperCase();
  }

  /// Get the City number (1-7) within its parent Territory.
  ///
  /// Each Territory (Res 5) contains ~7 City hexes (Res 6).
  /// This returns the position of the city among its siblings,
  /// providing a simple 1-7 identifier.
  ///
  /// Returns 1-7 based on the city's position among its 7 siblings.
  int getCityNumber(String baseHexId) {
    // Get the Res 6 (city) parent
    final cityHexId = getParentHexId(baseHexId, H3Config.cityResolution);
    // Get the Res 5 (territory) parent
    final territoryHexId = getParentHexId(baseHexId, H3Config.allResolution);

    // Get all 7 city children of this territory
    final siblingCities = getChildHexIds(
      territoryHexId,
      H3Config.cityResolution,
    );

    // Sort siblings for consistent ordering (lexicographic)
    siblingCities.sort();

    // Find position (1-based)
    final index = siblingCities.indexOf(cityHexId);
    return index >= 0 ? index + 1 : 1;
  }

  /// Get formatted territory display string for a base hex.
  ///
  /// Returns user-friendly name like "Amber Ridge" for UI display.
  String getTerritoryDisplayName(String baseHexId) {
    return getTerritoryName(baseHexId);
  }

  /// Get formatted city display string for a base hex.
  ///
  /// Returns "District N" format for UI display.
  String getCityDisplayName(String baseHexId) {
    final cityNum = getCityNumber(baseHexId);
    return 'District $cityNum';
  }

  /// Generate a random territory name for dummy data.
  ///
  /// Uses provided seed for deterministic generation in tests.
  static String generateRandomTerritoryName(int seed) {
    final adjIndex = seed % _territoryAdjectives.length;
    final nounIndex =
        (seed ~/ _territoryAdjectives.length) % _territoryNouns.length;
    return '${_territoryAdjectives[adjIndex]} ${_territoryNouns[nounIndex]}';
  }
}
