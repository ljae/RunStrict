import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/hex_model.dart';
import '../models/team.dart';
import '../repositories/hex_repository.dart';

export '../repositories/hex_repository.dart' show HexUpdateResult;

/// Hex data provider - thin wrapper around HexRepository for Provider pattern.
///
/// Delegates hex state to HexRepository (single source of truth).
/// Provides UI concerns: simulation fallback for missing hexes.
///
/// Privacy optimized: Only stores lastRunnerTeam + lastFlippedAt (for conflict resolution).
/// Memory optimized: Uses LRU cache via HexRepository to limit memory usage.
///
/// Note: No daily flip limit - same hex can be flipped multiple times per day.
class HexDataProvider with ChangeNotifier {
  final HexRepository _hexRepository = HexRepository();

  // Singleton
  static final HexDataProvider _instance = HexDataProvider._internal();
  factory HexDataProvider() => _instance;

  HexDataProvider._internal() {
    // Listen to HexRepository changes and forward notifications
    _hexRepository.addListener(_onHexRepositoryChanged);
  }

  void _onHexRepositoryChanged() {
    notifyListeners();
  }

  /// Get current user location from repository
  LatLng? get userLocation => _hexRepository.userLocation;

  /// Get current user hex ID from repository
  String? get currentUserHexId => _hexRepository.currentUserHexId;

  /// Stream of user location updates from repository
  Stream<LatLng> get locationStream => _hexRepository.locationStream;

  /// Update the shared user location (called during active runs)
  void updateUserLocation(LatLng location, String hexId) {
    _hexRepository.updateUserLocation(location, hexId);
    // notifyListeners() called via _onHexRepositoryChanged
  }

  /// Clear user location (called when run ends)
  void clearUserLocation() {
    _hexRepository.clearUserLocation();
    // notifyListeners() called via _onHexRepositoryChanged
  }

  /// Get cached hex if exists (from HexRepository)
  HexModel? getCachedHex(String hexId) {
    return _hexRepository.getHex(hexId);
  }

  /// Get cache stats for debugging/monitoring
  String get cacheStats {
    final stats = _hexRepository.cacheStats;
    return 'HexCache(size=${stats['size']}, maxSize=${stats['maxSize']}, hits=${stats['hits']}, misses=${stats['misses']})';
  }

  /// Get or create hex model for an ID
  ///
  /// Lookup order:
  /// 1. HexRepository cache (single source of truth, includes prefetched data)
  /// 2. Return neutral (unclaimed) hex — no fake simulation
  HexModel getHex(String hexId, dynamic center) {
    // center is expected to be LatLng from latlong2

    // 1. Check HexRepository cache (single source of truth, includes prefetched data)
    final cached = _hexRepository.getHex(hexId);
    if (cached != null) return cached;

    // 2. Not in cache = unclaimed hex (neutral)
    return HexModel(id: hexId, center: center, lastRunnerTeam: null);
  }

  /// Update hex with runner's color (delegates to HexRepository)
  ///
  /// Returns HexUpdateResult indicating the outcome of the update attempt.
  ///
  /// Daily flip rule: A runner can only earn flip points from the same hex
  /// once per day. This prevents farming points by repeatedly flipping.
  HexUpdateResult updateHexColor(String hexId, Team runnerTeam) {
    return _hexRepository.updateHexColor(hexId, runnerTeam);
    // notifyListeners() called via _onHexRepositoryChanged
  }

  /// Clear captured hexes (call when run ends or new run starts)
  void clearCapturedHexes() {
    _hexRepository.clearCapturedHexes();
    debugPrint('HexDataProvider: Cleared captured hexes for new session');
  }

  /// Get aggregated stats for visible hexes
  HexAggregatedStats getAggregatedStats(List<String> hexIds) {
    int blueCount = 0;
    int redCount = 0;
    int purpleCount = 0;
    int neutralCount = 0;

    for (final hexId in hexIds) {
      final hex = _hexRepository.getHex(hexId);
      if (hex == null || hex.lastRunnerTeam == null) {
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

    return HexAggregatedStats(
      blueCount: blueCount,
      redCount: redCount,
      purpleCount: purpleCount,
      neutralCount: neutralCount,
    );
  }

  /// Clear all hex data (for season reset / The Void)
  void clearAllHexData() {
    _hexRepository.clearAll();
    debugPrint('HexDataProvider: All hex data cleared (The Void)');
    // notifyListeners() called via _onHexRepositoryChanged
  }

  @override
  void dispose() {
    _hexRepository.removeListener(_onHexRepositoryChanged);
    super.dispose();
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
