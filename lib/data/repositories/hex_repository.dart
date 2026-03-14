import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config/h3_config.dart';
import '../models/hex_model.dart';
import '../models/team.dart';
import '../../core/services/hex_service.dart';
import '../../core/services/remote_config_service.dart';
import '../../core/utils/lru_cache.dart';

/// Result of hex color update operation
enum HexUpdateResult { flipped, sameTeam, alreadyCapturedSession, error }

/// HexRepository consolidates dual hex caches into a single source of truth.
///
/// Manages:
/// - LRU cache for memory-efficient hex storage
/// - User location tracking (shared across Map/Run screens)
/// - Session-specific capture tracking (prevents double-counting)
/// - Delta sync timing for prefetch operations
///
/// Privacy optimized: Only stores lastRunnerTeam + lastFlippedAt (for conflict resolution).
class HexRepository {
  // Singleton
  static final HexRepository _instance = HexRepository._internal();
  factory HexRepository() => _instance;

  // Testing constructor
  factory HexRepository.forTesting({required int maxCacheSize}) {
    return TestingHexRepository(maxCacheSize: maxCacheSize);
  }

  HexRepository._internal() {
    _initializeCache();
  }

  // Single LRU cache (consolidates HexDataProvider + PrefetchService caches)
  late LruCache<String, HexModel> _hexCache;

  // Local overlay: user's own today's flips — eviction-immune, never cleared by
  // bulkLoadFromSnapshot(). Keyed by hex_id → Team. Cleared only by clearAll()
  // (explicit full reset, e.g. home province change) or clearLocalOverlay().
  // getHex() merges this on top of the LRU result so today's flips always show.
  final Map<String, Team> _localOverlayHexes = {};

  void _initializeCache() {
    _hexCache = LruCache<String, HexModel>(
      maxSize: RemoteConfigService().config.hexConfig.maxCacheSize,
    );
  }

  // User location (shared across Map/Run screens)
  LatLng? _userLocation;
  String? _currentUserHexId;
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();

  // Run-specific state (NOT stored in cache)
  final Set<String> _capturedHexesThisSession = {};
  final Map<String, Team> _capturedHexTeams = {};

  // Delta sync tracking
  DateTime? _lastPrefetchTime;

  // Getters
  LatLng? get userLocation => _userLocation;
  String? get currentUserHexId => _currentUserHexId;
  Stream<LatLng> get locationStream => _locationController.stream;
  DateTime? get lastPrefetchTime => _lastPrefetchTime;

  /// Get cached hex if exists.
  ///
  /// Merges the eviction-immune local overlay on top: if the user flipped
  /// this hex today, their team color is always returned regardless of whether
  /// the LRU cache entry was evicted or overwritten by a snapshot reload.
  HexModel? getHex(String hexId) {
    final cached = _hexCache.get(hexId);
    final overlayTeam = _localOverlayHexes[hexId];
    if (overlayTeam == null) return cached;
    // Overlay wins — apply team on top of cached model (or create one).
    if (cached != null) return cached.copyWith(lastRunnerTeam: overlayTeam);
    try {
      final center = HexService().getHexCenter(hexId);
      return HexModel(id: hexId, center: center, lastRunnerTeam: overlayTeam);
    } catch (_) {
      return HexModel(
        id: hexId,
        center: const LatLng(0, 0),
        lastRunnerTeam: overlayTeam,
      );
    }
  }

