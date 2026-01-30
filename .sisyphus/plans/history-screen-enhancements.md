# History Screen Enhancements

## TL;DR

> **Quick Summary**: Replace text stat labels with emojis and change range navigation to select entire date range instead of auto-selecting the last day, with visual feedback for range vs. specific day selection.
> 
> **Deliverables**:
> - Stats header with emoji labels (🏃 ⏱️ 🔄 #️⃣)
> - Range selection behavior (null = whole range selected)
> - Visual feedback when in "range mode" vs "day mode"
> - Updated calendar/list views to handle range selection
> 
> **Estimated Effort**: Short (2-3 hours)
> **Parallel Execution**: NO - sequential (changes are interdependent)
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 4 → Task 5

---

## Context

### Original Request
User wants to enhance the History screen with:
1. Emoji labels instead of text (DISTANCE → 🏃, etc.)
2. When navigating to different ranges (week/month/year), select the RANGE not the last day
3. Running history should show ALL runs in the selected range when no specific day is picked

### Interview Summary
**Key Discussions**:
- Current `_buildStatsRow()` uses text labels - needs emoji replacement
- Line 102 sets `_selectedDate = _rangeEnd` - should be `null` for range mode
- List view already uses `_filterRunsByPeriod()` which works with range boundaries
- Calendar view needs to handle null `_selectedDate` (no day highlighted)

**Research Findings**:
- File is 1486 lines with Provider pattern
- Uses `AppTheme.electricBlue`, `AppTheme.athleticRed`, GoogleFonts
- `RunCalendar` widget has external range control
- `SelectedDateRuns` widget needs range-aware alternative

### Gap Analysis (Self-Review)
**Identified Gaps** (addressed in plan):
1. **Calendar mode behavior**: When `_selectedDate` is null, what shows below the calendar?
   - **Resolution**: Show a "Range Summary" widget or empty state prompting user to tap a day
2. **initState behavior**: On app launch, should default to range mode or today?
   - **Resolution**: Default to today selected (current behavior) for first load only
3. **Jump to Today behavior**: Should preserve range mode or select today?
   - **Resolution**: Select today specifically (switch from range mode)
4. **Emoji platform compatibility**: Emojis render differently across platforms
   - **Resolution**: Use simple, universal emojis that render consistently

---

## Work Objectives

### Core Objective
Transform the History screen stats header to use emoji labels and implement intelligent range selection that shows all runs in the selected period until a user explicitly taps a specific day.

### Concrete Deliverables
- Modified `_buildStatsRow()` with emoji labels
- Modified `_buildStatCard()` to accept emoji string
- Modified `_calculateRange()` to set `_selectedDate = null`
- Modified `_navigatePrevious()` and `_navigateNext()` to preserve null selection
- Visual feedback in range navigation showing selection state
- Updated calendar view to handle null selection (no highlight = range mode)
- New "Range Runs" widget or modified display for showing all runs when in range mode

### Definition of Done
- [ ] Stats row shows emojis instead of text labels
- [ ] Navigating ranges shows all runs for that range (not just last day)
- [ ] Tapping a specific day in calendar shows only that day's runs
- [ ] `flutter analyze` passes with no errors
- [ ] Visual verification on iOS simulator via Playwright

### Must Have
- Emoji labels visible and legible at current font sizes
- Range selection behavior for prev/next navigation
- Specific day selection when user taps calendar day
- Visual distinction between range mode and day mode

### Must NOT Have (Guardrails)
- NO changes to `run_calendar.dart` widget internals
- NO changes to chart logic or other screens
- NO new dependencies or packages
- NO changes to data models or providers
- NO breaking the existing calendar day selection functionality

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test available)
- **User wants tests**: Manual verification via flutter analyze + Playwright
- **Framework**: Flutter + Playwright for visual verification

### Automated Verification

Each TODO includes executable verification:

**For Flutter Code Changes:**
```bash
# Agent runs:
flutter analyze lib/screens/run_history_screen.dart
# Assert: No errors, no warnings
```

**For UI Verification (using playwright skill):**
```
# Agent executes via playwright browser automation:
1. Launch iOS Simulator with app
2. Navigate to History tab
3. Screenshot: Capture stats row showing emojis
4. Navigate to previous month
5. Verify: Run list shows multiple runs (not filtered to single day)
6. Tap specific day in calendar
7. Verify: Run list shows only that day's runs
8. Screenshot: .sisyphus/evidence/history-range-selection.png
```

---

## Execution Strategy

### Sequential Execution (No Parallelization)

These tasks must be executed in order due to dependencies:

