import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/h3_config.dart';
import '../models/hex_model.dart';
import '../models/team.dart';
import '../providers/leaderboard_provider.dart';
import '../repositories/hex_repository.dart';
import '../storage/local_storage.dart';
import 'hex_service.dart';
import 'season_service.dart';
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
/// | ZONE  | ~7        | Camera center     | Shows different hexes as user pans |
/// | CITY  | 343       | Home hex center   | **Fixed** - same 343 hexes always |
/// | ALL   | 2,401     | Home hex center   | **Fixed** - same 2,401 hexes always |
///
/// ### Data Prefetch
///
/// On app launch, downloads hex colors for the ALL range (2,401 hexes).
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
  final LocalStorage _localStorage = LocalStorage();

  PrefetchStatus _status = PrefetchStatus.notStarted;
  String? _homeHex;
  String? _seasonHomeHex;
  String? _storedSeasonStartDate;
  DateTime? _lastPrefetchTime;
  String? _errorMessage;

  // Cached data
  final List<LeaderboardEntry> _leaderboardCache = [];

  // Pre-computed parent hexes for each scope (location-based homeHex)
  String? _homeHexZone; // Res 8 parent
  String? _homeHexCity; // Res 6 parent
  String? _homeHexAll; // Res 5 parent

  // Pre-computed parent hex for season home (used for leaderboard/multiplier)
  String? _seasonHomeHexAll; // Res 5 parent of seasonHomeHex

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  PrefetchStatus get status => _status;
  String? get homeHex => _homeHex;
  String? get seasonHomeHex => _seasonHomeHex;
  String? get seasonHomeHexAll => _seasonHomeHexAll;
  String? get errorMessage => _errorMessage;
  DateTime? get lastPrefetchTime => _lastPrefetchTime;
  bool get isInitialized => _status == PrefetchStatus.completed;
  bool get hasHomeHex => _homeHex != null;
  bool get hasSeasonHomeHex => _seasonHomeHex != null;

  /// Get parent hex at specific scope level
  String? getHomeHexAtScope(GeographicScope scope) {
    if (_homeHex == null) return null;
    return switch (scope) {
      GeographicScope.zone => _homeHexZone,
      GeographicScope.city => _homeHexCity,
      GeographicScope.all => _homeHexAll,
    };
  }

  /// Get cached hex data (delegates to HexRepository)
  HexModel? getCachedHex(String hexId) => HexRepository().getHex(hexId);

  /// Get cached leaderboard
  List<LeaderboardEntry> get cachedLeaderboard =>
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

      // Step 1b: Handle season home hex (for leaderboard/multiplier)
      await _handleSeasonHomeHex();

      // Step 2: Download hex data for All range
      await _downloadHexData();

      // Step 3: Download leaderboard data
      await _downloadLeaderboardData();

      _lastPrefetchTime = DateTime.now();
      _status = PrefetchStatus.completed;
      debugPrint('PrefetchService: Initialization completed');
      debugPrint('  Home hex: $_homeHex');
      debugPrint('  Season home hex: $_seasonHomeHex');
      debugPrint('  Zone parent: $_homeHexZone');
      debugPrint('  City parent: $_homeHexCity');
      debugPrint('  All parent: $_homeHexAll');
      debugPrint('  Season All parent: $_seasonHomeHexAll');
      debugPrint('  Cached hexes: ${HexRepository().cacheStats['size']}');
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

  /// Handle season home hex logic for leaderboard/multiplier anchoring
  Future<void> _handleSeasonHomeHex() async {
    final seasonService = SeasonService();
    final currentSeasonStart = seasonService.seasonStartDate
        .toIso8601String()
        .split('T')[0];

    _storedSeasonStartDate = await _loadStoredSeasonStart();

    final isNewSeason =
        _storedSeasonStartDate == null ||
        _storedSeasonStartDate != currentSeasonStart;

    if (isNewSeason) {
      _seasonHomeHex = _homeHex;
      _seasonHomeHexAll = _hexService.getScopeHexId(
        _seasonHomeHex!,
        GeographicScope.all,
      );
      await _saveSeasonHomeHex(_seasonHomeHex!);
      await _saveStoredSeasonStart(currentSeasonStart);
      debugPrint(
        'PrefetchService: New season detected - set seasonHomeHex: $_seasonHomeHex',
      );
    } else {
      _seasonHomeHex = await _loadSeasonHomeHex();
      if (_seasonHomeHex != null) {
        _seasonHomeHexAll = _hexService.getScopeHexId(
          _seasonHomeHex!,
          GeographicScope.all,
        );
      }
      debugPrint(
        'PrefetchService: Same season - loaded seasonHomeHex: $_seasonHomeHex',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DATA DOWNLOAD
  // ---------------------------------------------------------------------------

  /// Download hex data from today's snapshot (frozen at midnight GMT+2).
  ///
  /// Always downloads the full snapshot — no delta sync needed because
  /// the snapshot is immutable for the day.
  /// After loading, applies local overlay (user's own today's flips from SQLite).
  Future<void> _downloadHexData() async {
    if (_homeHexAll == null) return;

    final repo = HexRepository();

    try {
      // Download today's snapshot (deterministic for all users)
      final hexes = await _supabase.getHexSnapshot(_homeHexAll!);

      if (hexes.isNotEmpty) {
        repo.bulkLoadFromSnapshot(hexes);
        debugPrint('PrefetchService: Snapshot loaded - ${hexes.length} hexes');
      } else {
        // Snapshot empty (cron hasn't run yet) — fall back to live hexes
        debugPrint(
          'PrefetchService: Snapshot empty, falling back to live hexes',
        );
        final liveHexes = await _supabase.getHexesDelta(_homeHexAll!);
        repo.bulkLoadFromServer(liveHexes);
        debugPrint(
          'PrefetchService: Live hexes loaded - ${liveHexes.length} hexes',
        );
      }

      // Apply local overlay: user's own today's flips from SQLite
      await _applyLocalOverlay(repo);

      _lastPrefetchTime = DateTime.now();
      await _saveLastPrefetchTime(_lastPrefetchTime!);
    } catch (e) {
      debugPrint('PrefetchService: Failed to download hex data - $e');
      // Fallback: try legacy delta sync
      try {
        final hexes = await _supabase.getHexesDelta(_homeHexAll!);
        repo.bulkLoadFromServer(hexes);
        await _applyLocalOverlay(repo);
        _lastPrefetchTime = DateTime.now();
        await _saveLastPrefetchTime(_lastPrefetchTime!);
        debugPrint(
          'PrefetchService: Fallback delta sync - ${repo.cacheStats['size']} hexes',
        );
      } catch (e2) {
        debugPrint('PrefetchService: Fallback delta sync also failed - $e2');
      }
    }
  }

  /// Apply local overlay: user's own today's flips from SQLite.
  ///
  /// After loading the snapshot, the user's own flips from today
  /// are applied on top so the map shows their personal progress.
  /// This prevents double-counting when re-running the same hexes.
  Future<void> _applyLocalOverlay(HexRepository repo) async {
    try {
      final todayFlips = await _localStorage.getTodayFlippedHexes();
      if (todayFlips.isNotEmpty) {
        repo.applyLocalOverlay(todayFlips);
        debugPrint(
          'PrefetchService: Applied ${todayFlips.length} local overlay hexes',
        );
      }
    } catch (e) {
      debugPrint('PrefetchService: Failed to apply local overlay - $e');
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
          LeaderboardEntry.fromCacheMap(
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
  List<LeaderboardEntry> getLeaderboardForScope(GeographicScope scope) {
    if (_homeHex == null) return _leaderboardCache;

    final homeParent = getHomeHexAtScope(scope);
    if (homeParent == null) return _leaderboardCache;

    return _leaderboardCache.where((entry) {
      if (entry.homeHex == null) return false;
      final entryParent = _hexService.getScopeHexId(entry.homeHex!, scope);
      return entryParent == homeParent;
    }).toList();
  }

  /// Check if a hex is within the user's home region (Res 5 parent).
  ///
  /// Check if hex is within the user's home region (Res 5 parent cell).
  bool isInHomeRegion(String hexId) {
    if (_seasonHomeHexAll == null) return true;

    final hexParent = _hexService.getScopeHexId(hexId, GeographicScope.all);
    return hexParent == _seasonHomeHexAll;
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
    HexRepository().bulkLoadFromServer([
      {
        'hex_id': hexId,
        'last_runner_team': team.name,
        'last_flipped_at': DateTime.now().toIso8601String(),
      },
    ]);
  }

  /// Load dummy hex data directly into memory cache.
  ///
  /// Used for testing/demo purposes. Replaces any existing hex cache.
  /// [hexData] - List of maps with 'hex_id', 'last_runner_team', 'last_updated'
  void loadDummyHexData(List<Map<String, dynamic>> hexData) {
    // Load into HexRepository (single source of truth)
    HexRepository().bulkLoadFromServer(hexData);

    debugPrint(
      'PrefetchService: Loaded ${HexRepository().cacheStats['size']} dummy hexes',
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
    try {
      await _localStorage.saveHomeHex(homeHex);
      debugPrint('PrefetchService: Saved home hex: $homeHex');
    } catch (e) {
      debugPrint('PrefetchService: Failed to save home hex - $e');
    }
  }

  /// Load home hex from persistent storage
  ///
  /// Called on app startup to restore home hex without GPS.
  Future<void> loadHomeHex() async {
    debugPrint('PrefetchService: Loading home hex from storage...');
    try {
      final storedHomeHex = await _localStorage.getHomeHex();
      if (storedHomeHex != null) {
        _homeHex = storedHomeHex;
        _computeParentHexes();
        debugPrint('PrefetchService: Loaded home hex: $storedHomeHex');
      } else {
        debugPrint('PrefetchService: No stored home hex found');
      }
    } catch (e) {
      debugPrint('PrefetchService: Failed to load home hex - $e');
    }
  }

  Future<void> _saveSeasonHomeHex(String seasonHomeHex) async {
    try {
      await _localStorage.savePrefetchMeta('season_home_hex', seasonHomeHex);
      debugPrint('PrefetchService: Saved seasonHomeHex: $seasonHomeHex');
    } catch (e) {
      debugPrint('PrefetchService: Failed to save seasonHomeHex - $e');
    }
  }

  Future<String?> _loadSeasonHomeHex() async {
    try {
      return await _localStorage.getPrefetchMeta('season_home_hex');
    } catch (e) {
      debugPrint('PrefetchService: Failed to load seasonHomeHex - $e');
      return null;
    }
  }

  Future<void> _saveStoredSeasonStart(String seasonStart) async {
    try {
      await _localStorage.savePrefetchMeta('season_start_date', seasonStart);
      debugPrint('PrefetchService: Saved season start: $seasonStart');
    } catch (e) {
      debugPrint('PrefetchService: Failed to save season start - $e');
    }
  }

  Future<String?> _loadStoredSeasonStart() async {
    try {
      return await _localStorage.getPrefetchMeta('season_start_date');
    } catch (e) {
      debugPrint('PrefetchService: Failed to load season start - $e');
      return null;
    }
  }

  Future<void> _saveLastPrefetchTime(DateTime time) async {
    try {
      await _localStorage.savePrefetchMeta(
        'last_prefetch_time',
        time.toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('PrefetchService: Failed to save prefetch time - $e');
    }
  }

  // ignore: unused_element
  Future<DateTime?> _loadLastPrefetchTime() async {
    try {
      final value = await _localStorage.getPrefetchMeta('last_prefetch_time');
      if (value == null) return null;
      return DateTime.parse(value);
    } catch (e) {
      debugPrint('PrefetchService: Failed to load prefetch time - $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // TESTING
  // ---------------------------------------------------------------------------

  @visibleForTesting
  void reset() {
    _status = PrefetchStatus.notStarted;
    _homeHex = null;
    _seasonHomeHex = null;
    _seasonHomeHexAll = null;
    _storedSeasonStartDate = null;
    _homeHexZone = null;
    _homeHexCity = null;
    _homeHexAll = null;
    _lastPrefetchTime = null;
    _errorMessage = null;
    _leaderboardCache.clear();
  }

  @visibleForTesting
  void setHomeHexForTesting(String homeHex) {
    _homeHex = homeHex;
    _computeParentHexes();
    _status = PrefetchStatus.completed;
  }

  @visibleForTesting
  void setSeasonHomeHexForTesting(String seasonHomeHex) {
    _seasonHomeHex = seasonHomeHex;
    _seasonHomeHexAll = _hexService.getScopeHexId(
      seasonHomeHex,
      GeographicScope.all,
    );
  }
}
