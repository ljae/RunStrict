import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service for managing crew multiplier based on yesterday's active members.
///
/// The multiplier represents the count of crew members who ran YESTERDAY.
/// This value is calculated daily at midnight GMT+2 via an Edge Function.
/// The multiplier is fetched once on app launch and cached for the session.
/// Default multiplier is 1 for solo runners or new crews.
class CrewMultiplierService with ChangeNotifier {
  final SupabaseService _supabaseService;

  int _multiplier = 1;
  String? _crewId;
  bool _isLoading = false;

  CrewMultiplierService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  /// Current multiplier value (yesterday's active crew count).
  /// Defaults to 1 if not yet loaded or for solo runners.
  int get multiplier => _multiplier;

  /// Whether a multiplier fetch is in progress.
  bool get isLoading => _isLoading;

  /// Loads the multiplier for the given crew ID.
  /// Fetches via RPC call to get_yesterday_crew_count.
  /// Caches the value for the session.
  Future<void> loadMultiplier(String crewId) async {
    _crewId = crewId;
    _isLoading = true;
    notifyListeners();

    try {
      final count = await _supabaseService.getYesterdayCrewCount(crewId);
      _multiplier = count > 0 ? count : 1;
    } catch (e) {
      debugPrint('Error loading crew multiplier: $e');
      _multiplier = 1; // Default to 1 on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually refreshes the multiplier for the current crew.
  /// Use this when you need to update the cached value.
  Future<void> refresh() async {
    if (_crewId == null) return;
    await loadMultiplier(_crewId!);
  }

  /// Resets the multiplier and clears the cached crew ID.
  /// Call this when the user leaves a crew.
  void reset() {
    _multiplier = 1;
    _crewId = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
