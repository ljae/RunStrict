# Remove total_runs from Supabase RPC Responses

## TL;DR

> **Quick Summary**: Remove `total_runs` from the `get_leaderboard()` RPC function return since the Flutter UI no longer displays this field. The database column is preserved for analytics.
> 
> **Deliverables**:
> - SQL migration file `007_remove_total_runs_from_responses.sql`
> - Updated `supabase/README.md` function signature documentation
> 
> **Estimated Effort**: Quick (< 30 min)
> **Parallel Execution**: NO - sequential (2 tasks, simple dependency)
> **Critical Path**: Task 1 (migration) -> Task 2 (docs)

---

## Context

### Original Request
User made client-side Flutter UI changes that removed the "runs" stat from displays:
1. All-time record section in `run_history_screen.dart` - now shows: pace, flips, stability (removed runs)
2. Leaderboard season stats - now shows: pace, distance, rank (removed runs)

The Supabase RPC functions need to be updated to stop returning `total_runs` to match the UI changes.

### Interview Summary
**Key Discussions**:
- Keep `total_runs` column in database (for analytics/historical purposes)
- Keep `total_runs` increment logic in `finalize_run()` (still tracking)
- Only modify RPC function return values, not the underlying data storage

**Research Findings**:
- `app_launch_sync()` - Already clean! Deployed version doesn't return `total_runs`
- `get_scoped_leaderboard()` - Already clean! Returns `stability_score` instead
- `get_leaderboard()` - **NEEDS UPDATE** - Currently returns `total_runs INTEGER`
- Flutter `UserModel` has null-safe parsing (`?? 0`) - won't break if field is missing

### Self-Review Gap Analysis
**Potential gaps identified and addressed**:
1. ✅ Backward compatibility: Flutter model handles missing field gracefully
2. ✅ Data preservation: Column and increment logic unchanged
3. ✅ Scope locked: Only `get_leaderboard()` needs modification
4. ✅ Documentation: README update included

---

## Work Objectives

### Core Objective
Remove `total_runs` from `get_leaderboard()` RPC function return values to align with Flutter UI changes.

### Concrete Deliverables
1. `supabase/migrations/007_remove_total_runs_from_responses.sql`
2. Updated `supabase/README.md` with new function signature

### Definition of Done
- [ ] Migration file created and syntactically valid
- [ ] `get_leaderboard()` no longer returns `total_runs` column
- [ ] README reflects the updated function signature
- [ ] Existing functionality preserved (function still returns other columns)

### Must Have
- Remove `total_runs` from `get_leaderboard()` RETURNS TABLE definition
- Remove `u.total_runs` from SELECT statement
- Update README documentation

### Must NOT Have (Guardrails)
- DO NOT drop the `total_runs` column from `users` table
- DO NOT modify `finalize_run()` logic (it should keep incrementing `total_runs`)
- DO NOT modify `app_launch_sync()` (already clean)
- DO NOT modify `get_scoped_leaderboard()` (already clean)
- DO NOT modify Flutter code in this migration (separate concern)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES - SQL can be verified via Supabase SQL Editor
- **User wants tests**: Manual verification via SQL queries
- **Framework**: Supabase SQL Editor / psql

### Manual Verification Procedures

Each task includes SQL verification queries that can be run in Supabase SQL Editor to confirm the changes work correctly.

---

## Execution Strategy

### Sequential Execution (No Parallelization)

```
Task 1: Create migration file
    ↓
Task 2: Update README documentation
```

**Rationale**: Task 2 references the changes made in Task 1. Simple 2-task sequential flow.

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2 | None |
| 2 | 1 | None | None |

---

## TODOs

