import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'team.dart';

/// Hex model with "last runner color" system
///
/// NO ownership - just tracks who ran through last.
/// Privacy optimized: No timestamps or runner IDs stored.
/// Only stores the team color of the last runner.
class HexModel {
  final String id;
  final LatLng center;
  Team? lastRunnerTeam; // null = neutral (no one ran here yet)

  HexModel({required this.id, required this.center, this.lastRunnerTeam});

  /// Check if this hex has been run through
  bool get isNeutral => lastRunnerTeam == null;

  bool wouldChangeColor(Team runnerTeam) {
    return lastRunnerTeam != runnerTeam;
  }

  bool setRunnerColor(Team runnerTeam) {
    if (lastRunnerTeam == runnerTeam) return false;
    lastRunnerTeam = runnerTeam;
    return true;
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
  };

  factory HexModel.fromJson(Map<String, dynamic> json) => HexModel(
    id: json['id'] as String,
    center: LatLng(json['latitude'] as double, json['longitude'] as double),
    lastRunnerTeam: json['lastRunnerTeam'] != null
        ? Team.values.byName(json['lastRunnerTeam'] as String)
        : null,
  );

  HexModel copyWith({Team? lastRunnerTeam}) => HexModel(
    id: id,
    center: center,
    lastRunnerTeam: lastRunnerTeam ?? this.lastRunnerTeam,
  );
}
