import 'location_point.dart';
import 'team.dart';

/// Unified Run model combining RunSession, RunSummary, and RunHistoryModel
///
/// STORED FIELDS (persisted to database):
/// - id, startTime, endTime, distanceMeters, durationSeconds
/// - hexesColored, teamAtRun, hexPath, buffMultiplier, cv, syncStatus
///
/// TRANSIENT FIELDS (active run only, not stored):
/// - route, hexesPassed, currentHexId, distanceInCurrentHex, isActive
///
/// COMPUTED GETTERS (derived on-demand, never stored):
/// - distanceKm, avgPaceMinPerKm, stabilityScore, flipPoints
class Run {
  // STORED FIELDS
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  double distanceMeters; // Store meters, not km
  final int durationSeconds;
  int hexesColored;
  final Team teamAtRun;
  final List<String> hexPath;
  final int buffMultiplier;
  final double? cv; // Coefficient of Variation (null for runs < 1km)
  final String syncStatus; // 'pending', 'synced', 'failed'

  // TRANSIENT FIELDS (active run only, not stored)
  final List<LocationPoint> route;
  final List<String> hexesPassed;
  String? currentHexId;
  double distanceInCurrentHex;
  bool isActive;

  Run({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.hexesColored,
    required this.teamAtRun,
    List<String>? hexPath,
    this.buffMultiplier = 1,
    this.cv,
    this.syncStatus = 'pending',
    List<LocationPoint>? route,
    List<String>? hexesPassed,
    this.currentHexId,
    this.distanceInCurrentHex = 0,
    this.isActive = false,
  }) : hexPath = hexPath ?? const [],
       route = route ?? [],
       hexesPassed = hexesPassed ?? [];

  // COMPUTED GETTERS (NOT stored - calculate on demand)

  /// Distance in kilometers (derived from distanceMeters)
  double get distanceKm => distanceMeters / 1000;

  /// Duration of the run
  Duration get duration => Duration(seconds: durationSeconds);

  /// Average pace in minutes per kilometer
  /// Returns 0 if distance or duration is 0
  double get avgPaceMinPerKm {
    if (distanceMeters == 0 || durationSeconds == 0) return 0;
    final km = distanceMeters / 1000;
    final minutes = durationSeconds / 60;
    return minutes / km;
  }

  /// Stability score (100 - CV, clamped 0-100)
  /// Higher = more consistent pace
  /// Returns null if CV is null (runs < 1km)
  int? get stabilityScore {
    if (cv == null) return null;
    return (100 - cv!).round().clamp(0, 100);
  }

  /// Flip points = hexes colored × buff multiplier
  int get flipPoints => hexesColored * buffMultiplier;

  // MUTABLE METHODS (for active run tracking)
  // Note: These mutate the Run object in-place during active runs.
  // After run completion, use copyWith() for immutable updates.

  /// Add a location point to the route
  void addPoint(LocationPoint point) {
    route.add(point);
  }

  /// Update total distance
  void updateDistance(double meters) {
    distanceMeters = meters;
  }

  /// Record a hex flip
  void recordFlip(String hexId) {
    hexesColored++;
    if (!hexesPassed.contains(hexId)) {
      hexesPassed.add(hexId);
    }
  }

  /// Mark run as complete and record end time
  void complete() {
    isActive = false;
    endTime = DateTime.now();
  }

  // SERIALIZATION

  /// For local SQLite storage (milliseconds epoch)
  /// Note: Database stores distanceKm (not meters) for backward compatibility
  /// SQLite only supports: num, String, Uint8List (NOT List, bool, Map)
  Map<String, dynamic> toMap() => {
    'id': id,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime':
        endTime?.millisecondsSinceEpoch ?? startTime.millisecondsSinceEpoch,
    'distanceKm': distanceMeters / 1000, // Convert meters to km for DB
    'durationSeconds': durationSeconds,
    'avgPaceSecPerKm': avgPaceMinPerKm * 60, // Convert min/km to sec/km for DB
    'hexesColored': hexesColored,
    'teamAtRun': teamAtRun.name,
    'isPurpleRunner': teamAtRun == Team.purple ? 1 : 0, // Legacy field
    'cv': cv,
    'sync_status': syncStatus,
    'flip_points': flipPoints,
  };

