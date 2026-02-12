#!/usr/bin/env python3
"""
RunStrict Daily Simulation Script

Generates random daily run data for 100 users around Apple Park area.
Outputs SQL that can be run in Supabase SQL Editor.

Usage:
    python3 daily_simulation.py --reset --days 40    # Reset + simulate full season
    python3 daily_simulation.py --days 40 > seed.sql # Save to file
"""

import random
import uuid
import argparse
from datetime import datetime, timedelta, timezone
from typing import List, Tuple

CENTER_LAT = 37.3349
CENTER_LNG = -122.0090
H3_RESOLUTION = 9

TEAM_DISTRIBUTION = {'red': 40, 'blue': 40, 'purple': 20}
MIN_PARTICIPATION = 0.4
MAX_PARTICIPATION = 0.7

MIN_DISTANCE_KM = 2.0
MAX_DISTANCE_KM = 15.0
MIN_PACE = 4.5
MAX_PACE = 8.0
MIN_CV = 3.0
MAX_CV = 25.0

BUFF_RANGE = {'red': (1, 4), 'blue': (1, 3), 'purple': (1, 3)}

FIRST_NAMES = [
    "Alex", "Jordan", "Casey", "Riley", "Morgan", "Taylor", "Quinn", "Avery",
    "Blake", "Cameron", "Dakota", "Emery", "Finley", "Gray", "Harper", "Indigo",
    "Jamie", "Kai", "Logan", "Mason", "Noah", "Oliver", "Parker", "Reese",
    "Sage", "Skyler", "Tatum", "River", "Winter", "Phoenix", "Storm", "Arrow",
    "Blaze", "Cloud", "Dawn", "Echo", "Falcon", "Galaxy", "Hawk", "Ion",
    "Jade", "Knight", "Luna", "Midnight", "Nova", "Orion", "Pulse", "Quantum",
    "Raven", "Shadow", "Thunder", "Ultra", "Vega", "Wolf", "Xenon", "Zen"
]

LAST_NAMES = [
    "Runner", "Dash", "Swift", "Flash", "Bolt", "Stride", "Pace", "Sprint",
    "Blaze", "Storm", "Wind", "Fire", "Wave", "Tide", "Frost", "Thunder",
    "Shadow", "Night", "Dawn", "Star", "Moon", "Sun", "Sky", "Cloud",
    "Stone", "Steel", "Iron", "Gold", "Silver", "Bronze", "Copper", "Chrome"
]

AVATARS = ["🏃", "🏃‍♂️", "🏃‍♀️", "🦊", "🐺", "🦅", "🐬", "🔥", "💨", "⚡", "🌊", "🌪️", "💎", "🚀", "🌟", "✨"]

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


def generate_users(num_users: int = 100) -> List[dict]:
    users = []
    team_counts = {'red': 0, 'blue': 0, 'purple': 0}
    
    for i in range(num_users):
        if team_counts['red'] < TEAM_DISTRIBUTION['red']:
            team = 'red'
        elif team_counts['blue'] < TEAM_DISTRIBUTION['blue']:
            team = 'blue'
        else:
            team = 'purple'
        team_counts[team] += 1
        
        user_id = f"aaaaaaaa-{i:04d}-{i:04d}-{i:04d}-{i:012d}"
        first = FIRST_NAMES[i % len(FIRST_NAMES)]
        last = LAST_NAMES[i % len(LAST_NAMES)]
        name = f"{first}{last}{i//len(FIRST_NAMES) if i >= len(FIRST_NAMES) else ''}"
        
        users.append({
            'id': user_id,
            'name': name,
            'team': team,
            'avatar': AVATARS[i % len(AVATARS)],
            'season_points': 0,
        })
    
    return users


def generate_run_path(num_hexes: int) -> List[str]:
    if num_hexes > len(ALL_HEXES):
        num_hexes = len(ALL_HEXES)
    return random.sample(ALL_HEXES, num_hexes)


