#!/usr/bin/env python3
"""
RunStrict Day-by-Day Season Simulator

Generates SQL for one season day at a time. Run day 1, paste SQL into Supabase,
check the app. Then run day 2, paste, check. See how the season evolves.

Usage:
    python3 simulate_day.py --day 1              # Print day 1 SQL to stdout
    python3 simulate_day.py --day 2              # Print day 2 SQL (cumulative)
    python3 simulate_day.py --day 1 --save       # Save to sql/day_01.sql
    python3 simulate_day.py --reset              # Print reset SQL only
    python3 simulate_day.py --status             # Show current state summary

State tracked in .sim_state.json between runs.
Run --day 1 first (creates users), then --day 2, --day 3, etc.
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

SCRIPT_DIR = Path(__file__).parent
STATE_FILE = SCRIPT_DIR / '.sim_state.json'
SQL_DIR = SCRIPT_DIR / 'sql'

SEASON_START = datetime(2026, 2, 11, tzinfo=timezone.utc)
NUM_USERS = 100
TEAM_DISTRIBUTION = {'red': 40, 'blue': 40, 'purple': 20}

ARCHETYPES = {
    'star':    {'weight': 10, 'participation': 0.92, 'dist': (8.0, 15.0), 'pace': (4.5, 5.5), 'cv': (3.0, 8.0)},
    'regular': {'weight': 40, 'participation': 0.62, 'dist': (4.0, 10.0), 'pace': (5.0, 6.5), 'cv': (5.0, 15.0)},
    'casual':  {'weight': 35, 'participation': 0.32, 'dist': (2.0, 6.0),  'pace': (6.0, 7.5), 'cv': (10.0, 25.0)},
    'ghost':   {'weight': 15, 'participation': 0.08, 'dist': (2.0, 4.0),  'pace': (6.5, 8.0), 'cv': (15.0, 30.0)},
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

ALL_HEXES = [
    '89283082803ffff', '89283082807ffff', '8928308280bffff', '8928308280fffff',
    '89283082813ffff', '89283082817ffff', '8928308281bffff', '8928308281fffff',
    '89283082823ffff', '89283082827ffff', '8928308282bffff', '8928308282fffff',
    '89283082833ffff', '89283082837ffff', '8928308283bffff', '8928308283fffff',
    '89283082843ffff', '89283082847ffff', '8928308284bffff', '8928308284fffff',
    '89283082853ffff', '89283082857ffff', '8928308285bffff', '8928308285fffff',
    '89283082863ffff', '89283082867ffff', '8928308286bffff', '8928308286fffff',
    '89283082873ffff', '89283082877ffff', '8928308287bffff', '8928308287fffff',
    '89283082883ffff', '89283082887ffff', '8928308288bffff', '8928308288fffff',
    '89283082893ffff', '89283082897ffff', '8928308289bffff', '8928308289fffff',
    '892830828a3ffff', '892830828a7ffff', '892830828abffff', '892830828afffff',
    '892830828b3ffff', '892830828b7ffff', '892830828bbffff', '892830828bfffff',
    '892830828c3ffff', '892830828c7ffff', '892830828cbffff', '892830828cfffff',
    '892830828d3ffff', '892830828d7ffff', '892830828dbffff', '892830828dfffff',
    '892830828e3ffff', '892830828e7ffff', '892830828ebffff', '892830828efffff',
    '892830828f3ffff', '892830828f7ffff', '892830828fbffff', '892830828ffffff',
    '89283082903ffff', '89283082907ffff', '8928308290bffff', '8928308290fffff',
    '89283082913ffff', '89283082917ffff', '8928308291bffff', '8928308291fffff',
    '89283082923ffff', '89283082927ffff', '8928308292bffff', '8928308292fffff',
    '89283082933ffff', '89283082937ffff', '8928308293bffff', '8928308293fffff',
    '89283082943ffff', '89283082947ffff', '8928308294bffff', '8928308294fffff',
    '89283082953ffff', '89283082957ffff', '8928308295bffff', '8928308295fffff',
    '89283082963ffff', '89283082967ffff', '8928308296bffff', '8928308296fffff',
    '89283082973ffff', '89283082977ffff', '8928308297bffff', '8928308297fffff',
    '89283082983ffff', '89283082987ffff', '8928308298bffff', '8928308298fffff',
    '89283082993ffff', '89283082997ffff', '8928308299bffff', '8928308299fffff',
    '892830829a3ffff', '892830829a7ffff', '892830829abffff', '892830829afffff',
    '892830829b3ffff', '892830829b7ffff', '892830829bbffff', '892830829bfffff',
    '892830829c3ffff', '892830829c7ffff', '892830829cbffff', '892830829cfffff',
    '892830829d3ffff', '892830829d7ffff', '892830829dbffff', '892830829dfffff',
    '892830829e3ffff', '892830829e7ffff', '892830829ebffff', '892830829efffff',
    '892830829f3ffff', '892830829f7ffff', '892830829fbffff', '892830829ffffff',
    '89283082a03ffff', '89283082a07ffff', '89283082a0bffff', '89283082a0fffff',
    '89283082a13ffff', '89283082a17ffff', '89283082a1bffff', '89283082a1fffff',
    '89283082a23ffff', '89283082a27ffff', '89283082a2bffff', '89283082a2fffff',
    '89283082a33ffff', '89283082a37ffff', '89283082a3bffff', '89283082a3fffff',
    '89283082a43ffff', '89283082a47ffff', '89283082a4bffff', '89283082a4fffff',
    '89283082a53ffff', '89283082a57ffff', '89283082a5bffff', '89283082a5fffff',
    '89283082a63ffff', '89283082a67ffff', '89283082a6bffff', '89283082a6fffff',
]

DEFECTION_DAYS = range(15, 26)
DEFECTION_COUNT = 8


def esc(s):
    return s.replace("'", "''")


def default_state():
    return {
        'last_day': 0,
        'seed': 42,
        'users': [],
        'user_points': {},
        'user_stats': {},
        'hex_teams': {},
        'yesterday_flip_points': {},
    }


def load_state():
    if STATE_FILE.exists():
        return json.load(open(STATE_FILE))
    return default_state()


def save_state(state):
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)


def generate_users(seed):
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

        users.append({
            'id': uid,
            'name': name,
            'team': team_list[i],
            'original_team': team_list[i],
            'avatar': AVATARS[i % len(AVATARS)],
            'archetype': archetype_names[i % len(archetype_names)],
            'home_hex': ALL_HEXES[i % len(ALL_HEXES)],
        })

    return users


def generate_run_path(user_home_idx, num_hexes):
    path = []
    nearby = 30
    for _ in range(num_hexes):
        if random.random() < 0.7:
            offset = random.randint(-nearby // 2, nearby // 2)
            idx = (user_home_idx + offset) % len(ALL_HEXES)
        else:
            idx = random.randint(0, len(ALL_HEXES) - 1)
        hid = ALL_HEXES[idx]
        if hid not in path:
            path.append(hid)
    return path if path else [ALL_HEXES[user_home_idx]]


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
                if u['team'] in ('red', 'blue') and u['original_team'] != 'purple']
    if not eligible:
        return []
    count = min(DEFECTION_COUNT // len(DEFECTION_DAYS) + 1, len(eligible))
    defectors = random.sample(eligible, min(count, len(eligible)))
    for u in defectors:
        u['team'] = 'purple'
    return defectors


def generate_day_data(state, day):
    random.seed(state['seed'] + day)
    users = state['users']
    hex_teams = dict(state.get('hex_teams', {}))
    runs = []
    day_flip_points = {}
    run_date = SEASON_START + timedelta(days=day - 1)

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
        home_idx = ALL_HEXES.index(user['home_hex']) if user['home_hex'] in ALL_HEXES else 0
        hex_path = generate_run_path(home_idx, num_hexes)

        team = user['team']
        flips = 0
        for hid in hex_path:
            if hex_teams.get(hid) != team:
                flips += 1
            hex_teams[hid] = team

        buff = calculate_buff(user, state, day)
        points = flips * buff

        hour = random.randint(5, 21)
        minute = random.randint(0, 59)
        start_time = run_date.replace(hour=hour, minute=minute, second=0)
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


def sql_auth_users_insert(users):
    lines = []
    lines.append("INSERT INTO auth.users (id, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, email, raw_app_meta_data, raw_user_meta_data) VALUES")
    vals = []
    for u in users:
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
    lines = []
    lines.append("INSERT INTO public.users (id, name, team, avatar, season_points, home_hex, season_home_hex, home_hex_end, total_distance_km, total_runs) VALUES")
    vals = []
    for u in users:
        vals.append(
            f"  ('{u['id']}', '{esc(u['name'])}', '{u['team']}', '{esc(u['avatar'])}', 0, "
            f"'{u['home_hex']}', '{u['home_hex']}', '{u['home_hex']}', 0, 0)"
        )
    lines.append(",\n".join(vals))
    lines.append("ON CONFLICT (id) DO UPDATE SET")
    lines.append("  name = EXCLUDED.name, team = EXCLUDED.team, avatar = EXCLUDED.avatar,")
    lines.append("  season_points = 0, home_hex = EXCLUDED.home_hex,")
    lines.append("  season_home_hex = EXCLUDED.season_home_hex, home_hex_end = EXCLUDED.home_hex_end,")
    lines.append("  total_distance_km = 0, total_runs = 0;")
    return "\n".join(lines)


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
    if not hex_teams:
        return "-- No hex updates"
    lines = []
    lines.append("INSERT INTO public.hexes (id, last_runner_team) VALUES")
    vals = []
    for hid, team in hex_teams.items():
        vals.append(f"  ('{hid}', '{team}')")
    lines.append(",\n".join(vals))
    lines.append("ON CONFLICT (id) DO UPDATE SET last_runner_team = EXCLUDED.last_runner_team;")
    return "\n".join(lines)


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
        if pts > 0 or tr > 0:
            lines.append(
                f"UPDATE public.users SET season_points = {pts}, "
                f"total_distance_km = {td}, total_runs = {tr}, "
                f"avg_pace_min_per_km = {avg_pace}, avg_cv = {avg_cv} "
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


def sql_verify_queries(day):
    return f"""
