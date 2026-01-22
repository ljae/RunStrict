import 'package:flutter/foundation.dart';

/// Service to manage flip points and daily settlement.
///
/// Points from crew competition are settled at 12:00 PM daily.
/// On first login after settlement, pending points are animated.
class PointsService extends ChangeNotifier {
  int _currentPoints;
  int _pendingPoints;
  DateTime? _lastSettlementCheck;
  bool _hasAnimatedPendingPoints = false;

  /// Settlement hour (12:00 PM / noon)
  static const int settlementHour = 12;

  PointsService({
    int initialPoints = 0,
    int pendingPoints = 0,
  })  : _currentPoints = initialPoints,
        _pendingPoints = pendingPoints;

  /// Current displayed points (before pending animation)
  int get currentPoints => _currentPoints;

  /// Points waiting to be animated (from daily settlement)
  int get pendingPoints => _pendingPoints;

  /// Total points including pending
  int get totalPoints => _currentPoints + _pendingPoints;

  /// Whether there are pending points to animate
  bool get hasPendingPoints => _pendingPoints > 0 && !_hasAnimatedPendingPoints;

  /// Check if settlement has occurred since last check
  bool checkForSettlement() {
    final now = DateTime.now();
    final todaySettlement = DateTime(now.year, now.month, now.day, settlementHour);

    // If we haven't checked today and it's past settlement time
    if (_lastSettlementCheck == null) {
      _lastSettlementCheck = now;
      return _pendingPoints > 0;
    }

    // Check if settlement happened between last check and now
    final lastCheck = _lastSettlementCheck!;
    if (lastCheck.isBefore(todaySettlement) && now.isAfter(todaySettlement)) {
      _lastSettlementCheck = now;
      return true;
    }

    _lastSettlementCheck = now;
    return false;
  }

  /// Add points from a run (immediate, no animation)
  void addRunPoints(int points) {
    _currentPoints += points;
    notifyListeners();
  }

  /// Set pending points from settlement (will animate on next display)
  void setPendingSettlementPoints(int points) {
    _pendingPoints = points;
    _hasAnimatedPendingPoints = false;
    notifyListeners();
  }

  /// Mark pending points animation as started
  void startPendingAnimation() {
    _hasAnimatedPendingPoints = true;
  }

  /// Called when pending points animation completes
  void completePendingAnimation() {
    _currentPoints += _pendingPoints;
    _pendingPoints = 0;
    _hasAnimatedPendingPoints = true;
    notifyListeners();
  }

  /// Simulate adding points with animation (for testing/demo)
  void simulateFlipPoints(int points) {
    _pendingPoints = points;
    _hasAnimatedPendingPoints = false;
    notifyListeners();
  }

  /// Reset for new season
  void resetForNewSeason() {
    _currentPoints = 0;
    _pendingPoints = 0;
    _hasAnimatedPendingPoints = false;
    _lastSettlementCheck = null;
    notifyListeners();
  }

  /// Format points with thousands separator
  static String formatPoints(int points) {
    if (points < 1000) return points.toString();
    final str = points.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  /// Get individual digits for flip animation (padded to minDigits)
  List<int> getDigits(int value, {int minDigits = 1}) {
    if (value == 0) return List.filled(minDigits, 0);

    final digits = <int>[];
    var remaining = value;
    while (remaining > 0) {
      digits.insert(0, remaining % 10);
      remaining ~/= 10;
    }

    // Pad with zeros if needed
    while (digits.length < minDigits) {
      digits.insert(0, 0);
    }

    return digits;
  }
}
