import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';

/// A calendar widget displaying running activity by day.
///
/// Shows a month grid with dot indicators for days with runs,
/// intensity based on distance/flips earned.
class RunCalendar extends StatefulWidget {
  final List<RunSession> runs;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<DateTime>? onMonthChanged;

  const RunCalendar({
    super.key,
    required this.runs,
    this.selectedDate,
    this.onDateSelected,
    this.onMonthChanged,
  });

  @override
  State<RunCalendar> createState() => _RunCalendarState();
}

class _RunCalendarState extends State<RunCalendar> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  void didUpdateWidget(RunCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != null &&
        widget.selectedDate != oldWidget.selectedDate) {
      _selectedDate = widget.selectedDate!;
    }
  }

  /// Group runs by date (year-month-day key)
  Map<String, List<RunSession>> get _runsByDate {
    final map = <String, List<RunSession>>{};
    for (final run in widget.runs) {
      final key = _dateKey(run.startTime);
      map.putIfAbsent(key, () => []).add(run);
    }
    return map;
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  List<RunSession> _runsForDate(DateTime date) {
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

  Widget _buildMonthHeader() {
    final monthName = _getMonthName(_currentMonth.month);
    final year = _currentMonth.year;

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
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final cells = <Widget>[];

    // Empty cells for days before the 1st
    for (int i = 0; i < startingWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
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

    // Calculate intensity based on total distance
    double intensity = 0;
    if (hasRuns) {
      final totalDistance = runs.fold(0.0, (sum, run) => sum + run.distanceKm);
      intensity = (totalDistance / 10).clamp(0.2, 1.0); // 10km = full intensity
    }

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
        child: Stack(
          alignment: Alignment.center,
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

            // Activity indicator (dot or ring)
            if (hasRuns)
              Positioned(
                bottom: 6,
                child: _buildActivityIndicator(runs, intensity),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityIndicator(List<RunSession> runs, double intensity) {
    final totalFlips = runs.fold(0, (sum, run) => sum + run.hexesColored);
    final color = totalFlips > 0 ? AppTheme.athleticRed : AppTheme.electricBlue;

    if (runs.length > 1) {
      // Multiple runs: show count badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: intensity),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${runs.length}',
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    // Single run: show dot
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color.withValues(alpha: intensity),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: intensity * 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
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
  final List<RunSession> runs;

  const SelectedDateRuns({super.key, required this.date, required this.runs});

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

  Widget _buildRunCard(RunSession run) {
    final timeStr =
        '${run.startTime.hour.toString().padLeft(2, '0')}:${run.startTime.minute.toString().padLeft(2, '0')}';

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
