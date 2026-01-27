import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/crew_provider.dart';
import '../providers/app_state_provider.dart';
import '../models/sponsor.dart';
import '../models/crew_model.dart';
import '../widgets/sponsor_selector.dart';
import '../widgets/sponsor_logo_painter.dart';
import '../widgets/crew_avatar.dart';

/// Crew Screen - Redesigned "Premium Athletic Minimal"
///
/// Features:
/// - Glassmorphic Bento-style Hero Card
/// - Minimal 4-column member grid
/// - Staggered entrance animations
/// - Pulsing active runner indicators
class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _entranceController.forward();
    });
  }

  void _loadData() {
    final user = context.read<AppStateProvider>().currentUser;
    if (user != null) {
      final crewProvider = context.read<CrewProvider>();
      if (crewProvider.myCrew == null && user.crewId != null) {
        crewProvider.loadMockData(user.team, hasCrew: true);
      } else if (crewProvider.myCrew == null) {
        crewProvider.fetchAvailableCrews(user.team);
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CrewProvider>(
      builder: (context, crewProvider, child) {
        if (crewProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundStart,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            actions: [
              if (crewProvider.hasCrew)
                IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white70,
                  ),
                  onPressed: () => _showCrewSettings(context),
                ),
            ],
          ),
          body: Stack(
            children: [
              // Background Elements (Subtle gradients/noise could go here)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.backgroundStart,
                        const Color(0xFF0A0E17),
                      ],
                    ),
                  ),
                ),
              ),

              // Main Content
              SafeArea(
                child: crewProvider.hasCrew
                    ? _buildCrewDashboard(crewProvider)
                    : _buildNoCrewView(crewProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CREW DASHBOARD
  // ---------------------------------------------------------------------------

  Widget _buildCrewDashboard(CrewProvider crewProvider) {
    final crew = crewProvider.myCrew!;
    final members = List<CrewMemberInfo>.from(crewProvider.myCrewMembers);
    final teamColor = crew.team.color;
    final yesterdayRunners = members.where((m) => m.ranYesterday).length;
    final totalFlips = members.fold(0, (sum, m) => sum + m.flipCount);
    final totalDistanceKm = members.length * 12.4; // Mock data
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // 1. Hero Bento Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _AnimatedEntrance(
              controller: _entranceController,
              delay: 0.0,
              child: _buildHeroBentoCard(
                crew,
                teamColor,
                totalFlips,
                totalDistanceKm,
                yesterdayRunners,
                isLandscape,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),

        // 2. Members Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _AnimatedEntrance(
              controller: _entranceController,
              delay: 0.2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ROSTER',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 2.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '${members.length}/${crew.maxMembers}',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // 3. Members Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLandscape ? 7 : 4,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              // Stagger grid items
              final double stagger = 0.3 + (index * 0.05).clamp(0.0, 0.5);
              return _AnimatedEntrance(
                controller: _entranceController,
                delay: stagger,
                child: _buildMemberGridItem(members[index], index, teamColor),
              );
            }, childCount: members.length),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildHeroBentoCard(
    dynamic crew,
    Color teamColor,
    int totalFlips,
    double totalDistance,
    int yesterdayRunners,
    bool isLandscape,
  ) {
    if (isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Name & Avatar
          Expanded(
            flex: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _GlassCard(
                    height: 160,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: teamColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: teamColor.withValues(alpha: 0.3),
                            ),
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
                        Text(
                          crew.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bebasNeue(
                            fontSize: 36,
                            height: 0.9,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _GlassCard(
                    height: 160,
                    color: teamColor.withValues(alpha: 0.1),
                    borderColor: teamColor.withValues(alpha: 0.3),
                    child: Center(
                      child: CrewAvatar.fromCrew(
                        crew as CrewModel,
                        size: 80,
                        showBorder: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: Stats & Multiplier
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _GlassCard(
                        height: 74,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'FLIPS',
                              style: GoogleFonts.sora(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totalFlips.toString(),
                              style: GoogleFonts.sora(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GlassCard(
                        height: 74,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'DISTANCE',
                              style: GoogleFonts.sora(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    totalDistance.toStringAsFixed(1),
                                    style: GoogleFonts.sora(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'KM',
                                    style: GoogleFonts.sora(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  height: 74,
                  color: yesterdayRunners > 0
                      ? teamColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.02),
                  borderColor: yesterdayRunners > 0
                      ? teamColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (yesterdayRunners > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: teamColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: teamColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: teamColor,
                          ),
                        ),
                      Text(
                        yesterdayRunners > 0
                            ? '$yesterdayRunners RAN YESTERDAY'
                            : 'NO RUNNERS YESTERDAY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 20,
                          color: yesterdayRunners > 0
                              ? Colors.white
                              : Colors.white38,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (yesterdayRunners > 0) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 1,
                          height: 20,
                          color: Colors.white24,
                        ),
                        Text(
                          '${yesterdayRunners}X',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 28,
                            color: teamColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Top Section: Name & Icon
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _GlassCard(
                height: 160,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: teamColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: teamColor.withValues(alpha: 0.3),
                        ),
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
                    Text(
                      crew.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 36,
                        height: 0.9,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _GlassCard(
                height: 160,
                color: teamColor.withValues(alpha: 0.1),
                borderColor: teamColor.withValues(alpha: 0.3),
                child: Center(
                  child: CrewAvatar.fromCrew(
                    crew as CrewModel,
                    size: 100,
                    showBorder: false,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Middle Section: Stats
        Row(
          children: [
            Expanded(
              child: _GlassCard(
                height: 100,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'FLIPS',
                      style: GoogleFonts.sora(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalFlips.toString(),
                      style: GoogleFonts.sora(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassCard(
                height: 100,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'DISTANCE',
                      style: GoogleFonts.sora(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          totalDistance.toStringAsFixed(1),
                          style: GoogleFonts.sora(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'KM',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Bottom Section: Multiplier (Hero)
        _GlassCard(
          height: 80,
          color: yesterdayRunners > 0
              ? teamColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.02),
          borderColor: yesterdayRunners > 0
              ? teamColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (yesterdayRunners > 0)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: teamColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: teamColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: teamColor,
                  ),
                ),
              Text(
                yesterdayRunners > 0
                    ? '$yesterdayRunners RAN YESTERDAY'
                    : 'NO RUNNERS YESTERDAY',
                style: GoogleFonts.bebasNeue(
                  fontSize: 24,
                  color: yesterdayRunners > 0 ? Colors.white : Colors.white38,
                  letterSpacing: 2.0,
                ),
              ),
              if (yesterdayRunners > 0) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: 1,
                  height: 24,
                  color: Colors.white24,
                ),
                Text(
                  '${yesterdayRunners}X',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 32,
                    color: teamColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberGridItem(
    CrewMemberInfo member,
    int index,
    Color teamColor,
  ) {
    final isLeader = index == 0;

    return Column(
      children: [
        // Avatar
        Stack(
          alignment: Alignment.center,
          children: [
            // Avatar Circle
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
                border: isLeader
                    ? Border.all(
                        color: const Color(0xFFFFD700),
                        width: 2,
                      ) // Gold ring
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                boxShadow: member.ranYesterday
                    ? [
                        BoxShadow(
                          color: teamColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
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

            // Leader Crown (Subtle)
            if (isLeader)
              Positioned(
                top: -4,
                child: Icon(
                  Icons.star,
                  size: 14,
                  color: const Color(0xFFFFD700),
                ),
              ),

            // Ran Yesterday Checkmark Badge
            if (member.ranYesterday)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.backgroundStart,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Name
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),

        // Status
        const SizedBox(height: 2),
        Text(
          member.ranYesterday ? 'RAN YESTERDAY' : '${member.flipCount} FLIPS',
          style: GoogleFonts.bebasNeue(
            fontSize: 12,
            color: member.ranYesterday
                ? teamColor
                : Colors.white.withValues(alpha: 0.4),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // NO CREW VIEW
  // ---------------------------------------------------------------------------

  Widget _buildNoCrewView(CrewProvider crewProvider) {
    final user = context.watch<AppStateProvider>().currentUser;
    final teamColor = user?.team.color ?? AppTheme.electricBlue;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AnimatedEntrance(
                controller: _entranceController,
                delay: 0.0,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        teamColor.withValues(alpha: 0.2),
                        teamColor.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(color: teamColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.groups_rounded, size: 56, color: teamColor),
                ),
              ),

              const SizedBox(height: 40),

              _AnimatedEntrance(
                controller: _entranceController,
                delay: 0.1,
                child: Text(
                  'RUN TOGETHER',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 48,
                    color: Colors.white,
                    letterSpacing: 2.0,
                    height: 0.9,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _AnimatedEntrance(
                controller: _entranceController,
                delay: 0.2,
                child: Text(
                  'Join forces. Multiply points.\nDominate the map together.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Buttons
              _AnimatedEntrance(
                controller: _entranceController,
                delay: 0.3,
                child: Row(
                  children: [
                    Expanded(
                      child: _GlassButton(
                        label: 'CREATE',
                        color: teamColor,
                        isOutlined: true,
                        onTap: () =>
                            _showCreateCrewDialog(context, crewProvider),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _GlassButton(
                        label: 'JOIN',
                        color: teamColor,
                        isOutlined: false,
                        onTap: () => _showJoinCrewSheet(context, crewProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

    // State for selected sponsor
    Sponsor? selectedSponsor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: Text(
              'CREATE CREW',
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 28,
                letterSpacing: 1.5,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.sora(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'CREW NAME',
                      labelStyle: GoogleFonts.bebasNeue(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: teamColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      labelText: 'PIN (OPTIONAL)',
                      labelStyle: GoogleFonts.bebasNeue(color: Colors.white54),
                      counterText: '',
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: teamColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sponsor Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SPONSOR',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white54,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (selectedSponsor == null)
                    _GlassButton(
                      label: 'SELECT SPONSOR',
                      color: teamColor,
                      isOutlined: true,
                      onTap: () async {
                        final result = await showModalBottomSheet<Sponsor>(
                          context: context,
                          backgroundColor: AppTheme.backgroundStart,
                          isScrollControlled: true,
                          builder: (c) => SizedBox(
                            height: MediaQuery.of(c).size.height * 0.7,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'SELECT SPONSOR',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SponsorSelector(
                                    onSelected: (s) => Navigator.pop(c, s),
                                    selectedSponsorId: selectedSponsor?.id,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() => selectedSponsor = result);
                        }
                      },
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        final result = await showModalBottomSheet<Sponsor>(
                          context: context,
                          backgroundColor: AppTheme.backgroundStart,
                          isScrollControlled: true,
                          builder: (c) => SizedBox(
                            height: MediaQuery.of(c).size.height * 0.7,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'SELECT SPONSOR',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SponsorSelector(
                                    onSelected: (s) => Navigator.pop(c, s),
                                    selectedSponsorId: selectedSponsor?.id,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (result != null) {
                          setState(() => selectedSponsor = result);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedSponsor!.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedSponsor!.primaryColor.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CustomPaint(
                                painter: SponsorLogoPainter(
                                  sponsor: selectedSponsor!,
                                  isSelected: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedSponsor!.name,
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    selectedSponsor!.tagline,
                                    style: GoogleFonts.sora(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.refresh,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white54,
                    fontSize: 18,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && user != null) {
                    final success = await provider.createCrew(
                      name: nameController.text,
                      team: user.team.name,
                      user: user,
                      pin: pinController.text.isEmpty
                          ? null
                          : pinController.text,
                      sponsorId: selectedSponsor?.id,
                    );
                    if (success && provider.myCrew != null && ctx.mounted) {
                      context.read<AppStateProvider>().updateCrewId(
                        provider.myCrew!.id,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: Text(
                  'CREATE',
                  style: GoogleFonts.bebasNeue(color: teamColor, fontSize: 18),
                ),
              ),
            ],
          );
        },
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
    final user = context.read<AppStateProvider>().currentUser;
    final provider = context.read<CrewProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red),
              ),
              title: Text(
                'LEAVE CREW',
                style: GoogleFonts.bebasNeue(
                  color: Colors.red,
                  fontSize: 20,
                  letterSpacing: 1.0,
                ),
              ),
              subtitle: Text(
                'You will lose your contribution stats.',
                style: GoogleFonts.sora(color: Colors.white54, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (user != null) {
                  final success = await provider.leaveCrew(user);
                  if (success && context.mounted) {
                    context.read<AppStateProvider>().updateCrewId(null);
                  }
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPER WIDGETS
// ---------------------------------------------------------------------------

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.height,
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppTheme.surfaceColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onTap;

  const _GlassButton({
    required this.label,
    required this.color,
    required this.isOutlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isOutlined
                  ? Colors.transparent
                  : color.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOutlined
                    ? color.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isOutlined ? color : Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;

  const _AnimatedEntrance({
    required this.controller,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animation = CurvedAnimation(
          parent: controller,
          curve: Interval(
            delay,
            (delay + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        );

        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// JOIN CREW SHEET (Refined)
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No open crews found.',
                  style: GoogleFonts.sora(color: Colors.white38),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: crews.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final crew = crews[index];
                  final hasPIN = crew.pin != null && crew.pin!.isNotEmpty;

                  return _GlassCard(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white.withValues(alpha: 0.03),
                    child: Row(
                      children: [
                        CrewAvatar.fromCrew(crew, size: 40, showBorder: true),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    crew.name,
                                    style: GoogleFonts.sora(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
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
                              Text(
                                '${crew.memberIds.length}/${crew.maxMembers} Members',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: crew.canAcceptMembers
                              ? () => _handleJoin(context, crew, user)
                              : null,
                          style: TextButton.styleFrom(
                            backgroundColor: crew.canAcceptMembers
                                ? teamColor.withValues(alpha: 0.1)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            crew.canAcceptMembers ? 'JOIN' : 'FULL',
                            style: GoogleFonts.bebasNeue(
                              color: crew.canAcceptMembers
                                  ? teamColor
                                  : Colors.white24,
                              fontSize: 16,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          if (_pendingJoinCrewId != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: teamColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: teamColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'ENTER PIN',
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 12.0,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: GoogleFonts.sora(
                        color: Colors.white12,
                        letterSpacing: 12.0,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_pinController.text.length == 4 && user != null) {
                          final success = await widget.provider.joinCrew(
                            crewId: _pendingJoinCrewId!,
                            user: user,
                            pin: _pinController.text,
                          );
                          if (success &&
                              widget.provider.myCrew != null &&
                              context.mounted) {
                            context.read<AppStateProvider>().updateCrewId(
                              widget.provider.myCrew!.id,
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teamColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'CONFIRM',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 18,
                          letterSpacing: 1.0,
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

  Future<void> _handleJoin(
    BuildContext context,
    dynamic crew,
    dynamic user,
  ) async {
    if (crew.pin != null && crew.pin!.isNotEmpty) {
      setState(() {
        _pendingJoinCrewId = crew.id;
        _pinController.clear();
      });
    } else {
      if (user != null) {
        final success = await widget.provider.joinCrew(
          crewId: crew.id,
          user: user,
        );
        if (success && widget.provider.myCrew != null && context.mounted) {
          context.read<AppStateProvider>().updateCrewId(
            widget.provider.myCrew!.id,
          );
        }
        if (context.mounted) Navigator.pop(context);
      }
    }
  }
}
