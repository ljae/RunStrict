# Draft: History Screen Redesign

## Requirements (confirmed)
- Move ALL-TIME stats section to fixed position at top (outside ScrollView)
- Period toggle (WEEK | MONTH | YEAR) should use Rankings screen minimal styling
- Range navigation should use Rankings screen minimal styling
- Reorder: Header → ALL-TIME Stats → Period Toggle → Range Navigation → ScrollView
- Remove ALL TIME section from inside CustomScrollView
- Keep period stats, calendar/chart, run list inside ScrollView

## Metis Review Findings

### Gap Classification

| Gap | Type | Resolution |
|-----|------|------------|
| Range nav tap-to-toggle behavior | AMBIGUOUS | DEFAULT: Keep behavior, just restyle visually |
| Landscape layout scope | AMBIGUOUS | DEFAULT: Update landscape similarly for consistency |
| "Fixed" position meaning | MINOR | DEFAULT: Restructure widget tree (not sticky) |
| Scroll behavior when ALL-TIME moves | MINOR | DEFAULT: ALL-TIME scrolls with page (in Column) |

### Guardrails from Metis
- MUST NOT modify HistoryPeriod enum (keep WEEK/MONTH/YEAR)
- MUST NOT touch _buildOverallStatsSection internals (just move it)
- MUST NOT add new visual effects (shadows, separators)
- MUST NOT change calendar widget or data logic
- MUST preserve existing tap-to-toggle behavior in range nav
- MUST copy EXACT styling values from Rankings

## Technical Decisions
- Only ONE file to modify: `lib/screens/run_history_screen.dart`
- Copy exact styling from `leaderboard_screen.dart` lines 578-686
- History screen has only 3 periods (WEEK/MONTH/YEAR) - no TOTAL option
- Landscape layout will also need similar reordering

## Research Findings

### Current Structure (Portrait - lines 243-428):
```
Column:
  - _buildHeader()
  - SizedBox(height: 10)
  - _buildRangeNavigation()     ← MOVE DOWN
  - SizedBox(height: 12)
  - _buildPeriodToggle()        ← MOVE UP
  - SizedBox(height: 24)
  - Expanded(CustomScrollView):
    - _buildOverallStatsSection()  ← MOVE OUT TO FIXED
    - SizedBox(height: 20)
    - Period Stats Row
    - Calendar/Chart
    - Run List
```

### Desired Structure (Portrait):
```
Column:
  - _buildHeader()
  - SizedBox(height: 10)
  - _buildOverallStatsSection()  ← NOW FIXED AT TOP
  - SizedBox(height: 12)
  - _buildPeriodToggle()         ← RANKINGS STYLE
  - SizedBox(height: 8)
  - _buildRangeNavigation()      ← RANKINGS STYLE
  - SizedBox(height: 16)
  - Expanded(CustomScrollView):
    - Period Stats Row
    - Calendar/Chart
    - Run List
```

### Rankings Period Toggle Styling (lines 578-625):
- Container height: 36
- Background: `AppTheme.surfaceColor.withValues(alpha: 0.3)`
- BorderRadius: 18
- Font: `GoogleFonts.inter`, fontSize: 11, letterSpacing: 0.5
- Selected: `Colors.white.withValues(alpha: 0.1)` background, white text, w600
- Unselected: transparent background, Colors.white38 text, w500
- No border on individual toggle items

### Rankings Range Navigation Styling (lines 628-686):
- Horizontal padding: 24
- Arrow icons: chevron_left/right_rounded, size 24, Colors.white54
- Arrow container: 32x32 with just alignment (no background)
- Center text: `GoogleFonts.inter`, fontSize: 13, w600, Colors.white70, letterSpacing: 0.5
- SizedBox(width: 8) between arrows and text
- Expanded text widget with center alignment

### Current Period Toggle Issues (lines 806-856):
- Uses padding 4, opacity 0.6
- BorderRadius 16 (should be 18)
- Has border on selected items
- Font size 12 (should be 11)

### Current Range Navigation Issues (lines 708-803):
- Has circular container with background color
- Uses complex range display with GestureDetector for mode toggle
- Uses Sora font (should be Inter)
- Font size 16 (should be 13)
- Has elaborate styling that needs simplification

## Scope Boundaries
- INCLUDE: Portrait layout changes
- INCLUDE: Landscape layout changes (similar reordering)
- INCLUDE: Period toggle styling update
- INCLUDE: Range navigation styling update
- EXCLUDE: Any logic changes (filtering, range calculation)
- EXCLUDE: Any new features

## Open Questions
- None - all requirements are clear from user context
