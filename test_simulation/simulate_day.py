#!/usr/bin/env python3
"""
RunStrict Day-by-Day Season Simulator (v2)

Key changes from v1:
- Relative date anchoring: day N (most recent) = yesterday GMT+2
- New archetypes: elite(20%), normal(70%), slow(10%)
- --user-id / --user-team: includes real user in simulation
- --days N: batch mode (simulates N days at once)
- Populates daily_all_range_stats table

Usage:
    python3 simulate_day.py --days 5 --home-hex 89283472a93ffff \\
      --user-id ff09fc1d-7f75-42da-9279-13a379c0c407 --user-team red
    python3 simulate_day.py --reset                               # Wipe all data
    python3 simulate_day.py --status                              # Show state
    python3 simulate_day.py --days 3 --dry-run                    # Print SQL only

Requires: pip install h3 psycopg2-binary
"""

import argparse
import json
import math
import os
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:
    import h3
except ImportError:
    print("ERROR: h3 library required. Install with: pip install h3", file=sys.stderr)
    sys.exit(1)

try:
    import psycopg2
except ImportError:
    psycopg2 = None

SCRIPT_DIR = Path(__file__).parent
STATE_FILE = SCRIPT_DIR / '.sim_state.json'
SQL_DIR = SCRIPT_DIR / 'sql'

NUM_USERS = 100
TEAM_DISTRIBUTION = {'red': 40, 'blue': 40, 'purple': 20}

# H3 resolutions matching the app
BASE_RESOLUTION = 9      # Gameplay hex resolution
CITY_RESOLUTION = 6      # District scope (city_hex in daily_buff_stats)
ALL_RESOLUTION = 5       # Province/Region scope (parent_hex in hex_snapshot)

# Fallback home hex (Apple Park area) if --home-hex not provided
DEFAULT_HOME_HEX = '89283082803ffff'

# GMT+2 timezone for date calculations
GMT2 = timezone(timedelta(hours=2))

# DB connection (Supabase direct)
DB_HOST = 'aws-1-ap-southeast-1.pooler.supabase.com'
DB_PORT = 5432
DB_NAME = 'postgres'
DB_USER = 'postgres.vhooaslzkmbnzmzwiium'
DB_PASS = 'jue2wYWxL8YV7wM7'

# New archetypes: 20% elite, 70% normal, 10% slow
ARCHETYPES = {
    'elite':  {'weight': 20, 'participation': 0.80, 'dist': (8.0, 14.0), 'pace': (4.5, 5.2), 'cv': (2.0, 6.0)},
    'normal': {'weight': 70, 'participation': 0.58, 'dist': (4.0, 9.0),  'pace': (5.5, 6.5), 'cv': (6.0, 15.0)},
    'slow':   {'weight': 10, 'participation': 0.35, 'dist': (2.5, 5.5),  'pace': (6.8, 7.8), 'cv': (12.0, 25.0)},
}

FIRST_NAMES = [
    "Alex", "Jordan", "Casey", "Riley", "Morgan", "Taylor", "Quinn", "Avery",
    "Blake", "Cameron", "Dakota", "Emery", "Finley", "Gray", "Harper", "Indigo",
    "Jamie", "Kai", "Logan", "Mason", "Noah", "Oliver", "Parker", "Reese",
    "Sage", "Skyler", "Tatum", "River", "Winter", "Phoenix", "Storm", "Arrow",
    "Blaze", "Cloud", "Dawn", "Echo", "Falcon", "Galaxy", "Hawk", "Ion",
    "Jade", "Knight", "Luna", "Midnight", "Nova", "Orion", "Pulse", "Quantum",
    "Raven", "Shadow", "Thunder", "Ultra", "Vega", "Wolf", "Xenon", "Zen",
    "Ace", "Bolt", "Cinder", "Drake", "Ember", "Flint", "Gale", "Haven",
    "Ivy", "Jinx", "Koda", "Lynx", "Mist", "Nyx", "Opal", "Pax",
    "Rain", "Slate", "Trek", "Vale", "Wren", "Xyla", "Yara", "Zephyr",
    "Atlas", "Birch", "Coral", "Dusk", "Elm", "Fern", "Grove", "Haze",
    "Isle", "Jet", "Kite", "Lark", "Moss", "Nebula", "Onyx", "Pine",
]

LAST_NAMES = [
    "Runner", "Dash", "Swift", "Flash", "Bolt", "Stride", "Pace", "Sprint",
    "Blaze", "Storm", "Wind", "Fire", "Wave", "Tide", "Frost", "Thunder",
    "Shadow", "Night", "Dawn", "Star", "Moon", "Sun", "Sky", "Cloud",
    "Stone", "Steel", "Iron", "Gold", "Silver", "Bronze", "Copper", "Chrome",
]

