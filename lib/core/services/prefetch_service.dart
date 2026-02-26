import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/h3_config.dart';
import '../../data/models/hex_model.dart';
import '../../data/models/team.dart';
import '../../features/leaderboard/providers/leaderboard_provider.dart';
import '../../data/repositories/hex_repository.dart';
import '../storage/local_storage.dart';
import 'buff_service.dart';
import 'hex_service.dart';
import 'supabase_service.dart';
import 'season_service.dart';

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
/// which is set on first GPS fix and changeable via Profile screen.
///
/// ### Home Hex Rules (Single Source of Truth)
///
/// 1. First launch: GPS → set as home → save locally + sync to server
/// 2. Subsequent launches: load from local storage (never auto-overwrite)
/// 3. Change: only via explicit `updateHomeHex()` from Profile screen
/// 4. Province check: GPS taken during init, compared with stored home
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
class PrefetchService {
  static final PrefetchService _instance = PrefetchService._internal();
  factory PrefetchService() => _instance;
  PrefetchService._internal();

  final HexService _hexService = HexService();
  final SupabaseService _supabase = SupabaseService();
  final LocalStorage _localStorage = LocalStorage();

  PrefetchStatus _status = PrefetchStatus.notStarted;
  String? _homeHex;
  String? _gpsBaseHex; // Current GPS position hex (Res 9), set during init
  DateTime? _lastPrefetchTime;
  String? _errorMessage;

  // Cached data
  final List<LeaderboardEntry> _leaderboardCache = [];

  // Pre-computed parent hexes for each scope (location-based homeHex)
  String? _homeHexZone; // Res 8 parent
  String? _homeHexCity; // Res 6 parent
  String? _homeHexAll; // Res 5 parent

  /// Whether current GPS position is in a different province than stored home.
  /// Set during initialize(), read synchronously by HomeScreen.
  bool _isOutsideHomeProvince = false;

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  PrefetchStatus get status => _status;
  String? get homeHex => _homeHex;
  String? get gpsHex => _gpsBaseHex;
  String? get homeHexCity => _homeHexCity;
  String? get homeHexAll => _homeHexAll;
  String? get errorMessage => _errorMessage;
  DateTime? get lastPrefetchTime => _lastPrefetchTime;
  bool get isInitialized => _status == PrefetchStatus.completed;
  bool get hasHomeHex => _homeHex != null;

  /// Whether user's current GPS is outside their stored home province.
  /// Computed once during initialize() — no async needed by consumers.
  bool get isOutsideHomeProvince => _isOutsideHomeProvince;

  /// Get parent hex at specific scope level
  String? getHomeHexAtScope(GeographicScope scope) {
    if (_homeHex == null) return null;
    return switch (scope) {
      GeographicScope.zone => _homeHexZone,
      GeographicScope.city => _homeHexCity,
      GeographicScope.all => _homeHexAll,
    };
  }

  /// Get GPS hex parent at a specific scope level
  String? getGpsHexAtScope(GeographicScope scope) {
    if (_gpsBaseHex == null) return null;
    return _hexService.getScopeHexId(_gpsBaseHex!, scope);
  }

  /// Get cached hex data (delegates to HexRepository)
  HexModel? getCachedHex(String hexId) => HexRepository().getHex(hexId);

  /// Get cached leaderboard
  List<LeaderboardEntry> get cachedLeaderboard =>
      List.unmodifiable(_leaderboardCache);

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  /// Initialize prefetch service.
  ///
  /// Flow:
  /// 1. Get current GPS position (always — needed for province check)
  /// 2. Load stored home hex from SQLite
  /// 3. If no stored hex: first-time setup (adopt GPS as home, sync server)
  /// 4. If stored hex exists: compare GPS province vs stored province
  /// 5. Download hex snapshot + leaderboard for home province
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
    _isOutsideHomeProvince = false;
    debugPrint('PrefetchService: Starting initialization...');

