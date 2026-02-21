import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../data/models/run.dart';
import '../../run/providers/run_provider.dart';
import '../../../core/providers/points_provider.dart';
import '../../../core/providers/user_repository_provider.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/timezone_preference_service.dart';
import '../../../theme/app_theme.dart';
import '../../../core/utils/gmt2_date_utils.dart';
import '../widgets/run_calendar.dart';

enum HistoryPeriod { day, week, month, year }

enum HistoryViewMode { calendar, list }

/// Run History Screen - Personal Running Statistics
/// Design aligned with LeaderboardScreen for consistency
class RunHistoryScreen extends ConsumerStatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  ConsumerState<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends ConsumerState<RunHistoryScreen> {
  HistoryPeriod _selectedPeriod = HistoryPeriod.day;
  HistoryViewMode _viewMode = HistoryViewMode.list;
  DateTime? _selectedDate;
  bool _useGmt2 = false;

  // Range-based navigation state
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  /// Returns "now" in the selected display timezone.
  DateTime get _now =>
      _useGmt2 ? Gmt2DateUtils.todayGmt2 : DateTime.now();

  /// Get user's team color for highlights (supports red, blue, purple)
  Color get _teamColor {
    return ref.read(userRepositoryProvider)?.team.color ?? AppTheme.electricBlue;
  }

  /// Convert a DateTime to the selected display timezone (local or GMT+2).
  DateTime _convertToDisplayTimezone(DateTime utcTime) {
    if (_useGmt2) {
      final offsetHours = RemoteConfigService()
          .config
          .seasonConfig
          .serverTimezoneOffsetHours;
      return utcTime.toUtc().add(Duration(hours: offsetHours));
    }
    return utcTime.toLocal();
  }

  /// Calculate range boundaries based on anchor date and period
  void _calculateRange(DateTime anchorDate, HistoryPeriod period) {
    switch (period) {
      case HistoryPeriod.day:
        // DAY mode: Monthly range (chart shows all days of the month)
        _rangeStart = DateTime(anchorDate.year, anchorDate.month, 1);
        _rangeEnd = DateTime(anchorDate.year, anchorDate.month + 1, 0);
        break;
      case HistoryPeriod.week:
        // Week starts Sunday (weekday % 7 gives Sunday = 0)
        final dayOfWeek = anchorDate.weekday % 7;
        _rangeStart = DateTime(
          anchorDate.year,
          anchorDate.month,
          anchorDate.day - dayOfWeek,
        );
        _rangeEnd = _rangeStart.add(const Duration(days: 6));
        break;
      case HistoryPeriod.month:
        // MONTH mode: Full year range (chart shows all 12 months)
        _rangeStart = DateTime(anchorDate.year, 1, 1);
        _rangeEnd = DateTime(anchorDate.year, 12, 31);
        break;
      case HistoryPeriod.year:
        // YEAR mode: Last 5 years range (chart shows 5 years)
        final currentYear = _now.year;
        _rangeStart = DateTime(currentYear - 4, 1, 1);
        _rangeEnd = DateTime(currentYear, 12, 31);
        break;
    }
    // Clear selection - entire range is selected (range mode)
    _selectedDate = null;
  }

  /// Navigate to previous range (day/week/month/year)
  void _navigatePrevious() {
    DateTime newAnchor;
    switch (_selectedPeriod) {
      case HistoryPeriod.day:
        // DAY mode navigates by month
        newAnchor = DateTime(_rangeStart.year, _rangeStart.month - 1, 1);
        break;
      case HistoryPeriod.week:
        newAnchor = _rangeStart.subtract(const Duration(days: 7));
        break;
      case HistoryPeriod.month:
        // MONTH mode navigates by year (shows all 12 months of that year)
        newAnchor = DateTime(_rangeStart.year - 1, 1, 1);
        break;
      case HistoryPeriod.year:
        // YEAR mode: no navigation (always shows last 5 years)
        return;
    }
    setState(() {
      _calculateRange(newAnchor, _selectedPeriod);
    });
  }

