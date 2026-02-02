import 'storage_service.dart';
import '../models/run.dart';

/// In-memory implementation of StorageService for MVP/Testing
class InMemoryStorageService implements StorageService {
  final List<Run> _runs = [];
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> saveRun(Run run) async {
    _checkInitialized();
    // Replace if exists, otherwise add
    final index = _runs.indexWhere((r) => r.id == run.id);
    if (index != -1) {
      _runs[index] = run;
    } else {
      _runs.insert(0, run); // Add to beginning (newest)
    }
  }

  @override
  Future<List<Run>> getAllRuns() async {
    _checkInitialized();
    return List.from(_runs);
  }

  @override
  Future<Run?> getRunById(String id) async {
    _checkInitialized();
    try {
      return _runs.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteRun(String id) async {
    _checkInitialized();
    _runs.removeWhere((r) => r.id == id);
  }

  @override
  Future<Map<String, dynamic>> getTotalStats() async {
    _checkInitialized();
    double totalDistance = 0;
    int totalRuns = _runs.length;
    int totalHexes = 0;

    for (var run in _runs) {
      totalDistance += run.distanceMeters;
      totalHexes += run.hexesColored; // Use hexesColored (flip count)
    }

    return {
      'totalDistance': totalDistance,
      'totalRuns': totalRuns,
      'totalHexes': totalHexes,
    };
  }

  @override
  Future<void> close() async {
    _isInitialized = false;
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      // Auto-initialize for convenience in this mock
      _isInitialized = true;
    }
  }
}
