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
  HistoryViewMode _viewMode = HistoryViewMode.list;
  DateTime? _selectedDate;
  String _timezone = 'Local';

  // Range-based navigation state
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

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

  /// Calculate range boundaries based on anchor date and period
  void _calculateRange(DateTime anchorDate, HistoryPeriod period) {
    switch (period) {
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
        // First to last day of month
        _rangeStart = DateTime(anchorDate.year, anchorDate.month, 1);
        _rangeEnd = DateTime(anchorDate.year, anchorDate.month + 1, 0);
        break;
      case HistoryPeriod.year:
        // Jan 1 to Dec 31
        _rangeStart = DateTime(anchorDate.year, 1, 1);
        _rangeEnd = DateTime(anchorDate.year, 12, 31);
        break;
    }
    // Clear selection - entire range is selected (range mode)
    _selectedDate = null;
  }

  /// Navigate to previous range (week/month/year)
  void _navigatePrevious() {
    DateTime newAnchor;
    switch (_selectedPeriod) {
      case HistoryPeriod.week:
        newAnchor = _rangeStart.subtract(const Duration(days: 7));
        break;
      case HistoryPeriod.month:
        newAnchor = DateTime(_rangeStart.year, _rangeStart.month - 1, 1);
        break;
      case HistoryPeriod.year:
        newAnchor = DateTime(_rangeStart.year - 1, 1, 1);
        break;
    }
    setState(() {
      _calculateRange(newAnchor, _selectedPeriod);
    });
  }

  /// Navigate to next range (week/month/year)
  void _navigateNext() {
    DateTime newAnchor;
    switch (_selectedPeriod) {
      case HistoryPeriod.week:
        newAnchor = _rangeStart.add(const Duration(days: 7));
        break;
      case HistoryPeriod.month:
        newAnchor = DateTime(_rangeStart.year, _rangeStart.month + 1, 1);
        break;
      case HistoryPeriod.year:
        newAnchor = DateTime(_rangeStart.year + 1, 1, 1);
        break;
    }
    setState(() {
      _calculateRange(newAnchor, _selectedPeriod);
    });
  }

  /// Jump to current period containing today
  void _jumpToToday() {
    setState(() {
      _calculateRange(DateTime.now(), _selectedPeriod);
    });
  }

  /// Format range display based on period
  String _formatRangeDisplay() {
    switch (_selectedPeriod) {
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
        // "JANUARY 2026"
        return DateFormat('MMMM yyyy').format(_rangeStart).toUpperCase();
      case HistoryPeriod.year:
        // "2026"
        return _rangeStart.year.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Initialize range based on current date and default period
    _calculateRange(_selectedDate!, _selectedPeriod);
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

            // Calculate OVERALL (all-time) Stats
            final overallDistance = allRuns.fold(
              0.0,
              (sum, run) => sum + run.distanceKm,
            );
            final overallPoints = allRuns.fold(
              0,
              (sum, run) => sum + run.hexesColored,
            );
            final overallRunCount = allRuns.length;
            double overallPace = 0.0;
            if (overallDistance > 0) {
              final overallSeconds = allRuns.fold(
                0,
                (sum, run) => sum + run.duration.inSeconds,
              );
              overallPace = (overallSeconds / 60.0) / overallDistance;
            }

            // Calculate PERIOD Stats
            final totalDistance = periodRuns.fold(
              0.0,
              (sum, run) => sum + run.distanceKm,
            );
            final totalPoints = periodRuns.fold(
              0,
              (sum, run) => sum + run.hexesColored,
            );
            final runCount = periodRuns.length;

            // Weighted average pace for period
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
                    // ALL-TIME stats at top (fixed, outside scroll)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildOverallStatsSection(
                        overallDistance,
                        overallPace,
                        overallPoints,
                        overallRunCount,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPeriodToggle(),
                    const SizedBox(height: 8),
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
                                    _selectedPeriod.name.toUpperCase(),
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
    List<RunSession> allRuns,
    List<RunSession> periodRuns,
    double totalDistance,
    double avgPace,
    int totalPoints,
    int runCount,
    double overallDistance,
    double overallPace,
    int overallPoints,
    int overallRunCount,
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
                ),
                const SizedBox(height: 12),
                _buildPeriodToggle(),
                const SizedBox(height: 8),
                _buildRangeNavigation(),
                const SizedBox(height: 16),
                _buildPeriodStatsSection(
                  totalDistance,
                  avgPace,
                  totalPoints,
                  runCount,
                  _selectedPeriod.name.toUpperCase(),
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

  Widget _buildCalendarContainer(List<RunSession> allRuns) {
    // Map period selection to calendar display mode
    CalendarDisplayMode displayMode;
    switch (_selectedPeriod) {
      case HistoryPeriod.week:
        displayMode = CalendarDisplayMode.week;
        break;
      case HistoryPeriod.year:
        displayMode = CalendarDisplayMode.year;
        break;
      case HistoryPeriod.month:
      default:
        displayMode = CalendarDisplayMode.month;
    }

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
          // Title - minimal
          Text(
            'HISTORY',
            style: GoogleFonts.sora(
              fontSize: isLandscape ? 18 : 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
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
                        ? Icons.bar_chart_rounded
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

  /// Unified range navigation with prev/next controls
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

          // Range display - tap to toggle range mode / jump to today
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedDate != null) {
                  // Exit day mode, enter range mode
                  setState(() => _selectedDate = null);
                } else {
                  // Jump to today's range
                  _jumpToToday();
                }
              },
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
                    _calculateRange(_selectedDate ?? DateTime.now(), period);
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

  /// Period stats section - smaller version of ALL TIME panel
  Widget _buildPeriodStatsSection(
    double distance,
    double pace,
    int flips,
    int runs,
    String periodLabel,
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
              // Distance - primary highlight
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          distance.toStringAsFixed(1),
                          style: GoogleFonts.sora(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'km',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStatSmall(_formatPace(pace), '/km'),
                      _buildMiniStatSmall(flips.toString(), 'flips'),
                      _buildMiniStatSmall(runs.toString(), 'runs'),
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
    return Column(
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
    );
  }

  /// Overall (all-time) stats section - minimal horizontal display
  Widget _buildOverallStatsSection(
    double distance,
    double pace,
    int flips,
    int runs,
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
          // Overall label
          Text(
            'ALL TIME',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.2),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          // Stats in a row with separators
          Row(
            children: [
              // Distance - primary highlight
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          distance.toStringAsFixed(0),
                          style: GoogleFonts.sora(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'km',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(_formatPace(pace), '/km'),
                      _buildMiniStat(flips.toString(), 'flips'),
                      _buildMiniStat(runs.toString(), 'runs'),
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

  /// Mini stat for overall section
  Widget _buildMiniStat(String value, String label) {
    return Column(
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
    // Prepare data buckets for distance and pace
    final Map<int, double> distanceBuckets = {};
    final Map<int, double> durationBuckets = {}; // in minutes
    int minX = 0;
    int maxX = 6;

    // Use range boundaries for bucketing
    if (period == HistoryPeriod.week) {
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
      // Month: days 1-N based on _rangeStart's month
      minX = 1;
      final daysInMonth = DateTime(
        _rangeStart.year,
        _rangeStart.month + 1,
        0,
      ).day;
      maxX = daysInMonth;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        // Only include runs from the range's month
        if (displayTime.year == _rangeStart.year &&
            displayTime.month == _rangeStart.month) {
          final day = displayTime.day;
          distanceBuckets[day] = (distanceBuckets[day] ?? 0) + run.distanceKm;
          durationBuckets[day] =
              (durationBuckets[day] ?? 0) + run.duration.inSeconds / 60.0;
        }
      }
    } else {
      // Year: months 1-12 based on _rangeStart's year
      minX = 1;
      maxX = 12;
      for (var run in runs) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        // Only include runs from the range's year
        if (displayTime.year == _rangeStart.year) {
          final month = displayTime.month;
          distanceBuckets[month] =
              (distanceBuckets[month] ?? 0) + run.distanceKm;
          durationBuckets[month] =
              (durationBuckets[month] ?? 0) + run.duration.inSeconds / 60.0;
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
                // Bar chart layer
                Row(
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
                                  ? AppTheme.electricBlue.withValues(alpha: 0.7)
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
    if (period == HistoryPeriod.week) {
      // Use range start to calculate the date for each bar
      final date = _rangeStart.add(Duration(days: value));
      return DateFormat.E().format(date)[0];
    } else if (period == HistoryPeriod.month) {
      // Show labels at day 1, 7, 14, 21, 28
      return (value == 1 || value % 7 == 0) ? '$value' : '';
    } else {
      if (value >= 1 && value <= 12) {
        final d = DateTime(_rangeStart.year, value);
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

  /// Build run list for entire range (when no specific day is selected)
  Widget _buildRangeRunsList(List<RunSession> runs) {
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
    // Filter runs by the current range boundaries
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
