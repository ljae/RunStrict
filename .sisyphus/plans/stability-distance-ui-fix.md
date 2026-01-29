# Stability Score & Distance UI Fixes

## TL;DR

> **Quick Summary**: Add stability score display to run history (list + calendar views) and add total distance to leaderboard rank tiles (4+). Requires adding `cv` field to `RunSession` model and updating three UI widgets.
> 
> **Deliverables**:
> - `RunSession` model with `cv` field and `stabilityScore` getter
> - Updated `LocalStorage.getAllRuns()` to propagate cv data
> - Stability badge in run history list view (`_buildRunTile`)
> - Stability badge in calendar card view (`_buildRunCard`)
> - Distance display in leaderboard rank tiles (`_buildRankTile`)
> 
> **Estimated Effort**: Short (4-5 tasks, ~1-2 hours)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 (model) → Tasks 2,3,4 (UI) → Task 5 (verify)

---

## Context

### Original Request
Fix two UI display issues:
1. Stability score not shown in run history (both list and calendar views)
2. Total distance not shown from 4th place in leaderboard

### Interview Summary
**Key Discussions**:
- Root cause: `RunSession` model lacks `cv` field; `LocalStorage.getAllRuns()` loses cv data during RunSummary→RunSession conversion
- Leaderboard issue is simple omission: data exists but isn't rendered

**User Decisions**:
1. Stability format: Same as leaderboard (`{score}%` with color coding)
2. List view placement: After pace in secondary stats row (time · pace · stability)
3. Calendar card placement: After flips (far right)
4. Rank tile placement: Between name and stability badge as "{distance}km"
5. Null handling: Hide completely when null (matches leaderboard)

### Research Findings
- `RunSummary` already has `cv` field (line 30) and `stabilityScore` getter (lines 54-59)
- `LocalStorage.getAllRuns()` parses `RunSummary.fromMap()` but doesn't pass cv to RunSession (lines 296-309)
- Leaderboard's `_getStabilityColor()` function exists (lines 1058-1062) - can be extracted or duplicated
- Existing UI patterns in `leaderboard_screen.dart` lines 766-798 (podium) and 932-954 (rank tile)

---

## Work Objectives

### Core Objective
Display stability scores in run history and total distance in leaderboard rank tiles, ensuring data flows correctly from storage to UI.

### Concrete Deliverables
- `lib/models/run_session.dart` - Add `cv` field and `stabilityScore` getter
- `lib/storage/local_storage.dart` - Pass cv to RunSession in `getAllRuns()`
- `lib/screens/run_history_screen.dart` - Stability badge in `_buildRunTile()`
- `lib/widgets/run_calendar.dart` - Stability badge in `_buildRunCard()`
- `lib/screens/leaderboard_screen.dart` - Distance in `_buildRankTile()`

### Definition of Done
- [ ] `flutter analyze` passes with no errors
- [ ] App launches without crashes
- [ ] Run history list view shows stability score (when available)
- [ ] Run history calendar view shows stability score (when available)
- [ ] Leaderboard ranks 4+ show distance like podium

### Must Have
- Stability score uses color coding (Green ≥80, Yellow 50-79, Red <50)
- Distance format matches podium: `{km}km`
- Null cv hides stability display completely
- No breaking changes to existing functionality

### Must NOT Have (Guardrails)
- DO NOT change `StorageService` interface (too invasive)
- DO NOT add cv calculation logic (already exists in `RunSummary`)
- DO NOT modify `RunProvider` (uses `RunSession` correctly already)
- DO NOT add new dependencies
- DO NOT duplicate `_getStabilityColor` logic - extract to shared location or import

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test)
- **User wants tests**: Not explicitly requested
- **Framework**: flutter test
- **QA approach**: Manual verification (visual UI changes)

### Manual Verification Steps
Each task includes specific verification using the app UI.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
└── Task 1: Add cv field to RunSession + update LocalStorage

Wave 2 (After Wave 1):
├── Task 2: Add stability to run history list view
├── Task 3: Add stability to calendar card view
└── Task 4: Add distance to leaderboard rank tiles

Wave 3 (After Wave 2):
└── Task 5: Final verification and flutter analyze
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3 | None |
| 2 | 1 | 5 | 3, 4 |
| 3 | 1 | 5 | 2, 4 |
| 4 | None | 5 | 2, 3 |
| 5 | 2, 3, 4 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1 | quick category, no special skills |
| 2 | 2, 3, 4 | quick category, frontend-ui-ux skill if available |
| 3 | 5 | quick category |

---

## TODOs

