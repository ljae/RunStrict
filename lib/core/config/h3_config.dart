import 'dart:math' show pow;

import '../services/remote_config_service.dart';

/// H3 Resolution Configuration for RunStrict
///
/// The H3 hierarchical spatial index uses resolutions 0-15, where higher
/// resolutions create smaller hexagons. RunStrict uses Resolution 9 as the
/// base gameplay hex, with parent resolutions for geographic scope filtering.
///
/// Resolution Reference:
/// - Res 5: ~252 km², ~8.5km edge (Province - PROVINCE scope)
/// - Res 6: ~36 km², ~3.2km edge (District - DISTRICT scope)
/// - Res 8: ~0.73 km², ~461m edge (Neighborhood - ZONE scope)
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

  /// District scope resolution (District level)
  /// Edge: ~3.2km, Area: ~36 km²
  static int get districtResolution =>
      RemoteConfigService().config.hexConfig.districtResolution;

  /// Province scope resolution (Province level)
  /// Edge: ~8.5km, Area: ~252 km²
  static int get provinceResolution =>
      RemoteConfigService().config.hexConfig.provinceResolution;

  /// Approximate children count per parent
  ///
  /// H3 uses Aperture 7, meaning each parent hex contains ~7 children.
  /// - Res 9 -> Res 8: ~7 hexes (ZONE)
  /// - Res 9 -> Res 6: ~7^3 = 343 hexes (DISTRICT)
  /// - Res 9 -> Res 5: ~7^4 = 2,401 hexes (PROVINCE)
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

  /// District: District level (~3.2km radius)
  /// - Shows individual hexes with stats overlay
  /// - Leaderboard filters by Res 6 parent cell
  district(resolution: 6, zoomLevel: 12.0, label: 'DISTRICT', description: 'District'),

  /// Province: Province level (no geographic filter)
  /// - Shows dense hex grid with stats overlay (~2,401 hexes)
  /// - Leaderboard shows all users in province
  province(resolution: 5, zoomLevel: 11.0, label: 'PROVINCE', description: 'Province');

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

  /// Get scope from index (0=zone, 1=district, 2=province)
  static GeographicScope fromIndex(int index) {
    return switch (index) {
      0 => GeographicScope.zone,
      1 => GeographicScope.district,
      2 => GeographicScope.province,
      _ => GeographicScope.zone,
    };
  }

  /// Get scope index for UI (zone=0, district=1, province=2)
  int get scopeIndex => switch (this) {
    GeographicScope.zone => 0,
    GeographicScope.district => 1,
    GeographicScope.province => 2,
  };

  /// Resolution delta from base resolution to this scope
  int get resolutionDelta => H3Config.baseResolution - resolution;

  /// Approximate number of base hexes in one scope hex
  int get approximateBaseHexCount =>
      H3Config.childrenPerParent(resolutionDelta);
}
