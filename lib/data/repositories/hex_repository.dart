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

  /// Get cached hex if exists
  HexModel? getHex(String hexId) {
    return _hexCache.get(hexId);
  }

  /// Update hex with runner's color
  ///
  /// Returns HexUpdateResult indicating the outcome of the update attempt.
  ///
  /// Session capture rule: A runner can only capture the same hex once per session.
  /// This prevents double-counting when re-entering a hex.
  HexUpdateResult updateHexColor(String hexId, Team runnerTeam) {
    final newTeam = runnerTeam;
    final existing = _hexCache.get(hexId);

    // Check if this hex was already captured this session
    // This prevents double-counting when re-entering a hex
    if (_capturedHexesThisSession.contains(hexId)) {
      debugPrint('HEX ALREADY CAPTURED THIS SESSION: $hexId (no flip)');
      return HexUpdateResult.alreadyCapturedSession;
    }

    if (existing != null) {
      // Hex exists in cache - check if color actually changes (flip)
      if (existing.lastRunnerTeam != newTeam) {
        debugPrint(
          'HEX FLIPPED: $hexId from ${existing.lastRunnerTeam} -> $newTeam',
        );
        _hexCache.put(hexId, existing.copyWith(lastRunnerTeam: newTeam));
        _capturedHexesThisSession.add(hexId);
        _capturedHexTeams[hexId] = newTeam;
        return HexUpdateResult.flipped; // Color changed (flipped)
      }
      // Same team as current owner — no color change, no flip
      debugPrint('HEX SAME TEAM: $hexId already $newTeam (no flip)');
      _capturedHexesThisSession.add(hexId);
      return HexUpdateResult.sameTeam; // No color change = not a flip
    } else {
      // Hex not in cache - create it with the runner's color
      try {
        final hexCenter = HexService().getHexCenter(hexId);
        _hexCache.put(
          hexId,
          HexModel(id: hexId, center: hexCenter, lastRunnerTeam: newTeam),
        );
        _capturedHexesThisSession.add(hexId);
        _capturedHexTeams[hexId] = newTeam;
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
  /// [todayFlips] - List of {hex_id, team} maps from LocalStorage.
  /// This ensures the map shows the user's personal progress for today,
  /// even though the snapshot only reflects yesterday's state.
  void applyLocalOverlay(List<Map<String, dynamic>> todayFlips) {
    final hexService = HexService();
    for (final flipData in todayFlips) {
      try {
        final hexId = flipData['hex_id'] as String;
        final teamName = flipData['team'] as String;
        final team = Team.values.byName(teamName);

        final existing = _hexCache.get(hexId);
        if (existing != null) {
          // Update existing hex with user's flip
          _hexCache.put(hexId, existing.copyWith(lastRunnerTeam: team));
        } else {
          // New hex not in snapshot — create it
          LatLng hexCenter;
          try {
            hexCenter = hexService.getHexCenter(hexId);
          } catch (_) {
            hexCenter = const LatLng(0, 0);
          }
          _hexCache.put(
            hexId,
            HexModel(id: hexId, center: hexCenter, lastRunnerTeam: team),
          );
        }
      } catch (e) {
        debugPrint('HexRepository: Failed to apply overlay hex: $e');
      }
    }
    if (todayFlips.isNotEmpty) {
      debugPrint(
        'HexRepository: Applied ${todayFlips.length} local overlay hexes',
      );
    }
  }

  void mergeFromServer(List<Map<String, dynamic>> hexes) {
    for (final hexData in hexes) {
      final hexId = hexData['hex_id'] as String;
      final teamName = hexData['last_runner_team'] as String?;
      final team = teamName != null ? Team.values.byName(teamName) : null;
      final flippedAt = hexData['last_flipped_at'] != null
          ? DateTime.parse(hexData['last_flipped_at'] as String)
          : null;

      final existing = _hexCache.get(hexId);
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

  /// Full reset (clears all state including cache)
  void clearAll() {
    _hexCache.clear();
    _userLocation = null;
    _currentUserHexId = null;
    _capturedHexesThisSession.clear();
    _capturedHexTeams.clear();
    _lastPrefetchTime = null;
    debugPrint('HexRepository: Cleared all state');
  }

  /// Compute hex dominance from cached data for given scope parents.
  /// Returns {'allRange': {red, blue, purple, total}, 'cityRange': {...}}
  Map<String, Map<String, int>> computeHexDominance({
    required String homeHexAll,
    String? homeHexCity,
  }) {
    int allRed = 0, allBlue = 0, allPurple = 0, allTotal = 0;
    int cityRed = 0, cityBlue = 0, cityPurple = 0, cityTotal = 0;

    final hexService = HexService();

    _hexCache.forEach((hexId, hex) {
      final parentAll = hexService.getParentHexId(
        hexId,
        H3Config.allResolution,
      );
      if (parentAll == homeHexAll) {
        allTotal++;
        switch (hex.lastRunnerTeam) {
          case Team.red:
            allRed++;
          case Team.blue:
            allBlue++;
          case Team.purple:
            allPurple++;
          case null:
            break;
        }

        if (homeHexCity != null) {
          final parentCity = hexService.getParentHexId(
            hexId,
            H3Config.cityResolution,
          );
          if (parentCity == homeHexCity) {
            cityTotal++;
            switch (hex.lastRunnerTeam) {
              case Team.red:
                cityRed++;
              case Team.blue:
                cityBlue++;
              case Team.purple:
                cityPurple++;
              case null:
                break;
            }
          }
        }
      }
    });

    return {
      'allRange': {
        'red': allRed,
        'blue': allBlue,
        'purple': allPurple,
        'total': allTotal,
      },
      'cityRange': {
        'red': cityRed,
        'blue': cityBlue,
        'purple': cityPurple,
        'total': cityTotal,
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