  /// Navigate to next range (day/week/month/year)
  void _navigateNext() {
    DateTime newAnchor;
    switch (_selectedPeriod) {
      case HistoryPeriod.day:
        // DAY mode navigates by month
        newAnchor = DateTime(_rangeStart.year, _rangeStart.month + 1, 1);
        break;
      case HistoryPeriod.week:
        newAnchor = _rangeStart.add(const Duration(days: 7));
        break;
      case HistoryPeriod.month:
        // MONTH mode navigates by year (shows all 12 months of that year)
        newAnchor = DateTime(_rangeStart.year + 1, 1, 1);
        break;
      case HistoryPeriod.year:
        // YEAR mode: no navigation (always shows last 5 years)
        return;
    }
    setState(() {
      _calculateRange(newAnchor, _selectedPeriod);
    });
  }

  /// Get descriptive label for period stats panel
  String _getPeriodStatsLabel() {
    switch (_selectedPeriod) {
      case HistoryPeriod.day:
        return 'TODAY';
      case HistoryPeriod.week:
        return 'WEEK';
      case HistoryPeriod.month:
        return 'THIS MONTH';
      case HistoryPeriod.year:
        return 'THIS YEAR';
    }
  }

  /// Format range display based on period
  String _formatRangeDisplay() {
    switch (_selectedPeriod) {
      case HistoryPeriod.day:
        // DAY mode shows month range: "JANUARY 2026"
        return DateFormat('MMMM yyyy').format(_rangeStart).toUpperCase();
      case HistoryPeriod.week:
        // "Jan 26 - Feb 1" or "Dec 28 - Jan 3, 2027" if years differ
        final startFormat = DateFormat('MMM d');
        if (_rangeStart.year != _rangeEnd.year) {
          return '${startFormat.format(_rangeStart)} - ${DateFormat('MMM d, yyyy').format(_rangeEnd)}';
        } else if (_rangeStart.month != _rangeEnd.month) {
          return '${startFormat.format(_rangeStart)} - ${DateFormat('MMM d').format(_rangeEnd)}';
        } else {
          return '${startFormat.format(_rangeStart)} - ${_rangeEnd.day}';
        }
      case HistoryPeriod.month:
        // MONTH mode shows year only: "2025"
        return _rangeStart.year.toString();
      case HistoryPeriod.year:
        // YEAR mode shows 5-year range: "2021 - 2025"
        final currentYear = _now.year;
        return '${currentYear - 4} - $currentYear';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Initialize range based on current date and default period
    _calculateRange(_selectedDate!, _selectedPeriod);
    // Load persisted timezone preference
    TimezonePreferenceService().load().then((tz) {
      if (mounted && tz == DisplayTimezone.gmt2) {
        setState(() {
          _useGmt2 = true;
          _selectedDate = _now;
          _calculateRange(_selectedDate!, _selectedPeriod);
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(runProvider.notifier).loadRunHistory();
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
        body: Builder(
          builder: (context) {
            final runState = ref.watch(runProvider);
            final allRuns = runState.runHistory;
            // For chart/calendar visualization (uses _rangeStart/_rangeEnd)
            final periodRuns = _filterRunsByPeriod(allRuns, _selectedPeriod);
            // For stats panel (uses actual period meaning: today/week/month/year)
            final statsRuns = _filterRunsForStats(allRuns, _selectedPeriod);

            // Calculate OVERALL (all-time) Stats
            // Server aggregates (UserModel) are the source of truth for ALL TIME.
            // PointsService.totalSeasonPoints is the only hybrid value (server
            // season_points + local unsynced today) — this ensures the header
            // and ALL TIME points stay in sync and reflect live running.
            // All other aggregates come from server (updated by finalize_run).
            final user = ref.read(userRepositoryProvider);
            final points = ref.read(pointsProvider.notifier);
            final overallDistance = user?.totalDistanceKm ?? 0.0;
            final overallPoints = points.totalSeasonPoints;
            final overallRunCount = user?.totalRuns ?? 0;
            final overallPace = user?.avgPaceMinPerKm ?? 0.0;
            final overallStability = user?.stabilityScore;

            // Calculate PERIOD Stats (from statsRuns - actual period)
            final totalDistance = statsRuns.fold(
              0.0,
              (sum, run) => sum + run.distanceKm,
            );
            final totalPoints = statsRuns.fold(
              0,
              (sum, run) => sum + run.flipPoints,
            );
            final runCount = statsRuns.length;

            // Weighted average pace for period
            double avgPace = 0.0;
            if (totalDistance > 0) {
              final totalSeconds = statsRuns.fold(
                0,
                (sum, run) => sum + run.duration.inSeconds,
              );
              final totalMinutes = totalSeconds / 60.0;
              avgPace = totalMinutes / totalDistance;
            }
            // Weighted avg stability for period (runs >= 1km only)
            final periodStability = _calculateWeightedStability(statsRuns);

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isLandscape ? 8 : 16),
                  if (!isLandscape) ...[
                    // ALL-TIME stats at top (fixed, outside scroll)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildOverallStatsSection(
                        overallDistance,
                        overallPace,
                        overallPoints,
                        overallRunCount,
                        overallStability,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Period toggle: DAY | WEEK | MONTH | YEAR
                    _buildPeriodToggle(),
                    const SizedBox(height: 8),
                    // Range navigation
                    _buildRangeNavigation(),
                    const SizedBox(height: 16),
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
                            overallDistance,
                            overallPace,
                            overallPoints,
                            overallRunCount,
                            overallStability,
                            periodStability,
                          )
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              // Period Stats Panel
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildPeriodStatsSection(
                                    totalDistance,
                                    avgPace,
                                    totalPoints,
                                    runCount,
                                    _getPeriodStatsLabel(),
                                    periodStability,
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

                                // Selected Date/Range Runs
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: _selectedDate != null
                                        ? SelectedDateRuns(
                                            date: _selectedDate!,
                                            runs: _runsForDate(
                                              allRuns,
                                              _selectedDate!,
                                            ),
                                            timezoneConverter:
                                                _convertToDisplayTimezone,
                                          )
                                        : _buildRangeRunsList(periodRuns),
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
    List<Run> allRuns,
    List<Run> periodRuns,
    double totalDistance,
    double avgPace,
    int totalPoints,
    int runCount,
    double overallDistance,
    double overallPace,
    int overallPoints,
    int overallRunCount,
    int? overallStability,
    int? periodStability,
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
                _buildOverallStatsSection(
                  overallDistance,
                  overallPace,
                  overallPoints,
                  overallRunCount,
                  overallStability,
                ),
                const SizedBox(height: 12),
                // Period toggle: DAY | WEEK | MONTH | YEAR
                _buildPeriodToggle(),
                const SizedBox(height: 8),
                // Range navigation
                _buildRangeNavigation(),
                const SizedBox(height: 16),
                _buildPeriodStatsSection(
                  totalDistance,
                  avgPace,
                  totalPoints,
                  runCount,
                  _getPeriodStatsLabel(),
                  periodStability,
                ),
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
                  child: _selectedDate != null
                      ? SelectedDateRuns(
                          date: _selectedDate!,
                          runs: _runsForDate(allRuns, _selectedDate!),
                          timezoneConverter: _convertToDisplayTimezone,
                        )
                      : _buildRangeRunsList(periodRuns),
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

  Widget _buildCalendarContainer(List<Run> allRuns) {
    // Map period selection to calendar display mode
    // DAY → month calendar (to select a day)
    // WEEK → week view
    // MONTH → year view (to select a month)
    // YEAR → 5-year view (custom widget)
    CalendarDisplayMode displayMode;
    switch (_selectedPeriod) {
      case HistoryPeriod.day:
        displayMode = CalendarDisplayMode.month;
        break;
      case HistoryPeriod.week:
        displayMode = CalendarDisplayMode.week;
        break;
      case HistoryPeriod.month:
        displayMode = CalendarDisplayMode.year;
        break;
      case HistoryPeriod.year:
        // Use custom 5-year view
        return _buildFiveYearCalendarWithToggle(allRuns);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and toggle
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CALENDAR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white30,
                    letterSpacing: 1.5,
                  ),
                ),
                _buildViewModeToggle(),
              ],
            ),
          ),
          RunCalendar(
            runs: allRuns,
            selectedDate: _selectedDate,
            displayMode: displayMode,
            externalRangeStart: _rangeStart,
            externalRangeEnd: _rangeEnd,
            onNavigatePrevious: _navigatePrevious,
            onNavigateNext: _navigateNext,
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
            },
            timezoneConverter: _convertToDisplayTimezone,
          ),
        ],
      ),
    );
  }

  /// Build 5-year calendar view for YEAR period (with toggle)
  Widget _buildFiveYearCalendarWithToggle(List<Run> allRuns) {
    final currentYear = _now.year;
    final years = List.generate(5, (i) => currentYear - 4 + i);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and toggle
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'YEARLY OVERVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white30,
                    letterSpacing: 1.5,
                  ),
                ),
                _buildViewModeToggle(),
              ],
            ),
          ),
          // Year grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: years.map((year) {
              final isSelected = _rangeStart.year == year;
              final yearRuns = allRuns.where((run) {
                final displayTime = _convertToDisplayTimezone(run.startTime);
                return displayTime.year == year;
              }).toList();
              final totalDistance = yearRuns.fold(
                0.0,
                (sum, run) => sum + run.distanceKm,
              );
              final runCount = yearRuns.length;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _calculateRange(DateTime(year, 6, 15), HistoryPeriod.year);
                  });
                },
                child: Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.white.withOpacity(0.2))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        year.toString(),
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatCompact(totalDistance),
                        style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: runCount > 0 ? _teamColor : Colors.white24,
                        ),
                      ),
                      Text(
                        'km',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.white30,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatCompactInt(runCount)} runs',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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

  /// Period toggle: DAY | WEEK | MONTH | YEAR
  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: HistoryPeriod.values.map((period) {
            final isSelected = _selectedPeriod == period;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPeriod = period;
                    // Recalculate range when period changes
                    _calculateRange(_selectedDate ?? _now, period);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    period.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white38,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Range navigation with prev/next controls and date display
  Widget _buildRangeNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous arrow
          GestureDetector(
            onTap: _navigatePrevious,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white54,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Range display
          Expanded(
            child: Text(
              _formatRangeDisplay(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Next arrow
          GestureDetector(
            onTap: _navigateNext,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Period stats section - smaller version of ALL TIME panel
  Widget _buildPeriodStatsSection(
    double distance,
    double pace,
    int flips,
    int runs,
    String periodLabel,
    int? stability,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period label
          Text(
            periodLabel,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.2),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          // Stats in a row with separators
          Row(
            children: [
              // Points - primary highlight
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCompactInt(flips),
                        style: GoogleFonts.sora(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'pts',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withOpacity(0.06),
              ),
              // Secondary stats
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Flexible(
                        child: _buildMiniStatSmall(
                          _formatCompact(distance),
                          'km',
                        ),
                      ),
                      Flexible(
                        child: _buildMiniStatSmall(_formatPace(pace), '/km'),
                      ),
                      Flexible(
                        child: stability != null
                            ? _buildMiniStatSmallColored(
                                '$stability%',
                                'stab',
                                _getStabilityColor(stability),
                              )
                            : _buildMiniStatSmall('--', 'stab'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mini stat for period section (smaller than ALL TIME)
  Widget _buildMiniStatSmall(String value, String label) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  /// Mini stat with custom color for period section (smaller)
  Widget _buildMiniStatSmallColored(
    String value,
    String label,
    Color valueColor,
  ) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  /// Overall (all-time) stats section - minimal horizontal display
  Widget _buildOverallStatsSection(
    double distance,
    double pace,
    int flips,
    int runs,
    int? stability,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall label with timezone toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALL TIME',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.2),
                  letterSpacing: 2.0,
                ),
              ),
              _buildTimezoneToggle(),
            ],
          ),
          const SizedBox(height: 12),
          // Stats in a row with separators
          Row(
            children: [
              // Points - primary highlight
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCompactInt(flips),
                        style: GoogleFonts.sora(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'pts',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.06),
              ),
              // Secondary stats
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Flexible(
                        child: _buildMiniStat(
                          _formatCompact(distance),
                          'km',
                        ),
                      ),
                      Flexible(child: _buildMiniStat(_formatPace(pace), '/km')),
                      Flexible(
                        child: stability != null
                            ? _buildMiniStatColored(
                                '$stability%',
                                'stab',
                                _getStabilityColor(stability),
                              )
                            : _buildMiniStat('--', 'stab'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mini stat with custom color for value
  Widget _buildMiniStatColored(String value, String label, Color valueColor) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  /// Mini stat for overall section
  Widget _buildMiniStat(String value, String label) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<Run> runs, HistoryPeriod period) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and toggle
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 8, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DISTANCE OVERVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white30,
                    letterSpacing: 1.5,
                  ),
                ),
                // Graph/Calendar toggle
                _buildViewModeToggle(),
              ],
            ),
          ),
          AspectRatio(aspectRatio: 1.8, child: _buildChart(runs, period)),
        ],
      ),
    );
  }

  /// Timezone toggle: segmented control matching Graph/Calendar style
  Widget _buildTimezoneToggle() {
    void handleToggle(bool gmt2) {
      if (_useGmt2 == gmt2) return;
      // Fire-and-forget persistence — update UI immediately
      TimezonePreferenceService().toggle();
      setState(() {
        _useGmt2 = gmt2;
        _selectedDate = _now;
        _calculateRange(_selectedDate!, _selectedPeriod);
      });
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(
            icon: Icons.schedule_rounded,
            label: 'Local',
            isSelected: !_useGmt2,
            onTap: () => handleToggle(false),
          ),
          _buildToggleOption(
            icon: Icons.public_rounded,
            label: 'GMT+2',
            isSelected: _useGmt2,
            onTap: () => handleToggle(true),
          ),
        ],
      ),
    );
  }

  /// Compact toggle switch for Graph/Calendar view modes
  Widget _buildViewModeToggle() {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(
            icon: Icons.bar_chart_rounded,
            label: 'Graph',
            isSelected: _viewMode == HistoryViewMode.list,
            onTap: () => setState(() => _viewMode = HistoryViewMode.list),
          ),
          _buildToggleOption(
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            isSelected: _viewMode == HistoryViewMode.calendar,
            onTap: () => setState(() => _viewMode = HistoryViewMode.calendar),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _teamColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? _teamColor : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _teamColor : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<Run> runs, HistoryPeriod period) {
    // Prepare data buckets for distance and pace
    final Map<int, double> distanceBuckets = {};
    final Map<int, double> durationBuckets = {}; // in minutes
    int minX = 0;
    int maxX = 6;

    // Chart displays based on new period mapping:
    // DAY: Show days of month (calendar shows month)
    // WEEK: Show 7 days
    // MONTH: Show 12 months (calendar shows year)
    // YEAR: Show 5 years

    if (period == HistoryPeriod.day) {
      // DAY period shows month data (to match month calendar)
      minX = 1;
      final daysInMonth = DateTime(
        _rangeStart.year,
        _rangeStart.month + 1,
        0,
      ).day;
      maxX = daysInMonth;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        if (displayTime.year == _rangeStart.year &&
            displayTime.month == _rangeStart.month) {
          final day = displayTime.day;
          distanceBuckets[day] = (distanceBuckets[day] ?? 0) + run.distanceKm;
          durationBuckets[day] =
              (durationBuckets[day] ?? 0) + run.duration.inSeconds / 60.0;
        }
      }
    } else if (period == HistoryPeriod.week) {
      // Week: 7 days starting from _rangeStart (index 0-6)
      minX = 0;
      maxX = 6;
      final rangeStartDate = DateTime(
        _rangeStart.year,
        _rangeStart.month,
        _rangeStart.day,
      );
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        final runDate = DateTime(
          displayTime.year,
          displayTime.month,
          displayTime.day,
        );
        final dayOffset = runDate.difference(rangeStartDate).inDays;
        if (dayOffset >= 0 && dayOffset <= 6) {
          distanceBuckets[dayOffset] =
              (distanceBuckets[dayOffset] ?? 0) + run.distanceKm;
          durationBuckets[dayOffset] =
              (durationBuckets[dayOffset] ?? 0) + run.duration.inSeconds / 60.0;
        }
      }
    } else if (period == HistoryPeriod.month) {
      // MONTH period shows year data (12 months - calendar shows year)
      minX = 1;
      maxX = 12;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        if (displayTime.year == _rangeStart.year) {
          final month = displayTime.month;
          distanceBuckets[month] =
              (distanceBuckets[month] ?? 0) + run.distanceKm;
          durationBuckets[month] =
              (durationBuckets[month] ?? 0) + run.duration.inSeconds / 60.0;
        }
      }
    } else {
      // YEAR period shows 5 years
      final currentYear = _now.year;
      minX = currentYear - 4;
      maxX = currentYear;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        final year = displayTime.year;
        if (year >= minX && year <= maxX) {
          distanceBuckets[year] = (distanceBuckets[year] ?? 0) + run.distanceKm;
          durationBuckets[year] =
              (durationBuckets[year] ?? 0) + run.duration.inSeconds / 60.0;
        }
      }
    }

    // Calculate max distance for normalization
    double maxY = 0;
    for (int i = minX; i <= maxX; i++) {
      final val = distanceBuckets[i] ?? 0.0;
      if (val > maxY) maxY = val;
    }
    if (maxY == 0) maxY = 5;

    // Build bar entries with pace (show all positions for consistent spacing)
    final entries = <_BarEntry>[];
    double minPace = double.infinity;
    double maxPace = 0;

    for (int i = minX; i <= maxX; i++) {
      final distance = distanceBuckets[i] ?? 0.0;
      final duration = durationBuckets[i] ?? 0.0;
      double? pace;

      if (distance > 0 && duration > 0) {
        pace = duration / distance; // min/km
        // Cap pace at 10 min/km (slower paces show at bottom)
        if (pace > 10.0) pace = 10.0;
      }

      entries.add(
        _BarEntry(
          x: i,
          value: distance,
          pace: pace,
          label: _getLabel(i, period),
        ),
      );
    }

    // Fixed pace range: 0-10 min/km
    // 0 min/km at top (fastest), 10 min/km at bottom (slowest)
    minPace = 0.0;
    maxPace = 10.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Bar chart layer with value labels on top
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: entries.map((entry) {
                    final fraction = entry.value / maxY;
                    final hasValue = entry.value > 0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Value label on top of bar
                            if (hasValue)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  _formatValueWithK(entry.value),
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            // Bar
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: fraction.clamp(0.02, 1.0),
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: hasValue
                                        ? AppTheme.electricBlue.withValues(
                                            alpha: 0.7,
                                          )
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Pace line overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PaceLinePainter(
                      entries: entries,
                      maxPace: maxPace,
                      minPace: minPace,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // X-axis labels
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
          // Legend
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Distance',
                style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
              ),
              const SizedBox(width: 16),
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Pace',
                style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLabel(int value, HistoryPeriod period) {
    if (period == HistoryPeriod.day) {
      // DAY period shows month days - show labels at day 1, 7, 14, 21, 28
      return (value == 1 || value % 7 == 0) ? '$value' : '';
    } else if (period == HistoryPeriod.week) {
      // Use range start to calculate the date for each bar
      final date = _rangeStart.add(Duration(days: value));
      return DateFormat.E().format(date)[0];
    } else if (period == HistoryPeriod.month) {
      // MONTH period shows 12 months
      if (value >= 1 && value <= 12) {
        final d = DateTime(_rangeStart.year, value);
        return DateFormat.MMM().format(d)[0];
      }
      return '';
    } else {
      // YEAR period shows years
      return value.toString().substring(
        2,
      ); // Just last 2 digits: "22", "23", etc.
    }
  }

  Widget _buildRunTile(Run run) {
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
                      _formatPace(run.avgPaceMinPerKm),
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
                color: _teamColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _teamColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${run.flipPoints}',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _teamColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'pts',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: _teamColor.withOpacity(0.7),
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

  /// Build run list for entire range (when no specific day is selected)
  Widget _buildRangeRunsList(List<Run> runs) {
    if (runs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 32,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 8),
            Text(
              'No runs in this ${_selectedPeriod.name}',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white30),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Range header - minimal
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatRangeDisplay(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${runs.length} run${runs.length > 1 ? 's' : ''}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white30),
            ),
            const Spacer(),
            // Subtle hint
            Text(
              'tap day',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Colors.white.withOpacity(0.2),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Compact run list
        ...runs
            .take(10)
            .map(
              (run) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildRunTile(run),
              ),
            ),
        if (runs.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                '+${runs.length - 10} more runs',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white30),
              ),
            ),
          ),
      ],
    );
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm.isInfinite || paceMinPerKm.isNaN || paceMinPerKm == 0) {
      return "-'--";
    }
    final min = paceMinPerKm.floor();
    final sec = ((paceMinPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}";
  }

  /// Format large numbers with K suffix (e.g., 10232 → "10.2K")
  String _formatCompact(num value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(1)}K';
    }
    return value is double ? value.toStringAsFixed(1) : value.toString();
  }

  /// Format large integers with K suffix (e.g., 58822 → "58.8K")
  String _formatCompactInt(int value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  /// Format bar chart values to be compact (single line)
  /// < 10: one decimal (e.g., "5.2")
  /// >= 10 and < 1000: no decimal (e.g., "42")
  /// >= 1000: K suffix (e.g., "1.2K")
  String _formatValueWithK(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(1)}K';
    } else if (value >= 10) {
      return value.round().toString();
    } else {
      return value.toStringAsFixed(1);
    }
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

  /// Calculate weighted average stability score from runs
  /// Only includes runs >= 1km with valid stability scores
  /// Weight is based on distance (longer runs count more)
  int? _calculateWeightedStability(List<Run> runs) {
    double totalWeight = 0.0;
    double weightedSum = 0.0;

    for (final run in runs) {
      // Only include runs >= 1km with valid stability score
      if (run.distanceKm >= 1.0 && run.stabilityScore != null) {
        final weight = run.distanceKm;
        weightedSum += run.stabilityScore! * weight;
        totalWeight += weight;
      }
    }

    if (totalWeight == 0) return null;
    return (weightedSum / totalWeight).round().clamp(0, 100);
  }

  List<Run> _runsForDate(List<Run> runs, DateTime date) {
    return runs.where((run) {
      final displayTime = _convertToDisplayTimezone(run.startTime);
      return displayTime.year == date.year &&
          displayTime.month == date.month &&
          displayTime.day == date.day;
    }).toList();
  }

  List<Run> _filterRunsByPeriod(
    List<Run> runs,
    HistoryPeriod period,
  ) {
    // Filter runs by the current range boundaries (for chart/calendar)
    return runs.where((run) {
      final displayTime = _convertToDisplayTimezone(run.startTime);
      final runDate = DateTime(
        displayTime.year,
        displayTime.month,
        displayTime.day,
      );
      final rangeStartDate = DateTime(
        _rangeStart.year,
        _rangeStart.month,
        _rangeStart.day,
      );
      final rangeEndDate = DateTime(
        _rangeEnd.year,
        _rangeEnd.month,
        _rangeEnd.day,
      );
      return !runDate.isBefore(rangeStartDate) &&
          !runDate.isAfter(rangeEndDate);
    }).toList();
  }

  /// Filter runs for stats panel based on the ACTUAL period meaning:
  /// - DAY: Today only
  /// - WEEK: Selected week range (Sun-Sat)
  /// - MONTH: Current month only
  /// - YEAR: Current year only
  List<Run> _filterRunsForStats(
    List<Run> runs,
    HistoryPeriod period,
  ) {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);

    DateTime statsStart;
    DateTime statsEnd;

    switch (period) {
      case HistoryPeriod.day:
        // Today only
        statsStart = today;
        statsEnd = today;
        break;
      case HistoryPeriod.week:
        // Selected week range (Sun-Sat based on _rangeStart)
        statsStart = DateTime(
          _rangeStart.year,
          _rangeStart.month,
          _rangeStart.day,
        );
        statsEnd = statsStart.add(const Duration(days: 6));
        break;
      case HistoryPeriod.month:
        // Current month only (not the navigated year)
        statsStart = DateTime(now.year, now.month, 1);
        statsEnd = DateTime(now.year, now.month + 1, 0); // Last day of month
        break;
      case HistoryPeriod.year:
        // Current year only (not 5-year range)
        statsStart = DateTime(now.year, 1, 1);
        statsEnd = DateTime(now.year, 12, 31);
        break;
    }

    return runs.where((run) {
      final displayTime = _convertToDisplayTimezone(run.startTime);
      final runDate = DateTime(
        displayTime.year,
        displayTime.month,
        displayTime.day,
      );
      return !runDate.isBefore(statsStart) && !runDate.isAfter(statsEnd);
    }).toList();
  }
}

