import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/h3_config.dart';
import '../models/team.dart';
import 'hex_service.dart';
import 'supabase_service.dart';

/// Status of the prefetch operation
enum PrefetchStatus {
  /// Prefetch has not started yet
  notStarted,

  /// Prefetch is currently in progress
  inProgress,

  /// Prefetch completed successfully
  completed,

  /// Prefetch failed (will retry on next app launch)
  failed,
}

/// Cached hex data for local storage
class CachedHex {
  final String hexId;
  final Team? lastRunnerTeam;
  final DateTime? lastUpdated;

  const CachedHex({required this.hexId, this.lastRunnerTeam, this.lastUpdated});

  Map<String, dynamic> toMap() => {
    'hex_id': hexId,
    'last_runner_team': lastRunnerTeam?.name,
    'last_updated': lastUpdated?.millisecondsSinceEpoch,
  };

  factory CachedHex.fromMap(Map<String, dynamic> map) => CachedHex(
    hexId: map['hex_id'] as String,
    lastRunnerTeam: map['last_runner_team'] != null
        ? Team.values.byName(map['last_runner_team'] as String)
        : null,
    lastUpdated: map['last_updated'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int)
        : null,
  );
}

/// Cached leaderboard entry
class CachedLeaderboardEntry {
  final String oderId;
  final String name;
  final String avatar;
  final Team team;
  final int flipPoints;
  final double totalDistanceKm;
  final int? stabilityScore;
  final String? homeHex;

  const CachedLeaderboardEntry({
    required this.oderId,
    required this.name,
    required this.avatar,
    required this.team,
    required this.flipPoints,
    required this.totalDistanceKm,
    this.stabilityScore,
    this.homeHex,
  });

  Map<String, dynamic> toMap() => {
    'user_id': oderId,
    'name': name,
    'avatar': avatar,
    'team': team.name,
    'flip_points': flipPoints,
    'total_distance_km': totalDistanceKm,
    'stability_score': stabilityScore,
    'home_hex': homeHex,
  };

  factory CachedLeaderboardEntry.fromMap(Map<String, dynamic> map) =>
      CachedLeaderboardEntry(
        oderId: map['user_id'] as String,
        name: map['name'] as String,
        avatar: map['avatar'] as String? ?? '🏃',
        team: Team.values.byName(map['team'] as String),
        flipPoints: (map['flip_points'] as num?)?.toInt() ?? 0,
        totalDistanceKm: (map['total_distance_km'] as num?)?.toDouble() ?? 0,
        stabilityScore: (map['stability_score'] as num?)?.toInt(),
        homeHex: map['home_hex'] as String?,
      );
}

/// PrefetchService - Manages initial data download and home hex anchoring
///
/// ## Home-Anchored Scope System
///
/// Geographic scopes (ZONE/CITY/ALL) are anchored to the user's **home hex**,
/// which is set once on first GPS fix and never updated after.
///
/// ### Scope Display Behavior
///
/// | Scope | Hex Count | Generation Center | Panning Behavior |
/// |-------|-----------|-------------------|------------------|
/// | ZONE  | ~91       | Camera center     | Shows different hexes as user pans |
/// | CITY  | 331       | Home hex center   | **Fixed** - same 331 hexes always |
/// | ALL   | 3,781     | Home hex center   | **Fixed** - same 3,781 hexes always |
///
/// ### Data Prefetch
///
/// On app launch, downloads hex colors for the ALL range (3,781 hexes).
/// This is the maximum data boundary - ZONE view uses this cached data.
/// If user runs outside ALL range (rare), on-demand fetch is needed.
///
/// ### Usage
/// ```dart
/// await PrefetchService().initialize();
/// final homeHex = PrefetchService().homeHex;
/// final isInScope = PrefetchService().isHexInScope(hexId, GeographicScope.city);
/// ```
class PrefetchService {
  static final PrefetchService _instance = PrefetchService._internal();
  factory PrefetchService() => _instance;
  PrefetchService._internal();

  final HexService _hexService = HexService();
  final SupabaseService _supabase = SupabaseService();

  PrefetchStatus _status = PrefetchStatus.notStarted;
  String? _homeHex;
  DateTime? _lastPrefetchTime;
  String? _errorMessage;

  // Cached data
  final Map<String, CachedHex> _hexCache = {};
  final List<CachedLeaderboardEntry> _leaderboardCache = [];

  // Pre-computed parent hexes for each scope
  String? _homeHexZone; // Res 8 parent
  String? _homeHexCity; // Res 6 parent
  String? _homeHexAll; // Res 4 parent

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  PrefetchStatus get status => _status;
  String? get homeHex => _homeHex;
  String? get errorMessage => _errorMessage;
  DateTime? get lastPrefetchTime => _lastPrefetchTime;
  bool get isInitialized => _status == PrefetchStatus.completed;
  bool get hasHomeHex => _homeHex != null;

