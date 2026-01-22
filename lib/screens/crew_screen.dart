import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/crew_provider.dart';
import '../providers/app_state_provider.dart';
import '../models/team.dart';
import '../models/crew_model.dart';

/// Mock stats for crew display
/// In production, these would be calculated from runs/ and dailyStats/
class _CrewDisplayStats {
  final double weeklyDistance;
  final int hexesClaimed;
  final int wins;
  final int losses;

  const _CrewDisplayStats({
    this.weeklyDistance = 0,
    this.hexesClaimed = 0,
    this.wins = 0,
    this.losses = 0,
  });

  /// Generate mock stats based on crew ID hash for consistent display
  factory _CrewDisplayStats.mockFor(String crewId, {bool isRival = false}) {
    final hash = crewId.hashCode.abs();
    return _CrewDisplayStats(
      weeklyDistance: 50.0 + (hash % 100) + (isRival ? 5 : 0),
      hexesClaimed: 5 + (hash % 20),
      wins: isRival ? 5 : 4,
      losses: isRival ? 4 : 5,
    );
  }
}

class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  // Removed _selectedIndex as tabs are gone

  @override
  void initState() {
    super.initState();
    // Load crew data if not loaded
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
                  ? _buildDashboard(crewProvider)
                  : _buildNoCrewView(crewProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboard(CrewProvider crewProvider) {
    return Column(
      children: [
        _buildHeader(crewProvider.myCrew?.name ?? 'CREW'),
        const SizedBox(height: 16),
        // Removed _buildTabToggle
        Expanded(
          child: _buildMyCrewView(crewProvider),
        ),
      ],
    );
  }

  // ... (keep _buildNoCrewView and helper methods same as before, they are fine)
  Widget _buildNoCrewView(CrewProvider crewProvider) {
    final user = context.watch<AppStateProvider>().currentUser;
    final teamColor = user?.team == Team.red
        ? AppTheme.athleticRed
        : AppTheme.electricBlue;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 80, color: teamColor),
          const SizedBox(height: 24),
          Text(
            'NO CREW ASSIGNED',
            style: GoogleFonts.bebasNeue(
              fontSize: 32,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Join forces with other runners to dominate territory and unlock special rewards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 16,
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'JOIN EXISTING CREW',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Create New
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showCreateCrewDialog(context, crewProvider),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'CREATE NEW CREW',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
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
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _JoinCrewSheet(provider: provider),
    );
  }

  void _showCreateCrewDialog(BuildContext context, CrewProvider provider) {
    final controller = TextEditingController();
    final user = context.read<AppStateProvider>().currentUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Create Crew',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter crew name',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty && user != null) {
                provider.createCrew(controller.text, user.team, user);
                Navigator.pop(ctx);
              }
            },
            child: Text(
              'Create',
              style: TextStyle(color: AppTheme.electricBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTheme.themeData.textTheme.headlineMedium?.copyWith(
                letterSpacing: 1.2,
                color: Colors.white,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.settings, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCrewView(CrewProvider provider) {
    final crew = provider.myCrew!;
    final members = List<CrewMember>.from(provider.myCrewMembers);
    
    // Sort logic handled in provider but ensure consistency here
    // Already sorted by flip count (descENDING)

    // Calculate Economies
    final totalFlips = members.fold(0, (sum, m) => sum + m.flipCount);
    final top4 = members.take(4).toList();
    final others = members.skip(4).toList();
    
    // Each winner gets: (Total / 4) * Multiplier
    final pointsPerWinner = top4.isEmpty ? 0 : (totalFlips / 4 * crew.multiplier).floor();

    final primaryColor = crew.team == Team.blue 
        ? AppTheme.electricBlue 
        : AppTheme.athleticRed;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Total Pool Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.meshDecoration(
              color: primaryColor.withOpacity(0.1),
              isRed: crew.team == Team.red,
            ),
            child: Column(
              children: [
                Text(
                  'TOTAL FLIP POOL',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalFlips',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: primaryColor.withOpacity(0.5),
                        blurRadius: 20,
                      )
                    ]
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26, 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'WINNERS GET: $pointsPerWinner PTS', 
                        style: GoogleFonts.inter(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 2. The Winners (Top 4)
          Row(
            children: [
              Text(
                'WINNERS CIRCLE',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                'TOP 4',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.amber.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (top4.isEmpty)
             _buildEmptyState("No members yet")
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: top4.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                return _buildMemberTile(
                  top4[index], 
                  index + 1, 
                  primaryColor, 
                  isWinner: true,
                  prize: pointsPerWinner
                );
              },
            ),

          const SizedBox(height: 32),

          // 3. The Contributors (Rest)
          if (others.isNotEmpty) ...[
            Row(
            children: [
              Text(
                'CONTRIBUTORS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '0 PTS',
                 style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: others.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                return _buildMemberTile(
                  others[index], 
                  index + 5, // Rank starts at 5
                  Colors.white24, 
                  isWinner: false
                );
              },
            ),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMemberTile(CrewMember member, int rank, Color accentColor, {required bool isWinner, int? prize}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: isWinner 
          ? Border.all(color: accentColor.withOpacity(0.3))
          : Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: isWinner 
          ? [BoxShadow(color: accentColor.withOpacity(0.1), blurRadius: 8)] 
          : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: GoogleFonts.outfit(
                color: isWinner ? accentColor : Colors.white24,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Avatar
          Text(member.avatar, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: isWinner ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${member.distance.toStringAsFixed(1)} km',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          
          // Flips
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${member.flipCount} flips',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isWinner && prize != null)
                Text(
                  '+$prize pts',
                  style: GoogleFonts.inter(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white30),
        ),
      ),
    );
  }
}

class _JoinCrewSheet extends StatelessWidget {
  final CrewProvider provider;

  const _JoinCrewSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final crews = provider.availableCrews;
    final user = context.read<AppStateProvider>().currentUser;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AVAILABLE CREWS',
            style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.white),
          ),
          const SizedBox(height: 16),
          if (crews.isEmpty)
            const Center(
              child: Text(
                "No open crews found.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: crews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final crew = crews[index];
                  return ListTile(
                    tileColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      crew.name,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${crew.memberIds.length}/12 Members • Level ${(crew.memberIds.length ~/ 2) + 1}',
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        if (user != null) {
                          provider.joinCrew(crew.id, user);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('JOIN'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
