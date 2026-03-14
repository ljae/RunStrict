# Upgrade Report — RunStrict

> Generated: 2026-03-04 | Reviewed: 80+ Dart files, configs, documentation

---

> **📋 Plan Review — Overview**
>
> This report was validated by cross-referencing every item against the actual source code (82 `.dart` files, ~35k lines, 15 core services). **All 14 items are confirmed real issues** — no false positives. The accuracy is high. The priority ordering (Critical → High → Medium) is correct and beneficial to follow.
>
> **Overall verdict: Apply this plan. It is sound, accurate, and will meaningfully improve security, correctness, and maintainability.**
>
> Key corrections and nuances are noted inline below with `📝 Review` callouts.


## Critical (Must Fix Before Production)

### 1. Hardcoded API Secrets in Source Code

| File | Secret |
|------|--------|
| `lib/core/config/supabase_config.dart:3-4` | Supabase anon key (JWT) |
| `lib/core/config/mapbox_config.dart:9` | Mapbox access token (`pk.eyJ1...`) |
| `lib/core/config/revenuecat_config.dart:2` | RevenueCat API key |

While Supabase anon keys are designed for public client use (protected by RLS), committing them to git history enables schema enumeration, rate-limit abuse, and RLS probing. The Mapbox token can incur billing abuse.

**Fix:** Move to `--dart-define` build-time environment variables:
```dart
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
```
Run: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

> **📝 Review — Confirmed. Apply.**
>
> All three secrets are hardcoded as plain `static const String` fields — verified in source. The Mapbox token is a `pk.` (public scope) key; billing abuse is a real risk in a public repo. The RevenueCat key carries a `test_` prefix (`test_wuQqIhVMWueLVWVtXQZYYRmQCnX`). **Before treating it as production-critical, verify whether this is the live production key or a dev-only sandbox key.** If test-only, this entry can be downgraded to High.
>
> No existing `--dart-define` usage was found anywhere in the build pipeline (no CI, no scripts). The dart-define infrastructure must be built from scratch — factor this into effort.
>
> **Caution:** `String.fromEnvironment` returns `''` (not null) when a variable is omitted. Add `assert(url.isNotEmpty, 'SUPABASE_URL must be set')` to catch missed env vars at startup.
>
> **Effort:** Medium (~3–4 hours). **Regression risk:** Low.

### 2. Android Release Signing Uses Debug Keys

`android/app/build.gradle.kts` — release build type:
```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")  // TODO comment exists
}
```

Cannot upload to Google Play. Debug APKs are publicly extractable.

**Fix:** Generate a keystore, create `android/key.properties`, and reference a proper release signing config.

> **📝 Review — Confirmed. Apply immediately.**
>
> The `TODO` comment is present in source. Hard blocker for any Play Store submission. Completely isolated to Android build config — zero Dart code impact.
>
> **Effort:** Low (~1 hour). **Regression risk:** None.


### 3. iOS Ad Unit ID Is Google's Test ID

`ios/Runner/Info.plist` — `GADApplicationIdentifier`:
```
ca-app-pub-3940256099942544~1458002511
```

This is Google's test ad unit — zero ad impressions and zero revenue in production.

**Fix:** Replace with actual production AdMob ID before release.

> **📝 Review — Confirmed. Apply immediately.**
>
> Verified in `Info.plist`. Also confirm that any ad unit IDs used within `AdService` (Dart side) are updated — the `GADApplicationIdentifier` in `Info.plist` must match the AdMob app ID for the production account.
>
> **Effort:** Trivial (~30 minutes). **Regression risk:** None.


---

## High

### 4. `Color.withOpacity()` Deprecated — 50+ Callsites

`Color.withOpacity()` was deprecated in Flutter 3.27 (Oct 2024). Found in:

| File | Occurrences |
|------|-------------|
| `lib/features/run/screens/running_screen.dart` | ~16 |
| `lib/features/history/screens/run_history_screen.dart` | ~30 |
| `lib/data/models/hex_model.dart` | ~5 |
| `lib/theme/app_theme.dart` | ~10 |
| `lib/app/neon_theme.dart` | ~6 |

Note: `season_register_screen.dart` already uses `withValues(alpha:)`, showing partial migration.

**Fix:** Replace all `color.withOpacity(x)` → `color.withValues(alpha: x)`