  /// Get parent hex at specific scope level
  String? getHomeHexAtScope(GeographicScope scope) {
    if (_homeHex == null) return null;
    return switch (scope) {
      GeographicScope.zone => _homeHexZone,
      GeographicScope.city => _homeHexCity,
      GeographicScope.all => _homeHexAll,
    };
  }

  /// Get cached hex data
  CachedHex? getCachedHex(String hexId) => _hexCache[hexId];

  /// Get all cached hexes
  Map<String, CachedHex> get cachedHexes => Map.unmodifiable(_hexCache);

  /// Get cached leaderboard
  List<CachedLeaderboardEntry> get cachedLeaderboard =>
      List.unmodifiable(_leaderboardCache);

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  /// Initialize prefetch service
  ///
  /// If home hex already exists (from previous session), skip GPS fix.
  /// If no home hex, get GPS position and set home hex.
  /// Then download all data for the "All" scope range.
  Future<void> initialize({bool forceRefresh = false}) async {
    if (_status == PrefetchStatus.inProgress) {
      debugPrint('PrefetchService: Already in progress');
      return;
    }

    if (_status == PrefetchStatus.completed && !forceRefresh) {
      debugPrint('PrefetchService: Already completed');
      return;
    }

    _status = PrefetchStatus.inProgress;
    _errorMessage = null;
    debugPrint('PrefetchService: Starting initialization...');

    try {
      // Step 1: Get or set home hex
      if (_homeHex == null) {
        await _setHomeHexFromGPS();
      }

      if (_homeHex == null) {
        throw Exception('Failed to determine home hex');
      }

      // Compute parent hexes for each scope
      _computeParentHexes();

      // Step 2: Download hex data for All range
      await _downloadHexData();

      // Step 3: Download leaderboard data
      await _downloadLeaderboardData();

      // Step 4: Download crew data (if user has crew)
      // TODO: Implement crew data prefetch

      _lastPrefetchTime = DateTime.now();
      _status = PrefetchStatus.completed;
      debugPrint('PrefetchService: Initialization completed');
      debugPrint('  Home hex: $_homeHex');
      debugPrint('  Zone parent: $_homeHexZone');
      debugPrint('  City parent: $_homeHexCity');
      debugPrint('  All parent: $_homeHexAll');
      debugPrint('  Cached hexes: ${_hexCache.length}');
      debugPrint('  Cached leaderboard entries: ${_leaderboardCache.length}');
    } catch (e) {
      _status = PrefetchStatus.failed;
      _errorMessage = e.toString();
      debugPrint('PrefetchService: Initialization failed - $e');
    }
  }

  /// Set home hex from current GPS position
  Future<void> _setHomeHexFromGPS() async {
    debugPrint('PrefetchService: Getting GPS position for home hex...');

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // Convert to H3 hex at base resolution (Res 9)
    final latLng = LatLng(position.latitude, position.longitude);
    _homeHex = _hexService.getBaseHexId(latLng);

    debugPrint(
      'PrefetchService: Home hex set to $_homeHex '
      '(${position.latitude}, ${position.longitude})',
    );
  }

  /// Compute and cache parent hexes for each scope level
  void _computeParentHexes() {
    if (_homeHex == null) return;

    _homeHexZone = _hexService.getScopeHexId(_homeHex!, GeographicScope.zone);
    _homeHexCity = _hexService.getScopeHexId(_homeHex!, GeographicScope.city);
    _homeHexAll = _hexService.getScopeHexId(_homeHex!, GeographicScope.all);
  }

  // ---------------------------------------------------------------------------
  // DATA DOWNLOAD
  // ---------------------------------------------------------------------------

  /// Download hex data for the entire "All" scope range
  Future<void> _downloadHexData() async {
    if (_homeHexAll == null) return;

    debugPrint('PrefetchService: Downloading hex data for All range...');

    try {
      // Call Supabase RPC to get all hexes in the All parent cell
      final result = await _supabase.client.rpc(
        'get_hexes_in_scope',
        params: {
          'p_parent_hex': _homeHexAll,
          'p_scope_resolution': GeographicScope.all.resolution,
        },
      );

      final hexes = result as List<dynamic>? ?? [];
      _hexCache.clear();

      for (final hex in hexes) {
        final cachedHex = CachedHex(
          hexId: hex['hex_id'] as String,
          lastRunnerTeam: hex['last_runner_team'] != null
              ? Team.values.byName(hex['last_runner_team'] as String)
              : null,
          lastUpdated: hex['last_flipped_at'] != null
              ? DateTime.parse(hex['last_flipped_at'] as String)
              : null,
        );
        _hexCache[cachedHex.hexId] = cachedHex;
      }

      debugPrint('PrefetchService: Downloaded ${_hexCache.length} hexes');
    } catch (e) {
      debugPrint('PrefetchService: Failed to download hex data - $e');
      // Don't throw - allow partial success
    }
  }

