import 'package:flutter/material.dart';

/// Impact tier enum with visual feedback properties
enum ImpactTier {
  starter, // 0-3 km: 10 pts/km
  warmingUp, // 3-6 km: 25 pts/km
  onFire, // 6-9 km: 50 pts/km
  beastMode, // 9-12 km: 100 pts/km
  legendary, // 12-15 km: 150 pts/km
  unstoppable; // 15+ km: 200 pts/km

  String get emoji {
    switch (this) {
      case ImpactTier.starter:
        return '🌱';
      case ImpactTier.warmingUp:
        return '🔥';
      case ImpactTier.onFire:
        return '⚡';
      case ImpactTier.beastMode:
        return '💎';
      case ImpactTier.legendary:
        return '👑';
      case ImpactTier.unstoppable:
        return '🏆';
    }
  }

  String get displayName {
    switch (this) {
      case ImpactTier.starter:
        return 'Starter';
      case ImpactTier.warmingUp:
        return 'Warming Up';
      case ImpactTier.onFire:
        return 'On Fire';
      case ImpactTier.beastMode:
        return 'Beast Mode';
      case ImpactTier.legendary:
        return 'Legendary';
      case ImpactTier.unstoppable:
        return 'Unstoppable';
    }
  }

  String get koreanName {
    switch (this) {
      case ImpactTier.starter:
        return '시작';
      case ImpactTier.warmingUp:
        return '워밍업';
      case ImpactTier.onFire:
        return '불타오르는 중';
      case ImpactTier.beastMode:
        return '비스트 모드';
      case ImpactTier.legendary:
        return '전설';
      case ImpactTier.unstoppable:
        return '멈출 수 없는';
    }
  }

  int get baseImpact {
    switch (this) {
      case ImpactTier.starter:
        return 10;
      case ImpactTier.warmingUp:
        return 25;
      case ImpactTier.onFire:
        return 50;
      case ImpactTier.beastMode:
        return 100;
      case ImpactTier.legendary:
        return 150;
      case ImpactTier.unstoppable:
        return 200;
    }
  }

  Color get color {
    switch (this) {
      case ImpactTier.starter:
        return Colors.green;
      case ImpactTier.warmingUp:
        return Colors.orange;
      case ImpactTier.onFire:
        return Colors.yellow;
      case ImpactTier.beastMode:
        return Colors.amber;
      case ImpactTier.legendary:
        return Colors.purple;
      case ImpactTier.unstoppable:
        return Colors.white;
    }
  }

  /// Distance required to reach this tier (in km)
  double get minDistance {
    switch (this) {
      case ImpactTier.starter:
        return 0;
      case ImpactTier.warmingUp:
        return 3;
      case ImpactTier.onFire:
        return 6;
      case ImpactTier.beastMode:
        return 9;
      case ImpactTier.legendary:
        return 12;
      case ImpactTier.unstoppable:
        return 15;
    }
  }

  /// Distance to next tier (in km), null if max tier
  double? get distanceToNextTier {
    switch (this) {
      case ImpactTier.starter:
        return 3;
      case ImpactTier.warmingUp:
        return 3;
      case ImpactTier.onFire:
        return 3;
      case ImpactTier.beastMode:
        return 3;
      case ImpactTier.legendary:
        return 3;
      case ImpactTier.unstoppable:
        return null;
    }
  }

  ImpactTier? get nextTier {
    switch (this) {
      case ImpactTier.starter:
        return ImpactTier.warmingUp;
      case ImpactTier.warmingUp:
        return ImpactTier.onFire;
      case ImpactTier.onFire:
        return ImpactTier.beastMode;
      case ImpactTier.beastMode:
        return ImpactTier.legendary;
      case ImpactTier.legendary:
        return ImpactTier.unstoppable;
      case ImpactTier.unstoppable:
        return null;
    }
  }
}

/// Running score calculator service
class RunningScoreService {
  // Singleton
  static final RunningScoreService _instance = RunningScoreService._internal();
  factory RunningScoreService() => _instance;
  RunningScoreService._internal();

