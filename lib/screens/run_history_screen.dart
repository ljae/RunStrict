import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/run_session.dart';
import '../providers/run_provider.dart';
import '../theme/app_theme.dart';

enum HistoryPeriod { week, month, year }

/// Run History Screen - Personal Running Statistics
/// Design aligned with LeaderboardScreen for consistency
class RunHistoryScreen extends StatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  HistoryPeriod _selectedPeriod = HistoryPeriod.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RunProvider>().loadRunHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<RunProvider>(
          builder: (context, provider, child) {
            final allRuns = provider.runHistory;
            final periodRuns = _filterRunsByPeriod(allRuns, _selectedPeriod);

            // Calculate Stats
            final totalDistance =
                periodRuns.fold(0.0, (sum, run) => sum + run.distanceKm);
            final totalPoints =
                periodRuns.fold(0, (sum, run) => sum + run.pointsEarned);
            final runCount = periodRuns.length;

            // Weighted average pace
            double avgPace = 0.0;
            if (totalDistance > 0) {
              final totalSeconds =
                  periodRuns.fold(0, (sum, run) => sum + run.duration.inSeconds);
              final totalMinutes = totalSeconds / 60.0;
              avgPace = totalMinutes / totalDistance;
            }

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildPeriodToggle(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // Stats Row
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildStatsRow(
                              totalDistance,
                              avgPace,
                              totalPoints,
                              runCount,
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                        // Chart
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildChartCard(periodRuns, _selectedPeriod),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 28)),

                        // Recent Runs Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'RECENT RUNS',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white24,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 16)),

                        // Run List
                        periodRuns.isEmpty
                            ? SliverToBoxAdapter(child: _buildEmptyState())
                            : SliverPadding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _buildRunTile(periodRuns[index]),
                                      );
                                    },
                                    childCount: periodRuns.length,
                                  ),
                                ),
                              ),

                        // Bottom spacing
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MY HISTORY',
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Personal running statistics',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: AppTheme.electricBlue,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: HistoryPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: AnimatedContainer(
                duration: AppTheme.fastDuration,
                curve: AppTheme.defaultCurve,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: Colors.white.withOpacity(0.15))
                      : null,
                ),
                child: Text(
                  period.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsRow(
    double totalDistance,
    double avgPace,
    int totalPoints,
    int runCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'DISTANCE',
            totalDistance.toStringAsFixed(1),
            'km',
            AppTheme.electricBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'AVG PACE',
            _formatPace(avgPace),
            '/km',
            Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'FLIPS',
            totalPoints.toString(),
            'pts',
            AppTheme.athleticRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'RUNS',
            runCount.toString(),
            '',
            Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String unit,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white30,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<RunSession> runs, HistoryPeriod period) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 16),
            child: Text(
              'DISTANCE OVERVIEW',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white30,
                letterSpacing: 1.5,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.8,
            child: _buildChart(runs, period),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<RunSession> runs, HistoryPeriod period) {
    // Prepare data buckets
    final Map<int, double> buckets = {};
    int minX = 0;
    int maxX = 6;

    if (period == HistoryPeriod.week) {
      final today = DateTime.now();
      minX = 0;
      maxX = 6;
      for (var run in runs) {
        final diff = today.difference(run.startTime).inDays;
        if (diff >= 0 && diff <= 6) {
          final x = 6 - diff;
          buckets[x] = (buckets[x] ?? 0) + run.distanceKm;
        }
      }
    } else if (period == HistoryPeriod.month) {
      minX = 1;
      maxX = 31;
      for (var run in runs) {
        final day = run.startTime.day;
        buckets[day] = (buckets[day] ?? 0) + run.distanceKm;
      }
    } else {
      minX = 1;
      maxX = 12;
      for (var run in runs) {
        final month = run.startTime.month;
        buckets[month] = (buckets[month] ?? 0) + run.distanceKm;
      }
    }

    // Build BarGroups
    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = minX; i <= maxX; i++) {
      final val = buckets[i] ?? 0.0;
      if (val > maxY) maxY = val;

      if (period == HistoryPeriod.month && val == 0) continue;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: val > 0
                  ? AppTheme.electricBlue
                  : Colors.white.withOpacity(0.05),
              width: period == HistoryPeriod.month ? 4 : 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY == 0 ? 10 : maxY * 1.2,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY == 0 ? 5 : maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceColor,
            tooltipBorder: BorderSide(color: Colors.white.withOpacity(0.1)),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} km',
                GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) =>
                  _getBottomTitles(val, meta, period),
              reservedSize: 28,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 3 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.03),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _getBottomTitles(double value, TitleMeta meta, HistoryPeriod period) {
    String text = '';
    final style = GoogleFonts.inter(
      fontSize: 10,
      color: Colors.white24,
      fontWeight: FontWeight.w500,
    );

    if (period == HistoryPeriod.week) {
      final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
      text = DateFormat.E().format(date)[0];
    } else if (period == HistoryPeriod.month) {
      if (value.toInt() % 5 == 0) {
        text = value.toInt().toString();
      }
    } else {
      if (value >= 1 && value <= 12) {
        final d = DateTime(2024, value.toInt());
        text = DateFormat.MMM().format(d)[0];
      }
    }

    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: style),
    );
  }

  Widget _buildRunTile(RunSession run) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Date Column
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.electricBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.electricBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('d').format(run.startTime),
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.electricBlue,
                    height: 1.0,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(run.startTime).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.electricBlue.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Run Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${run.distanceKm.toStringAsFixed(2)} km',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: Colors.white30,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(run.duration),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Icon(
                      Icons.speed_rounded,
                      size: 12,
                      color: Colors.white30,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatPace(run.averagePaceMinPerKm),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Points
          if (run.pointsEarned > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.athleticRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.athleticRed.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${run.pointsEarned}',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.athleticRed,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'pts',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.athleticRed.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_run_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.08),
            ),
            const SizedBox(height: 16),
            Text(
              'No runs yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start running to track your progress',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm.isInfinite || paceMinPerKm.isNaN || paceMinPerKm == 0) {
      return "-'--\"";
    }
    final min = paceMinPerKm.floor();
    final sec = ((paceMinPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  List<RunSession> _filterRunsByPeriod(
    List<RunSession> runs,
    HistoryPeriod period,
  ) {
    final now = DateTime.now();
    return runs.where((run) {
      final diff = now.difference(run.startTime);
      switch (period) {
        case HistoryPeriod.week:
          return diff.inDays < 7;
        case HistoryPeriod.month:
          return diff.inDays < 30;
        case HistoryPeriod.year:
          return diff.inDays < 365;
      }
    }).toList();
  }
}
