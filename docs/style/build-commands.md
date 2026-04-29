# Build & Run Commands

```bash
# Development
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter run -d ios       # Run on iOS
flutter run -d android   # Run on Android
flutter run -d macos     # Run on macOS

# Build
flutter build ios && flutter build apk && flutter build web && flutter build macos

# Analysis & Testing
flutter analyze          # Run static analysis (linter) — must be 0 issues before commit
dart format .            # Format code
flutter test             # Run all tests
flutter test test/widget_test.dart            # Single test file
flutter test --plain-name "App smoke test"    # Single test by name
flutter test --coverage  # With coverage

# GPS Simulation (iOS Simulator)
./simulate_run.sh        # Simulate a 2km run
./simulate_run_fast.sh   # Fast simulation
```

## Pre-Commit Hooks

```bash
./scripts/pre-edit-check.sh                   # Interactive pre-edit checklist
./scripts/pre-edit-check.sh --search <term>   # Grep error history (index + archive)
./scripts/post-revision-check.sh              # Full audit — auto-runs as git pre-commit hook
./scripts/post-revision-check.sh --staged     # Staged-files-only mode (used by hook)
SKIP_REVISION_CHECK=1 git commit              # Emergency bypass (leaves audit trail)
```

The pre-commit hook is installed via `ln -sf ../../scripts/post-revision-check.sh .git/hooks/pre-commit`.

## post-revision-check rules (21 across 10 groups)

| Group | Maps to |
|---|---|
| A — Code quality (`withOpacity`, `print()`, `StateNotifier`, `ChangeNotifier`) | AGENTS.md |
| B — Riverpod 3.0 (`ref.watch(.notifier)` misuse) | `riverpod_rule.md` |
| C — Data domain (UserModel server fields in display layer) | Invariant #7 |
| D — Points & sync (client `flipPoints` to `onRunSynced`, math.max trust) | Invariants #2, #12 |
| E — HexRepository (cache bypass, `clearAll()` misuse, dominance overlay) | Invariants #3, #4, #16, #18 |
| F — Timezone (`DateTime.now()` in server-domain models) | Invariant #11 |
| G — (disabled) Snapshot date +1 — server-side, undetectable via grep | Invariant #1 |
| H — SQL partition (`created_at` vs `run_date`) | Invariant #8 |
| I — SQLite DDL (`local_storage.dart` advisory WARN) | Missing-comma crash |
| J — AdMob (App ID vs ad-unit publisher mismatch) | SIGABRT crash |
| K — OnResume (`_onAppResume()` missing provider refresh) | Invariant #5 |

FAIL blocks the commit. WARN is advisory.

## Sentinel Comments (suppress known-good false positives)

```dart
final existing = _hexCache.get(id);                          // cache-merge: intentional
if (_hexCache.get(id) != null) continue;                     // dedup: intentional
HexRepository().clearAll();                                  // province-change: clearAll() is correct here
```