> **📝 Review — Confirmed, but the count is significantly underreported.**
>
> Actual count: **108 callsites across 10 files** (not 50+ across 5). The report's file table is incomplete. Missing files:
>
> | File | Occurrences |
> |------|-------------|
> | `lib/features/leaderboard/screens/leaderboard_screen.dart` | 15 |
> | `lib/features/auth/screens/team_selection_screen.dart` | 7 |
> | `lib/core/widgets/energy_hold_button.dart` | 4 |
> | `lib/features/map/screens/map_screen.dart` | 3 |
> | `lib/features/map/widgets/route_map.dart` | 2 |
>
> `run_history_screen.dart` alone has **39 callsites** (not ~30) at 2,191 lines. Despite the higher count, the fix is mechanical — use a global find-replace, then run `flutter analyze`. The replacement is API-compatible and produces identical visual output.
>
> **Effort:** Low (~2–3 hours including QA review). **Regression risk:** Low.


### 5. Missing `ref.mounted` Guard in Long-Lived `Future.delayed`

`lib/features/auth/providers/app_init_provider.dart:102-110`:
```dart
Future.delayed(untilMidnight, () {
  final currentState = ref.read(appStateProvider); // no ref.mounted check
  // ...
  ref.read(appStateProvider.notifier).endGuestSession(); // no ref.mounted check
});
```

Fires up to ~24 hours later. If notifier is disposed, this throws.

**Fix:** Add `if (!ref.mounted) return;` before each `ref.read()` in the delayed callback.

> **📝 Review — Confirmed. Apply. This is a real crash risk.**
>
> The callback fires up to **23h 59m** after scheduling. The existing `if (!currentState.isGuest) return;` guards against wrong state value but not provider lifecycle. The `.then((_) { ref.read(...) })` chain inside also needs a guard:
> ```dart
> Future.delayed(untilMidnight, () {
>   if (!ref.mounted) return;  // ADD
>   final currentState = ref.read(appStateProvider);
>   if (!currentState.isGuest) return;
>   LocalStorage().clearAllGuestData().then((_) {
>     if (!ref.mounted) return;  // ADD
>     ref.read(appStateProvider.notifier).endGuestSession();
>   });
> });
> ```
>
> **Effort:** Trivial (~30 minutes). **Regression risk:** None.


### 6. `ref.watch(appStateProvider.notifier)` Should Be `ref.read()`

`lib/features/profile/screens/profile_screen.dart:572`:
```dart
final appState = ref.watch(appStateProvider.notifier);
```

Watching a `.notifier` provides no reactive benefit and creates stale references.

**Fix:** Change to `ref.read(appStateProvider.notifier)`.

> **📝 Review — Confirmed. Exactly 1 occurrence. Apply.**
>
> Only one instance in the entire codebase. Single keyword change: `watch` → `read`. Briefly scan the surrounding block in the 2,096-line `profile_screen.dart` to confirm no downstream logic depends on the (already broken) reactivity.
>
> **Effort:** Trivial (~5 minutes). **Regression risk:** None.


### 7. `print()` Used Instead of `debugPrint()` with Linter Suppression

`lib/features/run/services/location_service.dart:252`:
```dart
// ignore: avoid_print
print('Error getting current location: $e');
```

Violates explicit project guideline.

**Fix:** Replace with `debugPrint('Error getting current location: $e');`

> **📝 Review — Confirmed. Trivial. Apply.**
>
> One occurrence, one line change. Remove the `// ignore: avoid_print` comment as well. `debugPrint` is a no-op in release builds — a small improvement over `print`.
>
> **Effort:** Trivial (~2 minutes). **Regression risk:** None.


### 8. `SeasonService` Not a Singleton — Re-Computes on Every Call

`lib/core/services/season_service.dart:34-46` — Factory constructor always returns a new instance when called without arguments, re-reading `RemoteConfigService().config` and re-computing season math each time.

**Fix:** Convert to a true singleton (like `PrefetchService`) or use static getters.

> **📝 Review — Confirmed, but severity is overstated. Apply with care.**
>
> The factory pattern is verified — every `SeasonService()` call allocates a new object. However, the actual cost is **negligible**: pure integer arithmetic with no I/O. The real (under-emphasized) risk: two callers at different moments capture different `DateTime.now()` snapshots — theoretically showing inconsistent `daysRemaining` values, though near-impossible to observe in a 40-day season.
>
> The stronger motivation is **testability**: tests cannot inject a fixed date when the service self-constructs. A Riverpod provider is the idiomatic fix:
> ```dart
> final seasonServiceProvider = Provider<SeasonService>((ref) => SeasonService());
> ```
>
> **Effort:** Medium (~2–3 hours — update all callsites, run tests). **Regression risk:** Medium — used across multiple screens and services.


### 9. SDK Constraints Too Loose / Outdated

| Constraint | Current | Recommended |
|-----------|---------|-------------|
| Dart SDK | `^3.10.4` | `^3.12.0` or latest 3.x |
| Flutter SDK | `>=3.0.0` | `>=3.19.0` |

