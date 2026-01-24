import 'package:flutter/foundation.dart';

class PointsService extends ChangeNotifier {
  int _currentPoints;

  PointsService({int initialPoints = 0}) : _currentPoints = initialPoints;

  int get currentPoints => _currentPoints;

  void addRunPoints(int points) {
    _currentPoints += points;
    notifyListeners();
  }

  void setPoints(int points) {
    _currentPoints = points;
    notifyListeners();
  }

  void resetForNewSeason() {
    _currentPoints = 0;
    notifyListeners();
  }

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

  List<int> getDigits(int value, {int minDigits = 1}) {
    if (value == 0) return List.filled(minDigits, 0);

    final digits = <int>[];
    var remaining = value;
    while (remaining > 0) {
      digits.insert(0, remaining % 10);
      remaining ~/= 10;
    }

    while (digits.length < minDigits) {
      digits.insert(0, 0);
    }

    return digits;
  }
}
