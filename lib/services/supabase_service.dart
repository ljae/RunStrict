import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/run.dart';

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

  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    final result = await client.rpc(
      'get_leaderboard',
      params: {'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<Map<String, dynamic>> finalizeRun(Run run) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final result = await client.rpc(
      'finalize_run',
      params: {
        'p_user_id': userId,
        'p_start_time': run.startTime.toIso8601String(),
        'p_end_time': run.endTime?.toIso8601String(),
        'p_distance_km': run.distanceKm,
        'p_duration_seconds': run.durationSeconds,
        'p_hex_path': run.hexPath,
        'p_buff_multiplier': run.buffMultiplier,
        'p_cv': run.cv,
      },
    );
    return result as Map<String, dynamic>;
  }

  /// Sync app state on launch: fetch user, buff multiplier, and hex viewport.
  ///
  /// Returns: { user, buff_multiplier, hexes_in_viewport }
  /// Called once on app launch to pre-patch all necessary data.
  Future<Map<String, dynamic>> appLaunchSync(String userId) async {
    final result = await client.rpc(
      'app_launch_sync',
      params: {'p_user_id': userId},
    );
    return result as Map<String, dynamic>;
  }

  /// Get user's current buff multiplier based on team, performance, and city.
  Future<Map<String, dynamic>> getUserBuff(String userId) async {
    final result = await client.rpc(
      'get_user_buff',
      params: {'p_user_id': userId},
    );
    return result as Map<String, dynamic>? ??
        {
          'multiplier': 1,
          'base_buff': 1,
          'all_range_bonus': 0,
          'reason': 'Default',
        };
  }

  Future<Map<String, dynamic>> getUserYesterdayStats(String userId) async {
    final result = await client.rpc(
      'get_user_yesterday_stats',
      params: {'p_user_id': userId},
    );
    return result as Map<String, dynamic>? ??
        {'has_data': false, 'run_count': 0};
  }

  Future<Map<String, dynamic>> getTeamRankings(
    String userId, {
    String? cityHex,
  }) async {
    final result = await client.rpc(
      'get_team_rankings',
      params: {'p_user_id': userId, 'p_city_hex': cityHex},
    );
    return result as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getHexDominance({String? cityHex}) async {
    final result = await client.rpc(
      'get_hex_dominance',
      params: {'p_city_hex': cityHex},
    );
    return result as Map<String, dynamic>? ?? {};
  }

  Future<List<Map<String, dynamic>>> getHexesDelta(
    String parentHex, {
    DateTime? sinceTime,
  }) async {
    final result = await client.rpc(
      'get_hexes_delta',
      params: {
        'p_parent_hex': parentHex,
        'p_since_time': sinceTime?.toUtc().toIso8601String(),
      },
    );
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }
}
