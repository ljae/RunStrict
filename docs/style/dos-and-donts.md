# Do's and Don'ts

## Do
- Use `const` constructors for immutable widgets
- Follow Riverpod 3.0 Notifier pattern per [`riverpod_rule.md`](../../riverpod_rule.md)
- Use relative imports for internal files
- Run `flutter analyze` before committing — must be 0 issues
- Add `///` documentation for public APIs
- Use derived getters (`isPurple`, `maxMembers`) instead of stored fields
- Use Supabase RPC for complex queries (multiplier, leaderboard)
- Use `debugPrint()` for logging
- Keep new files **under 500 lines** — see [`code-style.md`](./code-style.md) § File Size

## Don't
- Don't use `print()` — use `debugPrint()`
- Don't suppress lint rules without good reason
- Don't put business logic in widgets — use services/providers
- Don't hardcode colors — use `AppTheme` constants
- Don't use `ChangeNotifier`, `StateNotifier`, or legacy `provider` package — Riverpod 3.0 only
  - **Exception**: `_RouterRefreshNotifier` in `lib/app/routes.dart` extends `ChangeNotifier` as a `GoRouter.refreshListenable` adapter. This is a private, scoped adapter following the GoRouter team's official Riverpod integration pattern — `GoRouter.refreshListenable` requires a `Listenable`, not a Riverpod primitive. Do not replace without a concrete benefit.
- Don't create new state-management patterns
- Don't store derived/calculated data in database — calculate on-demand
- Don't create backend API endpoints — use RLS + Edge Functions
- Don't mix client-side (Running History) and server-side (Season) data domains — Invariant #7
- Don't use `UserModel` server aggregate fields for ALL TIME stats — use local SQLite `runs` table
- Don't create files over 500 lines (new code) — split by feature, not by chunking
- Don't `print` to stdout in tests — use the test runner's reporters

## Pre-Edit Checklist (mandatory before any code change)

```
[ ] 1. READ error-fix-history.md — search for the component/RPC you're about to edit.
       Is there a prior bug here? If yes, understand it before proceeding.
[ ] 2. TRACE the data flow (both directions): writer, reader, callers.
[ ] 3. LIST all consumers of the function/provider you're modifying.
[ ] 4. IDENTIFY the data domain (running history = local; season = server; points = hybrid).
[ ] 5. CHECK OnResume completeness — new stateful provider? Add to _onAppResume().
[ ] 6. RUN flutter analyze before AND after — 0 errors both times.
```

## Post-Edit Verification (before marking task done)

```
[ ] 1. flutter analyze — 0 issues
[ ] 2. LSP diagnostics on every modified file — 0 errors
[ ] 3. Trace the actual app call path (widget → provider → service → RPC).
       Direct RPC test ≠ fix verified.
[ ] 4. Update error-fix-history.md (and docs/invariants/fix-archive.md) with:
       Problem · Root cause · Fix (code snippet) · Verification · Lesson learned.
```

## Editing a Supabase RPC

```
[ ] 1. Check the client-side parser (grep for RPC name in lib/).
[ ] 2. Verify JSON key names match between RPC SELECT and Dart fromJson — Invariant #9.
[ ] 3. Test the RPC directly in SQL to confirm output shape.
[ ] 4. Re-run the app call path (not just the SQL query).
[ ] 5. Write a migration (never edit existing migrations).
[ ] 6. Document the date/offset convention if time math is involved.
```

## Editing a Provider or Notifier

```
[ ] 1. List every widget that calls ref.watch(thisProvider) or ref.read(thisProvider).
[ ] 2. If state shape changes (new field, renamed field), update ALL consumers.
[ ] 3. If provider holds server data: confirm it's refreshed in _onAppResume() — Invariant #5.
[ ] 4. If provider holds local data: confirm it survives app resume (no unintended clearAll) — Invariant #4.
[ ] 5. Check ref.mounted after every await — stale state after async ops is silent.
```

## Debugging Protocol

1. **Search `error-fix-history.md`** for the affected screen/provider/RPC first — it may be a repeat.
2. **Trace the full call path** (widget → provider → service → RPC → DB) before forming a hypothesis.
3. **Verify via app call path**, not direct RPC test. The bug is often in *when* the RPC is called, not *what* it returns.
4. After 2 failed fix attempts → consult Oracle with full failure context.
5. **Never fix + refactor simultaneously.** Fix minimally. Document. Then refactor separately if needed.
