# History Screen Redesign - Unified Range Navigation

## TL;DR

> **Quick Summary**: Redesign the History screen with unified date range navigation that works consistently across week/month/year periods, auto-selecting the last day of each range when navigating.
> 
> **Deliverables**:
> - Unified navigation controls (< [Range Display] >) replacing separate per-mode navigation
> - Range-based state management (`_rangeStart`, `_rangeEnd`) instead of single `_selectedDate`
> - Stats filtered by selected range (not "last N days from today")
> - Synchronized navigation between Calendar and Graph views
> - Deleted subtitle from header, minimal trendy design
> 
> **Estimated Effort**: Medium (4-6 hours)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 → Task 2 → Task 4 → Task 5

---

## Context

### Original Request
Redesign the History screen with unified date range navigation across all period modes (week/month/year), auto-selecting the last day of the range when navigating, and displaying stats for the entire selected range.

### Interview Summary
**Key Discussions**:
- **Navigation behavior**: Jump to period containing today; when switching period types, recalculate range based on currently selected date
- **Range display format**: Week "Jan 26 - Feb 1", Month "JANUARY 2026", Year "2026"
- **Stats display**: Total for ENTIRE selected range (not just selected date)
- **Calendar/Graph sync**: Both views maintain same selected range
- **Last day selection**: Auto-select last calendar day of range (e.g., Dec 31 for month, Saturday for week)
- **Chart scope**: Keep same structure (7/31/12 buckets), filtered to selected range

**Research Findings**:
- Current `run_history_screen.dart` (1313 lines) uses `_selectedDate` and `_filterRunsByPeriod()` with simple day count
- Current `run_calendar.dart` (944 lines) has separate navigation per mode (`_currentWeekStart`, `_currentMonth`, `_currentYear`)
- Navigation controls are duplicated in RunCalendar widget - need to lift state up to parent

### Self-Review Gap Analysis

**Identified Gaps (addressed)**:
- **Week start day**: Assume Sunday (current implementation uses `weekday % 7`). KEEP CURRENT.
- **Timezone handling**: Current `_convertToDisplayTimezone()` must be applied to range calculations. ADDRESSED in Task 2.
- **Landscape mode**: Current code has `_buildLandscapeLayout()`. MUST preserve but update for new navigation. ADDRESSED in Task 4.
- **Year boundary for week display**: "Jan 26 - Feb 1" - no year shown unless years differ. ADDRESSED in Task 3.

---

## Work Objectives

### Core Objective
Replace the current per-mode navigation with unified range-based navigation that works consistently across week/month/year periods.

### Concrete Deliverables
- Modified `lib/screens/run_history_screen.dart` with:
  - New state: `_rangeStart`, `_rangeEnd` (DateTime)
  - New methods: `_calculateRange()`, `_navigatePrevious()`, `_navigateNext()`
  - Updated `_buildHeader()` with unified navigation (deleted subtitle)
  - Updated `_filterRunsByPeriod()` to use range boundaries
  - Updated `_buildChart()` to use range boundaries
  - Updated `_buildCalendarContainer()` to pass range sync
- Modified `lib/widgets/run_calendar.dart` with:
  - New optional props for external range control
  - Callback for navigation events

### Definition of Done
- [ ] Navigation works identically in both Calendar and Graph views
- [ ] Switching period types recalculates range based on selected date
- [ ] Auto-selects last day of range when navigating prev/next
- [ ] Stats row shows totals for entire selected range
- [ ] Chart shows data for selected range (not "today - N days")
- [ ] Subtitle deleted from header
- [ ] `flutter analyze` passes with no new warnings
- [ ] Visual appearance matches minimal trendy design

### Must Have
- Unified < [Range] > navigation controls
- Range-based filtering for stats and runs list
- Auto-select last day of range on navigation
- Calendar/Graph view synchronization
- Preserved timezone conversion functionality
- Preserved landscape mode support

### Must NOT Have (Guardrails)
- **NO new files** - modify existing files only
- **NO changes to RunSession model** or data layer
- **NO changes to RunProvider** - keep data loading as-is
- **NO additional state management packages** - use existing setState
- **NO breaking changes to RunCalendar public API** - add optional props only
- **NO over-engineering** - keep solution simple and maintainable

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test exists, `test/widget_test.dart` present)
- **User wants tests**: Manual verification (UI changes are visual)
- **QA approach**: Manual verification via iOS Simulator + visual inspection

### Automated Verification (Manual QA Procedures)