  /// From local SQLite storage
  /// Note: Database stores distanceKm (not meters) for backward compatibility
  factory Run.fromMap(Map<String, dynamic> map) {
    // Handle both distanceKm (old DB) and distanceMeters (new format)
    double distanceMeters;
    if (map['distanceKm'] != null) {
      distanceMeters = (map['distanceKm'] as num).toDouble() * 1000; // km to m
    } else if (map['distanceMeters'] != null) {
      distanceMeters = (map['distanceMeters'] as num).toDouble();
    } else {
      distanceMeters = 0;
    }

    // Parse timestamps
    final startTime = DateTime.fromMillisecondsSinceEpoch(
      map['startTime'] as int,
    );
    final endTime = map['endTime'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int)
        : null;

    // Get durationSeconds from DB, or calculate from timestamps
    int durationSeconds;
    if (map['durationSeconds'] != null) {
      durationSeconds = (map['durationSeconds'] as num).toInt();
    } else if (endTime != null) {
      durationSeconds = endTime.difference(startTime).inSeconds;
    } else {
      durationSeconds = 0;
    }

    return Run(
      id: map['id'] as String,
      startTime: startTime,
      endTime: endTime,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      hexesColored: (map['hexesColored'] as num?)?.toInt() ?? 0,
      teamAtRun: Team.values.byName(map['teamAtRun'] as String),
      buffMultiplier: (map['buffMultiplier'] as num?)?.toInt() ?? 1,
      cv: (map['cv'] as num?)?.toDouble(),
      syncStatus:
          map['sync_status'] as String? ??
          map['syncStatus'] as String? ??
          'pending',
    );
  }

  /// To Supabase row (snake_case) for finalize_run RPC
  /// CRITICAL: Must match RunSummary.toRow() format for server sync
  Map<String, dynamic> toRow() => {
    'end_time': endTime?.toIso8601String(),
    'distance_meters': distanceMeters,
    'duration_seconds': durationSeconds,
    'avg_pace_min_per_km': avgPaceMinPerKm,
    'hexes_colored': hexesColored,
    'team_at_run': teamAtRun.name,
    'hex_path': hexPath,
    'buff_multiplier': buffMultiplier,
    'cv': cv,
  };

  /// From Supabase row (snake_case)
  factory Run.fromRow(Map<String, dynamic> row) {
    final endTime = row['end_time'] != null
        ? DateTime.parse(row['end_time'] as String)
        : null;
    final durationSeconds = (row['duration_seconds'] as num?)?.toInt() ?? 0;

    // Calculate startTime from endTime and duration if start_time is missing
    final startTime = row['start_time'] != null
        ? DateTime.parse(row['start_time'] as String)
        : (endTime != null
              ? endTime.subtract(Duration(seconds: durationSeconds))
              : DateTime.now());

    // Parse team safely
    final teamStr = row['team_at_run'] as String?;
    final team = teamStr != null && teamStr.isNotEmpty
        ? Team.values.byName(teamStr)
        : Team.red;

    return Run(
      id: row['id'] as String,
      startTime: startTime,
      endTime: endTime,
      distanceMeters: (row['distance_meters'] as num?)?.toDouble() ?? 0,
      durationSeconds: durationSeconds,
      hexesColored: (row['hexes_colored'] as num?)?.toInt() ?? 0,
      teamAtRun: team,
      hexPath: List<String>.from(row['hex_path'] as List? ?? []),
      buffMultiplier: (row['buff_multiplier'] as num?)?.toInt() ?? 1,
      cv: (row['cv'] as num?)?.toDouble(),
    );
  }

  /// Create a copy with modified fields
  /// Note: To set cv to null, pass cv: null explicitly
  Run copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceMeters,
    int? durationSeconds,
    int? hexesColored,
    Team? teamAtRun,
    List<String>? hexPath,
    int? buffMultiplier,
    Object? cv = const _Unspecified(),
    String? syncStatus,
    List<LocationPoint>? route,
    List<String>? hexesPassed,
    String? currentHexId,
    double? distanceInCurrentHex,
    bool? isActive,
  }) {
    return Run(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      hexesColored: hexesColored ?? this.hexesColored,
      teamAtRun: teamAtRun ?? this.teamAtRun,
      hexPath: hexPath ?? this.hexPath,
      buffMultiplier: buffMultiplier ?? this.buffMultiplier,
      cv: cv is _Unspecified ? this.cv : cv as double?,
      syncStatus: syncStatus ?? this.syncStatus,
      route: route ?? this.route,
      hexesPassed: hexesPassed ?? this.hexesPassed,
      currentHexId: currentHexId ?? this.currentHexId,
      distanceInCurrentHex: distanceInCurrentHex ?? this.distanceInCurrentHex,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'Run(id: $id, distance: ${distanceKm.toStringAsFixed(2)}km, '
      'flips: $hexesColored, team: ${teamAtRun.name}, active: $isActive)';
}

class _Unspecified {
  const _Unspecified();
}