AVATARS = [
    "\U0001f3c3", "\U0001f3c3\u200d\u2642\ufe0f", "\U0001f3c3\u200d\u2640\ufe0f",
    "\U0001f98a", "\U0001f43a", "\U0001f985", "\U0001f42c", "\U0001f525",
    "\U0001f4a8", "\u26a1", "\U0001f30a", "\U0001f32a\ufe0f",
    "\U0001f48e", "\U0001f680", "\U0001f31f", "\u2728",
]

# ISO country codes for nationality diversity
NATIONALITIES = [
    'KR', 'KR', 'KR', 'KR', 'KR',  # 25% Korean (weighted)
    'US', 'US', 'US',                 # 15% American
    'JP', 'JP',                        # 10% Japanese
    'GB', 'DE', 'FR', 'AU', 'CA',     # 5% each
    'BR', 'IN', 'MX', 'IT', 'ES',
]

DEFECTION_DAYS = range(15, 26)
DEFECTION_COUNT = 8


# ==================== Date Anchoring ====================

def today_gmt2():
    """Current date in GMT+2."""
    return datetime.now(GMT2).date()


def run_date_for_day(day, total_days):
    """Map simulation day number to a real date.

    Day 1 = oldest, day total_days = yesterday GMT+2.
    """
    yesterday = today_gmt2() - timedelta(days=1)
    return yesterday - timedelta(days=total_days - day)


# ==================== DB Connection ====================

def get_db_connection():
    if psycopg2 is None:
        print("ERROR: psycopg2 required for --execute. Install with: pip install psycopg2-binary", file=sys.stderr)
        sys.exit(1)
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASS,
    )


def execute_sql(sql, description="SQL"):
    """Execute SQL directly against Supabase."""
    conn = get_db_connection()
    conn.autocommit = True
    cur = conn.cursor()
    try:
        # Strip comment-only lines, then split on semicolons
        lines = []
        for line in sql.split('\n'):
            stripped = line.strip()
            if stripped and not stripped.startswith('--'):
                lines.append(line)
        clean_sql = '\n'.join(lines)
        statements = [s.strip() for s in clean_sql.split(';') if s.strip()]
        for stmt in statements:
            if not stmt:
                continue
            try:
                cur.execute(stmt + ';')
                if cur.description:  # SELECT query
                    cols = [d[0] for d in cur.description]
                    rows = cur.fetchall()
                    if rows:
                        widths = [max(len(str(c)), max(len(str(r[i])) for r in rows)) for i, c in enumerate(cols)]
                        header = ' | '.join(str(c).ljust(w) for c, w in zip(cols, widths))
                        print(header)
                        print('-+-'.join('-' * w for w in widths))
                        for row in rows:
                            print(' | '.join(str(v).ljust(w) for v, w in zip(row, widths)))
                        print()
                else:
                    rc = cur.rowcount
                    if rc >= 0:
                        verb = stmt.split()[0].upper() if stmt.split() else ''
                        if verb in ('INSERT', 'UPDATE', 'DELETE'):
                            print(f"  {verb} {rc} rows", file=sys.stderr)
            except Exception as e:
                print(f"  ERROR: {e}", file=sys.stderr)
                print(f"  Statement: {stmt[:100]}...", file=sys.stderr)
    finally:
        cur.close()
        conn.close()


# ==================== Helpers ====================

def esc(s):
    return s.replace("'", "''")


def generate_hexes_from_home(home_hex):
    """Generate hex pools from a home hex using h3 library."""
    res = h3.get_resolution(home_hex)
    parent_res5 = h3.cell_to_parent(home_hex, ALL_RESOLUTION)
    user_city_res6 = h3.cell_to_parent(home_hex, CITY_RESOLUTION)

    neighbors = sorted(h3.grid_disk(parent_res5, 1))
    other_province = [n for n in neighbors if n != parent_res5][0]

    # Get hexes from user's own city (Res 6) first
    user_city_hexes = sorted(h3.cell_to_children(user_city_res6, res))[:40]

    # Get hexes from other cities in the same province
    other_city_hexes = []
    province_cities = sorted(h3.cell_to_children(parent_res5, CITY_RESOLUTION))
    for city in province_cities:
        if city == user_city_res6:
            continue
        children = sorted(h3.cell_to_children(city, res))[:7]
        other_city_hexes.extend(children)
        if len(other_city_hexes) >= 40:
            break
    other_city_hexes = other_city_hexes[:40]

    same_hexes = user_city_hexes + other_city_hexes
    other_hexes = sorted(h3.cell_to_children(other_province, res))[:80]

    print(f"  Same province (Res {ALL_RESOLUTION}): {parent_res5} -> {len(same_hexes)} hexes ({len(user_city_hexes)} in user's city {user_city_res6})", file=sys.stderr)
    print(f"  Other province (Res {ALL_RESOLUTION}): {other_province} -> {len(other_hexes)} hexes", file=sys.stderr)

    return same_hexes, other_hexes