/// Simple data class for bar chart entries with distance and pace.
class _BarEntry {
  final int x;
  final double value; // distance in km
  final double? pace; // pace in min/km (null if no runs)
  final String label;

  const _BarEntry({
    required this.x,
    required this.value,
    this.pace,
    required this.label,
  });
}

/// CustomPainter for drawing the pace line overlay on the bar chart.
class _PaceLinePainter extends CustomPainter {
  final List<_BarEntry> entries;
  final double maxPace;
  final double minPace;

  _PaceLinePainter({
    required this.entries,
    required this.maxPace,
    required this.minPace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    // Filter entries with valid pace values
    final pacePoints = <Offset>[];
    final barWidth = size.width / entries.length;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.pace != null && entry.value > 0) {
        final x = (i + 0.5) * barWidth;
        // Invert Y: lower pace = higher position (better performance)
        // Normalize pace between minPace and maxPace
        final paceRange = maxPace - minPace;
        final normalizedPace = paceRange > 0
            ? (entry.pace! - minPace) / paceRange
            : 0.5;
        // Inverted: lower pace (faster) = higher Y position
        final y = size.height * normalizedPace;
        pacePoints.add(Offset(x, y));
      }
    }

    if (pacePoints.length < 2) return;

    // Draw the pace line with glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = const Color(0xFF0A0E1A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Create smooth path
    final path = Path();
    path.moveTo(pacePoints[0].dx, pacePoints[0].dy);

    for (int i = 1; i < pacePoints.length; i++) {
      final p0 = pacePoints[i - 1];
      final p1 = pacePoints[i];
      // Simple line connection (can be enhanced with bezier curves)
      path.lineTo(p1.dx, p1.dy);
    }

    // Draw glow then line
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Draw dots at each data point
    for (final point in pacePoints) {
      canvas.drawCircle(point, 5, dotPaint);
      canvas.drawCircle(point, 5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaceLinePainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.maxPace != maxPace ||
        oldDelegate.minPace != minPace;
  }
}
