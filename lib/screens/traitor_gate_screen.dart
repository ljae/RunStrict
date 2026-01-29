import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../services/season_service.dart';

/// Traitor's Gate - Purple team defection screen.
///
/// Per spec §2.8: Users can defect to Purple (CHAOS) after D-140.
/// Requirements:
/// - Must leave crew first (crewId == null)
/// - All Flip Points reset to 0
/// - Cannot return to Red/Blue for remainder of season
class TraitorGateScreen extends StatefulWidget {
  const TraitorGateScreen({super.key});

  @override
  State<TraitorGateScreen> createState() => _TraitorGateScreenState();
}

class _TraitorGateScreenState extends State<TraitorGateScreen> {
  bool _isDefecting = false;

  Future<void> _showConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AppTheme.chaosPurple.withOpacity(0.5),
            width: 1,
          ),
        ),
        title: Text(
          'FINAL WARNING',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: AppTheme.chaosPurple),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌀', style: TextStyle(fontSize: 48)),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'You are about to abandon your team forever.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'This cannot be undone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.chaosPurple,
            ),
            child: const Text('I ACCEPT CHAOS'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performDefection();
    }
  }

  Future<void> _performDefection() async {
    setState(() => _isDefecting = true);

    try {
      context.read<AppStateProvider>().defectToPurple();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('💀'),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Welcome to CHAOS',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              ],
            ),
            backgroundColor: AppTheme.chaosPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isDefecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasonService = SeasonService();

    // Safety check: redirect if purple not unlocked
    if (!seasonService.isPurpleUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final user = appState.currentUser;
        if (user == null) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundStart,
            body: Center(
              child: Text(
                'No user data',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        final isInCrew = user.crewId != null;
        final currentPoints = user.seasonPoints;
        final canDefect = !isInCrew && !_isDefecting;

        return Scaffold(
          backgroundColor: AppTheme.backgroundStart,
          appBar: AppBar(
            title: Text(
              "TRAITOR'S GATE",
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppTheme.chaosPurple),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppTheme.chaosPurple),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                const SizedBox(height: AppTheme.spacingL),

                // Chaos icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.chaosPurple.withOpacity(0.15),
                    border: Border.all(color: AppTheme.chaosPurple, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.chaosPurple.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('💀', style: TextStyle(fontSize: 56)),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXL),

                // Warning container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: AppTheme.meshDecoration().copyWith(
                    border: Border.all(
                      color: AppTheme.chaosPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PROTOCOL OF CHAOS',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.chaosPurple,
                              letterSpacing: 2.0,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      Text(
                        'Once you defect, there is no return.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Flexible(
                              child: Text(
                                'Your Flip Points will be reset to ZERO',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Current points display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: AppTheme.meshDecoration(),
                  child: Column(
                    children: [
                      Text(
                        'CURRENT FLIP POINTS',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        '$currentPoints',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: currentPoints > 0
                                  ? Colors.red
                                  : AppTheme.textMuted,
                            ),
                      ),
                      if (currentPoints > 0) ...[
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Will be lost forever',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.red.withOpacity(0.7)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Crew check / Defect button
                if (isInCrew) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.group_off,
                          color: Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'You must leave your crew first',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Go to Crew screen to leave your current crew',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null, // Disabled
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceColor,
                        disabledBackgroundColor: AppTheme.surfaceColor
                            .withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'LEAVE CREW FIRST',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canDefect
                          ? () => _showConfirmationDialog(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.chaosPurple,
                        disabledBackgroundColor: AppTheme.chaosPurple
                            .withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isDefecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('💀'),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'DEFECT TO CHAOS',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        letterSpacing: 1.0,
                                      ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.spacingXL),

                // Lore text
                Text(
                  '"Order is a lie. Chaos is the only truth."',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.chaosPurple.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTheme.spacingL),
              ],
            ),
          ),
        );
      },
    );
  }
}
