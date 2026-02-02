# Draft: Remove total_runs from Supabase RPC Responses

## Requirements (confirmed)
- Remove `total_runs` from RPC function responses (not displayed in UI anymore)
- Keep `total_runs` column in database (for analytics/historical purposes)
- Keep `total_runs` increment logic in `finalize_run` (still tracking the data)

## Research Findings

### Current State of `total_runs` in Supabase

| Function | Location | Returns `total_runs`? |
|----------|----------|----------------------|
| `get_leaderboard()` | 003_cv_aggregates.sql | YES - in return table |
| `app_launch_sync()` | 004_scoped_data_functions.sql | YES - in `user_stats` and `leaderboard` objects |
| `get_scoped_leaderboard()` | 004_scoped_data_functions.sql | NO - already clean |
| `finalize_run()` | 004_scoped_data_functions.sql | NO - but increments the value (keep this!) |

### Flutter Code Analysis
- `UserModel.totalRuns` - exists but has null-safe default (`?? 0`)
- No screens display `totalRuns`
- No providers depend on `totalRuns`
- Local storage calculates runs from local SQLite (independent of server)
- **Safe to remove from RPC responses**

## Technical Decisions
- Migration file: `007_remove_total_runs_from_responses.sql`
- Update `get_leaderboard()`: Remove from RETURNS TABLE and SELECT
- Update `app_launch_sync()`: Remove from user_stats JSON and leaderboard entries
- DO NOT modify `finalize_run()` - it should continue incrementing `total_runs`
- DO NOT drop the `total_runs` column from users table

## Scope Boundaries
- INCLUDE: RPC function return value modifications
- INCLUDE: Migration file creation
- INCLUDE: README update for function signatures
- EXCLUDE: Flutter model cleanup (separate task)
- EXCLUDE: Database column removal
- EXCLUDE: `finalize_run()` logic changes

## Open Questions - RESOLVED
1. Should we update the README.md to reflect the new function signatures? **YES - confirmed by user**
2. Any other RPC functions that might return `total_runs`? **Only `get_leaderboard()` needs update**
3. Which `app_launch_sync` version is deployed? **The simpler 20260128 version - already clean!**

## Final Scope
- **ONLY** update `get_leaderboard()` function
- Update `supabase/README.md` function signature docs
- `app_launch_sync` already clean (simpler version deployed)
- `get_scoped_leaderboard` already clean