def generate_run(user: dict, run_date: datetime, existing_hex_teams: dict) -> Tuple[dict, List[Tuple[str, str]], int]:
    team = user['team']
    
    distance_km = round(random.uniform(MIN_DISTANCE_KM, MAX_DISTANCE_KM), 2)
    pace = round(random.uniform(MIN_PACE, MAX_PACE), 2)
    duration_seconds = int(distance_km * pace * 60)
    cv = round(random.uniform(MIN_CV, MAX_CV), 1)
    
    num_hexes = max(3, int(distance_km * 2.5))
    hex_path = generate_run_path(num_hexes)
    
    flips = 0
    hex_updates = []
    for hex_id in hex_path:
        current_team = existing_hex_teams.get(hex_id)
        if current_team != team:
            flips += 1
        hex_updates.append((hex_id, team))
        existing_hex_teams[hex_id] = team
    
    buff_min, buff_max = BUFF_RANGE[team]
    multiplier = random.randint(buff_min, buff_max)
    points = flips * multiplier
    
    hour = random.randint(5, 21)
    minute = random.randint(0, 59)
    start_time = run_date.replace(hour=hour, minute=minute, second=0, microsecond=0)
    end_time = start_time + timedelta(seconds=duration_seconds)
    
    run_record = {
        'id': str(uuid.uuid4()),
        'user_id': user['id'],
        'run_date': run_date.strftime('%Y-%m-%d'),
        'start_time': start_time.strftime('%Y-%m-%d %H:%M:%S+00'),
        'end_time': end_time.strftime('%Y-%m-%d %H:%M:%S+00'),
        'distance_km': distance_km,
        'duration_seconds': duration_seconds,
        'avg_pace_min_per_km': pace,
        'flip_count': flips,
        'flip_points': points,
        'team_at_run': team,
        'cv': cv
    }
    
    return run_record, hex_updates, points


def escape_sql(s: str) -> str:
    return s.replace("'", "''")


def generate_reset_sql() -> str:
    return """-- ============================================================
-- RESET ALL DATA
-- ============================================================
TRUNCATE public.run_history;
TRUNCATE public.hexes;
TRUNCATE public.daily_flips;
DELETE FROM public.users WHERE id LIKE 'aaaaaaaa-%';
"""


def generate_users_sql(users: List[dict]) -> str:
    lines = ["-- ============================================================"]
    lines.append("-- USERS (100 total: 40 Red, 40 Blue, 20 Purple)")
    lines.append("-- ============================================================")
    lines.append("INSERT INTO public.users (id, name, team, avatar, season_points) VALUES")
    
    values = []
    for user in users:
        values.append(f"  ('{user['id']}', '{escape_sql(user['name'])}', '{user['team']}', '{user['avatar']}', 0)")
    
    lines.append(",\n".join(values))
    lines.append("ON CONFLICT (id) DO UPDATE SET")
    lines.append("  name = EXCLUDED.name,")
    lines.append("  team = EXCLUDED.team,")
    lines.append("  avatar = EXCLUDED.avatar,")
    lines.append("  season_points = 0;")
    lines.append("")
    
    return "\n".join(lines)


def generate_runs_sql(runs: List[dict]) -> str:
    if not runs:
        return ""
    
    lines = ["-- ============================================================"]
    lines.append(f"-- RUN HISTORY ({len(runs)} runs)")
    lines.append("-- ============================================================")
    lines.append("INSERT INTO public.run_history (id, user_id, run_date, start_time, end_time, distance_km, duration_seconds, avg_pace_min_per_km, flip_count, flip_points, team_at_run, cv) VALUES")
    
    values = []
    for run in runs:
        values.append(
            f"  ('{run['id']}', '{run['user_id']}', '{run['run_date']}', "
            f"'{run['start_time']}', '{run['end_time']}', "
            f"{run['distance_km']}, {run['duration_seconds']}, {run['avg_pace_min_per_km']}, "
            f"{run['flip_count']}, {run['flip_points']}, '{run['team_at_run']}', {run['cv']})"
        )
    
    lines.append(",\n".join(values) + ";")
    lines.append("")
    
    return "\n".join(lines)


def generate_hexes_sql(hex_teams: dict) -> str:
    if not hex_teams:
        return ""
    
    lines = ["-- ============================================================"]
    lines.append(f"-- HEXES ({len(hex_teams)} hexes)")
    lines.append("-- ============================================================")
    lines.append("INSERT INTO public.hexes (id, last_runner_team) VALUES")
    
    values = []
    for hex_id, team in hex_teams.items():
        values.append(f"  ('{hex_id}', '{team}')")
    
    lines.append(",\n".join(values))
    lines.append("ON CONFLICT (id) DO UPDATE SET last_runner_team = EXCLUDED.last_runner_team;")
    lines.append("")
    
    return "\n".join(lines)