```
Task 1: Update _buildStatCard to accept emoji
    ↓
Task 2: Update _buildStatsRow with emojis
    ↓
Task 3: Modify range selection behavior
    ↓
Task 4: Update UI to handle null _selectedDate
    ↓
Task 5: Run verification
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2 | None |
| 2 | 1 | 3 | None |
| 3 | 2 | 4 | None |
| 4 | 3 | 5 | None |
| 5 | 4 | None | None (final) |

---

## TODOs

- [ ] 1. Update `_buildStatCard` to support emoji labels

  **What to do**:
  - Modify `_buildStatCard()` method signature to accept emoji instead of text label
  - Add emoji display above or beside the value
  - Keep the value + unit display pattern
  - Ensure emoji renders at appropriate size (match current label font size ~12-14px)

  **Must NOT do**:
  - Don't add new dependencies for emoji handling
  - Don't change the overall card layout structure

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small, focused edit to a single method
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Ensures proper typography and spacing for emoji integration

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 2
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/screens/run_history_screen.dart:804-861` - Current `_buildStatCard()` implementation showing Container + Column layout
  - `lib/screens/run_history_screen.dart:524` - Header emoji usage pattern (`Text('📅', style: TextStyle(fontSize: 24))`)

  **API/Type References**:
  - `GoogleFonts.sora()` - Font for value display
  - `GoogleFonts.inter()` - Font for labels/units
  - `AppTheme.surfaceColor` - Card background color

  **WHY Each Reference Matters**:
  - Line 804-861 shows the exact method to modify with its current structure
  - Line 524 shows how emojis are already used in this file (header), same pattern applies

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/screens/run_history_screen.dart
  # Assert: No errors on the modified method
  ```

  **Commit**: NO (groups with Task 2)

---

- [ ] 2. Replace text labels with emojis in `_buildStatsRow`

  **What to do**:
  - Update `_buildStatsRow()` to pass emojis instead of text labels:
    - 'DISTANCE' → '🏃' (runner = distance traveled)
    - 'AVG PACE' → '⏱️' (timer = pace)
    - 'FLIPS' → '🔄' (arrows = flipping/capturing hexes)
    - 'RUNS' → '#️⃣' (number sign = count of runs)
  - Adjust spacing if needed for emoji display

  **Must NOT do**:
  - Don't change the color assignments (electricBlue, white, athleticRed, white54)
  - Don't change the stat calculation logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple string replacement in one method
  - **Skills**: None needed
    - Simple edit, no special domain knowledge required

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `lib/screens/run_history_screen.dart:757-802` - Current `_buildStatsRow()` with four `_buildStatCard()` calls

  **WHY Each Reference Matters**:
  - Lines 757-802 show the exact locations to change the label strings

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/screens/run_history_screen.dart
  # Assert: No errors
  
  # Visual verification (after full implementation):
  # Stats row should display: 🏃 ⏱️ 🔄 #️⃣ instead of DISTANCE AVG PACE FLIPS RUNS
  ```

  **Commit**: YES
  - Message: `feat(history): replace stat labels with emojis for cleaner UI`
  - Files: `lib/screens/run_history_screen.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 3. Modify range selection behavior

  **What to do**:
  - In `_calculateRange()` (line 78-103): Change `_selectedDate = _rangeEnd` to `_selectedDate = null`
  - In `_navigatePrevious()` (line 106-122): Ensure it preserves null selection (don't set _selectedDate)
  - In `_navigateNext()` (line 125-141): Ensure it preserves null selection
  - In `_jumpToToday()` (line 144-148): Keep selecting today specifically (exits range mode)
  - Keep `initState()` (line 173-181) as-is - it sets `_selectedDate = DateTime.now()` which is correct for first load

  **Must NOT do**:
  - Don't change period toggle behavior
  - Don't modify the range calculation logic itself (_rangeStart, _rangeEnd)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Focused logic change to navigation methods
  - **Skills**: None needed
    - State management is straightforward

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 4
  - **Blocked By**: Task 2

  **References**:

  **Pattern References**:
  - `lib/screens/run_history_screen.dart:78-103` - `_calculateRange()` method
  - `lib/screens/run_history_screen.dart:106-122` - `_navigatePrevious()` method
  - `lib/screens/run_history_screen.dart:125-141` - `_navigateNext()` method
  - `lib/screens/run_history_screen.dart:144-148` - `_jumpToToday()` method

  **WHY Each Reference Matters**:
  - These are the exact methods controlling when `_selectedDate` is set
  - Understanding the current flow is essential to not break navigation

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/screens/run_history_screen.dart
  # Assert: No errors
  ```

  **Commit**: NO (groups with Task 4)

---

