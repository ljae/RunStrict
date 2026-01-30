# History Screen Layout Alignment - Rankings-Style Design

## TL;DR

> **Quick Summary**: Restructure History screen to move ALL-TIME stats to fixed top position, and restyle period toggle + range navigation to match Rankings screen's minimal design.
> 
> **Deliverables**:
> - ALL-TIME stats section moved to top (outside ScrollView)
> - Period toggle restyled (height 36, borderRadius 18, Inter 11px)
> - Range navigation restyled (simpler arrows, Inter 13px)
> - Both portrait and landscape layouts updated
> 
> **Estimated Effort**: Quick
> **Parallel Execution**: NO - sequential (changes affect same file/methods)
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 4

---

## Context

### Original Request
User requested:
- "put all-time record top of the screen"
- "copy minimal design of date selection (except total) in rankings"
- "put it right below all-time record"
- "being aligned with whole design concept"

### Interview Summary
**Key Discussions**:
- ALL-TIME stats: Move from inside CustomScrollView to fixed position above it
- Period toggle: Copy Rankings styling (height 36, simpler design)
- Range navigation: Copy Rankings styling (simpler arrows, Inter font)
- History has 3 periods (WEEK/MONTH/YEAR) - no TOTAL option like Rankings

**Research Findings**:
- Current period toggle at lines 806-856 uses borderRadius 16, font 12px
- Target styling at leaderboard_screen.dart lines 578-625 uses height 36, borderRadius 18, font 11px
- Current range nav at lines 708-803 has complex purple styling with Sora font
- Target styling at leaderboard_screen.dart lines 628-686 uses simple 32x32 arrows, Inter 13px

### Metis Review
**Identified Gaps** (addressed):
- Range nav tap-to-toggle behavior: Keep behavior, just restyle visually
- Landscape layout scope: Update similarly for consistency
- "Fixed" position meaning: Restructure widget tree (not sticky)

---

## Work Objectives

### Core Objective
Restructure History screen layout and update styling to match Rankings screen's minimal design, while preserving all existing functionality.

### Concrete Deliverables
- `lib/screens/run_history_screen.dart` - Updated with new layout structure and styling

### Definition of Done
- [ ] `flutter analyze lib/screens/run_history_screen.dart` returns no errors
- [ ] `flutter test` passes all existing tests
- [ ] Portrait layout: ALL-TIME → Period Toggle → Range Nav → ScrollView
- [ ] Period toggle matches Rankings styling values
- [ ] Range navigation matches Rankings styling values

### Must Have
- ALL-TIME stats section at top (outside ScrollView) in portrait mode
- Period toggle with height 36, borderRadius 18
- Range navigation with Inter font 13px, simple arrow icons
- Preserve existing tap-to-toggle behavior in range nav
- Both portrait and landscape layouts updated

### Must NOT Have (Guardrails)
- DO NOT modify HistoryPeriod enum (keep WEEK/MONTH/YEAR - no TOTAL)
- DO NOT touch `_buildOverallStatsSection` internals (just move widget call)
- DO NOT add new visual effects (shadows, separators, borders)
- DO NOT change calendar widget (`_buildCalendarContainer`)
- DO NOT modify data fetching, filtering, or calculation logic
- DO NOT change chart or run list rendering
- DO NOT remove tap-to-toggle functionality from range navigation

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test)
- **User wants tests**: Manual-only (UI changes)
- **Framework**: flutter test (existing)

### Automated Verification

Each TODO includes executable verification that agents can run directly:

**Verification Tools:**
| Type | Tool | Command |
|------|------|---------|
| Static analysis | flutter analyze | `flutter analyze lib/screens/run_history_screen.dart` |
| Test suite | flutter test | `flutter test` |
| Structure check | grep | Verify widget order in build method |

---

## Task Dependency Graph

| Task | Depends On | Reason |
|------|------------|--------|
| Task 1 | None | Foundation - restructure portrait layout first |
| Task 2 | Task 1 | Landscape layout follows portrait pattern |
| Task 3 | Task 2 | Style period toggle after layout is stable |
| Task 4 | Task 3 | Style range nav last (most complex styling change) |

---

## Parallel Execution Graph

```
Wave 1 (Sequential execution required):
└── Task 1: Portrait Layout Restructure
    └── Task 2: Landscape Layout Restructure
        └── Task 3: Period Toggle Styling
            └── Task 4: Range Navigation Styling

Critical Path: Task 1 → Task 2 → Task 3 → Task 4
Parallel Speedup: N/A (sequential changes to same file)
```

---

## TODOs

### Task 1: Portrait Layout Restructure

**What to do**:
1. In `build()` method (around line 241-428), restructure the portrait Column children:
   - Keep `_buildHeader()` first
   - Move `_buildOverallStatsSection()` call from inside CustomScrollView to right after header (with padding)
   - Move `_buildPeriodToggle()` after ALL-TIME stats
   - Move `_buildRangeNavigation()` after period toggle
   - Update CustomScrollView to start with period stats (remove ALL-TIME sliver)