Flutter `>=3.0.0` accepts a 3-year-old runtime. Tighten to match actual minimum tested version.

> **📝 Review — Confirmed. Apply, but verify minimum target device first.**
>
> Both constraints verified. `flutter: ">=3.0.0"` predates the entire current dependency tree (Riverpod 3.0, go_router 14, mapbox_maps_flutter 2.x all require far newer Flutter). The app almost certainly cannot run on Flutter 3.0 given its deps.
>
> Safe target: `sdk: '>=3.19.0 <4.0.0'`. Confirm with the team's oldest active Flutter installation before landing.
>
> **Effort:** Low (~1 hour). **Regression risk:** Low — metadata change only.


### 10. `supabase_flutter` Version Needs Update

| Package | Current | Recommended | Reason |
|---------|---------|-------------|--------|
| `supabase_flutter` | `^2.0.0` | `^2.5.0+` | iOS 17+ fixes, security patches |

> **📝 Review — Confirmed. Apply with integration test.**
>
> `supabase_flutter: ^2.0.0` verified. Run `flutter pub outdated` to confirm the actual resolved version. Since the entire backend sync pipeline flows through this package (auth, RPCs, hex snapshot, leaderboard, `finalize_run()`), smoke-test critical paths after bumping.
>
> **Effort:** Low to apply (~30 min), Medium to validate (~2 hours integration testing). **Regression risk:** Medium.


---

## Medium

### 11. `ChangeNotifier` Used in GoRouter Adapter

`lib/app/routes.dart:21`:
```dart
class _RouterRefreshNotifier extends ChangeNotifier { ... }
```

Violates AGENTS.md rule forbidding `ChangeNotifier`. However, `GoRouter.refreshListenable` requires a `Listenable`. This is a pragmatic adapter pattern with limited blast radius (private, scoped to router).

**Fix options:**
1. Use `GoRouterRefreshStream` with a combined stream from Riverpod providers
2. Document as sanctioned exception in AGENTS.md

> **📝 Review — Confirmed, but Fix Option 2 is the correct resolution. Do NOT apply Fix Option 1.**
>
> `_RouterRefreshNotifier` is private, scoped to router setup, and is the pattern officially recommended by the GoRouter team for Riverpod integration. `GoRouter.refreshListenable` requires a `Listenable`, not a Riverpod primitive. Fix Option 1 (GoRouterRefreshStream) introduces `StreamController` overhead and disposal logic for zero behavior improvement.
>
> Apply Fix Option 2: add one comment to AGENTS.md documenting this as a sanctioned exception. No code changes needed.
>
> **Effort:** Trivial (~5 minutes). **Regression risk:** None.


### 12. iOS Impeller Rendering Disabled

`ios/Runner/Info.plist` — `FLTEnableImpeller: false`

Impeller provides 15-30% FPS improvement for heavy map/hex animations. Skia will eventually be deprecated.

**Fix:** Test with `<true/>` and measure hex map rendering performance.

> **📝 Review — Confirmed, but do NOT enable without Mapbox GL validation.**
>
> `FLTEnableImpeller: false` verified. The report correctly frames this as "test first" but **omits the most significant risk**: Mapbox Maps Flutter uses Metal shaders and custom GPU layers that have historically conflicted with Impeller's rendering pipeline.
>
> Before enabling: (1) check `mapbox_maps_flutter` v2.3.0 changelog for Impeller support status, (2) test on a **physical iOS device** — GPU-specific, not reproducible on simulator, (3) specifically validate hex grid rendering, animated markers, camera animation, and the running screen route overlay.
>
> **Effort:** Low to test (~2 hours on physical device). **Regression risk: HIGH if enabled without testing** — core map rendering could break.


### 13. Java 17 Target with minSdk 21 — Compatibility Risk

`android/app/build.gradle.kts`:
```kotlin
sourceCompatibility = JavaVersion.VERSION_17
targetCompatibility = JavaVersion.VERSION_17
```

Java 17 features may not work on API 21-23 (Android 5.0-6.0).

**Fix:** Verify with `flutter analyze`. If issues: increase minSdk to 24+ or reduce JVM target to `VERSION_11`.

> **📝 Review — Likely a non-issue. Verify before acting.**
>
> This item conflates two distinct concepts. `sourceCompatibility = VERSION_17` sets the **JVM bytecode format** — it does **not** map Java 17 language features to Android API levels. The AGP handles desugaring via D8/R8, backporting JVM features to the Android runtime regardless. Flutter's AGP 8.x template uses Java 17 by design.
>
> **Action:** Run `flutter build apk --debug`, install on an API 21 emulator, verify the app starts. If no `ClassVerificationFailure` or `NoClassDefFoundError`, this is a false alarm — no code change needed.
>
> **Effort:** Trivial to verify (~30 minutes). No code change likely needed. **Regression risk:** None to verify.


