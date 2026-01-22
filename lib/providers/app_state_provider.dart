import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/team.dart';

class AppStateProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUser => _currentUser != null;
  Team? get userTeam => _currentUser?.team;

  // Territory balance
  double _redPercentage = 48.0;
  double _bluePercentage = 52.0;

  double get redPercentage => _redPercentage;
  double get bluePercentage => _bluePercentage;

  void setUser(UserModel user) {
    _currentUser = user;
    _error = null;
    notifyListeners();
  }

  void selectTeam(Team team, String username) {
    _currentUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: username,
      team: team,
    );
    _error = null;
    notifyListeners();
  }

  void updateTerritoryBalance(double red, double blue) {
    _redPercentage = red;
    _bluePercentage = blue;
    notifyListeners();
  }

  /// Update user's season points
  void updateSeasonPoints(int additionalPoints) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        seasonPoints: _currentUser!.seasonPoints + additionalPoints,
      );
      notifyListeners();
    }
  }

  /// Join Purple Crew (The Traitor's Gate)
  /// Warning: This resets season points to 0
  void defectToPurple() {
    if (_currentUser != null && _currentUser!.team != Team.purple) {
      _currentUser = _currentUser!.defectToPurple();
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
