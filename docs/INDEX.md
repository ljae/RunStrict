# RunStrict Documentation Index

> Comprehensive map of all documentation. AI agents: jump to the **one** file that matches your task. Humans: this is the table of contents.

**App**: RunStrict (The 40-Day Journey) — location-based running game with hex territory.
**Tech**: Flutter ≥ 3.27 · Dart SDK ≥ 3.11 · Riverpod 3.0 · Mapbox · Supabase (PostgreSQL + RLS) · H3 · SQLite v26.

---

## 1 · Where to Start

| Audience | Start here |
|---|---|
| AI agent (Claude Code) | [`/CLAUDE.md`](../CLAUDE.md) — thin routing index |
| Human onboarding | [`/AGENTS.md`](../AGENTS.md) — project overview |
| Pre-edit safety check | [`/error-fix-history.md`](../error-fix-history.md) — 61-row invariants table |
| Production bug postmortem | [`./invariants/fix-archive.md`](./invariants/fix-archive.md) |

---

## 2 · Reference Manuals (Topic-Based)

Read **one** manual per task — they are sized for fast lookup.

| Manual | Covers | Open when… |
|---|---|---|
| [`01-game-rules.md`](./01-game-rules.md) | Season, teams, buff system, hex capture, scoring, CV/stability, leaderboard, purple defection, D-Day reset | Buff changes, scoring formulas, team mechanics, game-constant tuning |
| [`02-ui-screens.md`](./02-ui-screens.md) | Navigation, all screen specs, widget library, theme/colors, Mapbox rendering, animations | Screen redesigns, widget changes, theme updates, Mapbox layers, layout bugs |
| [`03-data-architecture.md`](./03-data-architecture.md) | Client models, DB schema, repositories, data flow, Two Data Domains, SQLite, tech stack | Adding/modifying models, DB changes, sync bugs, RPC implementation |
| [`04-sync-and-performance.md`](./04-sync-and-performance.md) | The Final Sync, GPS config, signal processing, battery, remote config | GPS tuning, sync strategy, performance work, remote config changes |
| [`05-changelog.md`](./05-changelog.md) | Roadmap, success metrics, session-by-session changelog | Historical "why was X designed this way?" |

---

## 3 · Coding Style & Standards

| File | Covers |
|---|---|
| [`/riverpod_rule.md`](../riverpod_rule.md) | Riverpod 3.0 patterns (Notifier, AsyncNotifier, Ref, ref.mounted, select) — **MUST** follow |
| [`./style/code-style.md`](./style/code-style.md) | Naming, imports, formatting, widget construction, models, **500-line file ceiling** |
| [`./style/dos-and-donts.md`](./style/dos-and-donts.md) | What to do, what to avoid; lint suppressions; legacy patterns |
| [`./style/build-commands.md`](./style/build-commands.md) | `flutter run`, build, test, GPS simulation commands |

---

## 4 · Production Invariants (Forged from Real Bugs)

| File | Covers |
|---|---|
| [`/error-fix-history.md`](../error-fix-history.md) | Quick Reference table — 61 invariants with one-line summaries |
| [`./invariants/README.md`](./invariants/README.md) | Categorical browse: audio, hex, buffs, sync, lifecycle, runtime guards |
| [`./invariants/fix-archive.md`](./invariants/fix-archive.md) | Full chronological postmortems (problem → root cause → fix → verification) |

**Search**: `./scripts/pre-edit-check.sh --search <component>` — greps both index and archive.

---

## 5 · Operational / Setup

| File | Covers |
|---|---|
| [`/CLAUDE_INTEGRATION_GUIDE.md`](../CLAUDE_INTEGRATION_GUIDE.md) | Claude Code environment setup |
| [`/CONFIG_GUIDE.md`](../CONFIG_GUIDE.md) | Server-side `app_config` remote configuration |
| [`/CHANGELOG.md`](../CHANGELOG.md) | Version-by-version release notes |
| [`/PRIVACY_POLICY.md`](../PRIVACY_POLICY.md) | User-facing privacy policy |
| [`/TERMS_OF_SERVICE.md`](../TERMS_OF_SERVICE.md) | User-facing ToS |
| [`/README.md`](../README.md) | Project README |
| [`/TODOS.md`](../TODOS.md) | Open follow-up TODOs |

---

## 6 · Archive (Historical / Read-Only)

Old plans and reports — kept for context but **not read by default**.

| Path | Notes |
|---|---|
| [`./archive/`](./archive/) | Launch-readiness plan, search results, version-1.1.x notes, upgrade reports |
| `/.sisyphus/plans/` | Implementation plans (per-feature) |
| `/.sisyphus/drafts/` | Earlier draft proposals |
| `/.sisyphus/notepads/` | Session learnings |

---

## 7 · Task → Doc Routing (Cheat Sheet)

| Task | Read |
|---|---|
| Buff multiplier, scoring formula, team rules | `01-game-rules.md` |
| Screen layout, widget, theme, Mapbox visual | `02-ui-screens.md` |
| Model field, DB schema, RPC, repository, data flow | `03-data-architecture.md` |
| GPS, sync, battery, remote config, performance | `04-sync-and-performance.md` |
| Riverpod patterns, state management | `riverpod_rule.md` |
| Code style, file size, formatting | `style/code-style.md` |
| Build / test / run commands | `style/build-commands.md` |
| Past decisions, roadmap | `05-changelog.md` |
| Investigate a bug | `error-fix-history.md` (table) → `invariants/fix-archive.md` |
| Multiple domains | INDEX + both relevant manuals |

---

## Project Layout (lib/)

```
lib/
├── main.dart                # App entry, ProviderScope
├── app/                     # Root widget, routes, theme re-export
├── features/
│   ├── auth/                # login, register, team-selection
│   ├── run/                 # active running session
│   ├── map/                 # hex map display
│   ├── leaderboard/         # rankings
│   ├── team/                # team stats, traitor gate
│   ├── profile/             # user profile
│   └── history/             # run history, calendar
├── core/
│   ├── config/              # h3, mapbox, supabase, auth
│   ├── storage/             # SQLite v26
│   ├── utils/               # gmt2_date, lru_cache, route_optimizer
│   ├── widgets/             # shared UI primitives
│   ├── services/            # supabase, remote_config, season, lifecycle, sync_retry, points, buff, prefetch, hex
│   └── providers/           # infrastructure, user_repository, points
├── data/
│   ├── models/              # team, user, hex, run, lap, location_point, app_config, team_stats
│   └── repositories/        # hex, leaderboard, user
└── theme/                   # app_theme.dart
```

Full schema and architectural detail → [`03-data-architecture.md`](./03-data-architecture.md).
