import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../config/h3_config.dart';
import '../theme/app_theme.dart';
import '../widgets/hexagon_map.dart';
import '../models/location_point.dart';
import '../providers/app_state_provider.dart';
import '../providers/hex_data_provider.dart';
import '../providers/run_provider.dart';
import '../services/ad_service.dart';
import '../services/local_storage_service.dart';
import '../services/prefetch_service.dart';
import '../services/hex_service.dart';
import 'profile_screen.dart';

/// Premium dark-themed map screen with hex territory visualization
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  mapbox.MapboxMap? _mapController;
  GeographicScope _selectedScope = GeographicScope.zone; // Default to ZONE
  HexAggregatedStats? _hexStats;

  // ZONE shows user location, CITY and ALL show stats overlay only
  bool get _showUserLocation => _selectedScope == GeographicScope.zone;

  Future<void> _onMapCreated(mapbox.MapboxMap controller) async {
    _mapController = controller;
    await _moveToUserLocation();
  }

  void _onStatsUpdated(HexAggregatedStats stats) {
    setState(() {
      _hexStats = stats;
    });
  }

  Future<void> _moveToUserLocation() async {
    if (_mapController == null) return;

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // 1. Try to get cached location first (FAST) for immediate response
      final savedLocation = await LocalStorageService().getLastLocation();
      final lastPosition = await Geolocator.getLastKnownPosition();

      // Fallback defaults (Seoul)
      const defaultLat = 37.5665;
      const defaultLng = 126.9780;

      // Determine initial position: saved -> lastKnown -> default
      double initialLat = defaultLat;
      double initialLng = defaultLng;

      if (savedLocation != null) {
        initialLat = savedLocation['latitude']!;
        initialLng = savedLocation['longitude']!;
      } else if (lastPosition != null) {
        initialLat = lastPosition.latitude;
        initialLng = lastPosition.longitude;
      }

      // Use setCamera for immediate positioning (no animation = no timeout)
      // Wrap in try-catch as map channel may not be ready immediately
      try {
        _mapController?.setCamera(
          mapbox.CameraOptions(
            center: mapbox.Point(
              coordinates: mapbox.Position(initialLng, initialLat),
            ),
            zoom: _selectedScope.zoomLevel,
          ),
        );
      } catch (e) {
        debugPrint('Initial setCamera failed (map not ready): $e');
      }

      // 2. Fetch fresh GPS position (SLOW but ACCURATE)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        // GPS couldn't get a high-accuracy fix in time.
        // Camera is already showing cached position — no action needed.
        debugPrint('GPS timeout: using cached position');
        return;
      }

      // Persist fresh location for next time
      LocalStorageService().saveLastLocation(
        position.latitude,
        position.longitude,
      );

      // If position differs significantly, animate smoothly to new location
      final distance = Geolocator.distanceBetween(
        initialLat,
        initialLng,
        position.latitude,
        position.longitude,
      );

      // Only animate if moved more than 50 meters (avoid unnecessary animation)
      // Use fire-and-forget easeTo — don't await the animation Future
      if (distance > 50 && _mapController != null) {
        try {
          _mapController!.easeTo(
            mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(
                  position.longitude,
                  position.latitude,
                ),
              ),
              zoom: _selectedScope.zoomLevel,
            ),
            mapbox.MapAnimationOptions(duration: 500, startDelay: 0),
          );
        } catch (e) {
          // Fallback to instant setCamera if easeTo fails
          _mapController!.setCamera(
            mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(
                  position.longitude,
                  position.latitude,
                ),
              ),
              zoom: _selectedScope.zoomLevel,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error moving to location: $e');
    }
  }

  void _onZoomChanged(int index) async {
    if (!mounted) return;
    final newScope = GeographicScope.fromIndex(index);
    setState(() => _selectedScope = newScope);

    // Determine camera center based on scope:
    // - ZONE: Center on current GPS location
    // - CITY/ALL: Center on home hex (fixed territory boundary)
    mapbox.Point? centerPoint;

    if (newScope == GeographicScope.zone) {
      // ZONE: Center on user's current location
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          centerPoint = mapbox.Point(
            coordinates: mapbox.Position(position.longitude, position.latitude),
          );
        }
      } catch (e) {
        debugPrint('Failed to get current location for ZONE: $e');
      }
    } else {
      // CITY/ALL: Center on GPS hex when outside province, home hex otherwise
      final prefetch = PrefetchService();
      final anchorHex = prefetch.isOutsideHomeProvince
          ? prefetch.gpsHex
          : prefetch.homeHex;
      if (anchorHex != null) {
        final homeCenter = HexService().getHexCenter(anchorHex);
        centerPoint = mapbox.Point(
          coordinates: mapbox.Position(
            homeCenter.longitude,
            homeCenter.latitude,
          ),
        );
      }
    }

    // Use easeTo for smooth zoom + center transitions
    try {
      _mapController?.easeTo(
        mapbox.CameraOptions(center: centerPoint, zoom: newScope.zoomLevel),
        mapbox.MapAnimationOptions(duration: 300, startDelay: 0),
      );
    } catch (e) {
      // Fallback to instant setCamera if easeTo fails
      debugPrint('easeTo zoom failed, falling back: $e');
      try {
        _mapController?.setCamera(
          mapbox.CameraOptions(center: centerPoint, zoom: newScope.zoomLevel),
        );
      } catch (e2) {
        debugPrint('setCamera zoom fallback failed: $e2');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Consumer<RunProvider>(
        builder: (context, runProvider, child) {
          // Get route from active run if in ZONE view
          final route = _showUserLocation ? runProvider.routePoints : null;

          return Stack(
            children: [
              // Full-bleed map (edge-to-edge like RunningScreen)
              Positioned.fill(
                child: _HexMapCard(
                  onMapCreated: _onMapCreated,
                  showUserLocation: _showUserLocation,
                  onStatsUpdated: _onStatsUpdated,
                  route: route,
                ),
              ),

              // Stats Overlay for CITY and ALL views only (not ZONE)
              if (!_showUserLocation && _hexStats != null)
                Positioned(
                  top: isLandscape
                      ? 16
                      : MediaQuery.of(context).padding.top + 76,
                  left: 16,
                  right: isLandscape ? null : 16,
                  width: isLandscape ? 350 : null,
                  child: _TeamStatsOverlay(
                    stats: _hexStats!,
                    scope: _selectedScope,
                  ),
                ),

              // Floating banner when outside home province (CITY/ALL views)
              if (!_showUserLocation && PrefetchService().isOutsideHomeProvince)
                Positioned(
                  top: isLandscape
                      ? (_hexStats != null ? 100 : 16)
                      : MediaQuery.of(context).padding.top +
                            (_hexStats != null ? 170 : 76),
                  left: 16,
                  right: isLandscape ? null : 16,
                  width: isLandscape ? 350 : null,
                  child: _OutsideProvinceBanner(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ),

              // Location FAB (upper right, below AppBar) - only in ZONE view
              if (_showUserLocation)
                Positioned(
                  top: isLandscape
                      ? 16
                      : MediaQuery.of(context).padding.top + 76,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'location_fab',
                    backgroundColor: AppTheme.surfaceColor.withValues(
                      alpha: 0.9,
                    ),
                    foregroundColor: AppTheme.electricBlue,
                    onPressed: _moveToUserLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),

              // Bottom Controls (right above bottom nav bar)
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: isLandscape
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _NativeAdCard(),
                          const SizedBox(height: 10),
                          _ZoomLevelSelector(
                            selectedIndex: _selectedScope.scopeIndex,
                            onChanged: _onZoomChanged,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ad banner (all views)
                          const _NativeAdCard(),
                          const SizedBox(height: 10),
                          // Zoom level selector (ZONE / CITY / ALL)
                          _ZoomLevelSelector(
                            selectedIndex: _selectedScope.scopeIndex,
                            onChanged: _onZoomChanged,
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HexMapCard extends StatelessWidget {
  final Function(mapbox.MapboxMap) onMapCreated;
  final bool showUserLocation;
  final Function(HexAggregatedStats)? onStatsUpdated;
  final List<LocationPoint>? route;

  const _HexMapCard({
    required this.onMapCreated,
    this.showUserLocation = true,
    this.onStatsUpdated,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    // Use team's color directly (supports red, blue, AND purple)
    final userTeam = appState.userTeam;
    final teamColor = userTeam?.color ?? AppTheme.electricBlue;

    return HexagonMap(
      initialCenter: null,
      showScoreLabels: false,
      teamColor: teamColor,
      userTeam: appState.userTeam,
      showUserLocation: showUserLocation,
      onMapCreated: onMapCreated,
      onScoresUpdated: onStatsUpdated,
      route: route,
    );
  }
}

/// Team stats overlay for ALL zoom levels
class _TeamStatsOverlay extends StatelessWidget {
  final HexAggregatedStats stats;
  final GeographicScope scope;

  const _TeamStatsOverlay({required this.stats, required this.scope});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalHexes;
    if (total == 0) return const SizedBox.shrink();

    // Calculate percentages for claimed territories
    final redPercent = (stats.redCount / total * 100).round();
    final bluePercent = (stats.blueCount / total * 100).round();
    final purplePercent = (stats.purpleCount / total * 100).round();

    // MapScreen displays GPS-based territory when outside province
    final prefetch = PrefetchService();
    final displayHex = prefetch.isOutsideHomeProvince
        ? prefetch.gpsHex
        : prefetch.homeHex;

    String scopeLabel;
    if (scope == GeographicScope.city && displayHex != null) {
      // CITY -> "District N"
      final districtNum = HexService().getCityNumber(displayHex);
      scopeLabel = 'DISTRICT $districtNum';
    } else if (scope == GeographicScope.all && displayHex != null) {
      // ALL -> Territory name (e.g., "Amber Ridge")
      scopeLabel = HexService().getTerritoryName(displayHex).toUpperCase();
    } else {
      scopeLabel = scope.label.toUpperCase();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // More transparent floating panel
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Scope badge + Total count
              Row(
                children: [
                  Flexible(
                    child: Text(
                      scopeLabel,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$total',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ' hexes',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Proportional Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      if (stats.redCount > 0)
                        Expanded(
                          flex: stats.redCount,
                          child: Container(color: AppTheme.athleticRed),
                        ),
                      if (stats.blueCount > 0)
                        Expanded(
                          flex: stats.blueCount,
                          child: Container(color: AppTheme.electricBlue),
                        ),
                      if (stats.purpleCount > 0)
                        Expanded(
                          flex: stats.purpleCount,
                          child: Container(color: AppTheme.chaosPurple),
                        ),
                      if (stats.neutralCount > 0)
                        Expanded(
                          flex: stats.neutralCount,
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Row 3: Team Stats (compact inline)
              // Use FittedBox to scale down when numbers are large
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactStat(
                      stats.redCount,
                      redPercent,
                      AppTheme.athleticRed,
                    ),
                    const SizedBox(width: 10),
                    _buildCompactStat(
                      stats.blueCount,
                      bluePercent,
                      AppTheme.electricBlue,
                    ),
                    const SizedBox(width: 10),
                    _buildCompactStat(
                      stats.purpleCount,
                      purplePercent,
                      AppTheme.chaosPurple,
                    ),
                    const SizedBox(width: 12),
                    // Neutral shown smaller
                    Text(
                      '${stats.neutralCount}',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      ' unclaimed',
                      style: GoogleFonts.sora(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact team stat: colored dot + count (percent%)
  Widget _buildCompactStat(int count, int percent, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '($percent%)',
          style: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Floating banner shown when user is outside their home province.
/// Prompts them to update location in Profile.
class _OutsideProvinceBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _OutsideProvinceBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.read<AppStateProvider>().userTeam?.color ?? AppTheme.electricBlue;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: teamColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: teamColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Outside home province',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        'Update location in Profile to run here',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomLevelSelector extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onChanged;

  const _ZoomLevelSelector({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.grid_view_rounded, // Close/ZONE
      Icons.location_city_rounded, // Medium/CITY
      Icons.public_rounded, // Far/ALL
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(icons.length, (index) {
          final isActive = index == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppTheme.electricBlue.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: Center(
                child: Icon(
                  icons[index],
                  size: 18,
                  color: isActive
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Banner ad card positioned above the zoom selector.
///
/// Loads a Google AdMob banner ad. Shows nothing while loading / on failure.
class _NativeAdCard extends StatefulWidget {
  const _NativeAdCard();

  @override
  State<_NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<_NativeAdCard> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner, // 320x50 standard banner
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: ${error.message}');
          ad.dispose();
          _bannerAd = null;
        },
      ),
      request: const AdRequest(),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