  /// Update hex with runner's color
  ///
  /// Returns HexUpdateResult indicating the outcome of the update attempt.
  ///
  /// Session capture rule: A runner can only capture the same hex once per session.
  /// This prevents double-counting when re-entering a hex.
  HexUpdateResult updateHexColor(String hexId, Team runnerTeam) {
    final newTeam = runnerTeam;
    // Use getHex() which merges _hexCache + _localOverlayHexes so that
    // a hex flipped earlier today (in overlay) is not re-counted as a flip.
    final existing = getHex(hexId);

    // Check if this hex was already captured this session
    // This prevents double-counting when re-entering a hex
    if (_capturedHexesThisSession.contains(hexId)) {
      debugPrint('HEX ALREADY CAPTURED THIS SESSION: $hexId (no flip)');
      return HexUpdateResult.alreadyCapturedSession;
    }

    if (existing != null) {
      // Hex exists - check if color actually changes (flip)
      if (existing.lastRunnerTeam != newTeam) {
        debugPrint(
          'HEX FLIPPED: $hexId from ${existing.lastRunnerTeam} -> $newTeam',
        );
        _hexCache.put(hexId, existing.copyWith(lastRunnerTeam: newTeam));
        _capturedHexesThisSession.add(hexId);
        _capturedHexTeams[hexId] = newTeam;
        _localOverlayHexes[hexId] = newTeam; // persist through snapshot reloads
        return HexUpdateResult.flipped; // Color changed (flipped)
      }
      // Same team as current owner (snapshot or overlay) — no color change, no flip
      debugPrint('HEX SAME TEAM: $hexId already $newTeam (no flip)');
      _capturedHexesThisSession.add(hexId);
      return HexUpdateResult.sameTeam; // No color change = not a flip
    } else {
      // Hex not in cache or overlay - create it with the runner's color
      try {
        final hexCenter = HexService().getHexCenter(hexId);
        _hexCache.put(
          hexId,
          HexModel(id: hexId, center: hexCenter, lastRunnerTeam: newTeam),
        );
        _capturedHexesThisSession.add(hexId);
        _capturedHexTeams[hexId] = newTeam;
        _localOverlayHexes[hexId] = newTeam; // persist through snapshot reloads
        debugPrint('HEX CREATED & CAPTURED: $hexId -> $newTeam');
        return HexUpdateResult.flipped; // New hex, counts as capture
      } catch (e) {
        debugPrint('HexRepository: Failed to create hex $hexId: $e');
        return HexUpdateResult.error;
      }
    }
  }

  void setLastPrefetchTime(DateTime time) {
    _lastPrefetchTime = time;
  }

  void bulkLoadFromServer(List<Map<String, dynamic>> hexes) {
    final hexService = HexService();
    for (final hexData in hexes) {
      try {
        // Support both 'id' (full row) and 'hex_id' (delta sync)
        final hexId = (hexData['id'] ?? hexData['hex_id']) as String;
        final teamName = hexData['last_runner_team'] as String?;
        final team = teamName != null ? Team.values.byName(teamName) : null;
        final flippedAt = hexData['last_flipped_at'] != null
            ? DateTime.parse(hexData['last_flipped_at'] as String)
            : null;

        // Calculate center from hex ID (delta sync doesn't include coordinates)
        // Use provided lat/lng if available, otherwise calculate from hex ID
        LatLng hexCenter;
        if (hexData['latitude'] != null && hexData['longitude'] != null) {
          hexCenter = LatLng(
            (hexData['latitude'] as num).toDouble(),
            (hexData['longitude'] as num).toDouble(),
          );
        } else {
          try {
            hexCenter = hexService.getHexCenter(hexId);
          } catch (_) {
            // Fallback for invalid hex IDs (e.g., in tests)
            hexCenter = const LatLng(0, 0);
          }
        }

        _hexCache.put(
          hexId,
          HexModel(
            id: hexId,
            center: hexCenter,
            lastRunnerTeam: team,
            lastFlippedAt: flippedAt,
          ),
        );
      } catch (e) {
        debugPrint('HexRepository: Failed to load hex from server: $e');
      }
    }
    _lastPrefetchTime = DateTime.now();
    debugPrint('HexRepository: bulkLoadFromServer - loaded ${hexes.length}, cache now ${_hexCache.size}');
  }

  /// Load hex data from the daily snapshot (frozen at midnight GMT+2).
  ///
  /// Clears the existing cache and replaces with snapshot data.
  /// The snapshot contains {hex_id, last_runner_team, last_run_end_time}.
  /// After calling this, use [applyLocalOverlay] to add the user's own
  /// today's flips on top.
  void bulkLoadFromSnapshot(List<Map<String, dynamic>> hexes) {
    debugPrint('HexRepository: bulkLoadFromSnapshot - clearing ${_hexCache.size} hexes, loading ${hexes.length} from snapshot');
    _hexCache.clear();
    final hexService = HexService();
    for (final hexData in hexes) {
      try {
        final hexId = hexData['hex_id'] as String;
        final teamName = hexData['last_runner_team'] as String?;
        final team = teamName != null ? Team.values.byName(teamName) : null;
        final flippedAt = hexData['last_run_end_time'] != null
            ? DateTime.parse(hexData['last_run_end_time'] as String)
            : null;

        LatLng hexCenter;
        try {
          hexCenter = hexService.getHexCenter(hexId);
        } catch (_) {
          hexCenter = const LatLng(0, 0);
        }

        _hexCache.put(
          hexId,
          HexModel(
            id: hexId,
            center: hexCenter,
            lastRunnerTeam: team,
            lastFlippedAt: flippedAt,
          ),
        );
      } catch (e) {
        debugPrint('HexRepository: Failed to load snapshot hex: $e');
      }
    }
    _lastPrefetchTime = DateTime.now();
    debugPrint('HexRepository: Loaded ${_hexCache.size} hexes from snapshot');
  }

