import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hexagon_map.dart';
import '../models/hex_model.dart';
import '../models/location_point.dart';
import '../widgets/energy_hold_button.dart';
import '../providers/app_state_provider.dart';
import '../providers/hex_data_provider.dart';
import '../providers/run_provider.dart';
import '../services/local_storage_service.dart';

/// Premium dark-themed map screen with hex territory visualization
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  mapbox.MapboxMap? _mapController;
  int _selectedZoomIndex = 0; // Default to ZONE (shows user location)
  HexAggregatedStats? _hexStats;

  // ZONE (index 0) shows user location, CITY and ALL show stats only
  bool get _showUserLocation => _selectedZoomIndex == 0;

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
            zoom: _getZoomLevelForIndex(_selectedZoomIndex),
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
              zoom: _getZoomLevelForIndex(_selectedZoomIndex),
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
              zoom: _getZoomLevelForIndex(_selectedZoomIndex),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error moving to location: $e');
    }
  }

  void _onZoomChanged(int index) {
    if (!mounted) return;
    setState(() => _selectedZoomIndex = index);
    // Use easeTo for smooth zoom transitions between ZONE/CITY/ALL
    try {
      _mapController?.easeTo(
        mapbox.CameraOptions(zoom: _getZoomLevelForIndex(index)),
        mapbox.MapAnimationOptions(duration: 300, startDelay: 0),
      );
    } catch (e) {
      // Fallback to instant setCamera if easeTo fails
      debugPrint('easeTo zoom failed, falling back: $e');
      try {
        _mapController?.setCamera(
          mapbox.CameraOptions(zoom: _getZoomLevelForIndex(index)),
        );
      } catch (e2) {
        debugPrint('setCamera zoom fallback failed: $e2');
      }
    }
  }

  double _getZoomLevelForIndex(int index) {
    switch (index) {
      case 0:
        return 15.0; // ZONE
      case 1:
        return 12.0; // CITY
      case 2:
        return 11.0; // ALL
      default:
        return 12.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Expanded Map Area with Overlays
                Expanded(
                  child: Consumer<RunProvider>(
                    builder: (context, runProvider, child) {
                      // Get route from active run if in ZONE view
                      final route = _showUserLocation
                          ? runProvider.routePoints
                          : null;

                      return Stack(
                        children: [
                          // Full size map container
                          Positioned.fill(
                            child: _HexMapCard(
                              isFullScreen: true,
                              onMapCreated: _onMapCreated,
                              showUserLocation: _showUserLocation,
                              onStatsUpdated: _onStatsUpdated,
                              route: route,
                            ),
                          ),

                          // Top Right Controls
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Column(
                              children: [
                                // Location FAB (only in ZONE view)
                                if (_showUserLocation)
                                  FloatingActionButton(
                                    mini: true,
                                    heroTag: 'location_fab',
                                    backgroundColor: AppTheme.surfaceColor
                                        .withValues(alpha: 0.9),
                                    foregroundColor: AppTheme.electricBlue,
                                    onPressed: _moveToUserLocation,
                                    child: const Icon(Icons.my_location),
                                  ),
                              ],
                            ),
                          ),

                          // Stats Overlay for CITY and ALL views
                          if (!_showUserLocation && _hexStats != null)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: _TeamStatsOverlay(stats: _hexStats!),
                            ),

                          // Bottom Overlay Controls
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ZoomLevelSelector(
                                  selectedIndex: _selectedZoomIndex,
                                  onChanged: _onZoomChanged,
                                ),
                                // Only show CTA card in ZONE view
                                if (_showUserLocation) ...[
                                  const SizedBox(height: 16),
                                  const _CallToActionCard(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HexMapCard extends StatelessWidget {
  final bool isFullScreen;
  final Function(mapbox.MapboxMap) onMapCreated;
  final bool showUserLocation;
  final Function(HexAggregatedStats)? onStatsUpdated;
  final List<LocationPoint>? route;

  const _HexMapCard({
    this.isFullScreen = false,
    required this.onMapCreated,
    this.showUserLocation = true,
    this.onStatsUpdated,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final isRedTeam = appState.userTeam?.name == 'red';
    final teamColor = isRedTeam ? AppTheme.athleticRed : AppTheme.electricBlue;

    return Container(
      width: double.infinity,
      padding: isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(4),
      decoration: AppTheme.meshDecoration().copyWith(
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Real Hexagon Map
            Positioned.fill(
              child: HexagonMap(
                initialCenter: null,
                showScoreLabels: false,
                teamColor: teamColor,
                showUserLocation: showUserLocation,
                onMapCreated: onMapCreated,
                onScoresUpdated: onStatsUpdated,
                route: route,
                onHexTapped: (hexId, hex) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _HexDetailSheet(hex: hex),
                  );
                },
              ),
            ),

            // Header badge (only in user location mode)
            if (showUserLocation)
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.hexagon_outlined,
                              color: AppTheme.textPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'HEX MAP',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Team stats overlay for CITY and ALL zoom levels
class _TeamStatsOverlay extends StatelessWidget {
  final HexAggregatedStats stats;

  const _TeamStatsOverlay({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalHexes;
    if (total == 0) return const SizedBox.shrink();

    final redPercent = (stats.redCount / total * 100).round();
    final bluePercent = (stats.blueCount / total * 100).round();
    final purplePercent = (stats.purpleCount / total * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Territory distribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
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
                      child: Container(color: const Color(0xFF8B5CF6)),
                    ),
                  if (stats.neutralCount > 0)
                    Expanded(
                      flex: stats.neutralCount,
                      child: Container(color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Inline team percentages + total hex count
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.athleticRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$redPercent%',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.athleticRed,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.electricBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$bluePercent%',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricBlue,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$purplePercent%',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const Spacer(),
              Text(
                '$total hexes',
                style: GoogleFonts.sora(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
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

class _CallToActionCard extends StatelessWidget {
  const _CallToActionCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 80,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // Product image
            SizedBox(
              width: 90,
              height: 80,
              child: Image.asset(
                'assets/images/nike_air_zoom.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Center(
                      child: Icon(
                        Icons.directions_run_rounded,
                        color: Color(0xFF333333),
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            // Ad content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'NIKE',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Air Zoom G.T.',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4500).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '25% OFF',
                            style: GoogleFonts.sora(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF4500),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Members Only',
                          style: GoogleFonts.sora(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '350m away \u2022 Nike Gangnam',
                      style: GoogleFonts.sora(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HexDetailSheet extends StatelessWidget {
  final HexModel hex;

  const _HexDetailSheet({required this.hex});

  @override
  Widget build(BuildContext context) {
    final color = hex.hexColor; // Use getter

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: color.withOpacity(0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HEX #${hex.id.substring(0, 6)}',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hex.displayName, // Use display name
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: color,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(
                  hex.emoji,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatRow('Status', 'Owned', Icons.check_circle),
          const SizedBox(height: 12),
          _buildStatRow('Last Flip', 'Just now', Icons.history),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: EnergyHoldButton(
              // label: 'START RUN HERE',
              icon: Icons.directions_run,
              baseColor: color.withOpacity(0.2),
              fillColor: color,
              iconColor: Colors.white,
              onComplete: () {
                Navigator.pop(context);
                // Navigate to run screen or focus
              },
              isHoldRequired: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(color: Colors.white54)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