  /// Get impact tier based on current run distance
  static ImpactTier getTier(double distanceKm) {
    if (distanceKm >= 15) return ImpactTier.unstoppable;
    if (distanceKm >= 12) return ImpactTier.legendary;
    if (distanceKm >= 9) return ImpactTier.beastMode;
    if (distanceKm >= 6) return ImpactTier.onFire;
    if (distanceKm >= 3) return ImpactTier.warmingUp;
    return ImpactTier.starter;
  }

  /// Get base impact per km for given distance
  static int getBaseImpact(double distanceKm) {
    return getTier(distanceKm).baseImpact;
  }

  /// Get pace multiplier based on pace (min/km)
  static double getPaceMultiplier(double paceMinPerKm) {
    if (paceMinPerKm > 8.0) return 0.8; // Walking pace
    if (paceMinPerKm > 7.0) return 1.0; // Easy jog
    if (paceMinPerKm > 6.0) return 1.2; // Comfortable run
    if (paceMinPerKm > 5.0) return 1.5; // Strong run
    if (paceMinPerKm > 4.5) return 1.8; // Fast run
    return 2.0; // Sprint pace
  }

  /// Get pace description
  static String getPaceDescription(double paceMinPerKm) {
    if (paceMinPerKm > 8.0) return 'Walking';
    if (paceMinPerKm > 7.0) return 'Easy Jog';
    if (paceMinPerKm > 6.0) return 'Comfortable';
    if (paceMinPerKm > 5.0) return 'Strong';
    if (paceMinPerKm > 4.5) return 'Fast';
    return 'Sprint';
  }

  /// Check if the current pace is sufficient to capture a hex
  /// Threshold: Faster than 8:00 min/km (7.5 km/h)
  static bool canCapture(double paceMinPerKm) {
    return paceMinPerKm < 8.0;
  }

  /// Calculate distance remaining to next tier
  static double getDistanceToNextTier(double currentDistanceKm) {
    final tier = getTier(currentDistanceKm);
    final nextTier = tier.nextTier;
    if (nextTier == null) return 0;
    return nextTier.minDistance - currentDistanceKm;
  }

  /// Get progress percentage within current tier (0-100)
  static double getTierProgress(double currentDistanceKm) {
    final tier = getTier(currentDistanceKm);
    final nextTier = tier.nextTier;

    if (nextTier == null) {
      // At max tier, show how much beyond 15km
      return ((currentDistanceKm - 15) / 5 * 100).clamp(0, 100);
    }

    double tierStart = tier.minDistance;
    double tierEnd = nextTier.minDistance;
    double progress = (currentDistanceKm - tierStart) / (tierEnd - tierStart);
    return (progress * 100).clamp(0, 100);
  }
}

/// Running session state for visuals and capture logic
class RunningScoreState {
  final double totalDistanceKm;
  final double currentPaceMinPerKm;
  final String? currentHexId;
  final int flipCount;

  RunningScoreState({
    this.totalDistanceKm = 0,
    this.currentPaceMinPerKm = 7.0,
    this.currentHexId,
    this.flipCount = 0,
  });

  ImpactTier get currentTier => RunningScoreService.getTier(totalDistanceKm);

  bool get canCapture => RunningScoreService.canCapture(currentPaceMinPerKm);

  String get paceDescription =>
      RunningScoreService.getPaceDescription(currentPaceMinPerKm);

  double get tierProgress =>
      RunningScoreService.getTierProgress(totalDistanceKm);

  RunningScoreState copyWith({
    double? totalDistanceKm,
    double? currentPaceMinPerKm,
    String? currentHexId,
    int? flipCount,
  }) {
    return RunningScoreState(
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      currentPaceMinPerKm: currentPaceMinPerKm ?? this.currentPaceMinPerKm,
      currentHexId: currentHexId ?? this.currentHexId,
      flipCount: flipCount ?? this.flipCount,
    );
  }

  RunningScoreState reset() {
    return RunningScoreState();
  }
}