  /// Apply local overlay: user's own today's flips on top of snapshot.
  ///
  /// Writes into the eviction-immune [_localOverlayHexes] map so the overlay
  /// survives LRU eviction and subsequent [bulkLoadFromSnapshot] calls.
  /// [todayFlips] - List of {hex_id, team} maps from LocalStorage.
  void applyLocalOverlay(List<Map<String, dynamic>> todayFlips) {
    for (final flipData in todayFlips) {
      try {
        final hexId = flipData['hex_id'] as String;
        final teamName = flipData['team'] as String;
        final team = Team.values.byName(teamName);
        _localOverlayHexes[hexId] = team;
      } catch (e) {
        debugPrint('HexRepository: Failed to apply overlay hex: $e');
      }
    }
    if (todayFlips.isNotEmpty) {
      debugPrint(
        'HexRepository: Applied ${todayFlips.length} local overlay hexes'
        ' (total overlay=${_localOverlayHexes.length})',
      );
    }
  }

  /// Clear only the local overlay (called at midnight when today becomes yesterday).
  ///
  /// After this, [bulkLoadFromSnapshot] will load tomorrow's snapshot and
  /// [applyLocalOverlay] will re-populate from the new day's SQLite runs.
  void clearLocalOverlay() {
    _localOverlayHexes.clear();
    debugPrint('HexRepository: Cleared local overlay');
  }

  void mergeFromServer(List<Map<String, dynamic>> hexes) {
    for (final hexData in hexes) {
      final hexId = hexData['hex_id'] as String;
      final teamName = hexData['last_runner_team'] as String?;
      final team = teamName != null ? Team.values.byName(teamName) : null;
      final flippedAt = hexData['last_flipped_at'] != null
          ? DateTime.parse(hexData['last_flipped_at'] as String)
          : null;

      final existing = _hexCache.get(hexId); // cache-merge: intentional direct cache read (no overlay needed for conflict resolution)
      if (existing != null) {
        // Only update if server data is newer (conflict resolution)
        if (flippedAt != null &&
            existing.lastFlippedAt != null &&
            flippedAt.isBefore(existing.lastFlippedAt!)) {
          continue; // Keep local (newer)
        }
        _hexCache.put(
          hexId,
          existing.copyWith(lastRunnerTeam: team, lastFlippedAt: flippedAt),
        );
      } else {
        try {
          final hexCenter = HexService().getHexCenter(hexId);
          _hexCache.put(
            hexId,
            HexModel(
              id: hexId,
              center: hexCenter,
              lastRunnerTeam: team,
              lastFlippedAt: flippedAt,
            ),
          );
        } catch (e) {
          debugPrint('HexRepository: Failed to merge hex $hexId: $e');
        }
      }
    }
    _lastPrefetchTime = DateTime.now();
  }

  /// Update user location (called during active runs)
  void updateUserLocation(LatLng location, String hexId) {
    _userLocation = location;
    _currentUserHexId = hexId;
    _locationController.add(location);
  }

  /// Clear user location (called when run ends)
  void clearUserLocation() {
    _userLocation = null;
    _currentUserHexId = null;
    clearCapturedHexes(); // Reset captured hexes for next run
  }

  /// Clear captured hexes (call when run ends or new run starts)
  void clearCapturedHexes() {
    _capturedHexesThisSession.clear();
    _capturedHexTeams.clear();
    debugPrint('HexRepository: Cleared captured hexes for new session');
  }

