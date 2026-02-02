import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import '../services/season_service.dart';
import '../services/hex_service.dart';
import '../services/prefetch_service.dart';

/// Season Register Screen - Combined season info, location confirmation,
/// and team selection in a split Red/Blue layout.
class SeasonRegisterScreen extends StatefulWidget {
  const SeasonRegisterScreen({super.key});

  @override
  State<SeasonRegisterScreen> createState() => _SeasonRegisterScreenState();
}

class _SeasonRegisterScreenState extends State<SeasonRegisterScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Location info
  String? _territory;
  String? _district;

  @override
  void initState() {
    super.initState();

    // Entrance animations
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Pulse for icons
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _entranceController.forward();
    _loadLocationInfo();
  }

  void _loadLocationInfo() {
    final homeHex = PrefetchService().homeHex;
    if (homeHex != null) {
      setState(() {
        _territory = HexService().getTerritoryName(homeHex);
        _district = HexService().getCityDisplayName(homeHex);
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final season = SeasonService();

    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Season Header
                _buildSeasonHeader(season),
                const SizedBox(height: 8),

                // Location Badge
                _buildLocationBadge(),
                const SizedBox(height: 24),

                // Split Team Selection
                Expanded(child: _buildSplitTeamSelection(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonHeader(SeasonService season) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Season number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SEASON ${season.seasonNumber}',
                  style: AppTheme.themeData.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 16,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 12),
                Text(
                  season.displayString,
                  style: AppTheme.themeData.textTheme.titleMedium?.copyWith(
                    color: season.daysRemaining <= 7
                        ? AppTheme.athleticRed
                        : AppTheme.electricBlue,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBadge() {
    if (_territory == null || _district == null) {
      return const SizedBox(height: 24);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            '$_territory',
            style: AppTheme.themeData.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            ' \u00b7 $_district',
            style: AppTheme.themeData.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTeamSelection(BuildContext context) {
    return Row(
      children: [
        // Red Team Half - ELITE FOCUSED (Hierarchy)
        Expanded(
          child: _FlameTeamHalf(
            pulseController: _pulseController,
            onSelect: () => _handleTeamSelection(context, Team.red),
          ),
        ),

        // Divider
        Container(width: 1, color: Colors.white.withValues(alpha: 0.1)),

        // Blue Team Half - UNION FOCUSED (Equality)
        Expanded(
          child: _WaveTeamHalf(
            pulseController: _pulseController,
            onSelect: () => _handleTeamSelection(context, Team.blue),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTeamSelection(BuildContext context, Team team) async {
    final appState = context.read<AppStateProvider>();

    try {
      await appState.selectTeam(team, 'Runner');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join team: $e'),
            backgroundColor: AppTheme.athleticRed,
          ),
        );
      }
    }
  }
}

// -----------------------------------------------------------------------------
// FLAME Team Half - ELITE FOCUSED (Hierarchy/Meritocracy)
// -----------------------------------------------------------------------------

class _FlameTeamHalf extends StatelessWidget {
  final AnimationController pulseController;
  final VoidCallback onSelect;

  static const Color _color = AppTheme.athleticRed;

  const _FlameTeamHalf({required this.pulseController, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _color.withValues(alpha: 0.03),
            _color.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          children: [
            // === HEADER SECTION (Aligned with WAVE) ===
            const SizedBox(height: 16),
            _buildPulsingIcon(),
            const SizedBox(height: 10),
            Text(
              'FLAME',
              style: AppTheme.themeData.textTheme.headlineMedium?.copyWith(
                color: _color,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ELITE REWARDED',
              style: AppTheme.themeData.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.5,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiplierBars(4),
            const SizedBox(height: 4),
            Text(
              'UP TO 4x',
              style: AppTheme.themeData.textTheme.titleSmall?.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 20),

            // === BUFF SECTION ===
            // Column headers
            _buildColumnHeaders(),
            const SizedBox(height: 8),

            // Elite tier (highlighted)
            _buildBuffTier(
              label: 'Elite',
              sublabel: 'Top 20%',
              normal: '2x',
              distWin: '3x',
              provWin: '4x',
              isHighlight: true,
            ),

            const SizedBox(height: 6),

            // Common tier (subdued)
            _buildBuffTier(
              label: 'Common',
              sublabel: 'Bottom 80%',
              normal: '1x',
              distWin: '1x',
              provWin: '2x',
              isHighlight: false,
            ),

            const Spacer(),

            // Join Button
            _buildJoinButton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingIcon() {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 1.0 + (pulseController.value * 0.06);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: 0.15),
              border: Border.all(
                color: _color.withValues(
                  alpha: 0.4 + pulseController.value * 0.3,
                ),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: 0.25 * pulseController.value),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 32,
              color: _color,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultiplierBars(int max) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < max;
        return Container(
          width: 16,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? _color : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(3),
            border: isActive
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
        );
      }),
    );
  }

  Widget _buildColumnHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox()),
          _headerCell('Normal'),
          _headerCell('Dist.'),
          _headerCell('Prov.'),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTheme.themeData.textTheme.labelSmall?.copyWith(
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
          fontSize: 8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBuffTier({
    required String label,
    required String sublabel,
    required String normal,
    required String distWin,
    required String provWin,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight
            ? _color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? _color.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          width: isHighlight ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Tier label
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isHighlight) ...[
                      Icon(Icons.star_rounded, color: _color, size: 12),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      label,
                      style: AppTheme.themeData.textTheme.bodySmall?.copyWith(
                        color: isHighlight ? _color : AppTheme.textSecondary,
                        fontWeight: isHighlight
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  sublabel,
                  style: AppTheme.themeData.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          // Multipliers
          _multiplierValue(normal, isHighlight: isHighlight),
          _multiplierValue(distWin, isHighlight: isHighlight),
          _multiplierValue(
            provWin,
            isHighlight: isHighlight,
            isMax: provWin == '4x',
          ),
        ],
      ),
    );
  }

  Widget _multiplierValue(
    String value, {
    bool isHighlight = false,
    bool isMax = false,
  }) {
    return Expanded(
      flex: 3,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: AppTheme.themeData.textTheme.bodySmall?.copyWith(
          color: isMax
              ? _color
              : (isHighlight ? AppTheme.textPrimary : AppTheme.textSecondary),
          fontWeight: isMax
              ? FontWeight.bold
              : (isHighlight ? FontWeight.w600 : FontWeight.w400),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onSelect,
        style: ElevatedButton.styleFrom(
          backgroundColor: _color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          'JOIN',
          style: AppTheme.themeData.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WAVE Team Half - UNION FOCUSED (Solidarity/Equality)
// Visual: Unified single tier where everyone benefits equally
// -----------------------------------------------------------------------------

class _WaveTeamHalf extends StatelessWidget {
  final AnimationController pulseController;
  final VoidCallback onSelect;

  static const Color _color = AppTheme.electricBlue;

  const _WaveTeamHalf({required this.pulseController, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _color.withValues(alpha: 0.03),
            _color.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          children: [
            // === HEADER SECTION (Aligned with FLAME) ===
            const SizedBox(height: 16),
            _buildPulsingIcon(),
            const SizedBox(height: 10),
            Text(
              'WAVE',
              style: AppTheme.themeData.textTheme.headlineMedium?.copyWith(
                color: _color,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ALL FOR ONE',
              style: AppTheme.themeData.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.5,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 12),
            _buildMultiplierBars(3),
            const SizedBox(height: 4),
            Text(
              'UP TO 3x',
              style: AppTheme.themeData.textTheme.titleSmall?.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 20),

            // === BUFF SECTION ===
            // Column headers
            _buildColumnHeaders(),
            const SizedBox(height: 8),

            // Union tier (single unified tier - highlighted)
            _buildBuffTier(
              label: 'Union',
              sublabel: 'All Runners',
              normal: '1x',
              distWin: '2x',
              provWin: '3x',
              isHighlight: true,
            ),

            const SizedBox(height: 12),

            // Unity message
            _buildUnityMessage(),

            const Spacer(),

            // Join Button
            _buildJoinButton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingIcon() {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 1.0 + (pulseController.value * 0.06);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: 0.15),
              border: Border.all(
                color: _color.withValues(
                  alpha: 0.4 + pulseController.value * 0.3,
                ),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: 0.25 * pulseController.value),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.waves_rounded, size: 32, color: _color),
          ),
        );
      },
    );
  }

  Widget _buildMultiplierBars(int max) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < max;
        return Container(
          width: 16,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? _color : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(3),
            border: isActive
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
        );
      }),
    );
  }

  Widget _buildColumnHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox()),
          _headerCell('Normal'),
          _headerCell('Dist.'),
          _headerCell('Prov.'),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTheme.themeData.textTheme.labelSmall?.copyWith(
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
          fontSize: 8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBuffTier({
    required String label,
    required String sublabel,
    required String normal,
    required String distWin,
    required String provWin,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight
            ? _color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? _color.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          width: isHighlight ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Tier label
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isHighlight) ...[
                      Icon(Icons.link_rounded, color: _color, size: 12),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      label,
                      style: AppTheme.themeData.textTheme.bodySmall?.copyWith(
                        color: isHighlight ? _color : AppTheme.textSecondary,
                        fontWeight: isHighlight
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  sublabel,
                  style: AppTheme.themeData.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          // Multipliers
          _multiplierValue(normal, isHighlight: isHighlight),
          _multiplierValue(distWin, isHighlight: isHighlight),
          _multiplierValue(
            provWin,
            isHighlight: isHighlight,
            isMax: provWin == '3x',
          ),
        ],
      ),
    );
  }

  Widget _multiplierValue(
    String value, {
    bool isHighlight = false,
    bool isMax = false,
  }) {
    return Expanded(
      flex: 3,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: AppTheme.themeData.textTheme.bodySmall?.copyWith(
          color: isMax
              ? _color
              : (isHighlight ? AppTheme.textPrimary : AppTheme.textSecondary),
          fontWeight: isMax
              ? FontWeight.bold
              : (isHighlight ? FontWeight.w600 : FontWeight.w400),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildUnityMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Connected dots visual
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Same for all',
              style: AppTheme.themeData.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onSelect,
        style: ElevatedButton.styleFrom(
          backgroundColor: _color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          'JOIN',
          style: AppTheme.themeData.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
