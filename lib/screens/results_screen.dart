import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Weekly/seasonal results screen with modern broadcast aesthetics.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppTheme.spacingS),
                      const _HeaderSummary(),
                      const SizedBox(height: AppTheme.spacingL),
                      const _DistrictResultCard(),
                      const SizedBox(height: AppTheme.spacingL),
                      const _HighlightsCard(),
                      const SizedBox(height: AppTheme.spacingXXL),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.electricBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'WEEKLY RESULTS',
                style: AppTheme.themeData.textTheme.titleMedium?.copyWith(
                  color: AppTheme.electricBlue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WEEK 47',
          style: AppTheme.themeData.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            height: 1.0,
          ),
        ),
        Text(
          'RESULTS',
          style: AppTheme.themeData.textTheme.displayMedium?.copyWith(
            color: AppTheme.electricBlue,
            height: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: AppTheme.meshDecoration(color: AppTheme.surfaceColor),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTeamScore(
                context,
                'RED TEAM',
                1,
                AppTheme.athleticRed,
                true,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildTeamScore(
                context,
                'BLUE TEAM',
                2,
                AppTheme.electricBlue,
                false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamScore(
    BuildContext context,
    String teamName,
    int score,
    Color color,
    bool isRed,
  ) {
    return Column(
      children: [
        Text(
          teamName,
          style: AppTheme.themeData.textTheme.labelLarge?.copyWith(
            color: color.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              score.toString(),
              style: AppTheme.themeData.textTheme.displayMedium?.copyWith(
                color: Colors.white,
                height: 1.0,
                shadows: AppTheme.glowShadow(color, intensity: 0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                'ZONES',
                style: AppTheme.themeData.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DistrictResultCard extends StatelessWidget {
  const _DistrictResultCard();

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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppTheme.electricBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ZONE BREAKDOWN',
                style: AppTheme.themeData.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          const _SeatRow(label: 'ZONE A', isRed: true, percentage: 0.82),
          const SizedBox(height: AppTheme.spacingM),
          const _SeatRow(label: 'ZONE B', isRed: false, percentage: 0.53),
          const SizedBox(height: AppTheme.spacingM),
          const _SeatRow(label: 'ZONE C', isRed: false, percentage: 0.71),
        ],
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final String label;
  final bool isRed;
  final double percentage;

  const _SeatRow({
    required this.label,
    required this.isRed,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRed ? AppTheme.athleticRed : AppTheme.electricBlue;
    final pctText = (percentage * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTheme.themeData.textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$pctText%',
              style: AppTheme.themeData.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontFamily: GoogleFonts.outfit().fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background track
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // Animated progress bar
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: percentage),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 12,
                      width: constraints.maxWidth * value,
                      decoration: BoxDecoration(
                        gradient: AppTheme.teamGradient(isRed),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: AppTheme.glowShadow(color, intensity: 0.8),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: AppTheme.meshDecoration(color: AppTheme.surfaceColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'HIGHLIGHTS',
                style: AppTheme.themeData.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _HighlightRow(
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            label: 'MVP',
            value: '@RunnerKim',
            subValue: '12.4km Contribution',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
            child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
          ),
          _HighlightRow(
            icon: Icons.bolt_rounded,
            iconColor: AppTheme.electricBlue,
            label: 'COMEBACK',
            value: 'ZONE B',
            subValue: 'Sat PM · Dramatic Turn',
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subValue;

  const _HighlightRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.themeData.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.themeData.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                subValue,
                style: AppTheme.themeData.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
