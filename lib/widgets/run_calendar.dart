import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/run.dart';
import '../theme/app_theme.dart';

/// Display mode for the calendar - adapts shape based on period selection
enum CalendarDisplayMode { week, month, year }

/// A calendar widget displaying running activity by day.
///
/// Shows different layouts based on displayMode:
/// - week: Single row showing 7 days
/// - month: Full month grid (default)
/// - year: 12 mini-month overview
///
/// Supports two modes:
/// - Internal navigation (default): Widget manages its own navigation state
/// - External navigation: Parent controls range via [externalRangeStart]/[externalRangeEnd]
class RunCalendar extends StatefulWidget {
  final List<Run> runs;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<DateTime>? onMonthChanged;

  /// Display mode: week shows 7 days, month shows full grid, year shows 12 mini months
  final CalendarDisplayMode displayMode;

  /// Optional function to convert UTC time to display timezone.
  /// If not provided, times are displayed as-is (local time).
  final DateTime Function(DateTime)? timezoneConverter;

  /// External range start for parent-controlled navigation (optional).
  /// When provided, internal navigation controls are hidden.
  final DateTime? externalRangeStart;

  /// External range end for parent-controlled navigation (optional).
  final DateTime? externalRangeEnd;

  /// Callback when user wants to navigate to previous range (external control mode)
  final VoidCallback? onNavigatePrevious;

  /// Callback when user wants to navigate to next range (external control mode)
  final VoidCallback? onNavigateNext;

  const RunCalendar({
    super.key,
    required this.runs,
    this.selectedDate,
    this.onDateSelected,
    this.onMonthChanged,
    this.displayMode = CalendarDisplayMode.month,
    this.timezoneConverter,
    this.externalRangeStart,
    this.externalRangeEnd,
    this.onNavigatePrevious,
    this.onNavigateNext,
  });

  @override
  State<RunCalendar> createState() => _RunCalendarState();
}

