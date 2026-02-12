import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'team.dart';

/// Hex model with "last runner color" system
///
/// NO ownership - just tracks who ran through last.
/// Privacy optimized: Minimal timestamps for fairness (lastFlippedAt), no runner IDs stored.
/// Only stores the team color of the last runner.
class HexModel {
  final String id;
  final LatLng center;
  Team? lastRunnerTeam; // null = neutral (no one ran here yet)
  DateTime?
  lastFlippedAt; // Run's endTime when hex was flipped (conflict resolution)

  HexModel({
    required this.id,
    required this.center,
    this.lastRunnerTeam,
    this.lastFlippedAt,
  });

  /// Check if this hex has been run through
  bool get isNeutral => lastRunnerTeam == null;

  bool wouldChangeColor(Team runnerTeam) {
    return lastRunnerTeam != runnerTeam;
  }

  /// Set runner color with conflict resolution.
  /// Returns true if color changed (flip occurred).
  ///
  /// Conflict resolution: "Later run wins"
  /// - If runEndTime > lastFlippedAt → Update hex color and timestamp
  /// - If runEndTime ≤ lastFlippedAt → Skip update (hex already claimed by later run)
  bool setRunnerColor(Team runnerTeam, DateTime runEndTime) {
    // Same team = no flip
    if (lastRunnerTeam == runnerTeam) return false;

    // Conflict resolution: Later run wins (prevents offline abusing)
    if (lastFlippedAt != null && runEndTime.isBefore(lastFlippedAt!)) {
      return false; // Skip - hex already claimed by a later run
    }

    lastRunnerTeam = runnerTeam;
    lastFlippedAt = runEndTime;
    return true; // Color changed (flip)
  }

  /// Get color based on last runner (NOT ownership)
  Color get hexColor {
    if (lastRunnerTeam == null) {
      return const Color(0xFF2A3550).withOpacity(0.15); // Neutral gray
    }
    switch (lastRunnerTeam!) {
      case Team.red:
        return const Color(0xFFFF003C); // Athletic Red
      case Team.blue:
        return const Color(0xFF008DFF); // Electric Blue
      case Team.purple:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  /// Get light color for subtle fills
  Color get hexLightColor {
    if (lastRunnerTeam == null) {
      return const Color(0xFF2A3550).withOpacity(0.15);
    }
    switch (lastRunnerTeam!) {
      case Team.red:
        return const Color(0xFFFF335F).withOpacity(0.3);
      case Team.blue:
        return const Color(0xFF33A4FF).withOpacity(0.3);
      case Team.purple:
        return const Color(0xFFA78BFA).withOpacity(0.3);
    }
  }

  /// Get border color
  Color get borderColor {
    if (lastRunnerTeam == null) {
      return const Color(0xFF6B7280); // Gray border
    }
    return hexColor;
  }

  /// Get border width
  double get borderWidth {
    if (lastRunnerTeam == null) return 1.0;
    return 1.5;
  }

  /// Get emoji for display
  String get emoji {
    if (lastRunnerTeam == null) return '';
    return lastRunnerTeam!.emoji;
  }

  /// Get display name
  String get displayName {
    if (lastRunnerTeam == null) return '미점령';
    switch (lastRunnerTeam!) {
      case Team.red:
        return '레드';
      case Team.blue:
        return '블루';
      case Team.purple:
        return '퍼플';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': center.latitude,
    'longitude': center.longitude,
    'lastRunnerTeam': lastRunnerTeam?.name,
    'lastFlippedAt': lastFlippedAt?.toIso8601String(),
  };

  factory HexModel.fromJson(Map<String, dynamic> json) => HexModel(
    id: json['id'] as String,
    center: LatLng(json['latitude'] as double, json['longitude'] as double),
    lastRunnerTeam: json['lastRunnerTeam'] != null
        ? Team.values.byName(json['lastRunnerTeam'] as String)
        : null,
    lastFlippedAt: json['lastFlippedAt'] != null
        ? DateTime.parse(json['lastFlippedAt'] as String)
        : null,
  );

  /// Create from Supabase row (snake_case)
  /// Handles both full hex rows (with id, latitude, longitude) and
  /// delta sync rows (with hex_id only, no coordinates)
  factory HexModel.fromRow(Map<String, dynamic> row) {
    // Support both 'id' (full row) and 'hex_id' (delta sync)
    final hexId = (row['id'] ?? row['hex_id']) as String;

    // If coordinates are provided, use them; otherwise use placeholder
    // The actual center will be calculated by HexService when needed
    final lat = (row['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (row['longitude'] as num?)?.toDouble() ?? 0.0;

    return HexModel(
      id: hexId,
      center: LatLng(lat, lng),
      lastRunnerTeam: row['last_runner_team'] != null
          ? Team.values.byName(row['last_runner_team'] as String)
          : null,
      lastFlippedAt: row['last_flipped_at'] != null
          ? DateTime.parse(row['last_flipped_at'] as String)
          : null,
    );
  }

  HexModel copyWith({Team? lastRunnerTeam, DateTime? lastFlippedAt}) =>
      HexModel(
        id: id,
        center: center,
        lastRunnerTeam: lastRunnerTeam ?? this.lastRunnerTeam,
        lastFlippedAt: lastFlippedAt ?? this.lastFlippedAt,
      );
}