Each task includes verification steps that can be executed via Flutter run.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Add range state and calculation methods
└── Task 3: Update RunCalendar for external range control

Wave 2 (After Wave 1):
├── Task 2: Update header with unified navigation (depends: 1)
└── Task 4: Update chart and filtering logic (depends: 1)

Wave 3 (After Wave 2):
└── Task 5: Integration and polish (depends: 2, 4)

Critical Path: Task 1 → Task 2 → Task 5
Parallel Speedup: ~30% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 4 | 3 |
| 2 | 1 | 5 | 4 |
| 3 | None | 5 | 1 |
| 4 | 1 | 5 | 2 |
| 5 | 2, 3, 4 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1, 3 | `visual-engineering` with Flutter skill |
| 2 | 2, 4 | `visual-engineering` with Flutter skill |
| 3 | 5 | `visual-engineering` with Flutter skill |

---

## TODOs

- [ ] 1. Add Range State and Calculation Methods

  **What to do**:
  - Add new state variables to `_RunHistoryScreenState`:
    ```dart
    DateTime _rangeStart = DateTime.now();
    DateTime _rangeEnd = DateTime.now();
    ```
  - Create `_calculateRange(DateTime anchorDate, HistoryPeriod period)` method:
    - For `week`: Calculate Sunday-Saturday containing anchorDate
    - For `month`: First day to last day of anchorDate's month
    - For `year`: Jan 1 to Dec 31 of anchorDate's year
  - Create `_getLastDayOfRange(DateTime start, DateTime end)` helper (just returns `end`)
  - Update `initState()` to call `_calculateRange(DateTime.now(), _selectedPeriod)`
  - Create `_navigatePrevious()` and `_navigateNext()` methods:
    - Calculate new range based on current `_rangeStart` and period
    - Auto-select last day of new range as `_selectedDate`

  **Must NOT do**:
  - Do not modify `_filterRunsByPeriod()` yet (Task 4)
  - Do not modify header UI yet (Task 2)
  - Do not change timezone handling - just use existing `_convertToDisplayTimezone()`

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Flutter UI state management, date calculations
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter 3.24+ / Dart 3.5+ development specialist

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 3)
  - **Blocks**: Tasks 2, 4
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/screens/run_history_screen.dart:24-28` - Current state variables (`_selectedPeriod`, `_selectedDate`)
  - `lib/screens/run_history_screen.dart:73-79` - `initState()` pattern with `addPostFrameCallback`
  - `lib/widgets/run_calendar.dart:56-58` - Week start calculation pattern (`now.weekday % 7`)

  **API/Type References**:
  - `lib/screens/run_history_screen.dart:11` - `HistoryPeriod` enum definition (week, month, year)

  **Documentation References**:
  - Dart DateTime API: `DateTime(year, month + 1, 0).day` gives last day of month
  - Week calculation: Sunday = 0 in this codebase (uses `weekday % 7`)

  **WHY Each Reference Matters**:
  - Lines 24-28 show where to add new state variables alongside existing ones
  - Lines 73-79 show initialization pattern to follow
  - run_calendar.dart:56-58 shows the exact week start calculation already in use

  **Acceptance Criteria**:

  **Automated Verification (using Bash for static analysis):**
  ```bash
  # Agent runs:
  cd /Users/jaelee/.gemini/antigravity/scratch/runner && flutter analyze lib/screens/run_history_screen.dart
  # Assert: No errors related to _rangeStart, _rangeEnd, _calculateRange
  # Assert: Exit code 0 or only pre-existing warnings
  ```

  **Manual Verification (via app inspection):**
  ```
  # After running flutter run:
  1. Open app, navigate to History screen
  2. Verify no crashes on load (range calculated correctly)
  3. Check debug prints show correct range values (add temporary debugPrint)
  ```

  **Evidence to Capture:**
  - [ ] Flutter analyze output showing no new errors
  - [ ] Debug print showing calculated range for current period

  **Commit**: YES
  - Message: `feat(history): add range state and calculation methods`
  - Files: `lib/screens/run_history_screen.dart`
  - Pre-commit: `flutter analyze lib/screens/run_history_screen.dart`

---

- [ ] 2. Update Header with Unified Navigation Controls

  **What to do**:
  - Modify `_buildHeader()` to:
    - DELETE the subtitle "Personal running statistics" (lines 450-462)
    - Add unified navigation row: `< [Range Display] >`
    - Keep emoji + "HISTORY" title
    - Keep timezone dropdown and view mode toggle
  - Create `_buildRangeNavigation()` widget:
    - Left chevron button calling `_navigatePrevious()`
    - Center text showing range (format varies by period)
    - Right chevron button calling `_navigateNext()`
    - Tap on center text jumps to "today" (current period containing now)
  - Create `_formatRangeDisplay()` method:
    - Week: "Jan 26 - Feb 1" (or "Dec 28 - Jan 3, 2027" if years differ)
    - Month: "JANUARY 2026"
    - Year: "2026"
  - Move period toggle below navigation (keep existing `_buildPeriodToggle()`)
  - When period toggle changes, recalculate range with current `_selectedDate` as anchor

  **Must NOT do**:
  - Do not modify chart logic (Task 4)
  - Do not modify RunCalendar widget (Task 3)
  - Do not change timezone dropdown functionality

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Flutter UI layout, widget composition
  - **Skills**: [`moai-lang-flutter`, `frontend-ui-ux`]
    - `moai-lang-flutter`: Flutter widget building
    - `frontend-ui-ux`: Minimal trendy design aesthetics

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/screens/run_history_screen.dart:399-502` - Current `_buildHeader()` implementation
  - `lib/screens/run_history_screen.dart:568-611` - `_buildPeriodToggle()` style pattern
  - `lib/widgets/run_calendar.dart:146-191` - Week header navigation pattern with IconButton

  **Style References**:
  - `lib/theme/app_theme.dart:13` - `electricBlue` color for accents
  - `lib/theme/app_theme.dart:36` - `textSecondary` for muted text
  - `lib/widgets/run_calendar.dart:175-179` - `GoogleFonts.bebasNeue` for range display

  **WHY Each Reference Matters**:
  - Lines 399-502 is the EXACT code to modify (header with subtitle to delete)
  - Lines 568-611 shows the design language for toggle buttons
  - run_calendar.dart:146-191 shows existing navigation pattern to unify

  **Acceptance Criteria**:

  **Automated Verification (using Bash):**
  ```bash
  # Agent runs:
  cd /Users/jaelee/.gemini/antigravity/scratch/runner && flutter analyze lib/screens/run_history_screen.dart
  # Assert: No errors
  
  # Verify subtitle is deleted:
  grep -n "Personal running statistics" lib/screens/run_history_screen.dart
  # Assert: No matches found (exit code 1)
  ```

  **Manual Verification (via Playwright browser for screenshots - if web build):**
  ```
  # After flutter run -d chrome (or iOS Simulator):
  1. Navigate to History screen
  2. Verify: No subtitle visible under "HISTORY"
  3. Verify: Navigation arrows visible with range display
  4. Tap left arrow → range updates to previous period
  5. Tap right arrow → range updates to next period
  6. Tap center text → jumps to today
  7. Switch period (Week→Month) → range recalculates
  ```

  **Evidence to Capture:**
  - [ ] Flutter analyze output
  - [ ] grep output confirming subtitle removed
  - [ ] Screenshot of new header design

  **Commit**: YES
  - Message: `feat(history): add unified range navigation, delete subtitle`
  - Files: `lib/screens/run_history_screen.dart`
  - Pre-commit: `flutter analyze lib/screens/run_history_screen.dart`