class _RunCalendarState extends State<RunCalendar> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  late DateTime _currentWeekStart;
  late int _currentYear;

  /// Check if navigation is externally controlled by parent
  bool get _isExternallyControlled => widget.externalRangeStart != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _currentYear = _selectedDate.year;
    // Calculate week start (Sunday)
    final now = DateTime.now();
    _currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
  }

  @override
  void didUpdateWidget(RunCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != null &&
        widget.selectedDate != oldWidget.selectedDate) {
      _selectedDate = widget.selectedDate!;
    }
    // Reset navigation when display mode changes
    if (widget.displayMode != oldWidget.displayMode) {
      final now = DateTime.now();
      _currentMonth = DateTime(now.year, now.month);
      _currentYear = now.year;
      _currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
    }
  }

  /// Convert time using the provided timezone converter or return as-is
  DateTime _convertTime(DateTime time) {
    return widget.timezoneConverter?.call(time) ?? time;
  }

  /// Group runs by date (year-month-day key) in display timezone
  Map<String, List<Run>> get _runsByDate {
    final map = <String, List<Run>>{};
    for (final run in widget.runs) {
      final dateKey = DateFormat('yyyy-MM-dd').format(run.startTime);
      map.putIfAbsent(dateKey, () => []);
      map[dateKey]!.add(run);
    }
    return map;
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  List<Run> _runsForDate(DateTime date) {
    return _runsByDate[_dateKey(date)] ?? [];
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    widget.onMonthChanged?.call(_currentMonth);
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    widget.onMonthChanged?.call(_currentMonth);
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.displayMode) {
      case CalendarDisplayMode.week:
        return _buildWeekView();
      case CalendarDisplayMode.year:
        return _buildYearView();
      case CalendarDisplayMode.month:
      default:
        return Column(
          children: [
            _buildMonthHeader(),
            const SizedBox(height: 16),
            _buildWeekdayHeaders(),
            const SizedBox(height: 8),
            _buildCalendarGrid(),
          ],
        );
    }
  }

  // ============ WEEK VIEW ============
  Widget _buildWeekView() {
    return Column(
      children: [
        _buildWeekHeader(),
        const SizedBox(height: 16),
        _buildWeekdayHeaders(),
        const SizedBox(height: 8),
        _buildWeekRow(),
      ],
    );
  }

  Widget _buildWeekHeader() {
    // Use external range if provided, otherwise internal state
    final weekStart = _isExternallyControlled
        ? widget.externalRangeStart!
        : _currentWeekStart;
    final weekEnd = _isExternallyControlled
        ? widget.externalRangeEnd!
        : _currentWeekStart.add(const Duration(days: 6));

    final startFormat = DateFormat('MMM d');
    final endFormat = weekStart.month == weekEnd.month
        ? DateFormat('d, yyyy')
        : DateFormat('MMM d, yyyy');

    // When externally controlled, don't show navigation (parent handles it)
    if (_isExternallyControlled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(
            '${startFormat.format(weekStart)} - ${endFormat.format(weekEnd)}',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousWeek,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white54,
            iconSize: 28,
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                final now = DateTime.now();
                _currentWeekStart = now.subtract(
                  Duration(days: now.weekday % 7),
                );
              });
            },
            child: Text(
              '${startFormat.format(weekStart)} - ${endFormat.format(weekEnd)}',
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          IconButton(
            onPressed: _nextWeek,
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white54,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
  }

  Widget _buildWeekRow() {
    // Use external range if provided, otherwise internal state
    final weekStart = _isExternallyControlled
        ? widget.externalRangeStart!
        : _currentWeekStart;
    final days = <Widget>[];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      days.add(_buildWeekDayCell(date));
    }
    return Row(children: days);
  }

  Widget _buildWeekDayCell(DateTime date) {
    final runs = _runsForDate(date);
    final hasRuns = runs.isNotEmpty;
    final isToday = _isToday(date);
    final isSelected = _isSameDay(date, _selectedDate);
    final isFuture = date.isAfter(DateTime.now());

    // Calculate total distance for display
    final totalDistance = runs.fold(0.0, (sum, run) => sum + run.distanceKm);

    return Expanded(
      child: GestureDetector(
        onTap: isFuture
            ? null
            : () {
                setState(() => _selectedDate = date);
                widget.onDateSelected?.call(date);
              },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.electricBlue.withValues(alpha: 0.2)
                : hasRuns
                ? AppTheme.surfaceColor.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppTheme.electricBlue, width: 1.5)
                : isToday
                ? Border.all(color: Colors.white24, width: 1)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                date.day.toString(),
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isFuture
                      ? Colors.white12
                      : isSelected
                      ? AppTheme.electricBlue
                      : isToday
                      ? Colors.white
                      : Colors.white70,
                ),
              ),
              if (hasRuns) ...[
                const SizedBox(height: 4),
                Text(
                  '${totalDistance.toStringAsFixed(1)}k',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.electricBlue.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============ YEAR VIEW ============
  Widget _buildYearView() {
    return Column(
      children: [
        _buildYearHeader(),
        const SizedBox(height: 20),
        _buildYearGrid(),
      ],
    );
  }

  Widget _buildYearHeader() {
    // Use external range if provided, otherwise internal state
    final displayYear = _isExternallyControlled
        ? widget.externalRangeStart!.year
        : _currentYear;

    // When externally controlled, don't show navigation (parent handles it)
    if (_isExternallyControlled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(
            displayYear.toString(),
            style: GoogleFonts.bebasNeue(
              fontSize: 32,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentYear--),
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white54,
            iconSize: 28,
          ),
          GestureDetector(
            onTap: () => setState(() => _currentYear = DateTime.now().year),
            child: Text(
              _currentYear.toString(),
              style: GoogleFonts.bebasNeue(
                fontSize: 32,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _currentYear++),
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white54,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildYearGrid() {
    // Use external range year if provided, otherwise internal state
    final displayYear = _isExternallyControlled
        ? widget.externalRangeStart!.year
        : _currentYear;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        return _buildMiniMonth(month, displayYear);
      },
    );
  }

  Widget _buildMiniMonth(int month, [int? yearOverride]) {
    final year = yearOverride ?? _currentYear;
    final monthDate = DateTime(year, month);
    final isCurrentMonth =
        DateTime.now().year == year && DateTime.now().month == month;

    // Count runs in this month
    final monthRuns = widget.runs.where((run) {
      final displayTime = _convertTime(run.startTime);
      return displayTime.year == year && displayTime.month == month;
    }).toList();

    final hasRuns = monthRuns.isNotEmpty;
    final totalDistance = monthRuns.fold(
      0.0,
      (sum, run) => sum + run.distanceKm,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMonth = monthDate;
        });
        widget.onMonthChanged?.call(monthDate);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: hasRuns
              ? AppTheme.electricBlue.withValues(alpha: 0.1)
              : AppTheme.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: isCurrentMonth
              ? Border.all(color: AppTheme.electricBlue, width: 1.5)
              : Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMM').format(monthDate).toUpperCase(),
              style: GoogleFonts.bebasNeue(
                fontSize: 14,
                color: isCurrentMonth ? AppTheme.electricBlue : Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
            if (hasRuns) ...[
              const SizedBox(height: 2),
              Text(
                '${totalDistance.toStringAsFixed(0)}km',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricBlue.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '${monthRuns.length}r',
                style: GoogleFonts.inter(fontSize: 8, color: Colors.white38),
              ),
            ] else
              Text(
                '—',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    // Use external range if provided, otherwise internal state
    final displayMonth = _isExternallyControlled
        ? widget.externalRangeStart!
        : _currentMonth;
    final monthName = _getMonthName(displayMonth.month);
    final year = displayMonth.year;

    // When externally controlled, don't show navigation (parent handles it)
    if (_isExternallyControlled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Column(
            children: [
              Text(
                monthName.toUpperCase(),
                style: GoogleFonts.bebasNeue(
                  fontSize: 28,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                year.toString(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white54,
            iconSize: 28,
          ),
          GestureDetector(
            onTap: () {
              // Jump to current month
              setState(() {
                _currentMonth = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                );
              });
            },
            child: Column(
              children: [
                Text(
                  monthName.toUpperCase(),
                  style: GoogleFonts.bebasNeue(
                    fontSize: 28,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  year.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white54,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Row(
      children: weekdays.map((day) {
        final isWeekend = day == 'SUN' || day == 'SAT';
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isWeekend ? Colors.white24 : Colors.white38,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    // Use external range if provided, otherwise internal state
    final displayMonth = _isExternallyControlled
        ? widget.externalRangeStart!
        : _currentMonth;

    final daysInMonth = DateTime(
      displayMonth.year,
      displayMonth.month + 1,
      0,
    ).day;
    final firstDayOfMonth = DateTime(displayMonth.year, displayMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final cells = <Widget>[];

    // Empty cells for days before the 1st
    for (int i = 0; i < startingWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(displayMonth.year, displayMonth.month, day);
      cells.add(_buildDayCell(date, day));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: cells,
    );
  }

  Widget _buildDayCell(DateTime date, int day) {
    final runs = _runsForDate(date);
    final hasRuns = runs.isNotEmpty;
    final isToday = _isToday(date);
    final isSelected = _isSameDay(date, _selectedDate);
    final isFuture = date.isAfter(DateTime.now());

    // Calculate total distance for the day
    final totalDistance = hasRuns
        ? runs.fold(0.0, (sum, run) => sum + run.distanceKm)
        : 0.0;

    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              setState(() => _selectedDate = date);
              widget.onDateSelected?.call(date);
            },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.electricBlue.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.electricBlue, width: 1.5)
              : isToday
              ? Border.all(color: Colors.white24, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day number
            Text(
              day.toString(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isFuture
                    ? Colors.white12
                    : isSelected
                    ? AppTheme.electricBlue
                    : isToday
                    ? Colors.white
                    : Colors.white70,
              ),
            ),

            // Distance indicator (like week view)
            if (hasRuns) ...[
              const SizedBox(height: 2),
              Text(
                '${totalDistance.toStringAsFixed(1)}k',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricBlue.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

/// Shows runs for a selected date as a compact list.
class SelectedDateRuns extends StatelessWidget {
  final DateTime date;
  final List<Run> runs;

  /// Optional function to convert UTC time to display timezone.
  final DateTime Function(DateTime)? timezoneConverter;

  const SelectedDateRuns({
    super.key,
    required this.date,
    required this.runs,
    this.timezoneConverter,
  });

  /// Convert time using the provided timezone converter or return as-is
  DateTime _convertTime(DateTime time) {
    return timezoneConverter?.call(time) ?? time;
  }

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateHeader(),
        const SizedBox(height: 12),
        ...runs.map(
          (run) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildRunCard(run),
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader() {
    final dayName = _getDayName(date.weekday);
    final monthDay = '${_getMonthName(date.month)} ${date.day}';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.electricBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.electricBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppTheme.electricBlue,
              ),
              const SizedBox(width: 6),
              Text(
                '$dayName, $monthDay',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${runs.length} run${runs.length > 1 ? 's' : ''}',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildRunCard(Run run) {
    final displayTime = _convertTime(run.startTime);
    final timeStr =
        '${displayTime.hour.toString().padLeft(2, '0')}:${displayTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Distance
          Expanded(
            child: Row(
              children: [
                Text(
                  run.distanceKm.toStringAsFixed(2),
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'km',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),

          // Duration
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: Colors.white30),
              const SizedBox(width: 4),
              Text(
                _formatDuration(run.duration),
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),

          // Flips
          if (run.hexesColored > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.athleticRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+${run.hexesColored}',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.athleticRed,
                ),
              ),
            ),
          ],

          // Stability badge (if available)
          if (run.stabilityScore != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _getStabilityColor(
                  run.stabilityScore!,
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${run.stabilityScore}%',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getStabilityColor(run.stabilityScore!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_run_rounded,
            size: 32,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 8),
          Text(
            'No runs on this day',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white30),
          ),
        ],
      ),
    );
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

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