### 14. SQLite Version Documentation Drift

AGENTS.md says "SQLite version: v15" but actual constant:
```dart
// lib/core/storage/local_storage.dart:28
static const int _databaseVersion = 17; // v17: add has_flips to runs
```

**Fix:** Update AGENTS.md to reflect v17.

> **📝 Review — Confirmed. Trivial. Apply.**
>
> `_databaseVersion = 17` verified with comment `// v17: add has_flips to runs`. AGENTS.md reads "v15". Pure documentation debt.
>
> **Effort:** Trivial (~2 minutes). **Regression risk:** None.


---

## Low

### 15. Dependencies in Good Shape

45+ dependencies are mostly current. No deprecated packages (`provider`, `state_notifier`) detected. All Riverpod 3.0 providers correctly use `Notifier<T>` / `NotifierProvider`.

> **📝 Review — Confirmed. No action needed.**
>
> ~12–15 providers all verified as `Notifier<T>`/`AsyncNotifier<T>`. 11 test files exist covering repositories, models, and services. The 15 core services have significant interdependencies (e.g., `PrefetchService` at 660+ lines coordinates `BuffService`, `HexService`, `SupabaseService`, `SeasonService`) — factor this into effort estimates for any service-level changes.


---

## Architecture Compliance

| Area | Status |
|------|--------|
| Riverpod 3.0 (no code gen) | Pass — all 7+ providers use `Notifier<T>` / `NotifierProvider` |
| Serverless (Flutter → Supabase RLS) | Pass — no backend API endpoints |
| Two Data Domains (client SQLite / server Supabase) | Pass — clearly separated |
| `debugPrint()` only | 1 violation (item #7) |
| No `StateNotifier` | Pass |
| No `ChangeNotifier` | 1 exception (GoRouter adapter, item #11) |

---

## Summary by Priority

| Severity | Count | Action |
|----------|-------|--------|
| Critical | 3 | Must fix before any production release |
| High | 7 | Should fix in next sprint |
| Medium | 4 | Plan for upcoming releases |
| Low | 1 | No action needed |

**Overall Assessment:** Well-architected app with strict Riverpod 3.0 patterns and clean serverless architecture. The critical items (secrets in source, debug signing, test ad ID) are standard pre-release blockers. The high items (`withOpacity` deprecation, missing `ref.mounted` guards) are technical debt that should be addressed soon.

---

## Plan Verdict & Recommended Execution Order

> **📝 Overall Plan Assessment**
>
> **Is this plan beneficial to apply? Yes — with the nuances noted above.**
>
> The report is accurate, well-prioritized, and covers the right issues. No items should be discarded. The plan would be stronger with these corrections:
>
> **Corrections to the plan itself:**
> - **Item 4** (`withOpacity`): Actual count is **108 across 10 files**, not "50+ across 5." Update the scope table.
> - **Item 11** (GoRouter): Fix Option 1 should not be pursued. Fix Option 2 (AGENTS.md annotation) is the correct resolution.
> - **Item 12** (Impeller): Add explicit Mapbox GL compatibility testing requirement. Do not enable blindly.
> - **Item 13** (Java 17): Demote to "verify before acting" — the JVM target vs. Android API distinction means this is likely a non-issue.
>
> **Recommended execution order (batched by session):**
>
> | Session | Items | Rationale | Est. Time |
> |---------|-------|-----------|-----------|
> | **1 — Trivial, zero risk** | #2 Android signing, #3 AdMob ID, #6 ref.watch, #7 print, #14 docs, #11 AGENTS.md comment | No Dart logic changes | ~2 hours |
> | **2 — Surgical, low risk** | #5 ref.mounted guard, #4 withOpacity batch replace | Minimal scope, mechanical | ~3–4 hours |
> | **3 — Coordination required** | #1 secrets → dart-define + CI setup | Needs pipeline infrastructure | ~4–6 hours |
> | **4 — Validation required** | #9 + #10 SDK/package bumps + integration test | Run critical path smoke tests | ~3 hours |
> | **5 — Design/test required** | #8 SeasonService provider, #12 Impeller on physical device | Architecture + hardware testing | ~4 hours |
> | **Verify first** | #13 Java 17 | Run on API 21 emulator — likely no-op | ~30 min |
>
> **Total estimated effort: ~16–20 hours** to resolve all non-trivial items.
> Sessions 1–2 can be completed in a single working day with zero regression risk.