SELECT 'Day {day} Summary' as info;

SELECT team, count(*) as user_count, sum(season_points) as total_points
FROM public.users WHERE id::text LIKE 'aaaaaaaa-%' GROUP BY team ORDER BY total_points DESC;

SELECT team, count(*) as hex_count
FROM (SELECT last_runner_team as team FROM public.hexes WHERE last_runner_team IS NOT NULL) t
GROUP BY team ORDER BY hex_count DESC;

SELECT u.name, u.team, u.season_points, u.total_distance_km, u.total_runs,
       CASE WHEN u.avg_cv IS NOT NULL THEN (100 - u.avg_cv)::INTEGER ELSE NULL END as stability
FROM public.users u
WHERE u.id::text LIKE 'aaaaaaaa-%' AND u.season_points > 0
ORDER BY u.season_points DESC LIMIT 15;

SELECT count(*) as total_runs_today
FROM public.run_history WHERE run_date = '{(SEASON_START + timedelta(days=day - 1)).strftime('%Y-%m-%d')}';
"""


def generate_full_sql(state, day):
    sections = []
    run_date = SEASON_START + timedelta(days=day - 1)
    sections.append(f"-- RunStrict Day {day} / 40 ({run_date.strftime('%Y-%m-%d')})")
    sections.append(f"-- Generated by simulate_day.py")
    sections.append("")

    if day == 1:
        sections.append("-- === CREATE 100 SIMULATION AUTH ENTRIES ===")
        sections.append(sql_auth_users_insert(state['users']))
        sections.append("")
        sections.append("-- === CREATE 100 SIMULATION USERS ===")
        sections.append(sql_users_insert(state['users']))
        sections.append("")

    defectors = handle_defections(state, day)
    if defectors:
        sections.append(f"-- === DEFECTIONS: {len(defectors)} users join PURPLE ===")
        sections.append(sql_defections(defectors))
        sections.append("")

    runs, hex_teams, day_flip_points = generate_day_data(state, day)
    update_state(state, day, runs, hex_teams, day_flip_points)

    sections.append(f"-- === DAY {day} RUNS ({len(runs)} runs) ===")
    sections.append(sql_runs_insert(runs))
    sections.append("")

    sections.append(f"-- === HEX MAP ({len(hex_teams)} hexes) ===")
    sections.append(sql_hexes_upsert(hex_teams))
    sections.append("")

    sections.append(f"-- === UPDATE USER SEASON STATS ===")
    sections.append(sql_user_points_update(state))
    sections.append("")

    sections.append(f"-- === VERIFICATION QUERIES ===")
    sections.append(sql_verify_queries(day))
    sections.append("")

    tc = {'red': 0, 'blue': 0, 'purple': 0}
    for t in hex_teams.values():
        if t in tc:
            tc[t] += 1
    rp = sum(state['user_points'].get(u['id'], 0) for u in state['users'] if u['team'] == 'red')
    bp = sum(state['user_points'].get(u['id'], 0) for u in state['users'] if u['team'] == 'blue')
    pp = sum(state['user_points'].get(u['id'], 0) for u in state['users'] if u['team'] == 'purple')

    sections.append(f"-- === DAY {day} STATS ===")
    sections.append(f"-- Runs today: {len(runs)}")
    sections.append(f"-- Flips today: {sum(r['flip_count'] for r in runs)}")
    sections.append(f"-- Points earned today: {sum(r['flip_points'] for r in runs)}")
    if defectors:
        sections.append(f"-- Defectors: {', '.join(d['name'] for d in defectors)}")
    sections.append(f"-- Cumulative Points: Red {rp:,} | Blue {bp:,} | Purple {pp:,}")
    sections.append(f"-- Hex Control: Red {tc.get('red',0)} | Blue {tc.get('blue',0)} | Purple {tc.get('purple',0)}")
    sections.append(f"-- Team sizes: Red {sum(1 for u in state['users'] if u['team']=='red')} | "
                     f"Blue {sum(1 for u in state['users'] if u['team']=='blue')} | "
                     f"Purple {sum(1 for u in state['users'] if u['team']=='purple')}")

    return "\n".join(sections)


def print_status(state):
    if state['last_day'] == 0:
        print("No simulation data. Run --day 1 to start.", file=sys.stderr)
        return

    print(f"Last simulated day: {state['last_day']}", file=sys.stderr)
    print(f"Users: {len(state['users'])}", file=sys.stderr)

    tc = {'red': 0, 'blue': 0, 'purple': 0}
    for t in state.get('hex_teams', {}).values():
        if t in tc:
            tc[t] += 1

    team_pts = {'red': 0, 'blue': 0, 'purple': 0}
    for u in state['users']:
        pts = state['user_points'].get(u['id'], 0)
        team_pts[u['team']] += pts

    team_sizes = {'red': 0, 'blue': 0, 'purple': 0}
    for u in state['users']:
        team_sizes[u['team']] += 1

    print(f"\nTeam Sizes: Red {team_sizes['red']} | Blue {team_sizes['blue']} | Purple {team_sizes['purple']}", file=sys.stderr)
    print(f"Points:     Red {team_pts['red']:,} | Blue {team_pts['blue']:,} | Purple {team_pts['purple']:,}", file=sys.stderr)
    print(f"Hexes:      Red {tc['red']} | Blue {tc['blue']} | Purple {tc['purple']}", file=sys.stderr)

    top = sorted(state['user_points'].items(), key=lambda x: x[1], reverse=True)[:10]
    print(f"\nTop 10 Leaderboard:", file=sys.stderr)
    for rank, (uid, pts) in enumerate(top, 1):
        user = next((u for u in state['users'] if u['id'] == uid), None)
        if user:
            print(f"  #{rank:2d}  {user['name']:20s}  {user['team']:6s}  {pts:,} pts", file=sys.stderr)


def generate_reset_sql():
    return open(SCRIPT_DIR / 'reset_simulation.sql').read()


def main():
    parser = argparse.ArgumentParser(description='RunStrict Day-by-Day Season Simulator')
    parser.add_argument('--day', type=int, help='Day number to simulate (1-40)')
    parser.add_argument('--save', action='store_true', help='Save SQL to sql/day_NN.sql')
    parser.add_argument('--reset', action='store_true', help='Output reset SQL and clear state')
    parser.add_argument('--status', action='store_true', help='Show current simulation state')
    parser.add_argument('--seed', type=int, default=42, help='Random seed (default: 42)')
    args = parser.parse_args()

    if args.status:
        print_status(load_state())
        return

    if args.reset:
        print(generate_reset_sql())
        if STATE_FILE.exists():
            STATE_FILE.unlink()
        print("-- State file cleared.", file=sys.stderr)
        return

    if args.day is None:
        parser.error("--day N is required (or use --reset / --status)")

    if args.day < 1 or args.day > 40:
        parser.error("Day must be 1-40")

    state = load_state()
    state['seed'] = args.seed

    if args.day == 1:
        state = default_state()
        state['seed'] = args.seed
        state['users'] = generate_users(args.seed)

    expected = args.day - 1
    if state['last_day'] != expected:
        if args.day == 1:
            pass
        else:
            print(f"ERROR: Must run day {expected + 1} first. Last completed: day {state['last_day']}", file=sys.stderr)
            print(f"Run: python3 simulate_day.py --day {state['last_day'] + 1}", file=sys.stderr)
            sys.exit(1)

    sql = generate_full_sql(state, args.day)

    if args.save:
        SQL_DIR.mkdir(exist_ok=True)
        path = SQL_DIR / f'day_{args.day:02d}.sql'
        path.write_text(sql)
        print(f"Saved to {path}", file=sys.stderr)
    else:
        print(sql)

    save_state(state)
    print(f"\nDay {args.day} generated. State saved.", file=sys.stderr)
    print_status(state)


if __name__ == '__main__':
    main()
