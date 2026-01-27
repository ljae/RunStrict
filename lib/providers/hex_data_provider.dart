import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/hex_model.dart';
import '../models/team.dart';
import '../services/hex_service.dart';
import '../utils/lru_cache.dart';

enum HexUpdateResult { flipped, sameTeam, alreadyCapturedSession, error }

/// Hex data provider for managing hex state (last runner color system)
///
/// Privacy optimized: Only stores lastRunnerTeam + lastFlippedAt (for conflict resolution).
/// Memory optimized: Uses LRU cache to limit memory usage.
///
/// Note: No daily flip limit - same hex can be flipped multiple times per day.
class HexDataProvider with ChangeNotifier {
  /// Max hex entries to keep in memory
  /// - ZONE: ~91 hexes
  /// - CITY: ~331 hexes
  /// - ALL: ~3,781 hexes
  /// With ~100 bytes per hex, 4000 hexes ≈ 400KB memory
  static const int maxCacheSize = 4000;

  // LRU cache for memory efficiency
  final LruCache<String, HexModel> _hexCache = LruCache<String, HexModel>(
    maxSize: maxCacheSize,
  );

  // Shared user location for synchronization between screens
  LatLng? _userLocation;
  String? _currentUserHexId;

  // Stream controller for location updates
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();

  // Singleton
  static final HexDataProvider _instance = HexDataProvider._internal();
  factory HexDataProvider() => _instance;
  HexDataProvider._internal();

  /// Get current user location
  LatLng? get userLocation => _userLocation;

  /// Get current user hex ID
  String? get currentUserHexId => _currentUserHexId;

  /// Stream of user location updates
  Stream<LatLng> get locationStream => _locationController.stream;

  /// Update the shared user location (called during active runs)
  void updateUserLocation(LatLng location, String hexId) {
    _userLocation = location;
    _currentUserHexId = hexId;
    _locationController.add(location);
    notifyListeners();
  }

  /// Clear user location (called when run ends)
  void clearUserLocation() {
    _userLocation = null;
    _currentUserHexId = null;
    clearCapturedHexes(); // Reset captured hexes for next run
    notifyListeners();
  }

  /// Get cached hex if exists
  HexModel? getCachedHex(String hexId) {
    return _hexCache.get(hexId);
  }

  /// Get cache stats for debugging/monitoring
  String get cacheStats => _hexCache.toString();

  /// Get or create hex model for an ID (with simulated last runner if new)
  HexModel getHex(String hexId, dynamic center) {
    // center is expected to be LatLng from latlong2
    final cached = _hexCache.get(hexId);
    if (cached != null) return cached;

    // Check if this hex was captured this session (survives LRU eviction)
    final capturedTeam = _capturedHexTeams[hexId];
    if (capturedTeam != null) {
      final hex = HexModel(
        id: hexId,
        center: center,
        lastRunnerTeam: capturedTeam,
      );
      _hexCache.put(hexId, hex);
      return hex;
    }

    // Create new hex with simulated last runner based on hash
    final hash = hexId.hashCode;
    final random = Random(hash);

    Team? lastRunner;
    final stateRoll = random.nextDouble();

    // Simulation distribution:
    // 20% Neutral (no one ran), 35% Blue, 35% Red, 10% Purple
    if (stateRoll < 0.20) {
      lastRunner = null; // Neutral - no one ran here yet
    } else if (stateRoll < 0.55) {
      lastRunner = Team.blue;
    } else if (stateRoll < 0.90) {
      lastRunner = Team.red;
    } else {
      lastRunner = Team.purple;
    }

    final hex = HexModel(id: hexId, center: center, lastRunnerTeam: lastRunner);
    _hexCache.put(hexId, hex);
    return hex;
  }

  /// Track hexes that have been captured by the runner during this session
  /// This ensures proper flip counting even when hex simulation assigns same team
  final Set<String> _capturedHexesThisSession = {};

  /// Persistent team colors for captured hexes (survives LRU eviction)
  /// Key: hexId, Value: team color set by the runner
  final Map<String, Team> _capturedHexTeams = {};

  /// Update hex with runner's color
  ///
  /// Returns HexUpdateResult indicating the outcome of the update attempt.
  ///
  /// Daily flip rule: A runner can only earn flip points from the same hex
  /// once per day. This prevents farming points by repeatedly flipping.
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
        notifyListeners();
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
        notifyListeners();
        return HexUpdateResult.flipped; // New hex, counts as capture
      } catch (e) {
        debugPrint('HexDataProvider: Failed to create hex $hexId: $e');
        return HexUpdateResult.error;
      }
    }
  }

  /// Update hex color in cache without counting as a flip
  void _updateHexColorInCache(String hexId, Team newTeam, HexModel? existing) {
    if (existing != null && existing.lastRunnerTeam != newTeam) {
      _hexCache.put(hexId, existing.copyWith(lastRunnerTeam: newTeam));
      _capturedHexTeams[hexId] = newTeam;
      notifyListeners();
    } else if (existing == null) {
      try {
        final hexCenter = HexService().getHexCenter(hexId);
        _hexCache.put(
          hexId,
          HexModel(id: hexId, center: hexCenter, lastRunnerTeam: newTeam),
        );
        _capturedHexTeams[hexId] = newTeam;
        notifyListeners();
      } catch (e) {
        debugPrint('HexDataProvider: Failed to update hex color: $e');
      }
    }
  }

  /// Clear captured hexes (call when run ends or new run starts)
  void clearCapturedHexes() {
    _capturedHexesThisSession.clear();
    _capturedHexTeams.clear();
    debugPrint('HexDataProvider: Cleared captured hexes for new session');
  }

  /// Get aggregated stats for visible hexes
  HexAggregatedStats getAggregatedStats(List<String> hexIds) {
    int blueCount = 0;
    int redCount = 0;
    int purpleCount = 0;
    int neutralCount = 0;

    for (final hexId in hexIds) {
      final hex = _hexCache.get(hexId);
      if (hex != null) {
        if (hex.lastRunnerTeam == null) {
          neutralCount++;
        } else {
          switch (hex.lastRunnerTeam!) {
            case Team.blue:
              blueCount++;
            case Team.red:
              redCount++;
            case Team.purple:
              purpleCount++;
          }
        }
      }
    }

    return HexAggregatedStats(
      blueCount: blueCount,
      redCount: redCount,
      purpleCount: purpleCount,
      neutralCount: neutralCount,
    );
  }

  /// Clear all hex data (for season reset / The Void)
  void clearAllHexData() {
    _hexCache.clear();
    _capturedHexesThisSession.clear();
    _capturedHexTeams.clear();
    debugPrint('HexDataProvider: All hex data cleared (The Void)');
    notifyListeners();
  }
}

/// Aggregated hex stats for a region
class HexAggregatedStats {
  final int blueCount;
  final int redCount;
  final int purpleCount;
  final int neutralCount;

  HexAggregatedStats({
    this.blueCount = 0,
    this.redCount = 0,
    this.purpleCount = 0,
    this.neutralCount = 0,
  });

  int get totalHexes => blueCount + redCount + purpleCount + neutralCount;
}