---

- [ ] 3. Update RunCalendar for External Range Control

  **What to do**:
  - Add optional props to `RunCalendar` widget:
    ```dart
    final DateTime? externalRangeStart;
    final DateTime? externalRangeEnd;
    final VoidCallback? onNavigatePrevious;
    final VoidCallback? onNavigateNext;
    ```
  - When `externalRangeStart` is provided:
    - Hide internal navigation controls (arrows)
    - Use external range for display
    - Call `onNavigatePrevious`/`onNavigateNext` callbacks instead of internal navigation
  - When `externalRangeStart` is null (default):
    - Keep existing behavior (internal navigation)
  - This ensures backward compatibility - existing usages don't break

  **Must NOT do**:
  - Do not change internal state management when external control not provided
  - Do not modify `SelectedDateRuns` widget
  - Do not change the visual layout of calendar grid itself

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Flutter widget API design, backward compatibility
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter widget patterns and state management

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 5
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/widgets/run_calendar.dart:16-41` - Current `RunCalendar` widget props
  - `lib/widgets/run_calendar.dart:133-144` - `_buildWeekView()` structure
  - `lib/widgets/run_calendar.dart:146-191` - `_buildWeekHeader()` with navigation

  **API/Type References**:
  - `lib/widgets/run_calendar.dart:8` - `CalendarDisplayMode` enum
  - `lib/widgets/run_calendar.dart:19-20` - `onDateSelected`, `onMonthChanged` callback patterns

  **WHY Each Reference Matters**:
  - Lines 16-41 show exactly where to add new optional props
  - Lines 133-144 and 146-191 show where navigation controls are rendered (to conditionally hide)
  - Lines 19-20 show existing callback pattern to follow for new callbacks

  **Acceptance Criteria**:

  **Automated Verification (using Bash):**
  ```bash
  # Agent runs:
  cd /Users/jaelee/.gemini/antigravity/scratch/runner && flutter analyze lib/widgets/run_calendar.dart
  # Assert: No errors
  
  # Verify new props exist:
  grep -n "externalRangeStart" lib/widgets/run_calendar.dart
  # Assert: Matches found (exit code 0)
  ```

  **Evidence to Capture:**
  - [ ] Flutter analyze output
  - [ ] grep output confirming new props added

  **Commit**: YES
  - Message: `feat(calendar): add external range control props for parent sync`
  - Files: `lib/widgets/run_calendar.dart`
  - Pre-commit: `flutter analyze lib/widgets/run_calendar.dart`

---

- [ ] 4. Update Chart and Filtering Logic

  **What to do**:
  - Update `_filterRunsByPeriod()` to use `_rangeStart` and `_rangeEnd`:
    ```dart
    List<RunSession> _filterRunsByPeriod(List<RunSession> runs, HistoryPeriod period) {
      return runs.where((run) {
        final displayTime = _convertToDisplayTimezone(run.startTime);
        return !displayTime.isBefore(_rangeStart) && !displayTime.isAfter(_rangeEnd);
      }).toList();
    }
    ```
  - Update `_buildChart()` to use range boundaries:
    - Week: Show 7 days starting from `_rangeStart`
    - Month: Show days 1-31 of `_rangeStart`'s month
    - Year: Show months 1-12 of `_rangeStart`'s year
  - Update `_getLabel()` to use range-based dates instead of "today - N"
  - Ensure stats row (`_buildStatsRow`) receives correctly filtered `periodRuns`

  **Must NOT do**:
  - Do not modify RunSession model
  - Do not change chart visual styling (colors, bar widths)
  - Do not remove the pace line overlay

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Flutter data filtering, chart logic
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Dart date handling and collection filtering

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 2)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/screens/run_history_screen.dart:1186-1204` - Current `_filterRunsByPeriod()` implementation
  - `lib/screens/run_history_screen.dart:749-937` - Current `_buildChart()` implementation
  - `lib/screens/run_history_screen.dart:939-955` - Current `_getLabel()` implementation

  **API/Type References**:
  - `lib/models/run_session.dart` - `RunSession.startTime` property
  - `lib/screens/run_history_screen.dart:59-71` - `_convertToDisplayTimezone()` method

  **WHY Each Reference Matters**:
  - Lines 1186-1204 is the EXACT method to modify (filtering logic)
  - Lines 749-937 is the chart code that needs range-based bucket calculation
  - Lines 939-955 shows label generation that needs range-aware dates

  **Acceptance Criteria**:

  **Automated Verification (using Bash):**
  ```bash
  # Agent runs:
  cd /Users/jaelee/.gemini/antigravity/scratch/runner && flutter analyze lib/screens/run_history_screen.dart
  # Assert: No errors
  
  # Verify _rangeStart is used in filtering:
  grep -n "_rangeStart" lib/screens/run_history_screen.dart | grep -v "^[0-9]*:\s*//"
  # Assert: Multiple matches in filtering and chart methods
  ```

  **Manual Verification:**
  ```
  # After flutter run:
  1. Navigate to History screen
  2. Navigate to a previous month with known runs
  3. Verify: Stats show totals for that month (not "last 30 days")
  4. Verify: Chart shows bars for that specific month
  5. Navigate to week view of same period
  6. Verify: Chart shows 7 bars for that specific week
  ```

  **Evidence to Capture:**
  - [ ] Flutter analyze output
  - [ ] grep output confirming range-based filtering

  **Commit**: YES
  - Message: `feat(history): update chart and filtering to use range boundaries`
  - Files: `lib/screens/run_history_screen.dart`
  - Pre-commit: `flutter analyze lib/screens/run_history_screen.dart`

