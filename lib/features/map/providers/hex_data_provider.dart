import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/hex_model.dart';
import '../../../data/models/team.dart';
import '../../../data/repositories/hex_repository.dart';

export '../../../data/repositories/hex_repository.dart' show HexUpdateResult;

class HexDataState {
  final LatLng? userLocation;
  final String? currentUserHexId;
  final int version; // bump to trigger rebuilds

  const HexDataState({
    this.userLocation,
    this.currentUserHexId,
    this.version = 0,
  });

  HexDataState copyWith({
    LatLng? Function()? userLocation,
    String? Function()? currentUserHexId,
    int? version,
  }) {
    return HexDataState(
      userLocation: userLocation != null ? userLocation() : this.userLocation,
      currentUserHexId: currentUserHexId != null ? currentUserHexId() : this.currentUserHexId,
      version: version ?? this.version,
    );
  }
}

/// Hex data notifier - thin wrapper around HexRepository for Riverpod.
///
/// Delegates hex state to HexRepository (single source of truth).
/// Provides UI concerns: simulation fallback for missing hexes.
class HexDataNotifier extends Notifier<HexDataState> {
  late final HexRepository _hexRepository;

  @override
  HexDataState build() {
    _hexRepository = HexRepository();
    return const HexDataState();
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
    state = state.copyWith(
      userLocation: () => location,
      currentUserHexId: () => hexId,
      version: state.version + 1,
    );
  }

  /// Clear user location (called when run ends)
  void clearUserLocation() {
    _hexRepository.clearUserLocation();
    state = state.copyWith(
      userLocation: () => null,
      currentUserHexId: () => null,
      version: state.version + 1,
    );
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
  HexModel getHex(String hexId, dynamic center) {
    final cached = _hexRepository.getHex(hexId);
    if (cached != null) return cached;
    return HexModel(id: hexId, center: center, lastRunnerTeam: null);
  }

  /// Update hex with runner's color (delegates to HexRepository)
  HexUpdateResult updateHexColor(String hexId, Team runnerTeam) {
    final result = _hexRepository.updateHexColor(hexId, runnerTeam);
    if (result == HexUpdateResult.flipped) {
      state = state.copyWith(version: state.version + 1);
    }
    return result;
  }

  /// Clear captured hexes (call when run ends or new run starts)
  void clearCapturedHexes() {
    _hexRepository.clearCapturedHexes();
    debugPrint('HexDataNotifier: Cleared captured hexes for new session');
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
    state = state.copyWith(version: state.version + 1);
    debugPrint('HexDataNotifier: All hex data cleared (The Void)');
  }

  /// Notify that hex data changed externally (e.g. from prefetch)
  void notifyHexDataChanged() {
    state = state.copyWith(version: state.version + 1);
  }
}

final hexDataProvider = NotifierProvider<HexDataNotifier, HexDataState>(
  HexDataNotifier.new,
);

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