  /// Full reset (clears all state including cache AND local overlay).
  ///
  /// Use only for explicit province changes or season resets.
  /// For normal refreshes, [bulkLoadFromSnapshot] + [applyLocalOverlay] is
  /// sufficient and preserves today's flips via [_localOverlayHexes].
  void clearAll() {
    _hexCache.clear();
    _localOverlayHexes.clear();
    _userLocation = null;
    _currentUserHexId = null;
    _capturedHexesThisSession.clear();
    _capturedHexTeams.clear();
    _lastPrefetchTime = null;
    debugPrint('HexRepository: Cleared all state (including local overlay)');
  }

  /// Compute hex dominance from cached data for given scope parents.
  /// Returns {'provinceRange': {red, blue, purple, total}, 'districtRange': {...}}
  Map<String, Map<String, int>> computeHexDominance({
    required String homeHexProvince,
    String? homeHexDistrict,
    bool includeLocalOverlay = true,
  }) {
    int provinceRed = 0, provinceBlue = 0, provincePurple = 0, provinceTotal = 0;
    int districtRed = 0, districtBlue = 0, districtPurple = 0, districtTotal = 0;

    final hexService = HexService();

    _hexCache.forEach((hexId, hex) {
      // Local overlay wins over LRU cache for dominance counting
      final effectiveTeam = (includeLocalOverlay ? _localOverlayHexes[hexId] : null) ?? hex.lastRunnerTeam;
      final parentProvince = hexService.getParentHexId(
        hexId,
        H3Config.provinceResolution,
      );
      if (parentProvince == homeHexProvince) {
        provinceTotal++;
        switch (effectiveTeam) {
          case Team.red:
            provinceRed++;
          case Team.blue:
            provinceBlue++;
          case Team.purple:
            provincePurple++;
          case null:
            break;
        }

        if (homeHexDistrict != null) {
          final parentDistrict = hexService.getParentHexId(
            hexId,
            H3Config.districtResolution,
          );
          if (parentDistrict == homeHexDistrict) {
            districtTotal++;
            switch (effectiveTeam) {
              case Team.red:
                districtRed++;
              case Team.blue:
                districtBlue++;
              case Team.purple:
                districtPurple++;
              case null:
                break;
            }
          }
        }
      }
    });

    // Also count overlay-only hexes not present in the LRU cache
    if (includeLocalOverlay) {
    for (final entry in _localOverlayHexes.entries) {
      if (_hexCache.get(entry.key) != null) continue; // dedup: intentional — checking if overlay hex already counted via LRU iteration above
      final parentProvince = hexService.getParentHexId(
        entry.key,
        H3Config.provinceResolution,
      );
      if (parentProvince == homeHexProvince) {
        provinceTotal++;
        switch (entry.value) {
          case Team.red:
            provinceRed++;
          case Team.blue:
            provinceBlue++;
          case Team.purple:
            provincePurple++;
        }

        if (homeHexDistrict != null) {
          final parentDistrict = hexService.getParentHexId(
            entry.key,
            H3Config.districtResolution,
          );
          if (parentDistrict == homeHexDistrict) {
            districtTotal++;
            switch (entry.value) {
              case Team.red:
                districtRed++;
              case Team.blue:
                districtBlue++;
              case Team.purple:
                districtPurple++;
            }
          }
        }
      }
    } // end for loop
    } // end if (includeLocalOverlay)

    return {
      'provinceRange': {
        'red': provinceRed,
        'blue': provinceBlue,
        'purple': provincePurple,
        'total': provinceTotal,
      },
      'districtRange': {
        'red': districtRed,
        'blue': districtBlue,
        'purple': districtPurple,
        'total': districtTotal,
      },
    };
  }

  /// Get cache statistics for debugging/monitoring
  Map<String, int> get cacheStats {
    return {
      'size': _hexCache.size,
      'maxSize': _hexCache.maxSize,
      'hits': _hexCache.hits,
      'misses': _hexCache.misses,
      'overlay': _localOverlayHexes.length,
    };
  }

  void dispose() {
    _locationController.close();
  }
}

/// Testing subclass for HexRepository with custom cache size
class TestingHexRepository extends HexRepository {
  TestingHexRepository({required int maxCacheSize}) : super._internal() {
    _hexCache = LruCache<String, HexModel>(maxSize: maxCacheSize);
  }
}
