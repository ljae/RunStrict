import '../models/run_session.dart';

/// Abstract interface for data persistence
/// This allows easy swapping between SQLite (MVP) and Firebase (future)
abstract class StorageService {
  /// Initialize the storage service
  Future<void> initialize();

  /// Save a completed run session
  Future<void> saveRun(RunSession run);

  /// Get all run sessions, sorted by date (newest first)
  Future<List<RunSession>> getAllRuns();

  /// Get a specific run session by ID
  Future<RunSession?> getRunById(String id);

  /// Delete a run session
  Future<void> deleteRun(String id);

  /// Get total statistics
  Future<Map<String, dynamic>> getTotalStats();

  /// Close the storage connection
  Future<void> close();
}
