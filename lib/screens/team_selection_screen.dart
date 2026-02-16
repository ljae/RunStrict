import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/team.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

class TeamSelectionScreen extends StatefulWidget {
  const TeamSelectionScreen({super.key});

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Background rotation controller
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Logo pulsing controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Entrance animations
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Stack(
        children: [
          // 1. Dynamic Background (Vortex/Mesh)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: VortexPainter(
                    animationValue: _backgroundController.value,
                    color: AppTheme.electricBlue.withOpacity(0.05),
                  ),
                );
              },
            ),
          ),

          // 2. Ambient Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Colors.transparent,
                    AppTheme.backgroundStart.withOpacity(0.8),
                    AppTheme.backgroundStart,
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 60),
                        _buildTeamSelector(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Pulsing Logo Icon
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration:
                    AppTheme.tubularBorder(
                      AppTheme.electricBlue.withOpacity(
                        0.6 + (_pulseController.value * 0.4),
                      ),
                      width: 3,
                    ).copyWith(
                      color: AppTheme.surfaceColor.withOpacity(0.5),
                      boxShadow: AppTheme.glowShadow(
                        AppTheme.electricBlue,
                        intensity: 0.6 + (_pulseController.value * 0.4),
                      ),
                    ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        // Main Title
        Text(
          'RUN',
          style: AppTheme.themeData.textTheme.displayLarge?.copyWith(
            fontStyle: FontStyle.italic,
            letterSpacing: 8,
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle / Call to Action
        Text(
          'CHOOSE YOUR SIDE',
          style: AppTheme.themeData.textTheme.titleLarge?.copyWith(
            color: AppTheme.textSecondary,
            letterSpacing: 4,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSelector(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout
        if (constraints.maxWidth > 600) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TeamCard(
                team: Team.red,
                title: 'RED TEAM',
                subtitle: 'Passion & Power',
                icon: Icons.local_fire_department_rounded,
                onSelect: () => _handleTeamSelection(context, Team.red),
              ),
              const SizedBox(width: 40),
              _TeamCard(
                team: Team.blue,
                title: 'BLUE TEAM',
                subtitle: 'Speed & Flow',
                icon: Icons.waves_rounded,
                onSelect: () => _handleTeamSelection(context, Team.blue),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _TeamCard(
                team: Team.red,
                title: 'RED TEAM',
                subtitle: 'Passion & Power',
                icon: Icons.local_fire_department_rounded,
                onSelect: () => _handleTeamSelection(context, Team.red),
              ),
              const SizedBox(height: 24),
              _TeamCard(
                team: Team.blue,
                title: 'BLUE TEAM',
                subtitle: 'Speed & Flow',
                icon: Icons.waves_rounded,
                onSelect: () => _handleTeamSelection(context, Team.blue),
              ),
            ],
          );
        }
      },
    );
  }

  Future<void> _handleTeamSelection(BuildContext context, Team team) async {
    final appState = context.read<AppStateProvider>();

    try {
      await appState.selectTeam(team);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _TeamCard extends StatefulWidget {
  final Team team;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSelect;

  const _TeamCard({
    required this.team,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onSelect,
  });

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRed = widget.team == Team.red;
    final primaryColor = isRed ? AppTheme.athleticRed : AppTheme.electricBlue;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        onTapDown: (_) => _hoverController.forward(),
        onTapUp: (_) => _hoverController.reverse(),
        onTapCancel: () => _hoverController.reverse(),
        child: AnimatedBuilder(
          animation: _hoverController,
          builder: (context, child) {
            final scale = 1.0 + (0.05 * _hoverController.value);
            final glowIntensity = _isHovered ? 1.0 : 0.0;

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 280,
                height: 320,
                decoration:
                    AppTheme.meshDecoration(
                      color: AppTheme.surfaceColor,
                      isRed: isRed,
                    ).copyWith(
                      border: Border.all(
                        color: primaryColor.withOpacity(_isHovered ? 0.8 : 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        ...AppTheme.glowShadow(
                          primaryColor,
                          intensity: glowIntensity,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                child: Stack(
                  children: [
                    // Background Gradient Mesh Effect
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: MeshGridPainter(
                            color: primaryColor.withOpacity(0.05),
                            offset: _hoverController.value * 10,
                          ),
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon Circle
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.teamGradient(isRed),
                              boxShadow: AppTheme.glowShadow(
                                primaryColor,
                                intensity: 0.5 + (_hoverController.value * 0.5),
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Title
                          Text(
                            widget.title,
                            style: AppTheme.themeData.textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            widget.subtitle,
                            style: AppTheme.themeData.textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PAINTERS
// -----------------------------------------------------------------------------

class VortexPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  VortexPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 8; i++) {
      final radius = (i + 1) * (maxRadius / 8);
      final rotationOffset =
          animationValue * 2 * math.pi * (i % 2 == 0 ? 1 : -1);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationOffset);

      // Draw hexagonal shapes instead of circles for tech feel
      final path = Path();
      for (int j = 0; j < 6; j++) {
        final angle = (j * 60) * math.pi / 180;
        final x = radius * math.cos(angle);
        final y = radius * math.sin(angle);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(VortexPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class MeshGridPainter extends CustomPainter {
  final Color color;
  final double offset;

  MeshGridPainter({required this.color, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 20.0;

    // Diagonal lines
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i + offset, 0),
        Offset(i + size.height + offset, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(MeshGridPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.color != color;
}
