import 'package:flutter/foundation.dart';

/// Service for tracking hex flip cooldowns.
///
/// Rule: A runner can only earn flip points from the same hex once per cooldown period.
/// This prevents farming points by repeatedly flipping the same hex with another runner,
/// while still allowing legitimate re-captures during longer runs or multiple runs per day.
///
/// Storage strategy:
/// - In-memory cache for fast lookup during active runs
/// - SQLite persistence for cross-session continuity
/// - Auto-cleanup of expired records (older than cooldown period)
class FlipCooldownService extends ChangeNotifier {
  /// Default cooldown duration (10 minutes)
  static const Duration defaultCooldown = Duration(minutes: 10);

  /// Cooldown duration for this instance
  final Duration cooldownDuration;

  /// In-memory cache: hexId -> last flip timestamp
  final Map<String, DateTime> _flipTimestamps = {};

  /// Database callbacks for persistence
  Future<void> Function(String hexId, DateTime timestamp)? _onFlipRecorded;
  Future<Map<String, DateTime>> Function()? _loadRecentFlips;
  Future<void> Function(Duration maxAge)? _cleanupOldFlips;

  /// Current user ID (set during initialization)
  String? _userId;

  /// Whether the service is initialized
  bool get isInitialized => _userId != null;

  /// Number of hexes currently in cooldown
  int get activeCooldownCount => _flipTimestamps.length;

  FlipCooldownService({this.cooldownDuration = defaultCooldown});

  /// Initialize the service for a specific user
  ///
  /// [userId] - The current user's ID
  /// [onFlipRecorded] - Callback to persist flip to database
  /// [loadRecentFlips] - Callback to load recent flips from database
  /// [cleanupOldFlips] - Callback to remove expired records from database
  Future<void> initialize({
    required String userId,
    Future<void> Function(String hexId, DateTime timestamp)? onFlipRecorded,
    Future<Map<String, DateTime>> Function()? loadRecentFlips,
    Future<void> Function(Duration maxAge)? cleanupOldFlips,
  }) async {
    _userId = userId;
    _onFlipRecorded = onFlipRecorded;
    _loadRecentFlips = loadRecentFlips;
    _cleanupOldFlips = cleanupOldFlips;

    // Load recent flips from database
    await _loadRecentFlipsFromDb();

    // Clean up expired records
    _cleanupExpiredInMemory();
    _cleanupOldFlips?.call(cooldownDuration);

    debugPrint(
      'FlipCooldownService: Initialized for user $userId, '
      '$activeCooldownCount active cooldowns, '
      'cooldown=${cooldownDuration.inMinutes}min',
    );
  }

  /// Load recent flips from database into memory
  Future<void> _loadRecentFlipsFromDb() async {
    if (_loadRecentFlips == null) return;

    try {
      final recentFlips = await _loadRecentFlips!();
      _flipTimestamps.clear();
      _flipTimestamps.addAll(recentFlips);
      _cleanupExpiredInMemory();
    } catch (e) {
      debugPrint('FlipCooldownService: Failed to load flips: $e');
    }
  }

  /// Remove expired entries from in-memory cache
  void _cleanupExpiredInMemory() {
    final now = DateTime.now();
    _flipTimestamps.removeWhere((hexId, timestamp) {
      return now.difference(timestamp) > cooldownDuration;
    });
  }

  /// Check if a hex is currently in cooldown for this user
  ///
  /// Returns true if the hex is in cooldown (no points should be awarded).
  bool isInCooldown(String hexId) {
    final lastFlip = _flipTimestamps[hexId];
    if (lastFlip == null) return false;

    final elapsed = DateTime.now().difference(lastFlip);
    if (elapsed > cooldownDuration) {
      // Cooldown expired, remove from cache
      _flipTimestamps.remove(hexId);
      return false;
    }

    return true;
  }

  /// Get remaining cooldown time for a hex (for UI display)
  Duration? getRemainingCooldown(String hexId) {
    final lastFlip = _flipTimestamps[hexId];
    if (lastFlip == null) return null;

    final elapsed = DateTime.now().difference(lastFlip);
    if (elapsed > cooldownDuration) {
      _flipTimestamps.remove(hexId);
      return null;
    }

    return cooldownDuration - elapsed;
  }

  /// Record a hex flip
  ///
  /// Returns true if this is a valid flip (not in cooldown, points should be awarded).
  /// Returns false if in cooldown (no points).
  Future<bool> recordFlip(String hexId) async {
    // Check cooldown first
    if (isInCooldown(hexId)) {
      final remaining = getRemainingCooldown(hexId);
      debugPrint(
        'FlipCooldownService: Hex $hexId in cooldown '
        '(${remaining?.inSeconds}s remaining)',
      );
      return false;
    }

    // Record the flip
    final timestamp = DateTime.now();
    _flipTimestamps[hexId] = timestamp;
    notifyListeners();

    // Persist to database (fire-and-forget)
    if (_onFlipRecorded != null) {
      try {
        await _onFlipRecorded!(hexId, timestamp);
      } catch (e) {
        debugPrint('FlipCooldownService: Failed to persist flip: $e');
        // Don't rollback memory - still count as flipped
      }
    }

    debugPrint(
      'FlipCooldownService: Recorded flip for hex $hexId '
      '(active cooldowns: $activeCooldownCount)',
    );
    return true;
  }

  /// Clear all cooldowns (for testing/debugging)
  void clearAllCooldowns() {
    _flipTimestamps.clear();
    notifyListeners();
    debugPrint('FlipCooldownService: Cleared all cooldowns');
  }

  /// Dispose resources
  @override
  void dispose() {
    _flipTimestamps.clear();
    _userId = null;
    super.dispose();
  }
}