2. Current order (lines 244-425):
   ```dart
   _buildHeader(),
   SizedBox(height: 10),
   _buildRangeNavigation(),        // Move down
   SizedBox(height: 12),
   _buildPeriodToggle(),           // Move up
   SizedBox(height: 24),
   Expanded(CustomScrollView(...)) // Remove ALL-TIME from here
   ```

3. New order:
   ```dart
   _buildHeader(),
   SizedBox(height: 10),
   Padding(
     padding: const EdgeInsets.symmetric(horizontal: 24),
     child: _buildOverallStatsSection(...),
   ),
   SizedBox(height: 12),
   _buildPeriodToggle(),
   SizedBox(height: 8),
   _buildRangeNavigation(),
   SizedBox(height: 16),
   Expanded(CustomScrollView(...))  // WITHOUT the ALL-TIME SliverToBoxAdapter
   ```

4. Remove from CustomScrollView (lines 268-284):
   ```dart
   // REMOVE this SliverToBoxAdapter:
   SliverToBoxAdapter(
     child: Padding(
       padding: const EdgeInsets.symmetric(horizontal: 24),
       child: _buildOverallStatsSection(...),
     ),
   ),
   const SliverToBoxAdapter(child: SizedBox(height: 20)),
   ```

**Must NOT do**:
- DO NOT change any calculation logic for overallDistance, overallPace, etc.
- DO NOT change `_buildOverallStatsSection` method implementation
- DO NOT add new widgets or visual elements

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Straightforward widget tree restructuring, single file, clear instructions
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter/Dart development specialist for widget restructuring

**Skills Evaluated but Omitted**:
- `frontend-ui-ux`: Not needed - no new design work, just restructuring
- `typescript-programmer`: Wrong language domain

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Sequential
- **Blocks**: Task 2, Task 3, Task 4
- **Blocked By**: None (starting task)

**References**:

**Pattern References** (existing code to follow):
- `lib/screens/run_history_screen.dart:244-249` - Current portrait Column structure
- `lib/screens/run_history_screen.dart:264-280` - Current CustomScrollView with ALL-TIME

**API/Type References**:
- `lib/screens/run_history_screen.dart:906-995` - `_buildOverallStatsSection()` method signature

**Why Each Reference Matters**:
- Lines 244-249: Shows current Column children order that needs reordering
- Lines 264-280: Shows the SliverToBoxAdapter wrapping ALL-TIME that needs removal
- Lines 906-995: Confirms method takes 4 params (distance, pace, points, runCount)

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
flutter analyze lib/screens/run_history_screen.dart
# Assert: No errors, no warnings about the modified code

# Structure verification:
grep -n "_buildOverallStatsSection\|CustomScrollView\|_buildPeriodToggle\|_buildRangeNavigation" lib/screens/run_history_screen.dart | head -20
# Assert: _buildOverallStatsSection appears BEFORE CustomScrollView line
# Assert: _buildOverallStatsSection does NOT appear inside SliverToBoxAdapter in portrait
# Assert: Order is: Header → OverallStats → PeriodToggle → RangeNav → ScrollView
```

**Evidence to Capture:**
- [ ] Terminal output from `flutter analyze` showing no errors
- [ ] grep output showing correct widget order

**Commit**: NO (groups with Task 4 for single commit)

---

### Task 2: Landscape Layout Restructure

**What to do**:
1. In `_buildLandscapeLayout()` method (lines 437-519), restructure left column:
   - Keep `_buildOverallStatsSection()` at top of left column (already there)
   - Move `_buildPeriodToggle()` before `_buildRangeNavigation()`

2. Current order in left column (lines 457-476):
   ```dart
   _buildOverallStatsSection(...),
   SizedBox(height: 16),
   _buildRangeNavigation(),        // Move down
   SizedBox(height: 12),
   _buildPeriodToggle(),           // Move up
   SizedBox(height: 16),
   _buildStatsRow(...),
   ```

3. New order:
   ```dart
   _buildOverallStatsSection(...),
   SizedBox(height: 12),
   _buildPeriodToggle(),           // Now second
   SizedBox(height: 8),
   _buildRangeNavigation(),        // Now third
   SizedBox(height: 16),
   _buildStatsRow(...),
   ```

**Must NOT do**:
- DO NOT change right column structure
- DO NOT change calendar/chart rendering in left column

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Simple reordering of existing widgets
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter/Dart development for widget ordering

**Skills Evaluated but Omitted**:
- `frontend-ui-ux`: Not needed - no new design

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Sequential
- **Blocks**: Task 3, Task 4
- **Blocked By**: Task 1

**References**:

**Pattern References**:
- `lib/screens/run_history_screen.dart:437-519` - Current landscape layout method
- `lib/screens/run_history_screen.dart:457-476` - Left column widget order

**Why Each Reference Matters**:
- Lines 437-519: Full landscape method to understand structure
- Lines 457-476: Specific lines that need reordering

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
flutter analyze lib/screens/run_history_screen.dart
# Assert: No errors

# Verify landscape order:
sed -n '437,519p' lib/screens/run_history_screen.dart | grep -n "buildOverallStatsSection\|buildPeriodToggle\|buildRangeNavigation"
# Assert: Order is OverallStats → PeriodToggle → RangeNav
```