- [ ] 1. Add cv field to RunSession model and update LocalStorage

  **What to do**:
  - Add `double? cv` field to `RunSession` class
  - Add `int? get stabilityScore` getter (same logic as `RunSummary`)
  - Update `RunSession` constructor to accept `cv` parameter
  - Update `RunSession.copyWith()` to include `cv`
  - Update `LocalStorage.getAllRuns()` to pass `summary.cv` to `RunSession` constructor

  **Must NOT do**:
  - Do NOT add cv to `RunSession.toSummary()` (cv flows FROM storage, not TO storage)
  - Do NOT modify `StorageService` interface

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple model field addition, localized changes to 2 files
  - **Skills**: None required
    - Model changes are straightforward Dart code
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not UI work, just model/storage layer

  **Parallelization**:
  - **Can Run In Parallel**: NO (foundational change)
  - **Parallel Group**: Wave 1 (solo)
  - **Blocks**: Tasks 2, 3 (depend on cv field existing)
  - **Blocked By**: None (can start immediately)

  **References** (CRITICAL - Be Exhaustive):

  **Pattern References**:
  - `lib/models/run_summary.dart:30` - Existing `cv` field declaration pattern
  - `lib/models/run_summary.dart:54-59` - `stabilityScore` getter implementation to copy
  - `lib/models/run_session.dart:97-116` - Existing `copyWith()` pattern to extend

  **Implementation References**:
  - `lib/storage/local_storage.dart:296-309` - `getAllRuns()` method where cv must be passed
  - `lib/models/run_session.dart:21-34` - Constructor to modify

  **WHY Each Reference Matters**:
  - `run_summary.dart:30` - Shows exact field type (`double? cv`) to use
  - `run_summary.dart:54-59` - Copy this exact getter logic for consistency
  - `local_storage.dart:296-309` - This is WHERE the cv data is lost; fix here

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] `flutter analyze` → No new errors introduced
  - [ ] Verify in code: `RunSession` class has `cv` field and `stabilityScore` getter
  - [ ] Verify in code: `LocalStorage.getAllRuns()` passes `cv: summary.cv` to RunSession

  **Commit**: YES
  - Message: `feat(models): add cv field to RunSession for stability score display`
  - Files: `lib/models/run_session.dart`, `lib/storage/local_storage.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 2. Add stability badge to run history list view

  **What to do**:
  - In `_buildRunTile()` method, add stability badge after pace display
  - Use color coding: Green (≥80), Yellow (50-79), Red (<50)
  - Add helper method `_getStabilityColor(int score)` (copy from leaderboard)
  - Only show if `run.stabilityScore != null`
  - Format: dot separator + colored percentage text

  **Must NOT do**:
  - Do NOT show placeholder when stability is null
  - Do NOT change existing layout structure significantly

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple UI addition following existing patterns
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Ensures consistent styling with existing design
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for this UI change

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1 (needs cv field)

  **References** (CRITICAL - Be Exhaustive):

  **Pattern References**:
  - `lib/screens/leaderboard_screen.dart:1058-1062` - `_getStabilityColor()` function to copy
  - `lib/screens/leaderboard_screen.dart:766-798` - Podium stability display pattern
  - `lib/screens/run_history_screen.dart:886-919` - Current secondary stats row to extend

  **UI Structure Reference**:
  - `lib/screens/run_history_screen.dart:823-962` - Full `_buildRunTile()` method
  - Line 900-906: Dot separator pattern between stats

  **Theme References**:
  - `lib/theme/app_theme.dart` - Color constants (though stability uses custom colors)

  **WHY Each Reference Matters**:
  - `leaderboard_screen.dart:1058-1062` - EXACT color logic to copy for consistency
  - `run_history_screen.dart:900-906` - Shows dot separator pattern to replicate

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] `flutter run` → Navigate to History screen (list view)
  - [ ] Verify: Runs with stability show colored percentage after pace
  - [ ] Verify: Runs without stability (short runs) show no stability indicator
  - [ ] Verify: Color coding correct (green ≥80, yellow 50-79, red <50)
  - [ ] Screenshot evidence saved

  **Commit**: NO (groups with Task 3)

---

- [ ] 3. Add stability badge to calendar card view

  **What to do**:
  - In `SelectedDateRuns._buildRunCard()` method, add stability badge after flips section
  - Use same color coding as list view
  - Add helper method `_getStabilityColor(int score)` to `SelectedDateRuns` class
  - Only show if stability score exists
  - Format: colored badge with percentage

  **Must NOT do**:
  - Do NOT show placeholder when stability is null
  - Do NOT break existing card layout

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple UI addition to existing widget
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Ensures visual consistency
  - **Skills Evaluated but Omitted**:
    - None needed beyond frontend skill

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 4)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1 (needs cv field)

  **References** (CRITICAL - Be Exhaustive):

  **Pattern References**:
  - `lib/screens/leaderboard_screen.dart:1058-1062` - `_getStabilityColor()` to copy
  - `lib/widgets/run_calendar.dart:505-522` - Flips badge pattern to follow

  **Implementation References**:
  - `lib/widgets/run_calendar.dart:439-526` - Full `_buildRunCard()` method
  - `lib/widgets/run_calendar.dart:507-521` - Flips container decoration pattern

  **WHY Each Reference Matters**:
  - `run_calendar.dart:505-522` - Shows exact badge styling to match
  - `run_calendar.dart:439` - Entry point for modifications

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] `flutter run` → Navigate to History screen (calendar view)
  - [ ] Select a date with runs
  - [ ] Verify: Run cards show stability badge after flips
  - [ ] Verify: Cards without stability show no indicator
  - [ ] Verify: Color coding matches list view
  - [ ] Screenshot evidence saved

  **Commit**: YES (with Task 2)
  - Message: `feat(ui): add stability score display to run history views`
  - Files: `lib/screens/run_history_screen.dart`, `lib/widgets/run_calendar.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 4. Add distance display to leaderboard rank tiles (4+)

  **What to do**:
  - In `_buildRankTile()` method, add distance text between name and stability badge
  - Format: `{km}km` (e.g., "154km")
  - Style: Small, muted text similar to podium
  - Position: After name `Expanded` widget, before stability badge

  **Must NOT do**:
  - Do NOT change podium card layout
  - Do NOT add distance if it's 0

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single UI element addition
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Ensures layout consistency
  - **Skills Evaluated but Omitted**:
    - None

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 3)
  - **Blocks**: Task 5
  - **Blocked By**: None (data already available)

  **References** (CRITICAL - Be Exhaustive):

  **Pattern References**:
  - `lib/screens/leaderboard_screen.dart:770-777` - Podium distance display pattern
  - `lib/screens/leaderboard_screen.dart:813-991` - Full `_buildRankTile()` method
  - `lib/screens/leaderboard_screen.dart:919-930` - Name section (insert after this)

  **Data Reference**:
  - `lib/screens/leaderboard_screen.dart:1097` - `totalDistanceKm` field in `LeaderboardRunner`

  **WHY Each Reference Matters**:
  - `leaderboard_screen.dart:770-777` - EXACT styling to match for consistency
  - `leaderboard_screen.dart:919-930` - Insertion point after name Expanded widget

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] `flutter run` → Navigate to Leaderboard screen
  - [ ] Scroll past podium (top 3)
  - [ ] Verify: Ranks 4+ show distance (e.g., "128km") before stability badge
  - [ ] Verify: Format matches podium distance display
  - [ ] Screenshot evidence saved

  **Commit**: YES
  - Message: `feat(ui): add distance display to leaderboard rank tiles`
  - Files: `lib/screens/leaderboard_screen.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 5. Final verification and code quality check

  **What to do**:
  - Run `flutter analyze` to ensure no lint errors
  - Run `flutter test` to ensure no regressions
  - Manual app walkthrough of all changed screens
  - Verify all three UI locations display correctly

  **Must NOT do**:
  - Do NOT skip any verification step
  - Do NOT commit if analyze fails

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Verification task, no complex implementation
  - **Skills**: None required
  - **Skills Evaluated but Omitted**:
    - `playwright`: Could be used but manual verification is sufficient for this scope

  **Parallelization**:
  - **Can Run In Parallel**: NO (final verification)
  - **Parallel Group**: Wave 3 (solo, final)
  - **Blocks**: None
  - **Blocked By**: Tasks 2, 3, 4

  **References** (CRITICAL - Be Exhaustive):

  **Verification Checklist**:
  - `lib/models/run_session.dart` - cv field exists
  - `lib/storage/local_storage.dart` - cv passed in getAllRuns
  - `lib/screens/run_history_screen.dart` - stability in _buildRunTile
  - `lib/widgets/run_calendar.dart` - stability in _buildRunCard  
  - `lib/screens/leaderboard_screen.dart` - distance in _buildRankTile

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] `flutter analyze` → 0 errors, 0 warnings (or pre-existing only)
  - [ ] `flutter test` → All tests pass
  - [ ] App test: History list view shows stability ✓
  - [ ] App test: History calendar view shows stability ✓
  - [ ] App test: Leaderboard 4+ shows distance ✓

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(models): add cv field to RunSession for stability score display` | run_session.dart, local_storage.dart | flutter analyze |
| 3 | `feat(ui): add stability score display to run history views` | run_history_screen.dart, run_calendar.dart | flutter analyze |
| 4 | `feat(ui): add distance display to leaderboard rank tiles` | leaderboard_screen.dart | flutter analyze |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze  # Expected: No errors
flutter test     # Expected: All tests pass
flutter run      # Manual UI verification
```

### Final Checklist
- [ ] All "Must Have" requirements present
- [ ] All "Must NOT Have" guardrails respected
- [ ] flutter analyze passes
- [ ] All three UI locations display correctly
- [ ] Null handling works (no stability shown for short runs)
- [ ] Color coding correct for all stability ranges
