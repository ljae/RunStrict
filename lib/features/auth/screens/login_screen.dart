import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../data/models/team.dart';
import '../providers/app_state_provider.dart';
import '../providers/app_init_provider.dart';
import '../../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(appStateProvider.notifier).signInWithApple();
      // go_router redirect handles navigation
    } catch (e) {
      if (mounted) _showError('Apple Sign-In failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(appStateProvider.notifier).signInWithGoogle();
      // go_router redirect handles navigation
    } catch (e) {
      if (mounted) _showError('Google Sign-In failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleCasualJoin() {
    showModalBottomSheet<Team>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeamPickerSheet(),
    ).then((team) {
      if (team == null || !mounted) return;
      ref.read(appStateProvider.notifier).joinAsGuest(team);
      ref.read(appInitProvider.notifier).initialize();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.sora(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: AppTheme.athleticRed,
      ),
    );
    debugPrint('Login Error: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),

                    // Logo
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'RUN',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 64,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'STRICT',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                              color: AppTheme.electricBlue,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Run. Conquer. Reset.',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Apple Sign In
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAppleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Sign in with Apple',
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Google Sign In
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.g_mobiledata,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Sign in with Google',
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // OR Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppTheme.textMuted.withValues(alpha: 0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppTheme.textMuted.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Casual Join
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _handleCasualJoin,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppTheme.textMuted.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'CASUAL JOIN',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'One-day pass. No account needed.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Loading indicator
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.electricBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: AppTheme.backgroundStart,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'CHOOSE YOUR SIDE',
              style: GoogleFonts.bebasNeue(
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a team for your casual run',
              style: GoogleFonts.sora(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            // Red team
            _TeamOptionTile(
              team: Team.red,
              color: AppTheme.athleticRed,
              subtitle: 'Elite hierarchy. Top 20% earn bonus.',
            ),
            const SizedBox(height: 12),
            // Blue team
            _TeamOptionTile(
              team: Team.blue,
              color: AppTheme.electricBlue,
              subtitle: 'Union strength. Equal buff for all.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamOptionTile extends StatelessWidget {
  final Team team;
  final Color color;
  final String subtitle;

  const _TeamOptionTile({
    required this.team,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(team),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.displayName,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 22,
                      color: color,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
