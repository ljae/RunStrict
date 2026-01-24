import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../models/team.dart';
import '../services/season_service.dart';
import '../widgets/stat_card.dart';

/// Profile screen displaying user manifesto, avatar, team, and season stats.
///
/// Per spec §3.2.8: Manifesto (12-char max), avatar, team display, season stats.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final SeasonService _seasonService;
  late final TextEditingController _manifestoController;
  bool _isEditingManifesto = false;

  @override
  void initState() {
    super.initState();
    _seasonService = SeasonService();
    final user = context.read<AppStateProvider>().currentUser;
    _manifestoController = TextEditingController(text: user?.manifesto ?? '');
  }

  @override
  void dispose() {
    _manifestoController.dispose();
    super.dispose();
  }

  Color _teamColor(Team team) {
    switch (team) {
      case Team.red:
        return AppTheme.athleticRed;
      case Team.blue:
        return AppTheme.electricBlue;
      case Team.purple:
        return AppTheme.chaosPurple;
    }
  }

  String _teamName(Team team) {
    switch (team) {
      case Team.red:
        return 'FLAME';
      case Team.blue:
        return 'WAVE';
      case Team.purple:
        return 'CHAOS';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final user = appState.currentUser;
        if (user == null) {
          return const Center(
            child: Text(
              'No user data',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        final teamColor = _teamColor(user.team);

        return Scaffold(
          backgroundColor: AppTheme.backgroundStart,
          appBar: AppBar(
            title: Text(
              'PROFILE',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                _AvatarSection(avatar: user.avatar, teamColor: teamColor),
                const SizedBox(height: AppTheme.spacingL),
                _TeamBadge(
                  team: user.team,
                  teamColor: teamColor,
                  teamName: _teamName(user.team),
                ),
                const SizedBox(height: AppTheme.spacingL),
                _ManifestoSection(
                  manifesto: user.manifesto,
                  isEditing: _isEditingManifesto,
                  controller: _manifestoController,
                  onToggleEdit: () {
                    setState(() {
                      _isEditingManifesto = !_isEditingManifesto;
                    });
                  },
                  onSave: () {
                    final text = _manifestoController.text.trim();
                    if (text.length <= 12) {
                      appState.setUser(user.copyWith(manifesto: text));
                      setState(() {
                        _isEditingManifesto = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppTheme.spacingXL),
                _SeasonStatsSection(
                  seasonPoints: user.seasonPoints,
                  seasonService: _seasonService,
                  teamColor: teamColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Displays the user's avatar emoji in a team-colored circle.
class _AvatarSection extends StatelessWidget {
  final String avatar;
  final Color teamColor;

  const _AvatarSection({required this.avatar, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: teamColor.withOpacity(0.15),
        border: Border.all(color: teamColor, width: 3),
      ),
      child: Center(child: Text(avatar, style: const TextStyle(fontSize: 48))),
    );
  }
}

/// Team name badge below the avatar.
class _TeamBadge extends StatelessWidget {
  final Team team;
  final Color teamColor;
  final String teamName;

  const _TeamBadge({
    required this.team,
    required this.teamColor,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: teamColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teamColor.withOpacity(0.4)),
      ),
      child: Text(
        teamName,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: teamColor,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

/// Manifesto display/edit section (12-char max).
class _ManifestoSection extends StatelessWidget {
  final String? manifesto;
  final bool isEditing;
  final TextEditingController controller;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;

  const _ManifestoSection({
    required this.manifesto,
    required this.isEditing,
    required this.controller,
    required this.onToggleEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: AppTheme.meshDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MANIFESTO',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
              ),
              GestureDetector(
                onTap: isEditing ? onSave : onToggleEdit,
                child: Icon(
                  isEditing ? Icons.check : Icons.edit_outlined,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          if (isEditing)
            TextField(
              controller: controller,
              maxLength: 12,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                counterStyle: TextStyle(color: AppTheme.textMuted),
                hintText: 'Your creed...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (_) => onSave(),
            )
          else
            Text(
              manifesto?.isNotEmpty == true ? manifesto! : 'Tap to set...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: manifesto?.isNotEmpty == true
                    ? AppTheme.textPrimary
                    : AppTheme.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Season stats section showing points, day, and progress.
class _SeasonStatsSection extends StatelessWidget {
  final int seasonPoints;
  final SeasonService seasonService;
  final Color teamColor;

  const _SeasonStatsSection({
    required this.seasonPoints,
    required this.seasonService,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEASON STATS',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'FLIP POINTS',
                value: '$seasonPoints',
                icon: Icons.bolt,
                color: teamColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: StatCard(
                label: 'SEASON DAY',
                value: '${seasonService.currentSeasonDay}',
                icon: Icons.calendar_today,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'D-DAY',
                value: seasonService.displayString,
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: StatCard(
                label: 'PROGRESS',
                value:
                    '${(seasonService.seasonProgress * 100).toStringAsFixed(0)}%',
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
