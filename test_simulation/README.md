# RunStrict Test Simulation

Generate random daily run data for 100 users to test the Flutter app.

## Quick Start (Full Season Reset)

```bash
cd test_simulation

# Generate full 40-day season (D-40 to D-1) with data reset
python3 daily_simulation.py --reset --days 40 > season_40days.sql

# Copy SQL and paste into Supabase SQL Editor:
# https://supabase.com/dashboard/project/vhooaslzkmbnzmzwiium/sql
```

## Usage

### Full season (40 days) with reset
```bash
python3 daily_simulation.py --reset --days 40
```

### Custom number of days
```bash
python3 daily_simulation.py --reset --days 10   # 10 days
python3 daily_simulation.py --reset --days 7    # 1 week
```

### Reproducible results
```bash
python3 daily_simulation.py --reset --days 40 --seed 42
```

### Save to file
```bash
python3 daily_simulation.py --reset --days 40 > season.sql
```

## What it generates

**Reset (with --reset flag):**
- Truncates run_history, hexes, daily_flips
- Deletes simulation users (keeps real users)

**100 Users:**
- 40 Red (FLAME)
- 40 Blue (WAVE)  
- 20 Purple (CHAOS)

**40 Days of Activity:**
- Each day: 40-70% participation
- Distance: 2-15 km per run
- Covers hexes around Apple Park

**Example 40-day summary:**
```
-- Total runs: 2,222
-- Total distance: 19,033 km
-- Total flips: 29,985
-- Team Points: Red 28,668 | Blue 22,837 | Purple 14,074
-- Hex Control: Red 36 | Blue 78 | Purple 42
```

## Daily Workflow

1. Run the script: `python3 daily_simulation.py --reset --days 40`
2. Copy output to [Supabase SQL Editor](https://supabase.com/dashboard/project/vhooaslzkmbnzmzwiium/sql)
3. Execute SQL
4. Open Flutter app: `flutter run`
5. See hex map, leaderboard, team stats

## Pre-generated Files

| File | Description |
|------|-------------|
| `season_40days.sql` | Full 40-day season (ready to use) |