**Evidence to Capture:**
- [ ] Terminal output confirming no analyze errors
- [ ] grep output showing correct landscape widget order

**Commit**: NO (groups with Task 4)

---

### Task 3: Period Toggle Styling Update

**What to do**:
1. Update `_buildPeriodToggle()` method (lines 806-856) to match Rankings styling:

2. Current styling:
   ```dart
   Container(
     margin: const EdgeInsets.symmetric(horizontal: 24),
     padding: const EdgeInsets.all(4),
     decoration: BoxDecoration(
       color: AppTheme.surfaceColor.withOpacity(0.6),
       borderRadius: BorderRadius.circular(16),
       border: Border.all(color: Colors.white.withOpacity(0.05)),
     ),
     // ... AnimatedContainer with padding vertical: 10, borderRadius 12
     // ... Text with fontSize 12
   )
   ```

3. New styling (copy from Rankings lines 578-624):
   ```dart
   Padding(
     padding: const EdgeInsets.symmetric(horizontal: 24),
     child: Container(
       height: 36,
       decoration: BoxDecoration(
         color: AppTheme.surfaceColor.withValues(alpha: 0.3),
         borderRadius: BorderRadius.circular(18),
       ),
       child: Row(
         children: HistoryPeriod.values.map((period) {
           final isSelected = _selectedPeriod == period;
           return Expanded(
             child: GestureDetector(
               onTap: () { /* existing logic */ },
               child: AnimatedContainer(
                 duration: const Duration(milliseconds: 200),
                 decoration: BoxDecoration(
                   color: isSelected
                       ? Colors.white.withValues(alpha: 0.1)
                       : Colors.transparent,
                   borderRadius: BorderRadius.circular(18),
                 ),
                 alignment: Alignment.center,
                 child: Text(
                   period.name.toUpperCase(),
                   style: GoogleFonts.inter(
                     fontSize: 11,
                     fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
   )
   ```

4. Key changes:
   - Container: Remove padding, add `height: 36`
   - borderRadius: 16 → 18
   - Background opacity: 0.6 → 0.3 (use `withValues(alpha:)`)
   - Remove outer border
   - AnimatedContainer: Remove padding, add `alignment: Alignment.center`, borderRadius 12 → 18
   - Remove inner border on selected state
   - Font size: 12 → 11
   - Duration: Use `const Duration(milliseconds: 200)` instead of AppTheme.fastDuration

**Must NOT do**:
- DO NOT change the onTap logic (`_calculateRange` call)
- DO NOT change HistoryPeriod.values iteration
- DO NOT add TOTAL period

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Direct styling value updates, copy from reference
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter styling patterns

**Skills Evaluated but Omitted**:
- `frontend-ui-ux`: Not needed - copying existing design

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Sequential
- **Blocks**: Task 4
- **Blocked By**: Task 2

**References**:

**Pattern References** (CRITICAL - copy exact values):
- `lib/screens/leaderboard_screen.dart:578-624` - Rankings period toggle (THE SOURCE)
- `lib/screens/run_history_screen.dart:806-856` - Current History toggle (THE TARGET)

**Why Each Reference Matters**:
- leaderboard lines 578-624: EXACT values to copy (height, borderRadius, colors, fonts)
- run_history lines 806-856: Method to modify, preserve onTap logic

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
flutter analyze lib/screens/run_history_screen.dart
# Assert: No errors