- [ ] 4. Update UI to handle null `_selectedDate`

  **What to do**:
  
  **A. Update Range Navigation visual feedback** (lines 639-702):
  - Add subtle visual indicator when in range mode (null selection)
  - Options: Different border color, "📅 Range" badge, or slightly different background
  
  **B. Update Calendar View usage** (lines 264-295):
  - When `_selectedDate` is null, pass null to `RunCalendar.selectedDate`
  - Calendar will show no day highlighted (this already works)
  - Replace `SelectedDateRuns` widget usage: When `_selectedDate` is null, show all runs for the range instead

  **C. Update SelectedDateRuns call** (lines 280-295):
  - When `_selectedDate` is null, show range runs instead
  - Create inline widget or conditional: If null, display `periodRuns` list similar to list view format
  - Add header like "All runs in [range]" when in range mode

  **D. Handle calendar day tap** (line 476):
  - Already calls `onDateSelected` which sets `_selectedDate` - this works correctly
  - User tapping a day will exit range mode and show specific day

  **Must NOT do**:
  - Don't modify `run_calendar.dart` internals
  - Don't change the list view behavior (it already works correctly)
  - Don't add complex new widgets - keep it simple

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI changes requiring visual feedback and layout adjustments
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Ensures visual feedback is clear and intuitive

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 5
  - **Blocked By**: Task 3

  **References**:

  **Pattern References**:
  - `lib/screens/run_history_screen.dart:639-702` - `_buildRangeNavigation()` for adding visual feedback
  - `lib/screens/run_history_screen.dart:264-295` - Calendar view section with `SelectedDateRuns`
  - `lib/screens/run_history_screen.dart:329-350` - List view run tile rendering pattern (reuse for range mode)
  - `lib/screens/run_history_screen.dart:1123-1282` - `_buildRunTile()` method to reuse

  **Widget References**:
  - `lib/widgets/run_calendar.dart:46-58` - RunCalendar constructor showing `selectedDate` is nullable

  **WHY Each Reference Matters**:
  - Lines 639-702 show where to add range mode indicator
  - Lines 264-295 show the calendar section that needs conditional rendering
  - Lines 329-350 show the pattern for rendering run tiles in a list (reuse this)

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/screens/run_history_screen.dart
  # Assert: No errors
  ```

  **Visual verification (via Playwright):**
  ```
  1. Navigate to History screen
  2. Switch to Calendar view
  3. Navigate to previous month using arrow
  4. Assert: No day is highlighted in calendar
  5. Assert: Run list shows ALL runs for the month (not "No runs on this day")
  6. Tap a specific day with runs
  7. Assert: That day is now highlighted
  8. Assert: Run list shows only runs for that specific day
  ```

  **Commit**: YES
  - Message: `feat(history): implement range selection behavior with visual feedback`
  - Files: `lib/screens/run_history_screen.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 5. Final verification

  **What to do**:
  - Run `flutter analyze` on the entire project
  - Use Playwright skill to visually verify:
    - Emoji labels display correctly in stats row
    - Range navigation selects entire range
    - Day selection in calendar works
    - List view shows appropriate runs for selection state

  **Must NOT do**:
  - Don't make code changes in this task - verification only

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Verification task, no complex implementation
  - **Skills**: [`playwright`]
    - `playwright`: Browser automation for visual verification

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (final task)
  - **Blocks**: None
  - **Blocked By**: Task 4

  **References**:

  **Documentation References**:
  - User requirements in original request specify `flutter analyze` must pass
  - User requirements specify iOS simulator verification with playwright skill

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze
  # Assert: 0 issues found
  ```

  ```
  # Playwright visual verification:
  1. Launch app on iOS Simulator
  2. Navigate to History tab
  3. Screenshot: .sisyphus/evidence/task-5-stats-emojis.png
     Assert: Shows 🏃 ⏱️ 🔄 #️⃣ labels
  4. Click previous month arrow
  5. Screenshot: .sisyphus/evidence/task-5-range-mode.png
     Assert: Calendar shows no highlighted day
     Assert: Run list shows multiple runs for the month
  6. Tap a day with runs
  7. Screenshot: .sisyphus/evidence/task-5-day-mode.png
     Assert: Calendar shows that day highlighted
     Assert: Run list shows only that day's runs
  ```

  **Evidence to Capture**:
  - [ ] Terminal output from `flutter analyze`
  - [ ] Screenshots in `.sisyphus/evidence/` for visual verification

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 2 | `feat(history): replace stat labels with emojis for cleaner UI` | run_history_screen.dart | flutter analyze |
| 4 | `feat(history): implement range selection behavior with visual feedback` | run_history_screen.dart | flutter analyze |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze lib/screens/run_history_screen.dart
# Expected: No issues found

flutter analyze
# Expected: No issues found (full project)
```

### Final Checklist
- [ ] Stats row displays emojis (🏃 ⏱️ 🔄 #️⃣) instead of text labels
- [ ] Navigating to prev/next range shows all runs for that range
- [ ] Calendar shows no highlighted day when in range mode
- [ ] Tapping a calendar day highlights it and filters to that day's runs
- [ ] Visual indicator shows when in range mode vs day mode
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] `flutter analyze` passes