def generate_points_sql(user_points: dict) -> str:
    if not user_points:
        return ""
    
    lines = ["-- ============================================================"]
    lines.append(f"-- UPDATE SEASON POINTS ({len([p for p in user_points.values() if p > 0])} users with points)")
    lines.append("-- ============================================================")
    
    for user_id, points in sorted(user_points.items(), key=lambda x: x[1], reverse=True):
        if points > 0:
            lines.append(f"UPDATE public.users SET season_points = {points} WHERE id = '{user_id}';")
    
    lines.append("")
    return "\n".join(lines)


def simulate_day(users: List[dict], run_date: datetime, existing_hex_teams: dict, user_points: dict) -> List[dict]:
    participation_rate = random.uniform(MIN_PARTICIPATION, MAX_PARTICIPATION)
    num_runners = int(len(users) * participation_rate)
    runners = random.sample(users, num_runners)
    
    all_runs = []
    
    for user in runners:
        run, hex_updates, points = generate_run(user, run_date, existing_hex_teams)
        all_runs.append(run)
        current = user_points.get(user['id'], 0)
        user_points[user['id']] = current + points
    
    return all_runs


def main():
    parser = argparse.ArgumentParser(description='RunStrict Daily Simulation')
    parser.add_argument('--days', type=int, default=40, help='Number of days to simulate (default: 40)')
    parser.add_argument('--reset', action='store_true', help='Include RESET SQL to clear existing data')
    parser.add_argument('--seed', type=int, help='Random seed for reproducibility')
    args = parser.parse_args()
    
    if args.seed:
        random.seed(args.seed)
    
    users = generate_users(100)
    
    today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    start_date = today - timedelta(days=args.days - 1)
    
    existing_hex_teams = {}
    user_points = {u['id']: 0 for u in users}
    all_runs = []
    
    for day_offset in range(args.days):
        run_date = start_date + timedelta(days=day_offset)
        day_runs = simulate_day(users, run_date, existing_hex_teams, user_points)
        all_runs.extend(day_runs)
    
    print("-- ============================================================")
    print(f"-- RunStrict Simulation: D-{args.days} to D-1 (ending {today.strftime('%Y-%m-%d')})")
    print(f"-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("-- ============================================================")
    print("")
    print("-- Run this SQL in Supabase SQL Editor:")
    print("-- https://supabase.com/dashboard/project/vhooaslzkmbnzmzwiium/sql")
    print("")
    
    if args.reset:
        print(generate_reset_sql())
    
    print(generate_users_sql(users))
    print(generate_runs_sql(all_runs))
    print(generate_hexes_sql(existing_hex_teams))
    print(generate_points_sql(user_points))
    
    total_distance = sum(r['distance_km'] for r in all_runs)
    total_flips = sum(r['flip_count'] for r in all_runs)
    
    red_points = sum(p for uid, p in user_points.items() if any(u['id'] == uid and u['team'] == 'red' for u in users))
    blue_points = sum(p for uid, p in user_points.items() if any(u['id'] == uid and u['team'] == 'blue' for u in users))
    purple_points = sum(p for uid, p in user_points.items() if any(u['id'] == uid and u['team'] == 'purple' for u in users))
    
    red_hexes = sum(1 for t in existing_hex_teams.values() if t == 'red')
    blue_hexes = sum(1 for t in existing_hex_teams.values() if t == 'blue')
    purple_hexes = sum(1 for t in existing_hex_teams.values() if t == 'purple')
    
    print("-- ============================================================")
    print("-- SUMMARY")
    print("-- ============================================================")
    print(f"-- Season: D-{args.days} to D-1")
    print(f"-- Users: {len(users)} (Red: 40, Blue: 40, Purple: 20)")
    print(f"-- Total runs: {len(all_runs)}")
    print(f"-- Total distance: {total_distance:.1f} km")
    print(f"-- Total flips: {total_flips}")
    print(f"--")
    print(f"-- Team Points:")
    print(f"--   Red:    {red_points:,}")
    print(f"--   Blue:   {blue_points:,}")
    print(f"--   Purple: {purple_points:,}")
    print(f"--")
    print(f"-- Hex Control:")
    print(f"--   Red:    {red_hexes}")
    print(f"--   Blue:   {blue_hexes}")
    print(f"--   Purple: {purple_hexes}")


if __name__ == '__main__':
    main()
