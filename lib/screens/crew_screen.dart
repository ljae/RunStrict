import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/crew_provider.dart';
import '../providers/app_state_provider.dart';

/// Crew Screen - Crew management per DEVELOPMENT_SPEC §3.2.7
///
/// Features:
/// - Create Crew (Name + optional 4-digit PIN)
/// - Join Crew (Search/browse + PIN entry)
/// - Member Display (Avatar grid layout)
/// - Per Member: Avatar + running status indicator
/// - Crew Stats: Total flips, total distance, active runners count
/// - Crew Image: Auto-generated on creation
class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppStateProvider>().currentUser;
      if (user != null) {
        if (context.read<CrewProvider>().myCrew == null &&
            user.crewId != null) {
          context.read<CrewProvider>().loadMockData(user.team, hasCrew: true);
        } else if (context.read<CrewProvider>().myCrew == null) {
          context.read<CrewProvider>().fetchAvailableCrews(user.team);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CrewProvider>(
      builder: (context, crewProvider, child) {
        if (crewProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: crewProvider.hasCrew
                  ? _buildCrewDashboard(crewProvider)
                  : _buildNoCrewView(crewProvider),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CREW DASHBOARD (When user has a crew)
  // ---------------------------------------------------------------------------

  Widget _buildCrewDashboard(CrewProvider crewProvider) {
    final crew = crewProvider.myCrew!;
    final members = List<CrewMemberInfo>.from(crewProvider.myCrewMembers);
    final teamColor = crew.team.color;
    final activeRunners = members.where((m) => m.isRunning).length;
    final totalFlips = members.fold(0, (sum, m) => sum + m.flipCount);
    // Mock total distance - in production calculated from daily_stats
    final totalDistanceKm = members.length * 12.4;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(crew.name, teamColor)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Crew Image + Stats Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildCrewCard(
              crew,
              teamColor,
              totalFlips: totalFlips,
              totalDistanceKm: totalDistanceKm,
              activeRunners: activeRunners,
              memberCount: members.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Stats Row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStatsRow(
              teamColor,
              totalFlips: totalFlips,
              totalDistanceKm: totalDistanceKm,
              activeRunners: activeRunners,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Members Section Title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'MEMBERS',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: Colors.white70,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: teamColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: teamColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    '${members.length}/${crew.maxMembers}',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: teamColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Avatar Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: members.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyState('No members yet'))
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildMemberGridItem(members[index], index, teamColor),
                    childCount: members.length,
                  ),
                ),
        ),

        // Bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildHeader(String title, Color teamColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.bebasNeue(
                fontSize: 28,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _showCrewSettings(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewCard(
    dynamic crew,
    Color teamColor, {
    required int totalFlips,
    required double totalDistanceKm,
    required int activeRunners,
    required int memberCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: teamColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: teamColor.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Crew Representative Image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: teamColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: teamColor.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Icon(Icons.groups_rounded, color: teamColor, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          // Crew Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: teamColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        crew.team.displayName,
                        style: GoogleFonts.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: teamColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (activeRunners > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$activeRunners running',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalFlips FLIPS',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${totalDistanceKm.toStringAsFixed(1)} km total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    Color teamColor, {
    required int totalFlips,
    required double totalDistanceKm,
    required int activeRunners,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            icon: Icons.flash_on_rounded,
            value: '$totalFlips',
            label: 'FLIPS',
            color: teamColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatChip(
            icon: Icons.straighten_rounded,
            value: totalDistanceKm.toStringAsFixed(0),
            label: 'KM',
            color: teamColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatChip(
            icon: Icons.directions_run_rounded,
            value: '$activeRunners',
            label: 'ACTIVE',
            color: activeRunners > 0 ? Colors.greenAccent : teamColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberGridItem(
    CrewMemberInfo member,
    int index,
    Color teamColor,
  ) {
    final isLeader = index == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with active indicator
        Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: teamColor.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: member.isRunning
                      ? Colors.greenAccent.withOpacity(0.8)
                      : teamColor.withOpacity(isLeader ? 0.5 : 0.2),
                  width: member.isRunning ? 2.5 : 1.5,
                ),
                boxShadow: member.isRunning
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  member.avatar,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            // Running indicator dot
            if (member.isRunning)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.backgroundStart,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    size: 8,
                    color: Colors.black87,
                  ),
                ),
              ),
            // Leader crown
            if (isLeader)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.backgroundStart,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 9)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Name
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        // Flip count
        Text(
          '${member.flipCount}',
          style: GoogleFonts.sora(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: teamColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // NO CREW VIEW (Join or Create)
  // ---------------------------------------------------------------------------

  Widget _buildNoCrewView(CrewProvider crewProvider) {
    final user = context.watch<AppStateProvider>().currentUser;
    final teamColor = user?.team.color ?? AppTheme.electricBlue;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: teamColor.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: teamColor.withOpacity(0.2), width: 2),
            ),
            child: Icon(Icons.groups_outlined, size: 48, color: teamColor),
          ),
          const SizedBox(height: 24),
          Text(
            'NO CREW ASSIGNED',
            style: GoogleFonts.bebasNeue(
              fontSize: 32,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Join forces with other runners.\nMore crew members running = higher multiplier.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Join Existing
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showJoinCrewSheet(context, crewProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: teamColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'JOIN EXISTING CREW',
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Create New
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showCreateCrewDialog(context, crewProvider),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: teamColor.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'CREATE NEW CREW',
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.5,
                  color: teamColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIALOGS & SHEETS
  // ---------------------------------------------------------------------------

  void _showCreateCrewDialog(BuildContext context, CrewProvider provider) {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    final user = context.read<AppStateProvider>().currentUser;
    final teamColor = user?.team.color ?? AppTheme.electricBlue;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Text(
          'CREATE CREW',
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            fontSize: 24,
            letterSpacing: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Crew Name
            Text(
              'Crew Name',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Enter crew name',
                hintStyle: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.25),
                ),
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: teamColor.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Optional PIN
            Row(
              children: [
                Text(
                  'PIN (optional)',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinController,
              style: GoogleFonts.sora(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 8.0,
              ),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: GoogleFonts.sora(
                  color: Colors.white.withOpacity(0.15),
                  fontSize: 18,
                  letterSpacing: 8.0,
                ),
                counterText: '',
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: teamColor.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Leave blank for open crew. PIN restricts who can join.',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && user != null) {
                provider.createCrew(nameController.text, user.team, user);
                Navigator.pop(ctx);
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: teamColor.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Create',
              style: GoogleFonts.inter(
                color: teamColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinCrewSheet(BuildContext context, CrewProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _JoinCrewSheet(provider: provider),
    );
  }

  void _showCrewSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: Text(
                'Leave Crew',
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                // In production: provider.leaveCrew(user)
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Text(message, style: GoogleFonts.inter(color: Colors.white30)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// JOIN CREW BOTTOM SHEET (with PIN entry support)
// ---------------------------------------------------------------------------

class _JoinCrewSheet extends StatefulWidget {
  final CrewProvider provider;

  const _JoinCrewSheet({required this.provider});

  @override
  State<_JoinCrewSheet> createState() => _JoinCrewSheetState();
}

class _JoinCrewSheetState extends State<_JoinCrewSheet> {
  String? _pendingJoinCrewId;
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crews = widget.provider.availableCrews;
    final user = context.read<AppStateProvider>().currentUser;
    final teamColor = user?.team.color ?? AppTheme.electricBlue;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'AVAILABLE CREWS',
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          if (crews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No open crews found.',
                  style: GoogleFonts.inter(color: Colors.white54),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: crews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final crew = crews[index];
                  final hasPIN = crew.pin != null && crew.pin!.isNotEmpty;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        // Crew icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: teamColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: teamColor.withOpacity(0.2),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.groups_rounded,
                              color: teamColor,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      crew.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (hasPIN) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.lock_outline,
                                      size: 12,
                                      color: Colors.white38,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${crew.memberIds.length}/${crew.maxMembers} Members',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Join button
                        ElevatedButton(
                          onPressed: crew.canAcceptMembers
                              ? () => _handleJoin(context, crew, user)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: teamColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            crew.canAcceptMembers ? 'JOIN' : 'FULL',
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // PIN Entry (if pending)
          if (_pendingJoinCrewId != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: teamColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: teamColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter PIN to join',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 10.0,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: GoogleFonts.sora(
                        color: Colors.white.withOpacity(0.15),
                        letterSpacing: 10.0,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_pinController.text.length == 4 && user != null) {
                          widget.provider.joinCrew(_pendingJoinCrewId!, user);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teamColor,
                      ),
                      child: Text(
                        'CONFIRM',
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  void _handleJoin(BuildContext context, dynamic crew, dynamic user) {
    if (crew.pin != null && crew.pin!.isNotEmpty) {
      // Show PIN entry
      setState(() {
        _pendingJoinCrewId = crew.id;
        _pinController.clear();
      });
    } else {
      // Direct join
      if (user != null) {
        widget.provider.joinCrew(crew.id, user);
        Navigator.pop(context);
      }
    }
  }
}
