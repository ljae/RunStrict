# Error Fix History — Quick Reference

> **Updated**: 2026-04-29
> Track all fixes to prevent duplicated errors or mistakes.
>
> This file is a thin **index**. The full chronological postmortems live in
> [`docs/invariants/fix-archive.md`](./docs/invariants/fix-archive.md).
> The pre-edit search script greps both: `./scripts/pre-edit-check.sh --search <term>`.

---

## ⚡ Critical Invariants — Quick Reference

> Before editing ANY file, check this list. Each invariant was forged from a real production bug.

| # | Rule | What breaks if violated |
|---|------|------------------------|
| 1 | **Snapshot date = D+1** | `get_hex_snapshot` must query `GMT+2_date + 1`. Map shows all gray if wrong. |
| 2 | **Server response is truth** | After `finalize_run()`, use `syncResult['points_earned']` — NOT client `flipPoints`. Inflated header points. |
| 3 | **Local overlay ≠ LRU cache** | `_localOverlayHexes` is a plain Map. Putting it in `_hexCache` causes today's flips to disappear on eviction. |
| 4 | **clearAll() is nuclear** | Only for province change. NOT for season reset (territory persists). Day rollover → use `clearLocalOverlay()` only. |
| 5 | **OnResume refreshes ALL providers** | `_onAppResume()` must call every server-derived provider. Missing one = stale data until cold restart. |
| 6 | **initState fires once** | Screens in the nav stack don't re-run `initState` on resume. Push data via `_onAppResume()`. |
| 7 | **Two data domains — never mix** | ALL TIME stats = local SQLite `runs.fold()`. Season data = server RPCs. Never read `UserModel` aggregates for display. |
| 8 | **Season boundary in RPCs** | RPCs querying 'yesterday' must guard: if yesterday < season start → return defaults (not last-season data). |
| 9 | **RPC shape = parser shape** | JSON key mismatch makes `fromJson` silently return 0. Always verify both sides. |
| 10 | **AppLifecycleManager singleton** | Only first `initialize()` wins. Don't call from multiple entry points. |
| 11 | **Server-domain fallback dates = GMT+2** | Any fallback `DateTime` in server-domain models (e.g., `YesterdayStats`, `TeamRankings`) must use `Gmt2DateUtils.todayGmt2`, never `DateTime.now()`. Wrong timezone causes stat gaps for users in non-GMT+2 zones. |
| 12 | **`_onAppResume` math.max must trust server zero** | Use `serverSeasonPoints == 0 ? 0 : math.max(serverSeasonPoints, points.seasonPoints)`. Using `math.max(server, totalSeasonPoints)` (1) blocks season resets and (2) double-counts `_localUnsyncedToday`. |
| 13 | **`snapshot_season_leaderboard()` must be date-bounded** | Old version read `users.season_points` + `users.team` — reset each season. Call after transition → empty snapshot. New version reads `run_history` with explicit date bounds. |
| 14 | **`get_season_leaderboard` must read `season_leaderboard_snapshot`** | Old version ignored `p_season_number` and always returned current live `users` data. Past-season navigation always showed current season. |
| 15 | **`handle_season_transition` cron must run at 21:55 UTC** | `build_daily_hex_snapshot()` runs at 22:00 UTC (midnight GMT+2). If reset runs after, hexes are still populated → new season starts with previous season's territory. |
| 16 | **`updateHexColor` must use `getHex()` not `_hexCache.get()`** | `getHex()` merges cache + overlay. Raw cache read ignores today's flips → same-color running counts as flips. |
| 17 | **Dart `if` in widget tree must be INSIDE `children: [...]`** | `if (cond) ...[...]` outside the list causes "Expected an identifier, but got 'if'" build error. |
| 18a | **finalize_run province change must update local home hex** | If client doesn't update local home hex, PrefetchService keeps downloading old province → "No data" on TeamScreen. |
| 18b | **`computeHexDominance` for TeamScreen must pass `includeLocalOverlay: false`** | TeamScreen territory = "yesterday's snapshot" — must never include today's runs. |
| 19 | **Buff indicator must always show during running** | Hiding the ⚡ stat when buff = 1x leaves new users with no buff feedback. Use dim color for 1x, amber for >1x. |
| 20 | **Buff reads `hex_snapshot`, not live `hexes`** | `calculate_daily_buffs()` must read frozen midnight snapshot, not live hexes (which diverge during the day). |
| 21 | **Province win query must filter by `province_hex`** | `get_user_buff()` province query must include `AND province_hex = v_province_hex`. `LIMIT 1` alone picks a random row. |
| 22 | **`midnight_cron_batch()` must sequence: snapshot first, then buffs** | Otherwise buff calc reads yesterday's snapshot → stale buff for first hours of each day. |
| 23 | **`city_hex` (Res 6) must be stored per hex for district accuracy** | Without it, server uses province counts as approximation → multi-district provinces show wrong winner. |
| 24 | **Run history MUST survive logout / stale session** | NEVER call `clearAllGuestData()` for authenticated users. Use `clearSessionCaches()` (caches only) on logout. |
| 25 | **Guard `isNotEmpty` alongside `!= null` before H3 BigInt parsing** | `BigInt.parse("", radix: 16)` throws `FormatException`. Server strings can be `""` even when non-null. |
| 26 | **iOS Google Sign-In must use native SDK + `signInWithIdToken`** | `signInWithOAuth` (browser-based) causes blank screen / "Access blocked" — Google banned embedded WKWebViews in 2021. |
| 27 | **`delete-account` must anonymize `public.users`, NOT delete it** | `run_history.user_id` has `ON DELETE CASCADE`. Deleting wipes ALL run history. Anonymize PII, hard-delete only `auth.users`. |
| 28 | **`finalize_run` INSERT into `run_history` must be idempotent** | `SyncRetryService` retries across sessions. Need `UNIQUE(user_id, start_time)` + `ON CONFLICT DO NOTHING`. |
| 29 | **`finalize_run` idempotency must be a full early-exit guard** | `ON CONFLICT DO NOTHING` skips INSERT but still runs UPDATE → double-counts season_points/total_runs/avg_cv. RETURN at top. |
| 30 | **`district_hex` = where user last ran — owned exclusively by `finalize_run`** | `update_home_location` must NOT write `district_hex`. Otherwise moving country → 1x buff with no rankings. |
| 31 | **`finalize_run` must derive `district_hex` from `p_hex_district_parents[1]`** | Client never sends `p_district_hex` (always NULL). Use the first hex's Res-6 parent which the client always sends. |
| 32 | **Both district-scoped RPCs must use server-wins COALESCE** | `get_team_rankings` and `get_user_buff` must use `COALESCE(users.district_hex, p_district_hex)` (server wins). |
| 33 | **`isInScope` primary and fallback paths must use same resolution source** | Primary must use `scope.resolution`, not `H3Config.provinceResolution`. Divergence makes users invisible in leaderboard. |
| 34 | **Never use `RECORD IS NOT NULL` in PL/pgSQL — use `FOUND`** | PG composite `IS NOT NULL` returns FALSE if ANY field is NULL. Always use `FOUND` after `SELECT INTO`. |
| 35 | **`season_leaderboard_snapshot` must refresh daily via cron** | Snapshot was created once. Mid-season joiners never appeared in rankings. Daily 22:05 UTC cron required. |
| 36 | **`get_user_buff` must not early-return on NULL `district_hex`** | Province wins are independent of district. Compute province wins whenever `province_hex` is available. |
| 37 | **Cron order: hex snapshot BEFORE buff calculation** | hex snapshot @ 22:00, buff @ 22:02, leaderboard @ 22:05 UTC. Otherwise buff reads mid-write snapshot. |
| 38 | **Team screen must auto-update location when hex data is missing** | Users with NULL `homeHex`/`homeHexDistrict` see empty territory. Silently call `PrefetchService.updateHomeHex()` first. |
| 39 | **Buff uses `yesterday_district_hex`, not current `district_hex`** | Otherwise buff looks up wrong district after user runs in a new area today. |
| 40 | **Buff is frozen for the entire GMT+2 day** | TeamScreen must NOT call `loadBuff()` separately — it reads from frozen `buffProvider` set at app launch. |
| 41 | **All pace formatters must guard `> 99` min/km** | Corrupted `avg_pace_min_per_km` (e.g. 468) produces "468'57/km". Return `"-'--"` when pace > 99. |
| 42 | **iOS voice announcements must duck audio, not interrupt** | (See Invariant #61 — superseded by native TTS approach.) |
| 43 | **Territory and buff must use same anchor: last-run location** | Use `yesterday_district_hex`/`yesterday_province_hex` (frozen at midnight), not GPS home. |
| 44 | **Cross-province hex download must merge, never clear** | During active runs, foreign provinces use `bulkMergeFromSnapshot()`, NOT `bulkLoadFromSnapshot()` (which clears LRU). |
| 45 | **Pause must not stop GPS subscription** | Stopping CLLocationManager causes 5-15s cold-start on resume. Gate in Dart with `_isPaused`, keep GPS warm. |
| 46 | **`fn_sync_snapshot_on_user_change` must skip NULL team** | Reset sets `team = NULL`, trigger tries `UPDATE snapshot SET team = NULL` → NOT NULL violation → reset rolls back. |
| 47 | **`sumAllFlipPoints()` must filter by season start date** | Without `WHERE startTime >= seasonStartMs`, offline fallback inflates header points across seasons. |
| 48 | **`Run.toMap()` columns must match SQLite schema** | Missing column → `sqflite` throws → run silently lost. Always add column to `_onCreate` AND a migration. |
| 49 | **Leaderboard subtraction must clamp with `GREATEST(0, ...)`** | Stale `users.total_distance_km` → subtraction goes negative on the leaderboard. |
| 50 | **Split audio session ownership: native sets category, flutter_tts mirrors** | (Superseded by #61 — see fix-archive.md for full historical detail.) |
| 51 | **`_speak()` must timeout + drop stale announcements** | Without timeout, hung `AVSpeechSynthesizer` deadlocks `_speakLock` → announcements burst at run end. |
| 52 | **Hexes (live) persist across season resets — "the land remembers"** | `reset_season()` must NOT `DELETE FROM hexes`. Territory carries between seasons. |
| 53 | **`hex_season_archive` stores final-day territory per season** | Before deleting `hex_snapshot` in reset, copy latest snapshot rows to archive. PK `(hex_id, season_number)`. |
| 54 | **Background TTS utterances on iOS must be wrapped in `beginBackgroundTask`** | Without it, isolate suspends in the gap between MethodChannel dispatch and `speak()`. |
| 55 | **Foreground-only `setCategory`/activation; background = `beginBackgroundTask`-only** | (Largely superseded by #61.) |
| 56 | **Use `.interruptSpokenAudioAndMixWithOthers` + `.duckOthers`** | (Superseded by #61.) |
| 57 | **~~200ms pre-speak delay~~** | SUPERSEDED by #58. |
| 58 | **Audio session stays active for entire run — no per-utterance toggling** | (Superseded by #61.) |
| 59 | **`prewarmTtsCategory` must not call `setActive(false)` first; register interruption observer** | (Superseded by #61.) |
| 60 | **Live Activity must be sequentially cleaned up and recoverable on resume** | Stale `Activity.end()` racing new `Activity.request()` → `await` cleanup, add `checkAndRecover()` on resume. |
| 61 | **iOS TTS: native `AVSpeechSynthesizer` with `usesApplicationAudioSession = false`** | SUPERSEDES #42, #50-#59. iOS manages audio session via `speechsynthesisd` XPC. App does NOT touch `AVAudioSession`. |

---

## How to Use This Index

| You're about to… | Look up |
|---|---|
| Edit hex / snapshot / overlay logic | #1, #3, #4, #16, #18b, #20, #44, #52, #53 |
| Edit `finalize_run` / sync | #2, #28, #29, #30, #31, #48 |
| Edit buffs / leaderboard / rankings | #13, #14, #19–23, #32, #34–43, #46, #49 |
| Edit OnResume / lifecycle / providers | #5, #6, #10, #12, #45, #60 |
| Edit timezone / date / season-boundary code | #1, #8, #11, #15, #22, #37 |
| Touch TTS / audio / iOS audio session | #61 (the rest are superseded but kept as historical) |
| Touch logout / account / auth | #24, #26, #27 |
| Display formatters (pace, distance, points) | #25, #41, #49 |
| Build error: `if` spread / widget tree | #17 |

For full postmortems on any invariant → grep `docs/invariants/fix-archive.md` for the rule keyword,
or run `./scripts/pre-edit-check.sh --search <component>`.

---

**Pre-edit script**: `./scripts/pre-edit-check.sh` — interactive checklist for any edit.
**Pre-edit search**: `./scripts/pre-edit-check.sh --search <component>` — grep history for your component.
**Full archive**: [`docs/invariants/fix-archive.md`](./docs/invariants/fix-archive.md)
