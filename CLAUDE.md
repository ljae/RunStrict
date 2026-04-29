# CLAUDE.md — RunStrict (AI Routing Index)

> Thin index for AI agents. Read this first, then jump to the **single** doc most relevant to your task.
> Do NOT read every file — pick from the table below.

**Tech stack**: Flutter ≥ 3.27, Dart SDK ≥ 3.11, Riverpod 3.0 (manual providers, NO codegen), Mapbox, Supabase (PostgreSQL + RLS), H3 hex grid, SQLite v26.
**Architecture**: Serverless (no backend API server). Runs on iOS, Android, macOS.

---

## 🚦 Task → File (read ONE)

| If you're about to… | Read this |
|---|---|
| Edit any code (always check first) | [`error-fix-history.md`](./error-fix-history.md) — invariants table |
| Riverpod provider / Notifier / Ref | [`riverpod_rule.md`](./riverpod_rule.md) |
| Code style, naming, build commands | [`docs/style/code-style.md`](./docs/style/code-style.md) |
| Do's & Don'ts, lint rules, file size limits | [`docs/style/dos-and-donts.md`](./docs/style/dos-and-donts.md) |
| Build / run / test commands | [`docs/style/build-commands.md`](./docs/style/build-commands.md) |
| Game rules: season, teams, buffs, hex capture | [`docs/01-game-rules.md`](./docs/01-game-rules.md) |
| Screen layout, widgets, theme, Mapbox visuals | [`docs/02-ui-screens.md`](./docs/02-ui-screens.md) |
| Data models, DB schema, RPCs, repositories | [`docs/03-data-architecture.md`](./docs/03-data-architecture.md) |
| GPS, sync, battery, remote config | [`docs/04-sync-and-performance.md`](./docs/04-sync-and-performance.md) |
| Past decisions, roadmap, version history | [`docs/05-changelog.md`](./docs/05-changelog.md) |
| Investigate a known bug / postmortem | [`docs/invariants/fix-archive.md`](./docs/invariants/fix-archive.md) |
| Project overview / business context | [`AGENTS.md`](./AGENTS.md) |
| Full doc index | [`docs/INDEX.md`](./docs/INDEX.md) |

---

## ⚡ Ripcord (most-asked topics, direct pointers)

- **"Is this a known bug?"** → grep `error-fix-history.md` first; full detail in `docs/invariants/fix-archive.md`. Or `./scripts/pre-edit-check.sh --search <component>`.
- **"What's the buff multiplier?"** → `docs/01-game-rules.md` § Team-Based Buff System.
- **"Where's the hex map rendering?"** → `docs/02-ui-screens.md` § Mapbox Patterns; code at `lib/features/map/widgets/hexagon_map.dart`.
- **"How do I add a new RPC?"** → `docs/03-data-architecture.md` § Key RPC Functions; verify Invariants #9, #29, #34.
- **"Timezone for X?"** → `docs/03-data-architecture.md` § Timezone Architecture + Invariant #11.
- **"Two data domains?"** → Running history = local SQLite; Season data = server. Never mix. Invariant #7.
- **"OnResume refresh?"** → `_onAppResume()` in `lib/features/auth/providers/app_init_provider.dart`. Invariant #5.
- **"Hex cache vs overlay?"** → Invariants #3, #4, #16. `HexRepository().getHex()` always merges both.
- **"Pre-edit checklist?"** → `./scripts/pre-edit-check.sh` (interactive). Required reading: relevant invariants.

---

## 🛑 Hard rules (always)

- **Riverpod 3.0 only.** No `ChangeNotifier`, `StateNotifier`, or legacy `provider` package.
  Exception: `_RouterRefreshNotifier` (GoRouter adapter) — see `lib/app/routes.dart`.
- **Logging**: `debugPrint()` — never `print()`.
- **Before commit**: `flutter analyze` (0 issues) + `./scripts/post-revision-check.sh`.
- **Before any edit**: check `error-fix-history.md` invariants table for related rules.
- **File size ceiling**: new or substantially-modified `.dart` / `.kt` / `.swift` files **must not exceed 500 lines** — split by feature, not by mechanical chunking. See [`docs/style/code-style.md`](./docs/style/code-style.md) § File Size.
- **Two data domains** (Invariant #7): client SQLite for run history; server for season state. Never read `UserModel` aggregates for ALL TIME stats.
- **Timezone**: GMT+2 for game logic (`Gmt2DateUtils.todayGmt2`); device-local for run history display.

---

## Skill routing (when user invokes commands)

When the user's request matches an available skill, ALWAYS invoke it via the Skill tool **before** any other action.

| User intent | Skill |
|---|---|
| Brainstorm / "is this worth building" | `office-hours` |
| Bug, error, "why is this broken" | `investigate` |
| Ship / deploy / create PR | `ship` |
| QA / test the site / find bugs | `qa` |
| Code review / check my diff | `review` |
| Save progress / checkpoint / resume | `checkpoint` |
| Architecture review | `plan-eng-review` |
| Code health check | `health` |
