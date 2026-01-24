import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class CrewMultiplierService with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  int _activeRunners = 1;
  String? _crewId;

  int get activeRunners => _activeRunners;
  int get multiplier => _activeRunners;

  void startListening(String crewId) {
    _crewId = crewId;

    // Use stream-based subscription for active runs
    _subscription = _supabaseService.subscribeToActiveRuns(crewId).listen((
      data,
    ) {
      _activeRunners = data.isNotEmpty ? data.length : 1;
      notifyListeners();
    });

    _refreshCount();
  }

  Future<void> _refreshCount() async {
    if (_crewId == null) return;
    try {
      final count = await _supabaseService.getCrewMultiplier(_crewId!);
      _activeRunners = count > 0 ? count : 1;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing crew multiplier: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _crewId = null;
    _activeRunners = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