- [ ] 1. Create migration to update get_leaderboard() function

  **What to do**:
  - Create new migration file `supabase/migrations/007_remove_total_runs_from_responses.sql`
  - Use `CREATE OR REPLACE FUNCTION` to update `get_leaderboard()`
  - Remove `total_runs INTEGER` from the RETURNS TABLE definition
  - Remove `u.total_runs` from the SELECT statement
  - Keep all other columns unchanged (id, name, team, avatar, season_points, crew_id, total_distance_km, avg_pace_min_per_km, avg_cv, rank)

  **Must NOT do**:
  - DO NOT drop the `total_runs` column from users table
  - DO NOT add any ALTER TABLE statements
  - DO NOT modify any other functions

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple SQL file creation with clear, well-defined changes
  - **Skills**: None needed
    - This is straightforward SQL - no special skills required

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Task 1)
  - **Blocks**: Task 2
  - **Blocked By**: None (can start immediately)

  **References** (CRITICAL - Be Exhaustive):

  **Pattern References** (existing code to follow):
  - `supabase/migrations/003_cv_aggregates.sql:194-228` - Current `get_leaderboard()` function definition to modify
  - `supabase/migrations/004_scoped_data_functions.sql:62-105` - Example of `get_scoped_leaderboard()` that already excludes `total_runs` (follow this pattern)

  **Why Each Reference Matters**:
  - `003_cv_aggregates.sql:194-228`: This is the EXACT function to replace. Copy this and remove `total_runs` from both RETURNS TABLE and SELECT
  - `004_scoped_data_functions.sql:62-105`: Shows how a similar leaderboard function looks WITHOUT `total_runs` - use as reference for the correct structure

  **Acceptance Criteria**:

  **Automated Verification (via Bash psql/Supabase CLI)**:
  ```bash
  # After applying migration, verify function signature no longer includes total_runs:
  # Run in Supabase SQL Editor or via supabase CLI
  
  # 1. Check function exists and verify return columns
  SELECT 
    column_name 
  FROM information_schema.columns 
  WHERE table_name = 'get_leaderboard';
  # Expected: Should NOT include 'total_runs' in results
  
  # 2. Test function execution
  SELECT * FROM get_leaderboard(5);
  # Expected: Returns rows with columns: id, name, team, avatar, season_points, crew_id, total_distance_km, avg_pace_min_per_km, avg_cv, rank
  # Expected: Does NOT have total_runs column
  ```

  **Evidence to Capture:**
  - [ ] Screenshot or output of `SELECT * FROM get_leaderboard(5)` showing no `total_runs` column
  - [ ] Migration file contents

  **Commit**: YES
  - Message: `chore(supabase): remove total_runs from get_leaderboard response`
  - Files: `supabase/migrations/007_remove_total_runs_from_responses.sql`
  - Pre-commit: N/A (SQL file, no linting needed)

---

- [ ] 2. Update supabase/README.md documentation

  **What to do**:
  - Update the `get_leaderboard` function signature in `supabase/README.md`
  - Remove `total_runs` from the documented return columns
  - Keep documentation in sync with actual function behavior

  **Must NOT do**:
  - DO NOT add new documentation sections
  - DO NOT modify other function documentation

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple documentation update, find and replace in markdown
  - **Skills**: None needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Task 2)
  - **Blocks**: None (final task)
  - **Blocked By**: Task 1

  **References** (CRITICAL - Be Exhaustive):

  **Documentation References**:
  - `supabase/README.md:129-133` - Current `get_leaderboard` documentation to update

  **Why Each Reference Matters**:
  - This is the EXACT section to modify - currently shows `RETURNS TABLE(id, name, team, avatar, season_points, crew_id)` but the actual function returns more columns. Update to match the new (post-migration) function signature.

  **Acceptance Criteria**:

  **Automated Verification (using grep)**:
  ```bash
  # Verify README no longer documents total_runs for get_leaderboard
  grep -A 10 "get_leaderboard" supabase/README.md | grep -v "total_runs"
  # Expected: Should show the function documentation without total_runs
  
  # Negative check - ensure total_runs is NOT in the get_leaderboard section
  grep -A 5 "get_leaderboard" supabase/README.md | grep "total_runs"
  # Expected: No matches (exit code 1)
  ```

  **Evidence to Capture:**
  - [ ] Updated README section showing new function signature

  **Commit**: YES
  - Message: `docs(supabase): update get_leaderboard signature (remove total_runs)`
  - Files: `supabase/README.md`
  - Pre-commit: N/A

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `chore(supabase): remove total_runs from get_leaderboard response` | `supabase/migrations/007_remove_total_runs_from_responses.sql` | SQL syntax check |
| 2 | `docs(supabase): update get_leaderboard signature (remove total_runs)` | `supabase/README.md` | grep validation |

---

## Success Criteria

### Verification Commands
```sql
-- Run in Supabase SQL Editor after applying migration

-- 1. Verify function exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'get_leaderboard' AND routine_schema = 'public';
-- Expected: 1 row with 'get_leaderboard'

-- 2. Verify function returns expected columns (without total_runs)
SELECT * FROM get_leaderboard(3);
-- Expected: Columns are id, name, team, avatar, season_points, crew_id, 
--           total_distance_km, avg_pace_min_per_km, avg_cv, rank
-- Expected: NO total_runs column
```

### Final Checklist
- [ ] Migration file `007_remove_total_runs_from_responses.sql` exists
- [ ] `get_leaderboard()` no longer returns `total_runs`
- [ ] README.md updated with correct function signature
- [ ] `users.total_runs` column still exists (not dropped)
- [ ] `finalize_run()` still increments `total_runs` (unchanged)