---

- [ ] 5. Integration, Calendar Sync, and Polish

  **What to do**:
  - Update `_buildCalendarContainer()` to pass external range props to `RunCalendar`:
    ```dart
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
    )
    ```
  - Update `_buildLandscapeLayout()` to use unified navigation (same as portrait)
  - Ensure period toggle change recalculates range with `_selectedDate` as anchor
  - Polish: Verify consistent spacing, animations, and visual polish
  - Final cleanup: Remove any debug prints added during development

  **Must NOT do**:
  - Do not introduce new state management patterns
  - Do not change color palette or typography
  - Do not add new dependencies

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Flutter integration, UI polish
  - **Skills**: [`moai-lang-flutter`, `frontend-ui-ux`]
    - `moai-lang-flutter`: Flutter widget composition
    - `frontend-ui-ux`: Visual polish and consistency

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential - final)
  - **Blocks**: None (final task)
  - **Blocked By**: Tasks 2, 3, 4

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/screens/run_history_screen.dart:340-372` - Current `_buildCalendarContainer()`
  - `lib/screens/run_history_screen.dart:268-338` - Current `_buildLandscapeLayout()`
  - `lib/screens/run_history_screen.dart:581-582` - Period toggle onTap handler

  **Style References**:
  - `lib/theme/app_theme.dart:29-32` - Animation durations to use
  - `lib/theme/app_theme.dart:279-285` - Spacing constants

  **WHY Each Reference Matters**:
  - Lines 340-372 is where to add new props to RunCalendar
  - Lines 268-338 is landscape code that needs unified navigation
  - Lines 581-582 shows where to add range recalculation on period change

  **Acceptance Criteria**:

  **Automated Verification (using Bash):**
  ```bash
  # Agent runs:
  cd /Users/jaelee/.gemini/antigravity/scratch/runner && flutter analyze
  # Assert: No errors in entire project
  
  # Verify no debug prints left:
  grep -rn "debugPrint.*range" lib/screens/run_history_screen.dart
  # Assert: No matches (or only intentional logging)
  ```

  **Manual Verification (comprehensive test):**
  ```
  # After flutter run:
  
  ## Portrait Mode Tests:
  1. Open History screen → Verify clean header (no subtitle)
  2. Verify unified navigation visible
  3. Tap Week → navigate prev/next → verify range updates
  4. Tap Month → navigate prev/next → verify range updates
  5. Tap Year → navigate prev/next → verify range updates
  6. Switch to Calendar view → verify same range displayed
  7. Navigate in Calendar view → verify range syncs
  8. Select a date in calendar → verify runs list updates
  
  ## Landscape Mode Tests:
  9. Rotate device → verify layout adapts
  10. Verify navigation works in landscape
  
  ## Edge Cases:
  11. Navigate to future month → verify future dates grayed out
  12. Navigate to month with no runs → verify empty state
  13. Switch period while viewing past date → verify range recalculates
  ```

  **Evidence to Capture:**
  - [ ] Flutter analyze output (full project)
  - [ ] Screenshots of final design (portrait + landscape)
  - [ ] Video/GIF of navigation flow (optional)

  **Commit**: YES
  - Message: `feat(history): complete unified range navigation with calendar sync`
  - Files: `lib/screens/run_history_screen.dart`, `lib/widgets/run_calendar.dart`
  - Pre-commit: `flutter analyze`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(history): add range state and calculation methods` | run_history_screen.dart | flutter analyze |
| 2 | `feat(history): add unified range navigation, delete subtitle` | run_history_screen.dart | flutter analyze |
| 3 | `feat(calendar): add external range control props for parent sync` | run_calendar.dart | flutter analyze |
| 4 | `feat(history): update chart and filtering to use range boundaries` | run_history_screen.dart | flutter analyze |
| 5 | `feat(history): complete unified range navigation with calendar sync` | run_history_screen.dart, run_calendar.dart | flutter analyze (full) |

---

## Success Criteria

### Verification Commands
```bash
# Static analysis
flutter analyze
# Expected: No errors, no new warnings

# Run tests (if any)
flutter test
# Expected: All tests pass

# Build verification
flutter build ios --no-codesign
# Expected: Build succeeds
```

### Final Checklist
- [ ] Subtitle "Personal running statistics" is deleted
- [ ] Unified navigation < [Range] > works for all periods
- [ ] Auto-selects last day when navigating to new range
- [ ] Stats show totals for entire selected range
- [ ] Chart shows data for selected range (not "today - N days")
- [ ] Calendar and Graph views stay synchronized
- [ ] Landscape mode works correctly
- [ ] Timezone conversion preserved
- [ ] No new flutter analyze warnings
- [ ] All "Must NOT Have" items verified absent
