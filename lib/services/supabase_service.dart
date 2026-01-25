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

  // ---------------------------------------------------------------------------
  // CREW OPERATIONS
  // ---------------------------------------------------------------------------

  /// Fetch all crews for a specific team that can accept new members
  Future<List<Map<String, dynamic>>> fetchCrewsByTeam(String team) async {
    final result = await client
        .from('crews')
        .select('id, name, team, member_ids, pin, representative_image')
        .eq('team', team)
        .order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  /// Get a specific crew by ID
  Future<Map<String, dynamic>?> getCrewById(String crewId) async {
    final result = await client
        .from('crews')
        .select('id, name, team, member_ids, pin, representative_image')
        .eq('id', crewId)
        .maybeSingle();
    return result;
  }

  /// Create a new crew
  ///
  /// Returns the created crew data with generated ID.
  Future<Map<String, dynamic>> createCrew({
    required String name,
    required String team,
    required String userId,
    String? pin,
    String? representativeImage,
  }) async {
    // Insert crew with user as first member (leader)
    final crewResult = await client
        .from('crews')
        .insert({
          'name': name,
          'team': team,
          'member_ids': [userId],
          'pin': pin,
          'representative_image': representativeImage,
        })
        .select()
        .single();

    // Update user's crew_id
    await client
        .from('users')
        .update({'crew_id': crewResult['id']})
        .eq('id', userId);

    return crewResult;
  }

  /// Join an existing crew
  ///
  /// Returns the updated crew data, or throws if PIN is incorrect or crew is full.
  Future<Map<String, dynamic>> joinCrew({
    required String crewId,
    required String userId,
    String? pin,
  }) async {
    // First, get the crew to verify PIN and capacity
    final crew = await getCrewById(crewId);
    if (crew == null) {
      throw Exception('Crew not found');
    }

    // Verify PIN if crew has one
    final crewPin = crew['pin'] as String?;
    if (crewPin != null && crewPin.isNotEmpty) {
      if (pin == null || pin != crewPin) {
        throw Exception('Invalid PIN');
      }
    }

    // Check capacity
    final memberIds = List<String>.from(crew['member_ids'] as List? ?? []);
    final team = crew['team'] as String;
    final maxMembers = team == 'purple' ? 24 : 12;
    if (memberIds.length >= maxMembers) {
      throw Exception('Crew is full');
    }

    // Check if already a member
    if (memberIds.contains(userId)) {
      throw Exception('Already a member of this crew');
    }

    // Add user to crew's member_ids array
    memberIds.add(userId);
    await client
        .from('crews')
        .update({'member_ids': memberIds})
        .eq('id', crewId);

    // Update user's crew_id
    await client.from('users').update({'crew_id': crewId}).eq('id', userId);

    // Return updated crew
    return (await getCrewById(crewId))!;
  }

  /// Leave a crew
  ///
  /// If user is the only member, the crew is deleted.
  /// If user is the leader (member_ids[0]), leadership transfers to next member.
  Future<void> leaveCrew({
    required String crewId,
    required String userId,
  }) async {
    final crew = await getCrewById(crewId);
    if (crew == null) {
      throw Exception('Crew not found');
    }

    final memberIds = List<String>.from(crew['member_ids'] as List? ?? []);
    if (!memberIds.contains(userId)) {
      throw Exception('Not a member of this crew');
    }

    // Remove user from member_ids
    memberIds.remove(userId);

    if (memberIds.isEmpty) {
      // Last member leaving - delete the crew
      await client.from('crews').delete().eq('id', crewId);
    } else {
      // Update crew with remaining members
      await client
          .from('crews')
          .update({'member_ids': memberIds})
          .eq('id', crewId);
    }

    // Clear user's crew_id
    await client.from('users').update({'crew_id': null}).eq('id', userId);
  }

  /// Fetch crew members with their details
  Future<List<Map<String, dynamic>>> fetchCrewMembers(String crewId) async {
    final crew = await getCrewById(crewId);
    if (crew == null) return [];

    final memberIds = List<String>.from(crew['member_ids'] as List? ?? []);
    if (memberIds.isEmpty) return [];

    // Fetch user details for all members
    final result = await client
        .from('users')
        .select('id, name, avatar, team, season_points')
        .inFilter('id', memberIds);

    // Sort by member order (leader first) and include running status
    final members = List<Map<String, dynamic>>.from(result);

    // Get active runs to determine who is running
    final activeRuns = await client
        .from('active_runs')
        .select('user_id')
        .eq('crew_id', crewId);
    final runningUserIds = (activeRuns as List)
        .map((r) => r['user_id'] as String)
        .toSet();

    // Add running status and sort by original member order
    for (final member in members) {
      member['is_running'] = runningUserIds.contains(member['id']);
    }

    // Sort to match memberIds order (leader first)
    members.sort((a, b) {
      final aIndex = memberIds.indexOf(a['id'] as String);
      final bIndex = memberIds.indexOf(b['id'] as String);
      return aIndex.compareTo(bIndex);
    });

    return members;
  }
}