# Verify styling values:
grep -A30 "_buildPeriodToggle" lib/screens/run_history_screen.dart | grep -E "height:|borderRadius|fontSize:|withValues"
# Assert: Contains "height: 36"
# Assert: Contains "borderRadius.circular(18)"
# Assert: Contains "fontSize: 11"
# Assert: Contains "withValues(alpha: 0.3)" or "withValues(alpha: 0.1)"
```

**Evidence to Capture:**
- [ ] Terminal output from flutter analyze
- [ ] grep output showing new styling values

**Commit**: NO (groups with Task 4)

---

### Task 4: Range Navigation Styling Update

**What to do**:
1. Update `_buildRangeNavigation()` method (lines 708-803) to match Rankings styling while KEEPING tap-to-toggle behavior:

2. Current styling issues to fix:
   - Arrow buttons have circular background with `AppTheme.surfaceColor.withOpacity(0.4)`
   - Center text uses `GoogleFonts.sora` fontSize 16
   - Has purple dot indicator and border for range mode
   - Complex Container decorations

3. New styling (simplified like Rankings lines 628-686):
   - Arrow containers: Just 32x32 with alignment, NO background
   - Arrow icons: size 24, Colors.white54
   - Center text: `GoogleFonts.inter`, fontSize 13, w600, Colors.white70
   - SizedBox(width: 8) between arrows and text
   - KEEP the GestureDetector and tap logic on center area
   - REMOVE purple styling, dot indicator, and mode-based decorations

4. Simplified structure:
   ```dart
   Widget _buildRangeNavigation() {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 24),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           // Previous arrow - SIMPLIFIED
           GestureDetector(
             onTap: _navigatePrevious,
             child: Container(
               width: 32,
               height: 32,
               alignment: Alignment.center,
               child: Icon(
                 Icons.chevron_left_rounded,
                 color: Colors.white54,
                 size: 24,
               ),
             ),
           ),

           const SizedBox(width: 8),

           // Range display - SIMPLIFIED but keep tap behavior
           Expanded(
             child: GestureDetector(
               onTap: () {
                 if (_selectedDate != null) {
                   setState(() => _selectedDate = null);
                 } else {
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

           // Next arrow - SIMPLIFIED
           GestureDetector(
             onTap: _navigateNext,
             child: Container(
               width: 32,
               height: 32,
               alignment: Alignment.center,
               child: Icon(
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
   ```

5. REMOVED elements:
   - Purple color styling (`AppTheme.chaosPurple`)
   - Mode dot indicator
   - Container backgrounds on arrows
   - Border decorations
   - Padding (16 horizontal between arrows → 8)

**Must NOT do**:
- DO NOT remove tap-to-toggle functionality (the GestureDetector on center text)
- DO NOT remove `_navigatePrevious`, `_navigateNext`, `_jumpToToday` calls
- DO NOT change `_formatRangeDisplay()` method

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Styling simplification with clear reference
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter widget styling

**Skills Evaluated but Omitted**:
- `frontend-ui-ux`: Not needed - simplifying to existing design

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Sequential (final task)
- **Blocks**: None (final task)
- **Blocked By**: Task 3

**References**:

**Pattern References** (CRITICAL):
- `lib/screens/leaderboard_screen.dart:628-686` - Rankings range nav (THE SOURCE)
- `lib/screens/run_history_screen.dart:708-803` - Current History nav (THE TARGET)

**Why Each Reference Matters**:
- leaderboard lines 628-686: Simplified structure to copy
- run_history lines 708-803: Current complex method to simplify

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
flutter analyze lib/screens/run_history_screen.dart
# Assert: No errors

# Final full test
flutter test
# Assert: All tests pass

# Verify removed purple styling:
grep -c "chaosPurple" lib/screens/run_history_screen.dart
# Assert: Returns 0 (all purple references removed from this method)

# Verify new styling:
grep -A50 "_buildRangeNavigation" lib/screens/run_history_screen.dart | grep -E "width: 32|height: 32|fontSize: 13|GoogleFonts.inter"
# Assert: Contains width: 32, height: 32
# Assert: Contains fontSize: 13
# Assert: Contains GoogleFonts.inter (not Sora)
```

**Evidence to Capture:**
- [ ] Terminal output from flutter analyze (no errors)
- [ ] Terminal output from flutter test (all pass)
- [ ] grep output showing new styling values

**Commit**: YES
- Message: `style(history): align layout and styling with Rankings screen`
- Files: `lib/screens/run_history_screen.dart`
- Pre-commit: `flutter analyze && flutter test`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 4 | `style(history): align layout and styling with Rankings screen` | run_history_screen.dart | `flutter analyze && flutter test` |

Single commit at the end since all changes are related and should be atomic.

---

## Success Criteria

### Verification Commands
```bash
# Static analysis
flutter analyze lib/screens/run_history_screen.dart
# Expected: No errors

# Test suite
flutter test
# Expected: All tests pass

# Visual structure verification
grep -n "build.*Stats\|build.*Toggle\|build.*Nav\|CustomScrollView" lib/screens/run_history_screen.dart | head -30
# Expected: Correct widget ordering in both portrait and landscape
```

### Final Checklist
- [ ] ALL-TIME stats appears above ScrollView in portrait mode
- [ ] Period toggle has height 36, borderRadius 18, Inter 11px
- [ ] Range navigation has simple 32x32 arrows, Inter 13px
- [ ] Purple styling removed from range navigation
- [ ] Tap-to-toggle behavior still works in range navigation
- [ ] Landscape layout has correct order (OverallStats → PeriodToggle → RangeNav)
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass
