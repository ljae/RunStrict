# Upgrade Report — RunStrict

> Generated: 2026-03-04 | Reviewed: 80+ Dart files, configs, documentation

---

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

### 2. Android Release Signing Uses Debug Keys

`android/app/build.gradle.kts` — release build type:
```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")  // TODO comment exists
}
```

Cannot upload to Google Play. Debug APKs are publicly extractable.

**Fix:** Generate a keystore, create `android/key.properties`, and reference a proper release signing config.

### 3. iOS Ad Unit ID Is Google's Test ID

`ios/Runner/Info.plist` — `GADApplicationIdentifier`:
```
ca-app-pub-3940256099942544~1458002511
```

This is Google's test ad unit — zero ad impressions and zero revenue in production.

**Fix:** Replace with actual production AdMob ID before release.

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

### 6. `ref.watch(appStateProvider.notifier)` Should Be `ref.read()`

`lib/features/profile/screens/profile_screen.dart:572`:
```dart
final appState = ref.watch(appStateProvider.notifier);
```

Watching a `.notifier` provides no reactive benefit and creates stale references.

**Fix:** Change to `ref.read(appStateProvider.notifier)`.

### 7. `print()` Used Instead of `debugPrint()` with Linter Suppression

`lib/features/run/services/location_service.dart:252`:
```dart
// ignore: avoid_print
print('Error getting current location: $e');
```

Violates explicit project guideline.

**Fix:** Replace with `debugPrint('Error getting current location: $e');`

### 8. `SeasonService` Not a Singleton — Re-Computes on Every Call

`lib/core/services/season_service.dart:34-46` — Factory constructor always returns a new instance when called without arguments, re-reading `RemoteConfigService().config` and re-computing season math each time.

**Fix:** Convert to a true singleton (like `PrefetchService`) or use static getters.

### 9. SDK Constraints Too Loose / Outdated

| Constraint | Current | Recommended |
|-----------|---------|-------------|
| Dart SDK | `^3.10.4` | `^3.12.0` or latest 3.x |
| Flutter SDK | `>=3.0.0` | `>=3.19.0` |

Flutter `>=3.0.0` accepts a 3-year-old runtime. Tighten to match actual minimum tested version.

### 10. `supabase_flutter` Version Needs Update

| Package | Current | Recommended | Reason |
|---------|---------|-------------|--------|
| `supabase_flutter` | `^2.0.0` | `^2.5.0+` | iOS 17+ fixes, security patches |

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

### 12. iOS Impeller Rendering Disabled

`ios/Runner/Info.plist` — `FLTEnableImpeller: false`

Impeller provides 15-30% FPS improvement for heavy map/hex animations. Skia will eventually be deprecated.

**Fix:** Test with `<true/>` and measure hex map rendering performance.

### 13. Java 17 Target with minSdk 21 — Compatibility Risk

`android/app/build.gradle.kts`:
```kotlin
sourceCompatibility = JavaVersion.VERSION_17
targetCompatibility = JavaVersion.VERSION_17
```

Java 17 features may not work on API 21-23 (Android 5.0-6.0).

**Fix:** Verify with `flutter analyze`. If issues: increase minSdk to 24+ or reduce JVM target to `VERSION_11`.

### 14. SQLite Version Documentation Drift

AGENTS.md says "SQLite version: v15" but actual constant:
```dart
// lib/core/storage/local_storage.dart:28
static const int _databaseVersion = 17; // v17: add has_flips to runs
```

**Fix:** Update AGENTS.md to reflect v17.

---

## Low

### 15. Dependencies in Good Shape

45+ dependencies are mostly current. No deprecated packages (`provider`, `state_notifier`) detected. All Riverpod 3.0 providers correctly use `Notifier<T>` / `NotifierProvider`.

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
