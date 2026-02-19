# RunStrict Test Simulation

Generate day-by-day season data for 100 dummy runners to test the Flutter app.

## Setup

```bash
cd test_simulation
pip install h3    # Required for hex generation
```

## Day-by-Day Workflow

```bash
# Step 1: Get your home hex from Supabase
# SELECT home_hex FROM users WHERE name = 'YourName'

# Step 2: Reset everything
python3 simulate_day.py --reset
# → Copy SQL to Supabase SQL Editor, execute
# → Delete app from device/simulator and reinstall (clears local SQLite)

# Step 3: Day 1 (creates 100 users + first day of runs)
python3 simulate_day.py --day 1 --home-hex 89283082803ffff
# → Copy SQL to Supabase SQL Editor, execute
# → Open app → check leaderboard, hex map, team standings

# Step 4: Day 2
python3 simulate_day.py --day 2
# → Copy SQL, execute, check app

# Repeat for days 3-40...

# Check status anytime
python3 simulate_day.py --status
```

## Province Split

The `--home-hex` flag determines where runners are placed:

- **50 runners** in your province (same Res 5 parent as your home hex)
- **50 runners** in a neighboring province (different Res 5 parent)

This lets you test:
- Hex map with both nearby and distant activity
- Leaderboard scoping (ZONE/DISTRICT/PROVINCE)
- Province boundary rendering

If `--home-hex` is omitted, defaults to Apple Park area (`89283082803ffff`).

## Usage Reference

```bash
# Day-by-day simulation
python3 simulate_day.py --day 1 --home-hex <hex>  # First day (requires --home-hex)
python3 simulate_day.py --day 2                     # Subsequent days use saved state
python3 simulate_day.py --day 1 --save              # Save to sql/day_01.sql

# Management
python3 simulate_day.py --reset                     # Output reset SQL + clear local state
python3 simulate_day.py --status                    # Show current simulation state
python3 simulate_day.py --day 1 --seed 99           # Custom random seed
```

## What Gets Generated

**Reset SQL (`--reset`):**
- Deletes simulation users (prefix `aaaaaaaa-*`)
- Truncates hexes, hex_snapshot
- Cleans daily_stats, daily_buff_stats for sim users
- Resets real users' season data

**Day 1 SQL:**
- 100 auth.users + public.users entries
- Run history for active runners
- Hex map state + hex_snapshot (app reads this)
- Daily stats aggregates
- Daily buff stats

**Day 2+ SQL:**
- New run_history entries
- Updated hex map + snapshot
- Updated daily_stats + daily_buff_stats
- Cumulative user season stats
- Defections to Purple (days 15-25)

## 100 Users

| Team | Count | Distribution |
|------|-------|-------------|
| Red (FLAME) | 40 | Stars, regulars, casuals, ghosts |
| Blue (WAVE) | 40 | Same archetypes |
| Purple (CHAOS) | 20 | Initial + defectors from day 15+ |

**Archetypes:**
- **Star** (10%): 92% participation, 8-15km, fast pace, low CV
- **Regular** (40%): 62% participation, 4-10km, moderate stats
- **Casual** (35%): 32% participation, 2-6km, slower pace
- **Ghost** (15%): 8% participation, rare appearances

## What to Check in App

| Screen | What to verify |
|--------|---------------|
| **Hex Map** | Hex colors update, province boundaries visible |
| **Leaderboard** | 100 users ranked, points accumulate, team totals shift |
| **Home Screen** | Season countdown, flip points badge |
| **Profile** | Stats, stability score |

## Data Tables Populated

| Table | Content |
|-------|---------|
| `auth.users` | Auth entries for sim users |
| `public.users` | User profiles with season stats |
| `public.run_history` | Individual run records |
| `public.hexes` | Live hex state (for buff/dominance) |
| `public.hex_snapshot` | Daily hex snapshot (app reads this for flip counting) |
| `public.daily_stats` | Per-user daily aggregates |
| `public.daily_buff_stats` | Per-user daily buff multipliers |
