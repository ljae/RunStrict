import '../models/run.dart';

/// Abstract interface for data persistence
/// This allows easy swapping between SQLite (MVP) and Firebase (future)
abstract class StorageService {
  /// Initialize the storage service
  Future<void> initialize();

  /// Save a completed run
  Future<void> saveRun(Run run);

  /// Get all runs, sorted by date (newest first)
  Future<List<Run>> getAllRuns();

  /// Get a specific run by ID
  Future<Run?> getRunById(String id);

  /// Delete a run
  Future<void> deleteRun(String id);

  /// Get total statistics
  Future<Map<String, dynamic>> getTotalStats();

  /// Close the storage connection
  Future<void> close();
}
