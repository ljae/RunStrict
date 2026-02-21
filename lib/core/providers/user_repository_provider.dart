import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/models/team.dart';
import '../../data/repositories/user_repository.dart';

/// Riverpod Notifier wrapping UserRepository for reactive state.
///
/// The underlying UserRepository singleton handles persistence.
/// This Notifier exposes the current UserModel? as reactive state.
class UserRepositoryNotifier extends Notifier<UserModel?> {
  late final UserRepository _repo;

  @override
  UserModel? build() {
    _repo = UserRepository();
    return _repo.currentUser;
  }

  UserRepository get repository => _repo;

  Future<void> setUser(UserModel user) async {
    await _repo.setUser(user);
    state = _repo.currentUser;
  }

  void updateSeasonPoints(int points) {
    _repo.updateSeasonPoints(points);
    state = _repo.currentUser;
  }

  void defectToPurple() {
    _repo.defectToPurple();
    state = _repo.currentUser;
  }

  void clear() {
    _repo.clear();
    state = null;
  }

  Future<void> saveToDisk() async {
    await _repo.saveToDisk();
  }

  Future<void> loadFromDisk() async {
    await _repo.loadFromDisk();
    state = _repo.currentUser;
  }

  Future<void> deleteFromDisk() async {
    await _repo.deleteFromDisk();
  }

  bool get hasUser => _repo.hasUser;
  Team? get userTeam => _repo.userTeam;
  int get seasonPoints => _repo.seasonPoints;
}

final userRepositoryProvider =
    NotifierProvider<UserRepositoryNotifier, UserModel?>(
  UserRepositoryNotifier.new,
);