    try {
      // Step 1: Always get GPS (needed for first-time setup OR province check)
      final position = await _getGPSPosition();
      final gpsLatLng = LatLng(position.latitude, position.longitude);
      final gpsBaseHex = _hexService.getBaseHexId(gpsLatLng);
      _gpsBaseHex = gpsBaseHex;
      final gpsProvince =
          _hexService.getScopeHexId(gpsBaseHex, GeographicScope.all);

      // Step 2: Try to restore stored home hex
      if (_homeHex == null) {
        await _loadHomeHex();
      }

      // Step 3: First-time vs returning user
      if (_homeHex == null) {
        // First-time user: adopt GPS as home
        _homeHex = gpsBaseHex;
        _computeParentHexes();
        await _saveHomeHex(_homeHex!);
        await _syncHomeToServer();
        _isOutsideHomeProvince = false;
        debugPrint(
          'PrefetchService: First-time home set to $_homeHex '
          '(${position.latitude}, ${position.longitude})',
        );
      } else {
        // Returning user: keep stored home, check province mismatch
        _computeParentHexes();
        _isOutsideHomeProvince = gpsProvince != _homeHexAll;
        if (_isOutsideHomeProvince) {
          debugPrint(
            'PrefetchService: OUTSIDE home province! '
            'GPS province: $gpsProvince, Home province: $_homeHexAll',
          );
        }
      }

      if (_homeHex == null) {
        throw Exception('Failed to determine home hex');
      }

      // Step 4: Download hex data for home province
      await _downloadHexData();

      // Step 5: Download leaderboard data
      await _downloadLeaderboardData();

      _lastPrefetchTime = DateTime.now();
      _status = PrefetchStatus.completed;
      debugPrint('PrefetchService: Initialization completed');
      debugPrint('  Home hex: $_homeHex');
      debugPrint('  Zone parent: $_homeHexZone');
      debugPrint('  City parent: $_homeHexCity');
      debugPrint('  All parent: $_homeHexAll');
      debugPrint('  Outside province: $_isOutsideHomeProvince');
      debugPrint('  Cached hexes: ${HexRepository().cacheStats['size']}');
      debugPrint('  Cached leaderboard entries: ${_leaderboardCache.length}');
    } catch (e) {
      _status = PrefetchStatus.failed;
      _errorMessage = e.toString();
      debugPrint('PrefetchService: Initialization failed - $e');
    }
  }

  /// Guest-only initialization: gets GPS position and sets home hex locally.
  /// Guest location init: sets home hex from GPS and downloads hex snapshot
  /// so casual runners see territory colors on the map.
  Future<void> initializeGuestLocation() async {
    if (_status == PrefetchStatus.inProgress) return;

    _status = PrefetchStatus.inProgress;
    _errorMessage = null;
    debugPrint('PrefetchService: Guest location init starting...');

    try {
      final position = await _getGPSPosition();
      final gpsLatLng = LatLng(position.latitude, position.longitude);
      final gpsBaseHex = _hexService.getBaseHexId(gpsLatLng);

      _gpsBaseHex = gpsBaseHex;
      _homeHex = gpsBaseHex;
      _computeParentHexes();
      await _saveHomeHex(_homeHex!);

      // Download hex snapshot so casual runners see territory colors
      await _downloadHexData();

      _lastPrefetchTime = DateTime.now();
      _status = PrefetchStatus.completed;
      debugPrint(
        'PrefetchService: Guest location set to $_homeHex '
        '(city=$_homeHexCity, province=$_homeHexAll)',
      );
    } catch (e) {
      _status = PrefetchStatus.failed;
      _errorMessage = e.toString();
      debugPrint('PrefetchService: Guest location init failed - $e');
    }
  }

  /// Sync home hex to server (home_hex + district_hex).
  Future<void> _syncHomeToServer() async {
    try {
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null && _homeHexCity != null) {
        await _supabase.updateHomeLocation(userId, _homeHex!, _homeHexCity!);
        debugPrint('PrefetchService: Home hex synced to server');
      }
    } catch (e) {
      debugPrint('PrefetchService: Failed to sync home hex to server - $e');
    }
  }

  /// Get current GPS position with permission checks
  Future<Position> _getGPSPosition() async {
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

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
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
  // HOME LOCATION UPDATE (Profile screen)
  // ---------------------------------------------------------------------------

  /// Update home location from GPS via Profile screen.
  ///
  /// 1. Gets current GPS position
  /// 2. Computes new home_hex and parent hexes
  /// 3. Saves locally and syncs to server
  /// 4. Re-downloads hex snapshot and leaderboard for new province
  /// 5. Refreshes buff for new district
  /// 6. Clears province mismatch flag
  Future<void> updateHomeHex(String userId) async {
    debugPrint('PrefetchService: Updating home hex from GPS...');

    final position = await _getGPSPosition();
    final latLng = LatLng(position.latitude, position.longitude);

    // 1. Compute new home_hex from GPS
    _homeHex = _hexService.getBaseHexId(latLng);

    // 2. Recompute parent hexes (zone, city, province)
    _computeParentHexes();

    // 3. Save locally
    await _saveHomeHex(_homeHex!);

    // 4. Update server (home_hex + district_hex)
    if (_homeHexCity != null) {
      await _supabase.updateHomeLocation(userId, _homeHex!, _homeHexCity!);
    }

    // 5. Re-download hex snapshot for new province
    HexRepository().clearAll();
    await _downloadHexData();
    await _downloadLeaderboardData();

    // 6. Refresh buff for new district
    await BuffService().refresh(userId, districtHex: _homeHexCity);

    // 7. Clear province mismatch (user just adopted current GPS as home)
    _isOutsideHomeProvince = false;

    debugPrint(
      'PrefetchService: Home hex updated to $_homeHex '
      '(${position.latitude}, ${position.longitude})',
    );
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
    // On Season Day 1, no snapshot exists and hexes table is empty after reset.
    // Skip all network calls — just clear the cache and apply local overlay.
    if (SeasonService().isFirstDay) {
      debugPrint('PrefetchService: Day 1 — skipping snapshot download');
      final repo = HexRepository();
      repo.clearAll();
      await _applyLocalOverlay(repo);
      _lastPrefetchTime = DateTime.now();
      await _saveLastPrefetchTime(_lastPrefetchTime!);
      return;
    }

    // Always download for home province (server data = home-anchored)
    final provinceHex = _homeHexAll;
    if (provinceHex == null) return;

    final repo = HexRepository();

    try {
      // Download today's snapshot (deterministic for all users)
      final hexes = await _supabase.getHexSnapshot(provinceHex);

      if (hexes.isNotEmpty) {
        repo.bulkLoadFromSnapshot(hexes);
        debugPrint('PrefetchService: Snapshot loaded - ${hexes.length} hexes');
      } else {
        // Snapshot empty (cron hasn't run yet) — fall back to live hexes
        debugPrint(
          'PrefetchService: Snapshot empty, falling back to live hexes',
        );
        final liveHexes = await _supabase.getHexesDelta(provinceHex);
        repo.bulkLoadFromServer(liveHexes);
        debugPrint(
          'PrefetchService: Live hexes loaded - ${liveHexes.length} hexes',
        );
      }

      // Apply local overlay: user's own today's flips from SQLite
      await _applyLocalOverlay(repo);
      debugPrint('PrefetchService: Hex cache final size: ${repo.cacheStats['size']}');

      _lastPrefetchTime = DateTime.now();
      await _saveLastPrefetchTime(_lastPrefetchTime!);
    } catch (e) {
      debugPrint('PrefetchService: Failed to download hex data - $e');
      // Fallback: try legacy delta sync
      try {
        final hexes = await _supabase.getHexesDelta(provinceHex);
        repo.bulkLoadFromServer(hexes);
        await _applyLocalOverlay(repo);
        debugPrint('PrefetchService: Fallback hex cache size: ${repo.cacheStats['size']}');
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
    // On Day 1, no one has points yet — skip network call.
    if (SeasonService().isFirstDay) {
      debugPrint('PrefetchService: Day 1 — skipping leaderboard download');
      _leaderboardCache.clear();
      return;
    }
    if (_homeHexAll == null) return;

    debugPrint('PrefetchService: Downloading leaderboard data...');

    try {
      // Use get_leaderboard RPC (works with remote schema)
      final result = await _supabase.client.rpc(
        'get_leaderboard',
        params: {'p_limit': 200},
      );

      final entries = result as List<dynamic>? ?? [];
      _leaderboardCache.clear();

      for (int i = 0; i < entries.length; i++) {
        _leaderboardCache.add(
          LeaderboardEntry.fromJson(
            Map<String, dynamic>.from(entries[i] as Map),
            i + 1,
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
  ///
  /// For province (ALL) scope, uses [districtHex] from the RPC response
  /// rather than computing cellToParent from home_hex, because seed
  /// home_hex values may not be valid H3 cells.
  List<LeaderboardEntry> getLeaderboardForScope(GeographicScope scope) {
    if (_homeHex == null) return _leaderboardCache;

    final homeParent = getHomeHexAtScope(scope);
    if (homeParent == null) return _leaderboardCache;

    return _leaderboardCache.where((entry) {
      if (entry.homeHex == null && entry.districtHex == null) return false;
      return entry.isInScope(
        _homeHex,
        scope,
        referenceDistrictHex: _homeHexCity,
      );
    }).toList();
  }

  /// Check if a hex is within the user's home region (Res 5 parent).
  bool isInHomeRegion(String hexId) {
    if (_homeHexAll == null) return true;

    final hexParent = _hexService.getScopeHexId(hexId, GeographicScope.all);
    return hexParent == _homeHexAll;
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
  // PERSISTENCE (private — only called internally)
  // ---------------------------------------------------------------------------

  Future<void> _saveHomeHex(String homeHex) async {
    _homeHex = homeHex;
    _computeParentHexes();
    try {
      await _localStorage.saveHomeHex(homeHex);
      debugPrint('PrefetchService: Saved home hex: $homeHex');
    } catch (e) {
      debugPrint('PrefetchService: Failed to save home hex - $e');
    }
  }

  Future<void> _loadHomeHex() async {
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

  // Keep public for backward compat (used by tests and profile update)
  Future<void> saveHomeHex(String homeHex) => _saveHomeHex(homeHex);
  Future<void> loadHomeHex() => _loadHomeHex();

  // ---------------------------------------------------------------------------
  // TESTING
  // ---------------------------------------------------------------------------

  @visibleForTesting
  void reset() {
    _status = PrefetchStatus.notStarted;
    _homeHex = null;
    _gpsBaseHex = null;
    _homeHexZone = null;
    _homeHexCity = null;
    _homeHexAll = null;
    _lastPrefetchTime = null;
    _errorMessage = null;
    _isOutsideHomeProvince = false;
    _leaderboardCache.clear();
  }

  @visibleForTesting
  void setHomeHexForTesting(String homeHex) {
    _homeHex = homeHex;
    _computeParentHexes();
    _status = PrefetchStatus.completed;
  }
}
