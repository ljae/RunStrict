import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../models/team.dart';
import '../services/season_service.dart';
import '../models/user_model.dart';
import '../utils/country_utils.dart';
import '../services/voice_announcement_service.dart';
import 'traitor_gate_screen.dart';

/// Profile screen displaying user manifesto, avatar, team, and season stats.
///
/// Redesigned for professional look with inline controls and minimal text.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

const int _manifestoMaxLength = 30;

class _ProfileScreenState extends State<ProfileScreen> {
  late final SeasonService _seasonService;
  late final TextEditingController _manifestoController;
  bool _isEditingManifesto = false;
  bool _isEditingDetails = false;

  // Staging state for edits
  String? _selectedSex;
  DateTime? _selectedBirthday;
  String? _selectedNationality;
  bool _voiceMuted = false;

  @override
  void initState() {
    super.initState();
    _seasonService = SeasonService();
    _voiceMuted = VoiceAnnouncementService().isMuted;
    final user = context.read<AppStateProvider>().currentUser;
    _manifestoController = TextEditingController(text: user?.manifesto ?? '');
    _selectedSex = user?.sex;
    _selectedBirthday = user?.birthday;
    _selectedNationality = user?.nationality;
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
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return Scaffold(
          backgroundColor: AppTheme.backgroundStart,
          appBar: AppBar(
            title: Text(
              'PROFILE',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              if (!_isEditingDetails)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () {
                    setState(() {
                      _isEditingDetails = true;
                      _selectedSex = user.sex;
                      _selectedBirthday = user.birthday;
                      _selectedNationality = user.nationality;
                    });
                  },
                )
              else
                IconButton(
                  icon: Icon(Icons.check, color: teamColor, size: 20),
                  onPressed: () async {
                    appState.setUser(
                      user.copyWith(
                        sex: _selectedSex,
                        birthday: _selectedBirthday,
                        nationality: _selectedNationality,
                      ),
                    );
                    setState(() {
                      _isEditingDetails = false;
                    });
                    try {
                      await appState.saveUserProfile();
                    } catch (e) {
                      debugPrint('ProfileScreen: Failed to save profile - $e');
                    }
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: isLandscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _ProfileHeader(
                              user: user,
                              teamColor: teamColor,
                              nationality:
                                  _selectedNationality ?? user.nationality,
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _ManifestoCard(
                              manifesto: user.manifesto,
                              isEditing: _isEditingManifesto,
                              controller: _manifestoController,
                              teamColor: teamColor,
                              onToggleEdit: () {
                                setState(() {
                                  _isEditingManifesto = !_isEditingManifesto;
                                });
                              },
                              onSave: () async {
                                final text = _manifestoController.text.trim();
                                if (text.length <= _manifestoMaxLength) {
                                  appState.setUser(
                                    user.copyWith(manifesto: text),
                                  );
                                  setState(() {
                                    _isEditingManifesto = false;
                                  });
                                  try {
                                    await appState.saveUserProfile();
                                  } catch (e) {
                                    debugPrint(
                                      'ProfileScreen: Failed to save manifesto - $e',
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingL),
                      Expanded(
                        child: Column(
                          children: [
                            _DetailsCard(
                              sex: _selectedSex ?? user.sex,
                              birthday: _selectedBirthday ?? user.birthday,
                              nationality:
                                  _selectedNationality ?? user.nationality,
                              isEditing: _isEditingDetails,
                              teamColor: teamColor,
                              onSexChanged: (val) =>
                                  setState(() => _selectedSex = val),
                              onBirthdayChanged: (val) =>
                                  setState(() => _selectedBirthday = val),
                              onNationalityChanged: (val) =>
                                  setState(() => _selectedNationality = val),
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _StatsCard(
                              user: user,
                              seasonService: _seasonService,
                              teamColor: teamColor,
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _VoiceMuteToggle(
                              isMuted: _voiceMuted,
                              teamColor: teamColor,
                              onToggle: () async {
                                final newVal =
                                    await VoiceAnnouncementService()
                                        .toggleMute();
                                setState(() => _voiceMuted = newVal);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _ProfileHeader(
                        user: user,
                        teamColor: teamColor,
                        nationality: _selectedNationality ?? user.nationality,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _ManifestoCard(
                        manifesto: user.manifesto,
                        isEditing: _isEditingManifesto,
                        controller: _manifestoController,
                        teamColor: teamColor,
                        onToggleEdit: () {
                          setState(() {
                            _isEditingManifesto = !_isEditingManifesto;
                          });
                        },
                        onSave: () async {
                          final text = _manifestoController.text.trim();
                          if (text.length <= _manifestoMaxLength) {
                            appState.setUser(user.copyWith(manifesto: text));
                            setState(() {
                              _isEditingManifesto = false;
                            });
                            try {
                              await appState.saveUserProfile();
                            } catch (e) {
                              debugPrint(
                                'ProfileScreen: Failed to save manifesto - $e',
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _DetailsCard(
                        sex: _selectedSex ?? user.sex,
                        birthday: _selectedBirthday ?? user.birthday,
                        nationality: _selectedNationality ?? user.nationality,
                        isEditing: _isEditingDetails,
                        teamColor: teamColor,
                        onSexChanged: (val) =>
                            setState(() => _selectedSex = val),
                        onBirthdayChanged: (val) =>
                            setState(() => _selectedBirthday = val),
                        onNationalityChanged: (val) =>
                            setState(() => _selectedNationality = val),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _StatsCard(
                        user: user,
                        seasonService: _seasonService,
                        teamColor: teamColor,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _VoiceMuteToggle(
                        isMuted: _voiceMuted,
                        teamColor: teamColor,
                        onToggle: () async {
                          final newVal =
                              await VoiceAnnouncementService().toggleMute();
                          setState(() => _voiceMuted = newVal);
                        },
                      ),
                      if (_seasonService.isPurpleUnlocked &&
                          user.team != Team.purple) ...[
                        const SizedBox(height: AppTheme.spacingL),
                        const _TraitorGateButton(),
                      ],
                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final Color teamColor;
  final String? nationality;

  const _ProfileHeader({
    required this.user,
    required this.teamColor,
    this.nationality,
  });

  @override
  Widget build(BuildContext context) {
    final flag = CountryUtils.getFlag(nationality);

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: teamColor.withValues(alpha: 0.1),
            border: Border.all(
              color: teamColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(flag, style: const TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Text(
          user.name.toUpperCase(),
          style: GoogleFonts.sora(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: teamColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            user.team.displayName,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: teamColor,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ManifestoCard extends StatelessWidget {
  final String? manifesto;
  final bool isEditing;
  final TextEditingController controller;
  final Color teamColor;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;

  const _ManifestoCard({
    required this.manifesto,
    required this.isEditing,
    required this.controller,
    required this.teamColor,
    required this.onToggleEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('💬', style: TextStyle(fontSize: 16)),
              if (!isEditing)
                GestureDetector(
                  onTap: onToggleEdit,
                  child: Icon(Icons.edit, size: 14, color: AppTheme.textMuted),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          if (isEditing)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: _manifestoMaxLength,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Your creed...',
                      hintStyle: TextStyle(
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSave(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.check, color: teamColor),
                  onPressed: onSave,
                ),
              ],
            )
          else
            Text(
              manifesto?.isNotEmpty == true ? manifesto! : 'No manifesto set',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: manifesto?.isNotEmpty == true
                    ? Colors.white
                    : AppTheme.textMuted,
                fontStyle: manifesto?.isNotEmpty == true
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatefulWidget {
  final String sex;
  final DateTime birthday;
  final String? nationality;
  final bool isEditing;
  final Color teamColor;
  final ValueChanged<String> onSexChanged;
  final ValueChanged<DateTime> onBirthdayChanged;
  final ValueChanged<String> onNationalityChanged;

  const _DetailsCard({
    required this.sex,
    required this.birthday,
    this.nationality,
    required this.isEditing,
    required this.teamColor,
    required this.onSexChanged,
    required this.onBirthdayChanged,
    required this.onNationalityChanged,
  });

  @override
  State<_DetailsCard> createState() => _DetailsCardState();
}

class _DetailsCardState extends State<_DetailsCard> {
  void _showDatePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: AppTheme.surfaceColor,
        child: CupertinoTheme(
          data: const CupertinoThemeData(brightness: Brightness.dark),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: widget.birthday,
            minimumDate: DateTime(1940),
            maximumDate: DateTime.now().subtract(
              const Duration(days: 365 * 10),
            ),
            onDateTimeChanged: widget.onBirthdayChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Nationality
          if (widget.isEditing) ...[
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CountryUtils.countries.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final country = CountryUtils.countries[index];
                  final isSelected = widget.nationality == country['code'];
                  return GestureDetector(
                    onTap: () => widget.onNationalityChanged(country['code']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.teamColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? widget.teamColor
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],

          Row(
            children: [
              // Sex
              Expanded(
                child: Column(
                  children: [
                    if (widget.isEditing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SexOption(
                            icon: '♂',
                            value: 'male',
                            groupValue: widget.sex,
                            onChanged: widget.onSexChanged,
                            activeColor: widget.teamColor,
                          ),
                          const SizedBox(width: 8),
                          _SexOption(
                            icon: '♀',
                            value: 'female',
                            groupValue: widget.sex,
                            onChanged: widget.onSexChanged,
                            activeColor: widget.teamColor,
                          ),
                        ],
                      )
                    else
                      Text(
                        widget.sex == 'male' ? '♂' : '♀',
                        style: const TextStyle(fontSize: 24),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'SEX',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.1),
              ),

              // Birthday
              Expanded(
                child: GestureDetector(
                  onTap: widget.isEditing
                      ? () => _showDatePicker(context)
                      : null,
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMM d').format(widget.birthday),
                        style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isEditing
                              ? widget.teamColor
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BIRTHDAY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.1),
              ),

              // Nationality Display (Non-editing)
              if (!widget.isEditing)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        CountryUtils.getFlag(widget.nationality),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.nationality ?? 'WORLD',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        CountryUtils.getFlag(widget.nationality),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'REGION',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SexOption extends StatelessWidget {
  final String icon;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;
  final Color activeColor;

  const _SexOption({
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value.toLowerCase() == groupValue.toLowerCase();
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(icon, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final UserModel user;
  final SeasonService seasonService;
  final Color teamColor;

  const _StatsCard({
    required this.user,
    required this.seasonService,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: '⚡',
                  value: '${user.seasonPoints}',
                  label: 'POINTS',
                  color: teamColor,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: '📅',
                  value: '${seasonService.currentSeasonDay}',
                  label: 'DAY',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: '⏳',
                  value: seasonService.displayString,
                  label: 'REMAINING',
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: '📈',
                  value:
                      '${(seasonService.seasonProgress * 100).toStringAsFixed(0)}%',
                  label: 'PROGRESS',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _VoiceMuteToggle extends StatelessWidget {
  final bool isMuted;
  final Color teamColor;
  final VoidCallback onToggle;

  const _VoiceMuteToggle({
    required this.isMuted,
    required this.teamColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(
            isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: isMuted ? AppTheme.textMuted : teamColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              'VOICE ANNOUNCEMENTS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: isMuted
                    ? Colors.white.withValues(alpha: 0.1)
                    : teamColor.withValues(alpha: 0.4),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    isMuted ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMuted ? AppTheme.textMuted : teamColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraitorGateButton extends StatelessWidget {
  const _TraitorGateButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TraitorGateScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppTheme.chaosPurple.withValues(alpha: 0.6),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💀', style: TextStyle(fontSize: 18)),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              "TRAITOR'S GATE",
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.chaosPurple,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