def default_state():
    return {
        'last_day': 0,
        'seed': 42,
        'home_hex': None,
        'same_hexes': [],
        'other_hexes': [],
        'users': [],
        'user_points': {},
        'user_stats': {},
        'hex_teams': {},
        'yesterday_flip_points': {},
        'total_days': 0,
        'real_user_id': None,
        'real_user_team': None,
    }


def load_state():
    if STATE_FILE.exists():
        return json.load(open(STATE_FILE))
    return default_state()


def save_state(state):
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)


def generate_users(seed, same_hexes, other_hexes):
    """Generate 100 simulation users. First 50 in same province, last 50 in other."""
    random.seed(seed)
    users = []
    team_list = []
    for team, count in TEAM_DISTRIBUTION.items():
        team_list.extend([team] * count)

    archetype_names = []
    for name, cfg in ARCHETYPES.items():
        archetype_names.extend([name] * cfg['weight'])

    for i in range(NUM_USERS):
        uid = f"aaaaaaaa-{i:04d}-{i:04d}-{i:04d}-{i:012d}"
        first = FIRST_NAMES[i % len(FIRST_NAMES)]
        last = LAST_NAMES[i % len(LAST_NAMES)]
        suffix = str(i // len(FIRST_NAMES)) if i >= len(FIRST_NAMES) else ''
        name = f"{first}{last}{suffix}"

        if i < 50:
            home_hex = same_hexes[i % len(same_hexes)]
            province = 'same'
        else:
            home_hex = other_hexes[(i - 50) % len(other_hexes)]
            province = 'other'

        users.append({
            'id': uid,
            'name': name,
            'team': team_list[i],
            'original_team': team_list[i],
            'avatar': AVATARS[i % len(AVATARS)],
            'archetype': archetype_names[i % len(archetype_names)],
            'home_hex': home_hex,
            'province': province,
            'is_real_user': False,
            'nationality': NATIONALITIES[i % len(NATIONALITIES)],
        })

    return users


def generate_run_path(user, same_hexes, other_hexes, num_hexes):
    """Generate a run path. Users run 80% in their own province, 20% crossover."""
    if user['province'] == 'same':
        home_pool = same_hexes
        away_pool = other_hexes
    else:
        home_pool = other_hexes
        away_pool = same_hexes

    path = []
    for _ in range(num_hexes):
        if random.random() < 0.8:
            hid = random.choice(home_pool)
        else:
            hid = random.choice(away_pool)
        if hid not in path:
            path.append(hid)
    return path if path else [user['home_hex']]


def calculate_buff(user, state, day):
    if day <= 1:
        return 1

    team = user['team']
    uid = user['id']
    hex_teams = state.get('hex_teams', {})
    yp = state.get('yesterday_flip_points', {})

    tc = {'red': 0, 'blue': 0, 'purple': 0}
    for t in hex_teams.values():
        if t in tc:
            tc[t] += 1

    dominant = max(tc, key=tc.get) if any(tc.values()) else None
    is_city_leader = (dominant == team) if dominant else False

    if team == 'red':
        red_pts = sorted([
            pts for u_id, pts in yp.items()
            if any(u['id'] == u_id and u['team'] == 'red' for u in state['users'])
            and pts > 0
        ])
        if red_pts:
            threshold = red_pts[int(len(red_pts) * 0.8)] if len(red_pts) > 1 else red_pts[0]
            is_elite = yp.get(uid, 0) >= threshold and yp.get(uid, 0) > 0
        else:
            is_elite = False

        base = 3 if is_elite and is_city_leader else (2 if is_elite else 1)
        bonus = 1 if dominant == 'red' else 0
        return min(base + bonus, 4)

    elif team == 'blue':
        base = 2 if is_city_leader else 1
        bonus = 1 if dominant == 'blue' else 0
        return min(base + bonus, 3)

    elif team == 'purple':
        pu = [u for u in state['users'] if u['team'] == 'purple']
        pa = len([
            u_id for u_id, pts in yp.items()
            if pts > 0 and any(u['id'] == u_id and u['team'] == 'purple' for u in state['users'])
        ])
        rate = pa / len(pu) if pu else 0
        if rate >= 0.60:
            return 3
        elif rate >= 0.30:
            return 2
        return 1

    return 1


def handle_defections(state, day):
    if day not in DEFECTION_DAYS:
        return []
    random.seed(state['seed'] + day + 9999)
    eligible = [u for u in state['users']
                if u['team'] in ('red', 'blue') and u['original_team'] != 'purple'
                and not u.get('is_real_user', False)]
    if not eligible:
        return []
    count = min(DEFECTION_COUNT // len(DEFECTION_DAYS) + 1, len(eligible))
    defectors = random.sample(eligible, min(count, len(eligible)))
    for u in defectors:
        u['team'] = 'purple'
    return defectors


def generate_day_data(state, day, total_days):
    random.seed(state['seed'] + day)
    users = state['users']
    hex_teams = dict(state.get('hex_teams', {}))
    same_hexes = state['same_hexes']
    other_hexes = state['other_hexes']
    runs = []
    day_flip_points = {}
    run_date = run_date_for_day(day, total_days)

    for user in users:
        arch = ARCHETYPES[user['archetype']]
        if random.random() > arch['participation']:
            continue

        d_min, d_max = arch['dist']
        p_min, p_max = arch['pace']
        c_min, c_max = arch['cv']

        distance_km = round(random.uniform(d_min, d_max), 2)
        pace = round(random.uniform(p_min, p_max), 2)
        duration_seconds = int(distance_km * pace * 60)
        cv = round(random.uniform(c_min, c_max), 1)

        num_hexes = max(3, int(distance_km * 2.5))
        hex_path = generate_run_path(user, same_hexes, other_hexes, num_hexes)

        team = user['team']
        flips = 0
        for hid in hex_path:
            if hex_teams.get(hid) != team:
                flips += 1
            hex_teams[hid] = team

        buff = calculate_buff(user, state, day)
        points = flips * buff

        # ~30% of runs in timezone-boundary window (15:00-21:59 UTC)
        # These appear on different dates in KST (UTC+9) vs GMT+2
        # e.g., 16:00 UTC = Feb 17 01:00 KST but Feb 16 18:00 GMT+2
        if random.random() < 0.30:
            hour = random.randint(15, 21)
        else:
            hour = random.randint(5, 14)
        minute = random.randint(0, 59)
        run_date_dt = datetime(run_date.year, run_date.month, run_date.day, tzinfo=timezone.utc)
        start_time = run_date_dt.replace(hour=hour, minute=minute, second=0)
        end_time = start_time + timedelta(seconds=duration_seconds)

        runs.append({
            'id': str(uuid.uuid4()),
            'user_id': user['id'],
            'run_date': run_date.strftime('%Y-%m-%d'),
            'start_time': start_time.strftime('%Y-%m-%d %H:%M:%S+00'),
            'end_time': end_time.strftime('%Y-%m-%d %H:%M:%S+00'),
            'distance_km': distance_km,
            'duration_seconds': duration_seconds,
            'avg_pace_min_per_km': pace,
            'hex_path': hex_path,
            'flip_count': flips,
            'flip_points': points,
            'buff_multiplier': buff,
            'team_at_run': team,
            'cv': cv,
        })
        day_flip_points[user['id']] = day_flip_points.get(user['id'], 0) + points

    return runs, hex_teams, day_flip_points


def update_state(state, day, runs, hex_teams, day_flip_points):
    state['hex_teams'] = hex_teams
    state['yesterday_flip_points'] = day_flip_points
    state['last_day'] = day

    for run in runs:
        uid = run['user_id']
        pts = run['flip_points']
        state['user_points'][uid] = state['user_points'].get(uid, 0) + pts

        stats = state['user_stats'].setdefault(uid, {
            'total_runs': 0, 'total_distance_km': 0.0,
            'sum_pace': 0.0, 'sum_cv': 0.0, 'cv_count': 0,
        })
        stats['total_runs'] += 1
        stats['total_distance_km'] = round(stats['total_distance_km'] + run['distance_km'], 2)
        stats['sum_pace'] += run['avg_pace_min_per_km']
        if run['cv'] is not None:
            stats['sum_cv'] += run['cv']
            stats['cv_count'] += 1


# ==================== SQL Generation ====================

def sql_auth_users_insert(users):
    # Only insert simulation users (not real user)
    sim_users = [u for u in users if not u.get('is_real_user', False)]
    if not sim_users:
        return "-- No auth users to insert"
    lines = []
    lines.append("INSERT INTO auth.users (id, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, email, raw_app_meta_data, raw_user_meta_data) VALUES")
    vals = []
    for u in sim_users:
        email = f"sim_{u['id'][:8]}_{u['name'].lower()}@runstrict.test"
        vals.append(
            f"  ('{u['id']}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', "
            f"'$2a$10$SimulatedPasswordHashForTestingOnly000000000000000000000', now(), now(), now(), '', "
            f"'{email}', '{{\"provider\":\"email\",\"providers\":[\"email\"]}}', '{{}}')"
        )
    lines.append(",\n".join(vals))
    lines.append("ON CONFLICT (id) DO NOTHING;")
    return "\n".join(lines)


def sql_users_insert(users):
    """Insert simulation users. Real user already exists — just update their home_hex."""
    sim_users = [u for u in users if not u.get('is_real_user', False)]
    real_users = [u for u in users if u.get('is_real_user', False)]
    parts = []

    if sim_users:
        lines = []
        lines.append("INSERT INTO public.users (id, name, team, avatar, season_points, home_hex, home_hex_start, home_hex_end, season_home_hex, total_distance_km, total_runs, nationality) VALUES")
        vals = []
        for u in sim_users:
            nat = u.get('nationality', 'KR')
            vals.append(
                f"  ('{u['id']}', '{esc(u['name'])}', '{u['team']}', '{esc(u['avatar'])}', 0, "
                f"'{u['home_hex']}', '{u['home_hex']}', '{u['home_hex']}', '{u['home_hex']}', 0, 0, '{nat}')"
            )
        lines.append(",\n".join(vals))
        lines.append("ON CONFLICT (id) DO UPDATE SET")
        lines.append("  name = EXCLUDED.name, team = EXCLUDED.team, avatar = EXCLUDED.avatar,")
        lines.append("  season_points = 0, home_hex = EXCLUDED.home_hex,")
        lines.append("  home_hex_start = EXCLUDED.home_hex_start, home_hex_end = EXCLUDED.home_hex_end,")
        lines.append("  season_home_hex = EXCLUDED.season_home_hex,")
        lines.append("  total_distance_km = 0, total_runs = 0, nationality = EXCLUDED.nationality;")
        parts.append("\n".join(lines))

    # For real user, just ensure season_home_hex is set
    for u in real_users:
        parts.append(
            f"UPDATE public.users SET season_home_hex = '{u['home_hex']}', "
            f"home_hex = '{u['home_hex']}', home_hex_end = '{u['home_hex']}' "
            f"WHERE id = '{u['id']}';"
        )

    return "\n".join(parts) if parts else "-- No user inserts"


def sql_runs_insert(runs):
    if not runs:
        return "-- No runs this day"
    lines = []
    lines.append("INSERT INTO public.run_history (id, user_id, run_date, start_time, end_time, distance_km, duration_seconds, avg_pace_min_per_km, flip_count, flip_points, team_at_run, cv) VALUES")
    vals = []
    for r in runs:
        vals.append(
            f"  ('{r['id']}', '{r['user_id']}', '{r['run_date']}', "
            f"'{r['start_time']}', '{r['end_time']}', "
            f"{r['distance_km']}, {r['duration_seconds']}, {r['avg_pace_min_per_km']}, "
            f"{r['flip_count']}, {r['flip_points']}, '{r['team_at_run']}', {r['cv']})"
        )
    lines.append(",\n".join(vals) + ";")
    return "\n".join(lines)


def sql_hexes_upsert(hex_teams):
    """Upsert hexes with parent_hex (Res 5 parent for spatial grouping)."""
    if not hex_teams:
        return "-- No hex updates"
    lines = []
    lines.append("INSERT INTO public.hexes (id, last_runner_team, parent_hex) VALUES")
    vals = []
    for hid, team in hex_teams.items():
        parent_hex = h3.cell_to_parent(hid, ALL_RESOLUTION)
        vals.append(f"  ('{hid}', '{team}', '{parent_hex}')")
    lines.append(",\n".join(vals))
    lines.append("ON CONFLICT (id) DO UPDATE SET last_runner_team = EXCLUDED.last_runner_team, parent_hex = EXCLUDED.parent_hex;")
    return "\n".join(lines)


def sql_hex_snapshot_insert(hex_teams, run_date_str):
    """Build hex_snapshot for this day's hex state."""
    if not hex_teams:
        return "-- No hex snapshot updates"
    lines = []
    lines.append("INSERT INTO public.hex_snapshot (hex_id, last_runner_team, snapshot_date, parent_hex) VALUES")
    vals = []
    for hid, team in hex_teams.items():
        parent_hex = h3.cell_to_parent(hid, ALL_RESOLUTION)
        vals.append(f"  ('{hid}', '{team}', '{run_date_str}'::date, '{parent_hex}')")
    lines.append(",\n".join(vals))
    lines.append("ON CONFLICT (hex_id, snapshot_date) DO UPDATE SET last_runner_team = EXCLUDED.last_runner_team;")
    return "\n".join(lines)


def sql_daily_buff_stats_insert(state, day, hex_teams, run_date_str):
    """Write daily_buff_stats per (stat_date, city_hex)."""
    if not hex_teams:
        return "-- No buff stats"

    yp = state.get('yesterday_flip_points', {})

    # Group hexes by city_hex (Res 6 parent)
    city_stats = {}
    for hid, team in hex_teams.items():
        city_hex = h3.cell_to_parent(hid, CITY_RESOLUTION)
        if city_hex not in city_stats:
            city_stats[city_hex] = {'red': 0, 'blue': 0, 'purple': 0}
        city_stats[city_hex][team] += 1

    # Red elite threshold (top 20%)
    red_pts = sorted([
        pts for u_id, pts in yp.items()
        if any(u['id'] == u_id and u['team'] == 'red' for u in state['users'])
        and pts > 0
    ])
    red_threshold = red_pts[int(len(red_pts) * 0.8)] if len(red_pts) > 1 else (red_pts[0] if red_pts else 0)

    # Purple participation
    purple_users = [u for u in state['users'] if u['team'] == 'purple']
    purple_total = len(purple_users)
    purple_active = len([
        u_id for u_id, pts in yp.items()
        if pts > 0 and any(u['id'] == u_id and u['team'] == 'purple' for u in state['users'])
    ])
    purple_rate = round(purple_active / purple_total, 2) if purple_total > 0 else 0

    lines = []
    lines.append("INSERT INTO public.daily_buff_stats (stat_date, city_hex, dominant_team, red_hex_count, blue_hex_count, purple_hex_count, red_elite_threshold_points, purple_total_users, purple_active_users, purple_participation_rate) VALUES")
    vals = []
    for city_hex, counts in city_stats.items():
        dominant = max(counts, key=counts.get) if any(counts.values()) else None
        vals.append(
            f"  ('{run_date_str}'::date, '{city_hex}', "
            f"'{dominant}', {counts['red']}, {counts['blue']}, {counts['purple']}, "
            f"{red_threshold}, {purple_total}, {purple_active}, {purple_rate})"
        )
    lines.append(",\n".join(vals))
    lines.append("ON CONFLICT (stat_date, city_hex) DO UPDATE SET")
    lines.append("  dominant_team = EXCLUDED.dominant_team,")
    lines.append("  red_hex_count = EXCLUDED.red_hex_count,")
    lines.append("  blue_hex_count = EXCLUDED.blue_hex_count,")
    lines.append("  purple_hex_count = EXCLUDED.purple_hex_count,")
    lines.append("  red_elite_threshold_points = EXCLUDED.red_elite_threshold_points,")
    lines.append("  purple_total_users = EXCLUDED.purple_total_users,")
    lines.append("  purple_active_users = EXCLUDED.purple_active_users,")
    lines.append("  purple_participation_rate = EXCLUDED.purple_participation_rate;")
    return "\n".join(lines)


def sql_daily_all_range_stats_insert(hex_teams, run_date_str):
    """Write daily_all_range_stats (province-level hex counts per day)."""
    if not hex_teams:
        return "-- No all-range stats"

    tc = {'red': 0, 'blue': 0, 'purple': 0}
    for team in hex_teams.values():
        if team in tc:
            tc[team] += 1

    dominant = max(tc, key=tc.get) if any(tc.values()) else None

    return (
        f"INSERT INTO public.daily_all_range_stats (stat_date, dominant_team, red_hex_count, blue_hex_count, purple_hex_count, created_at)\n"
        f"VALUES ('{run_date_str}'::date, '{dominant}', {tc['red']}, {tc['blue']}, {tc['purple']}, NOW())\n"
        f"ON CONFLICT (stat_date) DO UPDATE SET\n"
        f"  dominant_team = EXCLUDED.dominant_team,\n"
        f"  red_hex_count = EXCLUDED.red_hex_count,\n"
        f"  blue_hex_count = EXCLUDED.blue_hex_count,\n"
        f"  purple_hex_count = EXCLUDED.purple_hex_count;"
    )


def sql_user_points_update(state):
    lines = []
    for uid in sorted(state['user_points'], key=lambda u: state['user_points'][u], reverse=True):
        pts = state['user_points'][uid]
        stats = state['user_stats'].get(uid, {})
        tr = stats.get('total_runs', 0)
        td = stats.get('total_distance_km', 0)
        avg_pace = round(stats['sum_pace'] / tr, 2) if tr > 0 else 'NULL'
        cc = stats.get('cv_count', 0)
        avg_cv = round(stats['sum_cv'] / cc, 1) if cc > 0 else 'NULL'
        cv_run_count = cc
        if pts > 0 or tr > 0:
            lines.append(
                f"UPDATE public.users SET season_points = {pts}, "
                f"total_distance_km = {td}, total_runs = {tr}, "
                f"avg_pace_min_per_km = {avg_pace}, avg_cv = {avg_cv}, "
                f"cv_run_count = {cv_run_count} "
                f"WHERE id = '{uid}';"
            )
    return "\n".join(lines) if lines else "-- No point updates"


def sql_defections(defectors):
    if not defectors:
        return ""
    lines = []
    for u in defectors:
        lines.append(f"UPDATE public.users SET team = 'purple' WHERE id = '{u['id']}';")
    return "\n".join(lines)


def sql_verify_queries(day, total_days):
    run_date = run_date_for_day(day, total_days)
    run_date_str = run_date.strftime('%Y-%m-%d')
    return f"""
SELECT 'Day {day}/{total_days} ({run_date_str})' as info;

SELECT team, count(*) as user_count, sum(season_points) as total_points
FROM public.users WHERE id::text LIKE 'aaaaaaaa-%' GROUP BY team ORDER BY total_points DESC;

SELECT team, count(*) as hex_count
FROM (SELECT last_runner_team as team FROM public.hexes WHERE last_runner_team IS NOT NULL) t
GROUP BY team ORDER BY hex_count DESC;

SELECT u.name, u.team, u.season_points, u.total_distance_km, u.total_runs,
       CASE WHEN u.avg_cv IS NOT NULL THEN (100 - u.avg_cv)::INTEGER ELSE NULL END as stability
FROM public.users u
WHERE u.season_points > 0
ORDER BY u.season_points DESC LIMIT 10;

SELECT count(*) as runs_today FROM public.run_history WHERE run_date = '{run_date_str}';
SELECT count(*) as hex_snapshot_count FROM public.hex_snapshot WHERE snapshot_date = '{run_date_str}';
SELECT count(*) as all_range_stats FROM public.daily_all_range_stats WHERE stat_date = '{run_date_str}';
"""


# ==================== Full SQL Generation ====================

def generate_full_sql(state, day, total_days):
    sections = []
    run_date = run_date_for_day(day, total_days)
    run_date_str = run_date.strftime('%Y-%m-%d')
    sections.append(f"-- RunStrict Day {day} / {total_days} ({run_date_str})")
    sections.append(f"-- Home hex: {state.get('home_hex', 'N/A')}")
    sections.append(f"-- Yesterday GMT+2: {today_gmt2() - timedelta(days=1)}")
    sections.append("")

    if day == 1:
        sections.append(sql_auth_users_insert(state['users']))
        sections.append("")
        sections.append(sql_users_insert(state['users']))
        sections.append("")

    defectors = handle_defections(state, day)
    if defectors:
        sections.append(sql_defections(defectors))
        sections.append("")

    runs, hex_teams, day_flip_points = generate_day_data(state, day, total_days)
    update_state(state, day, runs, hex_teams, day_flip_points)

    sections.append(sql_runs_insert(runs))
    sections.append("")
    sections.append(sql_hexes_upsert(hex_teams))
    sections.append("")
    sections.append(sql_hex_snapshot_insert(hex_teams, run_date_str))
    sections.append("")
    sections.append(sql_daily_buff_stats_insert(state, day, hex_teams, run_date_str))
    sections.append("")
    sections.append(sql_daily_all_range_stats_insert(hex_teams, run_date_str))
    sections.append("")
    sections.append(sql_user_points_update(state))
    sections.append("")
    sections.append(sql_verify_queries(day, total_days))

    return "\n".join(sections)


def print_status(state):
    if state['last_day'] == 0:
        print("No simulation data. Run --days N --home-hex <your_hex> to start.", file=sys.stderr)
        return

    total_days = state.get('total_days', state['last_day'])
    print(f"Day {state['last_day']}/{total_days} | Home: {state.get('home_hex', 'N/A')}", file=sys.stderr)
    print(f"Hexes: {len(state.get('same_hexes', []))} same + {len(state.get('other_hexes', []))} other province", file=sys.stderr)

    if state.get('real_user_id'):
        print(f"Real user: {state['real_user_id']} ({state.get('real_user_team', '?')})", file=sys.stderr)

    tc = {'red': 0, 'blue': 0, 'purple': 0}
    for t in state.get('hex_teams', {}).values():
        if t in tc:
            tc[t] += 1

    team_pts = {'red': 0, 'blue': 0, 'purple': 0}
    team_sizes = {'red': 0, 'blue': 0, 'purple': 0}
    for u in state['users']:
        team_pts[u['team']] += state['user_points'].get(u['id'], 0)
        team_sizes[u['team']] += 1

    print(f"Teams:  Red {team_sizes['red']} | Blue {team_sizes['blue']} | Purple {team_sizes['purple']}", file=sys.stderr)
    print(f"Points: Red {team_pts['red']:,} | Blue {team_pts['blue']:,} | Purple {team_pts['purple']:,}", file=sys.stderr)
    print(f"Hexes:  Red {tc['red']} | Blue {tc['blue']} | Purple {tc['purple']}", file=sys.stderr)

    # Date mapping
    for d in range(1, state['last_day'] + 1):
        rd = run_date_for_day(d, total_days)
        label = " (yesterday)" if rd == today_gmt2() - timedelta(days=1) else ""
        print(f"  Day {d} -> {rd}{label}", file=sys.stderr)

    top = sorted(state['user_points'].items(), key=lambda x: x[1], reverse=True)[:5]
    print(f"Top 5:", file=sys.stderr)
    for rank, (uid, pts) in enumerate(top, 1):
        user = next((u for u in state['users'] if u['id'] == uid), None)
        if user:
            real_tag = " [YOU]" if user.get('is_real_user') else ""
            print(f"  #{rank} {user['name']:18s} {user['team']:6s} {pts:,} pts{real_tag}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description='RunStrict Day-by-Day Season Simulator v2')
    parser.add_argument('--days', type=int, help='Number of days to simulate (batch mode)')
    parser.add_argument('--day', type=int, help='Single day number to simulate (legacy)')
    parser.add_argument('--home-hex', type=str, help='Your H3 Res 9 hex ID')
    parser.add_argument('--user-id', type=str, help='Real user UUID to include in simulation')
    parser.add_argument('--user-team', type=str, choices=['red', 'blue', 'purple'], help='Real user team')
    parser.add_argument('--dry-run', action='store_true', help='Print SQL only, do not execute')
    parser.add_argument('--save', action='store_true', help='Save SQL to sql/day_NN.sql')
    parser.add_argument('--reset', action='store_true', help='Wipe all data and clear state')
    parser.add_argument('--status', action='store_true', help='Show current simulation state')
    parser.add_argument('--seed', type=int, default=42, help='Random seed (default: 42)')
    args = parser.parse_args()

    if args.status:
        print_status(load_state())
        return

    if args.reset:
        sql = open(SCRIPT_DIR / 'reset_simulation.sql').read()
        if args.dry_run:
            print(sql)
        else:
            print("Resetting all data...", file=sys.stderr)
            execute_sql(sql, "Reset")
            print("Done.", file=sys.stderr)
        if STATE_FILE.exists():
            STATE_FILE.unlink()
            print("State file cleared.", file=sys.stderr)
        return

    # Determine total_days and which days to simulate
    if args.days is not None:
        total_days = args.days
        days_to_simulate = list(range(1, total_days + 1))
    elif args.day is not None:
        # Legacy single-day mode
        total_days = args.day  # Assume total = day number (backward compat)
        days_to_simulate = [args.day]
    else:
        parser.error("--days N or --day N is required (or use --reset / --status)")
        return

    if any(d < 1 or d > 40 for d in days_to_simulate):
        parser.error("Days must be 1-40")

    home_hex = args.home_hex or DEFAULT_HOME_HEX
    if not args.home_hex:
        print(f"No --home-hex provided, using default: {DEFAULT_HOME_HEX}", file=sys.stderr)

    try:
        res = h3.get_resolution(home_hex)
        if res != BASE_RESOLUTION:
            print(f"WARNING: Home hex is resolution {res}, expected {BASE_RESOLUTION}.", file=sys.stderr)
    except Exception as e:
        parser.error(f"Invalid H3 hex ID '{home_hex}': {e}")

    # Initialize state for batch mode (always fresh for --days)
    if args.days is not None:
        same_hexes, other_hexes = generate_hexes_from_home(home_hex)

        state = default_state()
        state['seed'] = args.seed
        state['home_hex'] = home_hex
        state['same_hexes'] = same_hexes
        state['other_hexes'] = other_hexes
        state['total_days'] = total_days
        state['users'] = generate_users(args.seed, same_hexes, other_hexes)

        # Add real user if specified
        if args.user_id and args.user_team:
            state['real_user_id'] = args.user_id
            state['real_user_team'] = args.user_team
            state['users'].append({
                'id': args.user_id,
                'name': 'You',  # Placeholder — real user's name is already in DB
                'team': args.user_team,
                'original_team': args.user_team,
                'avatar': '\U0001f3c3',
                'archetype': 'normal',  # Real user gets normal archetype (mid-range)
                'home_hex': home_hex,
                'province': 'same',
                'is_real_user': True,
            })
            print(f"Real user {args.user_id} ({args.user_team}) added as 'normal' archetype", file=sys.stderr)
    else:
        # Legacy single-day mode
        state = load_state()
        state['seed'] = args.seed
        if not state.get('same_hexes'):
            same_hexes, other_hexes = generate_hexes_from_home(home_hex)
            state['home_hex'] = home_hex
            state['same_hexes'] = same_hexes
            state['other_hexes'] = other_hexes
            state['users'] = generate_users(args.seed, same_hexes, other_hexes)
        state['total_days'] = total_days

    # Print date mapping
    print(f"\nDate mapping (total_days={total_days}):", file=sys.stderr)
    for d in days_to_simulate:
        rd = run_date_for_day(d, total_days)
        label = " <- yesterday GMT+2" if rd == today_gmt2() - timedelta(days=1) else ""
        print(f"  Day {d} -> {rd}{label}", file=sys.stderr)
    print("", file=sys.stderr)

    # Generate and execute each day
    for day in days_to_simulate:
        print(f"Generating day {day}/{total_days}...", file=sys.stderr)
        sql = generate_full_sql(state, day, total_days)

        if args.save:
            SQL_DIR.mkdir(exist_ok=True)
            path = SQL_DIR / f'day_{day:02d}.sql'
            path.write_text(sql)
            print(f"Saved to {path}", file=sys.stderr)

        if args.dry_run:
            print(sql)
        else:
            print(f"Executing day {day} SQL...", file=sys.stderr)
            execute_sql(sql, f"Day {day}")

    save_state(state)
    print_status(state)


if __name__ == '__main__':
    main()
