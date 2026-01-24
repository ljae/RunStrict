import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  Future<bool> hasFlippedToday(String userId, String hexId) async {
    final result = await client.rpc(
      'has_flipped_today',
      params: {'p_user_id': userId, 'p_hex_id': hexId},
    );
    return result as bool? ?? false;
  }

  Future<int> getCrewMultiplier(String crewId) async {
    final result = await client.rpc(
      'get_crew_multiplier',
      params: {'p_crew_id': crewId},
    );
    return (result as num?)?.toInt() ?? 1;
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    final result = await client.rpc(
      'get_leaderboard',
      params: {'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<void> recordActiveRun({
    required String userId,
    required String? crewId,
    required String team,
  }) async {
    await client.from('active_runs').upsert({
      'user_id': userId,
      'crew_id': crewId,
      'team': team,
    });
  }

  Future<void> removeActiveRun(String userId) async {
    await client.from('active_runs').delete().eq('user_id', userId);
  }

  Future<void> recordFlip({
    required String userId,
    required String hexId,
    required String team,
    required int multiplier,
  }) async {
    await client.from('daily_flips').insert({
      'user_id': userId,
      'date_key': DateTime.now().toIso8601String().substring(0, 10),
      'hex_id': hexId,
    });

    await client.from('hexes').upsert({'id': hexId, 'last_runner_team': team});

    await client.rpc(
      'increment_season_points',
      params: {'p_user_id': userId, 'p_points': multiplier},
    );
  }

  /// Returns a stream of active run records for a crew.
  /// Use `.listen()` on the returned stream to receive updates.
  Stream<List<Map<String, dynamic>>> subscribeToActiveRuns(String crewId) {
    return client
        .from('active_runs')
        .stream(primaryKey: ['user_id'])
        .eq('crew_id', crewId);
  }
}
