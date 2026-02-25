import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../../data/models/run.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    final result = await client.rpc(
      'get_leaderboard',
      params: {'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<List<Map<String, dynamic>>> getSeasonLeaderboard(
    int seasonNumber, {
    int limit = 200,
  }) async {
    final result = await client.rpc(
      'get_season_leaderboard',
      params: {'p_season_number': seasonNumber, 'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(result as List);
  }

  /// Get scoped season leaderboard from snapshot.
  ///
  /// When [parentHex] is provided, filters to users in that province.
  /// Otherwise returns global top [limit].
  Future<List<Map<String, dynamic>>> getScopedSeasonLeaderboard(
    int seasonNumber, {
    String? parentHex,
    int limit = 50,
  }) async {
    final result = await client.rpc(
      'get_season_scoped_leaderboard',
      params: {
        'p_season_number': seasonNumber,
        'p_parent_hex': parentHex,
        'p_limit': limit,
      },
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
        'p_hex_parents': run.hexParents.isNotEmpty ? run.hexParents : null,
        'p_buff_multiplier': run.buffMultiplier,
        'p_cv': run.cv,
        'p_client_points': run.flipPoints,
      },
    );
    return result as Map<String, dynamic>;
  }

  /// Sync app state on launch: fetch user, buff multiplier, and hex viewport.
  ///
  /// Returns: { user, buff_multiplier, hexes_in_viewport }
  /// Called once on app launch to pre-patch all necessary data.
  Future<Map<String, dynamic>> appLaunchSync(
    String userId, {
    String? districtHex,
  }) async {
    final result = await client.rpc(
      'app_launch_sync',
      params: {
        'p_user_id': userId,
        'p_district_hex': districtHex,
      },
    );
    return result as Map<String, dynamic>;
  }

  /// Fetch user's run history from Supabase for local backfill.
  /// Returns runs ordered by start_time ASC.
  Future<List<Map<String, dynamic>>> fetchRunHistory(String userId) async {
    final result = await client
        .from('run_history')
        .select()
        .eq('user_id', userId)
        .order('start_time', ascending: true);
    return List<Map<String, dynamic>>.from(result as List);
  }

  /// Get user's current buff multiplier based on team, performance, and city.
  Future<Map<String, dynamic>> getUserBuff(
    String userId, {
    String? districtHex,
  }) async {
    final result = await client.rpc(
      'get_user_buff',
      params: {
        'p_user_id': userId,
        'p_district_hex': districtHex,
      },
    );
    return result as Map<String, dynamic>? ??
        {
          'multiplier': 1,
          'base_buff': 1,
          'all_range_bonus': 0,
          'reason': 'Default',
        };
  }

  Future<Map<String, dynamic>> getUserYesterdayStats(
    String userId, {
    String? date,
  }) async {
    final params = <String, dynamic>{'p_user_id': userId};
    if (date != null) params['p_date'] = date;
    final result = await client.rpc(
      'get_user_yesterday_stats',
      params: params,
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

  Future<Map<String, dynamic>> getHexDominance({String? parentHex}) async {
    final result = await client.rpc(
      'get_hex_dominance',
      params: {'p_parent_hex': parentHex},
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

  /// Get hex snapshot for a given parent hex and date.
  ///
  /// Downloads the daily snapshot (frozen at midnight GMT+2).
  /// Returns list of {hex_id, last_runner_team, last_run_end_time}.
  /// Update user's home location (home_hex + district_hex).
  ///
  /// Called from Profile screen when user changes location via GPS.
  Future<Map<String, dynamic>> updateHomeLocation(
    String userId,
    String homeHex,
    String districtHex,
  ) async {
    final result = await client.rpc(
      'update_home_location',
      params: {
        'p_user_id': userId,
        'p_home_hex': homeHex,
        'p_district_hex': districtHex,
      },
    );
    return result as Map<String, dynamic>;
  }

  /// Update user's team to purple (irreversible defection).
  Future<void> updateUserTeam(String userId, String team) async {
    await client.from('users').update({'team': team}).eq('id', userId);
  }

  Future<List<Map<String, dynamic>>> getHexSnapshot(
    String parentHex, {
    String? snapshotDate,
  }) async {
    final params = <String, dynamic>{'p_parent_hex': parentHex};
    if (snapshotDate != null) {
      params['p_snapshot_date'] = snapshotDate;
    }

    final result = await client.rpc('get_hex_snapshot', params: params);
    return List<Map<String, dynamic>>.from(result as List? ?? []);
  }
}
