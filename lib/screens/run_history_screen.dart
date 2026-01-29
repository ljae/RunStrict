import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/run_session.dart';
import '../providers/run_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/run_calendar.dart';

enum HistoryPeriod { week, month, year }

enum HistoryViewMode { calendar, list }

/// Run History Screen - Personal Running Statistics
/// Design aligned with LeaderboardScreen for consistency
class RunHistoryScreen extends StatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  HistoryPeriod _selectedPeriod = HistoryPeriod.month;
  HistoryViewMode _viewMode = HistoryViewMode.calendar;
  DateTime? _selectedDate;
  String _timezone = 'Local';

  static const List<String> _timezones = [
    'Local',
    'UTC',
    'GMT+9 (KST)',
    'GMT+2 (SAST)',
    'GMT-5 (EST)',
    'GMT-8 (PST)',
  ];

  /// Get the UTC offset in hours for the selected timezone
  int _getTimezoneOffsetHours() {
    switch (_timezone) {
      case 'UTC':
        return 0;
      case 'GMT+9 (KST)':
        return 9;
      case 'GMT+2 (SAST)':
        return 2;
      case 'GMT-5 (EST)':
        return -5;
      case 'GMT-8 (PST)':
        return -8;
      case 'Local':
      default:
        // Return local timezone offset (device timezone)
        return DateTime.now().timeZoneOffset.inHours;
    }
  }

  /// Convert a DateTime to the selected timezone for display
  /// All stored times should be in UTC; this converts to display timezone
  DateTime _convertToDisplayTimezone(DateTime utcTime) {
    if (_timezone == 'Local') {
      // For local, convert UTC to local time
      return utcTime.toLocal();
    }
    // For explicit timezones, add the offset to UTC time
    final offsetHours = _getTimezoneOffsetHours();
    // Ensure we're working with UTC, then add offset
    final utc = utcTime.isUtc ? utcTime : utcTime.toUtc();
    return utc.add(Duration(hours: offsetHours));
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RunProvider>().loadRunHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<RunProvider>(
          builder: (context, provider, child) {
            final allRuns = provider.runHistory;
            final periodRuns = _filterRunsByPeriod(allRuns, _selectedPeriod);

            // Calculate Stats
            final totalDistance = periodRuns.fold(
              0.0,
              (sum, run) => sum + run.distanceKm,
            );
            final totalPoints = periodRuns.fold(
              0,
              (sum, run) => sum + run.hexesColored,
            );
            final runCount = periodRuns.length;

            // Weighted average pace
            double avgPace = 0.0;
            if (totalDistance > 0) {
              final totalSeconds = periodRuns.fold(
                0,
                (sum, run) => sum + run.duration.inSeconds,
              );
              final totalMinutes = totalSeconds / 60.0;
              avgPace = totalMinutes / totalDistance;
            }

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  SizedBox(height: isLandscape ? 4 : 10),
                  if (!isLandscape) ...[
                    _buildPeriodToggle(),
                    const SizedBox(height: 24),
                  ],
                  Expanded(
                    child: isLandscape
                        ? _buildLandscapeLayout(
                            allRuns,
                            periodRuns,
                            totalDistance,
                            avgPace,
                            totalPoints,
                            runCount,
                          )
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              // Stats Row
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildStatsRow(
                                    totalDistance,
                                    avgPace,
                                    totalPoints,
                                    runCount,
                                  ),
                                ),
                              ),

                              const SliverToBoxAdapter(
                                child: SizedBox(height: 24),
                              ),

                              // Calendar or Chart based on view mode
                              if (_viewMode == HistoryViewMode.calendar) ...[
                                // Calendar View
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: _buildCalendarContainer(allRuns),
                                  ),
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 20),
                                ),

                                // Selected Date Runs
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: SelectedDateRuns(
                                      date: _selectedDate ?? DateTime.now(),
                                      runs: _runsForDate(
                                        allRuns,
                                        _selectedDate ?? DateTime.now(),
                                      ),
                                      timezoneConverter:
                                          _convertToDisplayTimezone,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // List View - Chart
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: _buildChartCard(
                                      periodRuns,
                                      _selectedPeriod,
                                    ),
                                  ),
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 28),
                                ),

                                // Recent Runs Header
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: _buildRecentRunsHeader(),
                                  ),
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 16),
                                ),

                                // Run List
                                periodRuns.isEmpty
                                    ? SliverToBoxAdapter(
                                        child: _buildEmptyState(),
                                      )
                                    : SliverPadding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        sliver: SliverList(
                                          delegate: SliverChildBuilderDelegate((
                                            context,
                                            index,
                                          ) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _buildRunTile(
                                                periodRuns[index],
                                              ),
                                            );
                                          }, childCount: periodRuns.length),
                                        ),
                                      ),
                              ],

                              // Bottom spacing
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 100),
                              ),
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

  Widget _buildLandscapeLayout(
    List<RunSession> allRuns,
    List<RunSession> periodRuns,
    double totalDistance,
    double avgPace,
    int totalPoints,
    int runCount,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Stats + Calendar/Chart
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 24),
            child: Column(
              children: [
                _buildPeriodToggle(),
                const SizedBox(height: 16),
                _buildStatsRow(totalDistance, avgPace, totalPoints, runCount),
                const SizedBox(height: 16),
                if (_viewMode == HistoryViewMode.calendar)
                  _buildCalendarContainer(allRuns)
                else
                  _buildChartCard(periodRuns, _selectedPeriod),
              ],
            ),
          ),
        ),
        // Right Column: Details / List
        Expanded(
          flex: 1,
          child: _viewMode == HistoryViewMode.calendar
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 24, 24),
                  child: SelectedDateRuns(
                    date: _selectedDate ?? DateTime.now(),
                    runs: _runsForDate(
                      allRuns,
                      _selectedDate ?? DateTime.now(),
                    ),
                    timezoneConverter: _convertToDisplayTimezone,
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 24, 16),
                      child: _buildRecentRunsHeader(),
                    ),
                    Expanded(
                      child: periodRuns.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 24, 24),
                              itemCount: periodRuns.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildRunTile(periodRuns[index]),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCalendarContainer(List<RunSession> allRuns) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: RunCalendar(
        runs: allRuns,
        selectedDate: _selectedDate,
        onDateSelected: (date) {
          setState(() => _selectedDate = date);
        },
        timezoneConverter: _convertToDisplayTimezone,
      ),
    );
  }

  Widget _buildRecentRunsHeader() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
          child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isLandscape ? 2 : 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: isLandscape
                // Landscape: Single line compact header
                ? Text(
                    'MY HISTORY',
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  )
                // Portrait: Two-line header with subtitle
                : Column(
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timezone selector
              _buildTimezoneDropdown(),
              const SizedBox(width: 8),
              // View mode toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _viewMode = _viewMode == HistoryViewMode.calendar
                        ? HistoryViewMode.list
                        : HistoryViewMode.calendar;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(
                    _viewMode == HistoryViewMode.calendar
                        ? Icons.list_rounded
                        : Icons.calendar_month_rounded,
                    color: AppTheme.electricBlue,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimezoneDropdown() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() => _timezone = value);
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.surfaceColor,
      itemBuilder: (context) => _timezones.map((tz) {
        final isSelected = _timezone == tz;
        return PopupMenuItem<String>(
          value: tz,
          child: Row(
            children: [
              if (isSelected)
                Icon(Icons.check, size: 16, color: AppTheme.electricBlue)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Text(
                tz,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isSelected ? AppTheme.electricBlue : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              _timezone,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
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
          AspectRatio(aspectRatio: 1.8, child: _buildChart(runs, period)),
        ],
      ),
    );
  }

  Widget _buildChart(List<RunSession> runs, HistoryPeriod period) {
    // Prepare data buckets
    final Map<int, double> buckets = {};
    int minX = 0;
    int maxX = 6;

    // Use current time in selected timezone
    final today = _convertToDisplayTimezone(DateTime.now().toUtc());

    if (period == HistoryPeriod.week) {
      minX = 0;
      maxX = 6;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        final diff = today.difference(displayTime).inDays;
        if (diff >= 0 && diff <= 6) {
          final x = 6 - diff;
          buckets[x] = (buckets[x] ?? 0) + run.distanceKm;
        }
      }
    } else if (period == HistoryPeriod.month) {
      minX = 1;
      maxX = 31;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        final day = displayTime.day;
        buckets[day] = (buckets[day] ?? 0) + run.distanceKm;
      }
    } else {
      minX = 1;
      maxX = 12;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        final month = displayTime.month;
        buckets[month] = (buckets[month] ?? 0) + run.distanceKm;
      }
    }

    // Calculate max value for normalization
    double maxY = 0;
    for (int i = minX; i <= maxX; i++) {
      final val = buckets[i] ?? 0.0;
      if (val > maxY) maxY = val;
    }
    if (maxY == 0) maxY = 5;

    // Build bar entries (show all positions for consistent spacing)
    final entries = <_BarEntry>[];
    for (int i = minX; i <= maxX; i++) {
      final val = buckets[i] ?? 0.0;
      entries.add(_BarEntry(x: i, value: val, label: _getLabel(i, period)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((entry) {
                final fraction = entry.value / maxY;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FractionallySizedBox(
                      heightFactor: fraction.clamp(0.02, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: entry.value > 0
                              ? AppTheme.electricBlue
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: entries.map((entry) {
              return Expanded(
                child: Center(
                  child: Text(
                    entry.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getLabel(int value, HistoryPeriod period) {
    if (period == HistoryPeriod.week) {
      // Use current time in selected timezone
      final today = _convertToDisplayTimezone(DateTime.now().toUtc());
      final date = today.subtract(Duration(days: 6 - value));
      return DateFormat.E().format(date)[0];
    } else if (period == HistoryPeriod.month) {
      // Show labels at day 1, 7, 14, 21, 28
      return (value == 1 || value % 7 == 0) ? '$value' : '';
    } else {
      if (value >= 1 && value <= 12) {
        final d = DateTime(2024, value);
        return DateFormat.MMM().format(d)[0];
      }
      return '';
    }
  }

  Widget _buildRunTile(RunSession run) {
    // Convert time to selected timezone for display
    final displayTime = _convertToDisplayTimezone(run.startTime);

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
              border: Border.all(color: AppTheme.electricBlue.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('d').format(displayTime),
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.electricBlue,
                    height: 1.0,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(displayTime).toUpperCase(),
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
                    Icon(Icons.speed_rounded, size: 12, color: Colors.white30),
                    const SizedBox(width: 4),
                    Text(
                      _formatPace(run.paceMinPerKm),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    // Stability badge (if available)
                    if (run.stabilityScore != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        '${run.stabilityScore}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStabilityColor(run.stabilityScore!),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Points
          if (run.hexesColored > 0)
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
                    '+${run.hexesColored}',
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
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white38),
            ),
            const SizedBox(height: 8),
            Text(
              'Start running to track your progress',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white24),
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

  /// Get color for stability score badge
  /// Green = high stability (≥80), Yellow = medium (50-79), Red = low (<50)
  Color _getStabilityColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E); // Green
    if (score >= 50) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  List<RunSession> _runsForDate(List<RunSession> runs, DateTime date) {
    return runs.where((run) {
      final displayTime = _convertToDisplayTimezone(run.startTime);
      return displayTime.year == date.year &&
          displayTime.month == date.month &&
          displayTime.day == date.day;
    }).toList();
  }

  List<RunSession> _filterRunsByPeriod(
    List<RunSession> runs,
    HistoryPeriod period,
  ) {
    // Use current time in selected timezone for filtering
    final now = _convertToDisplayTimezone(DateTime.now().toUtc());
    return runs.where((run) {
      final displayTime = _convertToDisplayTimezone(run.startTime);
      final diff = now.difference(displayTime);
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

/// Simple data class for bar chart entries.
class _BarEntry {
  final int x;
  final double value;
  final String label;

  const _BarEntry({required this.x, required this.value, required this.label});
}
