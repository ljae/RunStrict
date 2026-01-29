import 'dart:math' show pow;

import '../services/remote_config_service.dart';

/// H3 Resolution Configuration for RunStrict
///
/// The H3 hierarchical spatial index uses resolutions 0-15, where higher
/// resolutions create smaller hexagons. RunStrict uses Resolution 9 as the
/// base gameplay hex, with parent resolutions for geographic scope filtering.
///
/// Resolution Reference:
/// - Res 4: ~1,770 km², ~22.6km edge (Metro/Region)
/// - Res 6: ~36 km², ~3.2km edge (City/District)
/// - Res 8: ~0.73 km², ~461m edge (Neighborhood)
/// - Res 9: ~0.10 km², ~174m edge (Block - Base gameplay)
///
/// H3 uses Aperture 7 subdivision: each parent contains ~7 children.
class H3Config {
  H3Config._();

  /// Base gameplay resolution - ALL flip points calculated at this level
  /// Edge: ~174m, Area: ~0.10 km²
  static int get baseResolution =>
      RemoteConfigService().config.hexConfig.baseResolution;

  /// Zone scope resolution (Neighborhood level)
  /// Edge: ~461m, Area: ~0.73 km²
  static int get zoneResolution =>
      RemoteConfigService().config.hexConfig.zoneResolution;

  /// City scope resolution (District level)
  /// Edge: ~3.2km, Area: ~36 km²
  static int get cityResolution =>
      RemoteConfigService().config.hexConfig.cityResolution;

  /// All/Region scope resolution (Metro area level)
  /// Edge: ~22.6km, Area: ~1,770 km²
  static int get allResolution =>
      RemoteConfigService().config.hexConfig.allResolution;

  /// Approximate children count per parent
  ///
  /// H3 uses Aperture 7, meaning each parent hex contains ~7 children.
  /// - Res 9 -> Res 8: ~7 hexes
  /// - Res 9 -> Res 6: ~7^3 = 343 hexes
  /// - Res 9 -> Res 4: ~7^5 = 16,807 hexes
  static int childrenPerParent(int resolutionDelta) {
    if (resolutionDelta <= 0) return 1;
    return pow(7, resolutionDelta).round();
  }
}

/// Geographic scope for leaderboard filtering and map display
///
/// Each scope corresponds to an H3 parent resolution level.
/// Users within the same parent hex are considered "in the same scope".
enum GeographicScope {
  /// Zone: Neighborhood level (~461m radius)
  /// - Shows individual hexes with user location
  /// - Leaderboard filters by Res 8 parent cell
  zone(
    resolution: 8,
    zoomLevel: 15.0,
    label: 'ZONE',
    description: 'Neighborhood',
  ),

  /// City: District level (~3.2km radius)
  /// - Shows individual hexes with stats overlay
  /// - Leaderboard filters by Res 6 parent cell
  city(resolution: 6, zoomLevel: 12.0, label: 'CITY', description: 'District'),

  /// All: Metro/Region level (no geographic filter)
  /// - Shows dense hex grid with stats overlay
  /// - Leaderboard shows all users (no filter)
  all(resolution: 4, zoomLevel: 10.0, label: 'ALL', description: 'Region');

  /// H3 resolution for this scope's parent cell grouping
  final int resolution;

  /// Recommended map zoom level for this scope
  final double zoomLevel;

  /// Display label for UI
  final String label;

  /// Human-readable description
  final String description;

  const GeographicScope({
    required this.resolution,
    required this.zoomLevel,
    required this.label,
    required this.description,
  });

  /// Get scope from index (0=zone, 1=city, 2=all)
  static GeographicScope fromIndex(int index) {
    return switch (index) {
      0 => GeographicScope.zone,
      1 => GeographicScope.city,
      2 => GeographicScope.all,
      _ => GeographicScope.zone,
    };
  }

  /// Get scope index for UI (zone=0, city=1, all=2)
  int get scopeIndex => switch (this) {
    GeographicScope.zone => 0,
    GeographicScope.city => 1,
    GeographicScope.all => 2,
  };

  /// Resolution delta from base resolution to this scope
  int get resolutionDelta => H3Config.baseResolution - resolution;

  /// Approximate number of base hexes in one scope hex
  int get approximateBaseHexCount =>
      H3Config.childrenPerParent(resolutionDelta);
}
