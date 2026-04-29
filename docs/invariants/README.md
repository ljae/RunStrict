# Invariants — Categorical Index

> Browse production-bug invariants by topic. For the **flat numbered table** of all 61 invariants → see [`error-fix-history.md`](../../error-fix-history.md) at the repo root. For **full postmortems** (problem, root cause, fix, verification) → see [`fix-archive.md`](./fix-archive.md) in this directory.

---

## 🔊 Audio / TTS / iOS Audio Session

Most rules here are **superseded by Invariant #61** (native `AVSpeechSynthesizer` with `usesApplicationAudioSession = false`). Older invariants kept as historical context only.

| # | Rule (one-line) |
|---|---|
| **61** ✅ | iOS TTS: native AVSpeechSynthesizer with `usesApplicationAudioSession = false`. App does NOT touch `AVAudioSession`. (SUPERSEDES 42, 50–59.) |
| 60 | Live Activity sequential cleanup + resume recovery. |
| 51 | `_speak()` must timeout + drop stale announcements. |
| 54 | Background TTS utterances must be wrapped in `beginBackgroundTask`. |
| 42, 50, 55–59 | Historical AVAudioSession management — see fix-archive.md. |

---

## 🗺️ Hex / Snapshot / Local Overlay

| # | Rule |
|---|---|
| 1 | Snapshot date = D+1. `get_hex_snapshot` must query `GMT+2_date + 1`. |
| 3 | Local overlay ≠ LRU cache. `_localOverlayHexes` is a plain Map. |
| 4 | `clearAll()` is nuclear. Province change only — never season reset, never day rollover. |
| 16 | `updateHexColor` must use `getHex()` (which merges cache + overlay), not `_hexCache.get()`. |
| 18b | `computeHexDominance` for TeamScreen must pass `includeLocalOverlay: false`. |
| 20 | Buff reads `hex_snapshot`, not live `hexes`. |
| 44 | Cross-province hex download must merge (`bulkMergeFromSnapshot`), never clear. |
| 52 | Hexes (live) persist across season resets — "the land remembers." |
| 53 | `hex_season_archive` stores final-day territory per season. |

---

## 🏆 Buffs / Leaderboard / Rankings

| # | Rule |
|---|---|
| 13 | `snapshot_season_leaderboard()` must be date-bounded (read `run_history`, not live `users`). |
| 14 | `get_season_leaderboard` must read `season_leaderboard_snapshot` (filter by `p_season_number`). |
| 19 | Buff indicator must always show during running (dim for 1x, amber for >1x). |
| 21 | Province win query must filter by `province_hex` (not `LIMIT 1` alone). |
| 22 | `midnight_cron_batch()` order: snapshot first, then buffs. |
| 23 | `city_hex` (Res 6) must be stored per hex for district accuracy. |
| 32 | Both district-scoped RPCs (`get_team_rankings`, `get_user_buff`) use server-wins COALESCE. |
| 33 | `isInScope` primary and fallback must use same resolution source. |
| 34 | Never use `RECORD IS NOT NULL` in PL/pgSQL — use `FOUND`. |
| 35 | `season_leaderboard_snapshot` refresh daily via cron (22:05 UTC). |
| 36 | `get_user_buff` must not early-return on NULL `district_hex`. |
| 38 | Team screen must auto-update location when hex data is missing. |
| 39 | Buff uses `yesterday_district_hex`, not current `district_hex`. |
| 40 | Buff is frozen for the entire GMT+2 day. |
| 41 | All pace formatters must guard `> 99` min/km. |
| 43 | Territory and buff must use same anchor: last-run location. |
| 46 | `fn_sync_snapshot_on_user_change` must skip NULL team. |
| 49 | Leaderboard subtraction must clamp with `GREATEST(0, ...)`. |

---

## 🔄 Sync / Points / RPC Hygiene

| # | Rule |
|---|---|
| 2 | Server response is truth. Use `syncResult['points_earned']`, not client `flipPoints`. |
| 9 | RPC shape = parser shape. Mismatched JSON keys silently return 0. |
| 12 | `_onAppResume` math.max must trust server zero. |
| 28 | `finalize_run` INSERT into `run_history` must be idempotent (`UNIQUE(user_id, start_time)` + `ON CONFLICT DO NOTHING`). |
| 29 | `finalize_run` idempotency must be a full early-exit guard, not just `ON CONFLICT DO NOTHING`. |
| 30 | `district_hex` is owned exclusively by `finalize_run` (NOT `update_home_location`). |
| 31 | `finalize_run` must derive `district_hex` from `p_hex_district_parents[1]`. |
| 47 | `sumAllFlipPoints()` must filter by season start date. |
| 48 | `Run.toMap()` columns must match SQLite schema. |

---

## 🧱 Two Data Domains / Cross-Season

| # | Rule |
|---|---|
| 7 | Two data domains — never mix. ALL TIME = local SQLite. Season = server RPCs. |
| 8 | Season boundary in RPCs. Yesterday < season start → return defaults. |
| 24 | Run history MUST survive logout / stale session. |
| 27 | `delete-account` must anonymize `public.users`, not delete it. |

---

## ⏰ Timezone / Date / Season Boundary

| # | Rule |
|---|---|
| 11 | Server-domain fallback dates = GMT+2 (`Gmt2DateUtils.todayGmt2`, never `DateTime.now()`). |
| 15 | `handle_season_transition` cron must run at 21:55 UTC (5 min before midnight). |
| 22 | Snapshot before buffs in `midnight_cron_batch()`. |
| 37 | Cron order: hex snapshot @ 22:00, buff @ 22:02, leaderboard @ 22:05 UTC. |

---

## ♻️ Lifecycle / Init / OnResume

| # | Rule |
|---|---|
| 5 | OnResume refreshes ALL stateful providers. |
| 6 | `initState` fires once — push data via `_onAppResume()` for screens in nav stack. |
| 10 | `AppLifecycleManager` is a singleton — only first `initialize()` wins. |
| 45 | Pause must not stop GPS subscription (gate in Dart with `_isPaused`). |
| 60 | Live Activity sequential cleanup + resume recovery. |

---

## 🛡️ Runtime Guards / Build Errors

| # | Rule |
|---|---|
| 17 | Dart `if` in widget tree must be INSIDE the `children: [...]` list. |
| 25 | Guard `isNotEmpty` alongside `!= null` before H3 BigInt parsing. |
| 26 | iOS Google Sign-In must use native SDK + `signInWithIdToken`, never `signInWithOAuth`. |
| 41 | Pace formatters must guard `> 99` min/km. |

---

## How to Look Up Full Detail

```bash
./scripts/pre-edit-check.sh --search <keyword>   # grep both index + archive
```

Or open [`fix-archive.md`](./fix-archive.md) and search for the invariant number / rule keyword.