  /// Download leaderboard data for all scopes
  Future<void> _downloadLeaderboardData() async {
    if (_homeHexAll == null) return;

    debugPrint('PrefetchService: Downloading leaderboard data...');

    try {
      // Call Supabase RPC to get leaderboard filtered by scope
      final result = await _supabase.client.rpc(
        'get_scoped_leaderboard',
        params: {
          'p_parent_hex': _homeHexAll,
          'p_scope_resolution': GeographicScope.all.resolution,
          'p_limit': 100,
        },
      );

      final entries = result as List<dynamic>? ?? [];
      _leaderboardCache.clear();

      for (final entry in entries) {
        _leaderboardCache.add(
          CachedLeaderboardEntry.fromMap(
            Map<String, dynamic>.from(entry as Map),
          ),
        );
      }

      debugPrint(
        'PrefetchService: Downloaded ${_leaderboardCache.length} leaderboard entries',
      );
    } catch (e) {
      debugPrint('PrefetchService: Failed to download leaderboard - $e');
      // Don't throw - allow partial success
    }
  }

  // ---------------------------------------------------------------------------
  // SCOPE HELPERS
  // ---------------------------------------------------------------------------

  /// Check if a hex is within the home scope range
  ///
  /// Returns true if the hex shares the same parent cell as home hex
  /// at the specified scope level.
  bool isHexInScope(String hexId, GeographicScope scope) {
    if (_homeHex == null) return false;

    final homeParent = getHomeHexAtScope(scope);
    if (homeParent == null) return false;

    final hexParent = _hexService.getScopeHexId(hexId, scope);
    return hexParent == homeParent;
  }

  /// Get leaderboard entries filtered by scope
  ///
  /// Filters cached leaderboard to only include users whose home hex
  /// is in the same scope as the current user's home hex.
  List<CachedLeaderboardEntry> getLeaderboardForScope(GeographicScope scope) {
    if (_homeHex == null) return _leaderboardCache;

    final homeParent = getHomeHexAtScope(scope);
    if (homeParent == null) return _leaderboardCache;

    return _leaderboardCache.where((entry) {
      if (entry.homeHex == null) return false;
      final entryParent = _hexService.getScopeHexId(entry.homeHex!, scope);
      return entryParent == homeParent;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  /// Refresh prefetched data (called on app resume)
  ///
  /// Does NOT change home hex - only refreshes hex colors and leaderboard.
  Future<void> refresh() async {
    if (_homeHex == null) {
      debugPrint('PrefetchService: Cannot refresh - no home hex set');
      return;
    }

    if (_status == PrefetchStatus.inProgress) {
      debugPrint('PrefetchService: Refresh skipped - already in progress');
      return;
    }

    debugPrint('PrefetchService: Refreshing data...');
    _status = PrefetchStatus.inProgress;

    try {
      await _downloadHexData();
      await _downloadLeaderboardData();
      _lastPrefetchTime = DateTime.now();
      _status = PrefetchStatus.completed;
      debugPrint('PrefetchService: Refresh completed');
    } catch (e) {
      _status = PrefetchStatus.failed;
      _errorMessage = e.toString();
      debugPrint('PrefetchService: Refresh failed - $e');
    }
  }

  /// Update a single hex in the cache (after a run)
  void updateCachedHex(String hexId, Team team) {
    _hexCache[hexId] = CachedHex(
      hexId: hexId,
      lastRunnerTeam: team,
      lastUpdated: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE
  // ---------------------------------------------------------------------------

  /// Save home hex to persistent storage
  ///
  /// Called after initial GPS fix to persist home hex across app restarts.
  Future<void> saveHomeHex(String homeHex) async {
    _homeHex = homeHex;
    _computeParentHexes();
    // TODO: Save to SharedPreferences or SQLite
    debugPrint('PrefetchService: Saved home hex: $homeHex');
  }

  /// Load home hex from persistent storage
  ///
  /// Called on app startup to restore home hex without GPS.
  Future<void> loadHomeHex() async {
    // TODO: Load from SharedPreferences or SQLite
    // For now, homeHex will be null and require GPS fix
    debugPrint('PrefetchService: Loading home hex from storage...');
  }

  // ---------------------------------------------------------------------------
  // TESTING
  // ---------------------------------------------------------------------------

  @visibleForTesting
  void reset() {
    _status = PrefetchStatus.notStarted;
    _homeHex = null;
    _homeHexZone = null;
    _homeHexCity = null;
    _homeHexAll = null;
    _lastPrefetchTime = null;
    _errorMessage = null;
    _hexCache.clear();
    _leaderboardCache.clear();
  }

  @visibleForTesting
  void setHomeHexForTesting(String homeHex) {
    _homeHex = homeHex;
    _computeParentHexes();
    _status = PrefetchStatus.completed;
  }
}
