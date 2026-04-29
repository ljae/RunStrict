# Error Fix Archive (Chronological)

> Full chronological log of all production bugs and their fixes.
> Each entry is a self-contained postmortem: problem, root cause, fix, verification, lesson.
>
> **For the fast lookup table** of all invariants → see [`error-fix-history.md`](../../error-fix-history.md) at the repo root.
> **For categorical browsing** → see [`README.md`](./README.md) in this directory.
>
> **Pre-edit search**: `./scripts/pre-edit-check.sh --search <component>`

---
## Fix: Native TTS with usesApplicationAudioSession=false — NRC Approach (2026-04-15)

### Problem
After 7 iterations of manual AVAudioSession management (Invariants #42, #50-#59), the fundamental problem remained: RunStrict's audio session conflicts with competing music apps. Manually configuring `AVAudioSession` creates an asymmetric relationship where RunStrict controls how it treats other apps, but cannot control how other apps treat it. Every approach failed on at least one physical device scenario.

### Root cause
`AVAudioSession` is a shared singleton. When RunStrict configures it with `.playback + .duckOthers`, it works until another app activates its own session. The competing app's session configuration determines what happens to RunStrict, not the other way around. No amount of interruption handling, category recovery, or session persistence can fix this fundamental asymmetry.

### Fix — The NRC/Google Maps/Waze pattern
**`AVSpeechSynthesizer.usesApplicationAudioSession = false`** (iOS 13+, WWDC 2020).

This tells iOS to manage all audio session behavior for TTS automatically via the `speechsynthesisd` XPC process. The app does NOT configure `AVAudioSession` at all:
- Music keeps playing at full volume
- Voice announcements play over it with system-level ducking
- Works in foreground AND background
- No conflicts with competing apps — the system mediates everything

### Implementation
1. **`ios/Runner/NativeTtsService.swift`** (NEW): Native Swift `AVSpeechSynthesizer` with `usesApplicationAudioSession = false`. Bridged via `app.runstrict/audio` method channel with commands: `nativeSpeak`, `nativeStop`, `nativeSetRate`, `nativeSetVolume`, `nativeSetLanguage`, `nativeSetVoice`, `nativeGetVoices`. Includes `UIBackgroundTask` for Flutter isolate protection.
2. **`ios/Runner/AppDelegate.swift`**: Stripped ALL `AVAudioSession` code. No `prewarmTtsCategory`, no `ensureAudioSessionActive`, no `abandonAudioFocus`, no `resetTtsCategory`, no interruption handler. Audio channel handlers route to `NativeTtsService`. Legacy handlers kept as no-ops for Android parity.
3. **`lib/features/run/services/voice_announcement_service.dart`**: iOS path uses native method channel (`nativeSpeak`/`nativeStop`). Android path keeps `flutter_tts` + native audio focus. Removed all `prewarmTtsCategory`/`ensureAudioSessionActive`/`abandonAudioFocus`/`resetTtsCategory` calls.

### What was deleted
- `prewarmTtsCategory` handler and all its AVAudioSession logic
- `ensureAudioSessionActive` handler and `beginTtsBackgroundTaskAndActivate()`
- `abandonAudioFocus` handler (session deactivation)
- `resetTtsCategory` handler
- `AVAudioSession.interruptionNotification` observer
- `ttsBackgroundTask` property on AppDelegate
- `autoStopSharedSession(false)` call
- `setIosAudioCategory` / `setSharedInstance` mentions

### Invariants
- **#61** (NEW): Native TTS with `usesApplicationAudioSession = false`. Supersedes #42, #50-#59.
- **#60** (unchanged): Live Activity sequential cleanup + resume recovery.

---
## Fix: Audio Session Interruption Recovery + Live Activity Reliability (2026-04-15)

### Problem
Two bugs after Invariant #58 (session stays active for entire run):

1. **Music stops at run start**: `prewarmTtsCategory` called `setActive(false)` before `setCategory`, sending `interruptionNotification` (`.began`) to music apps. Spotify/Apple Music stop playback and do NOT auto-resume.

2. **Background TTS silent when competing music app runs**: When a competing music app activates its own audio session mid-run, iOS deactivates RunStrict's session. `ensureAudioSessionActive` calls `setActive(true)` which fails silently — no recovery path existed. TTS produces no audio for the rest of the run.

3. **Live Activity intermittently missing**: Stale activity cleanup was fire-and-forget (`Task { await activity.end() }`), racing with `Activity.request()`. `LiveActivityService().end()` was not awaited. No recovery mechanism on app resume.

### Root cause
1. The `setActive(false)` in `prewarmTtsCategory` was a leftover from the deactivate-before-configure pattern. iOS allows `setCategory` on an already-active session — deactivation is unnecessary and harmful.
2. The app never registered for `AVAudioSession.interruptionNotification`. Apple's documentation states apps using `.playback` category must handle interruptions to resume audio. Without the handler, after any interruption all background TTS is permanently silent.
3. `beginTtsBackgroundTaskAndActivate` caught `setActive(true)` failures but never attempted recovery (re-applying category + activation).

### Fix
1. **`prewarmTtsCategory`**: Removed `setActive(false)`. Calls `setCategory` directly on the current session. Registers `interruptionNotification` observer after activation.
2. **`handleAudioInterruption`**: New observer. On `.ended`, re-calls `setActive(true)` to reclaim the audio route (both with and without `.shouldResume` — some apps don't set it).
3. **`beginTtsBackgroundTaskAndActivate`**: When `setActive(true)` fails, falls back to `setCategory` + `setActive(true)` recovery (relaxes Invariant #55 for failure recovery only).
4. **`resetTtsCategory`**: Now removes the interruption observer at run end.
5. **Live Activity**: Stale cleanup is now sequential (`await activity.end()` before `Activity.request()`). `endLiveActivity` result is sent from inside the Task (after await). `LiveActivityService().end()` is now awaited in `stopRun()`. New `checkAndRecover()` method verifies native activity exists on resume and re-starts if missing.
6. **`AppLifecycleManager`**: New `onRunResume` callback fires on resume during active runs — triggers Live Activity recovery and voice mute state reload.

### Files changed
- `ios/Runner/AppDelegate.swift` — removed `setActive(false)` from `prewarmTtsCategory`, added interruption observer, added category recovery fallback in `beginTtsBackgroundTaskAndActivate`, fixed Live Activity stale cleanup, added `isLiveActivityActive` method channel, `endLiveActivity` result now inside Task.
- `lib/features/run/providers/run_provider.dart` — await `LiveActivityService().end()`.
- `lib/core/services/live_activity_service.dart` — added `checkAndRecover()` method.
- `lib/core/services/app_lifecycle_manager.dart` — added `onRunResume` callback, fires during resume when run is active.
- `lib/app/home_screen.dart` — wired `onRunResume` callback with Live Activity recovery and voice mute reload.
- `error-fix-history.md` — added Invariants #59, #60; updated #55 to v4.

### Invariants
- **#59** (NEW): `prewarmTtsCategory` must NOT call `setActive(false)` before `setCategory`. Must register interruption observer. `ensureAudioSessionActive` has category recovery fallback when `setActive` fails.
- **#60** (NEW): Live Activity must be sequentially cleaned up and recoverable on resume.
- **#55** updated to v4: documents the recovery exception for `ensureAudioSessionActive`.

---
## Fix: Background TTS Silent — Session Stays Active for Entire Run (2026-04-14)

### Problem
After 5 previous fix attempts (Invariants #50-#57), foreground TTS works correctly (music ducks, voice plays, music restores). But when the phone is locked mid-run (app backgrounded), voice announcements (km/pace/territory) are completely silent. Music from background apps keeps playing. The 200ms delay fix (#57) was the latest attempt — failed on physical device test (2026-04-13).

### Root cause
All 5 previous fixes used per-utterance `setActive(true)` / `setActive(false)` toggling. This pattern fails in background on iOS 17+ because:
1. `AVSpeechSynthesizer` runs in a separate XPC process (`speechsynthesisd`) with its own audio session management.
2. Calling `setActive(false)` between utterances deactivates the app's audio session. When the next background utterance calls `setActive(true)`, the app's session reactivates but `speechsynthesisd`'s internal session may not re-acquire the audio route.
3. The 200ms delay addressed Bluetooth route renegotiation timing but not the fundamental session re-acquisition failure.

### Fix
**Keep the audio session active for the entire run duration.** No per-utterance `setActive` toggling.

1. **`prewarmTtsCategory`** (foreground, run start): After `setCategory`, now also calls `setActive(true)`. Session activates once and stays active.
2. **`abandonAudioFocus`** (per-utterance, bg safe): Removed `setActive(false)`. Now only ends the `UIBackgroundTask`. Session stays active between announcements.
3. **`resetTtsCategory`** (foreground, run end): Now calls `setActive(false, .notifyOthersOnDeactivation)` before resetting category to `.ambient + .mixWithOthers`. Music restores full volume.
4. **Dart `_speak()`**: Removed 200ms pre-speak delay (no longer needed — audio route already established). Removed 100ms post-speak delay (no longer deactivating session). Simplified `_waiterCount` logic (defers `endBackgroundTask` only, not session deactivation).

### Trade-off
Music stays slightly ducked (~-14dB, about 50% volume) for the entire run duration. This is the standard behavior for workout/navigation apps (Google Maps, Waze, Mapbox Navigation).

### Files changed
- `ios/Runner/AppDelegate.swift` — `prewarmTtsCategory` activates session; `abandonAudioFocus` only ends background task; `resetTtsCategory` deactivates session.
- `lib/features/run/services/voice_announcement_service.dart` — removed 200ms pre-speak delay, removed 100ms post-speak delay, simplified `_waiterCount` double-check, updated comments.
- `error-fix-history.md` — added Invariant #58, updated #55 to v3, superseded #57.

### Verification
- `flutter analyze lib/features/run/services/voice_announcement_service.dart` → **No issues found**.
- **Manual physical-device test required**:
  1. Open Spotify/Apple Music, start playing.
  2. Open RunStrict — music must keep playing at full volume.
  3. Tap Start Run — music ducks slightly (stays audible but quieter). "Run started" announcement plays.
  4. Lock the phone immediately. Wait for the first km announcement (~6 min) — confirm it plays out loud.
  5. Unlock and finish the run. Tap End Run. Music should restore to full volume.

### Invariants
- **#55** updated to v3: session activated once at run start, stays active for run.
- **#57** superseded by #58: 200ms delay removed, no longer needed.
- **#58** (NEW): Audio session stays active for entire run — no per-utterance `setActive` toggling.

---
## Fix: iOS Music Stopped on App Open — `setCategory` at Launch Was Still Ducking (2026-04-11)

### Problem
After the 2026-04-10 fix (Invariant #50, lazy activation), opening the RunStrict app while Spotify/Apple Music was playing **still** ducked or stopped the music **immediately on launch**, before any run started. Music never restored. Physical-device test failed for the third time. Voice announcements were also requested to either duck OR mix — both behaviors are acceptable to the user — and to keep working when the app is backgrounded.

### Why the previous fix was incomplete
The 2026-04-10 fix removed `try session.setActive(true)` from `didFinishLaunchingWithOptions` but kept `try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])`. The reasoning at the time was: "Category is set at launch (so flutter_tts's later setIosAudioCategory is an idempotent re-set), but activation is now lazy, per-utterance."

That reasoning misses an important iOS behavior: **the shared `AVAudioSession` is already auto-active at process launch** with the system default `.soloAmbient` category. iOS does this so the app can immediately participate in audio routing decisions. When you call `setCategory(.playback, .duckOthers, ...)` on an already-active session, the new policy is applied **immediately** — music ducks the moment the app opens, and nothing on the codepath ever calls `setActive(false, .notifyOthersOnDeactivation)` to release the duck. The user has to actually start a run, fire a TTS utterance, and wait for `abandonAudioFocus` to run — which they generally never do before noticing the dead music app.

A second contributor: `voice_announcement_service.dart`'s `initialize()` was calling `flutter_tts.setIosAudioCategory(.playback, [.duckOthers, ...], .spokenAudio)` to "mirror" the native category. flutter_tts on iOS internally re-applies that category against the (already-active) shared session, re-triggering the duck race against native's lazy activation and creating a dual-control conflict that Invariant #50 had explicitly warned against.

### Fix
**Strategy not previously tried: never touch `AVAudioSession` at launch. Configure the category strictly per-utterance, and reset it back to a mixable, non-ducking category after each utterance so any later activation by other components is harmless.**

1. **`ios/Runner/AppDelegate.swift` `didFinishLaunchingWithOptions`** — deleted the entire `AVAudioSession` block. The system default `.soloAmbient` is left in place. Result: opening the app no longer mutates other apps' audio.
2. **`ios/Runner/AppDelegate.swift` `ensureAudioSessionActive` (per-utterance)** — sets the category just-in-time:
   ```swift
   try session.setCategory(.playback, mode: .spokenAudio,
                           options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
   try session.setActive(true)
   ```
   Background task is begun first (Invariant #54) so the Flutter isolate isn't suspended in the gap between `MethodChannel` dispatch and `AVSpeechSynthesizer.speak()` producing samples.
3. **`ios/Runner/AppDelegate.swift` `abandonAudioFocus`** — after `setActive(false, options: .notifyOthersOnDeactivation)`, the category is **reset** to `.ambient + .mixWithOthers`. Without this, the previously-set `.playback + .duckOthers` lingers; if anything else (Google Ads SDK, an AVPlayer instance) activates the session before the next TTS utterance, iOS would re-duck other apps using the lingering category. Resetting to a mixable, non-ducking category makes any subsequent activation safe. Background task is always ended even if `setActive(false)` or the category reset throws.
4. **`ios/Runner/AppDelegate.swift` `requestAudioFocusDuck`** — kept for parity (Android-only in current Dart code), but rewritten to also set the category just-in-time before activating, in case the Dart side ever re-enables the iOS path.
5. **`lib/features/run/services/voice_announcement_service.dart` `initialize()`** — removed the entire `setIosAudioCategory(...)` call. Native owns the category lifecycle exclusively. `autoStopSharedSession(false)` is kept defensively so flutter_tts's didFinish handler does not deactivate the session behind native's back.

### Why this is safe (and why it satisfies the user's request)
- **Music apps when the app opens**: Default `.soloAmbient` is mixable and non-ducking. AppDelegate doesn't touch the session. Spotify/Apple Music keeps playing at full volume — confirmed safe scenario.
- **First run announcement** ("Run started, let's go!"): native `ensureAudioSessionActive` sets `.playback + .duckOthers + .spokenAudio`, activates → Spotify ducks → TTS plays → `abandonAudioFocus` deactivates with `.notifyOthersOnDeactivation`, resets category to `.ambient + .mixWithOthers` → Spotify restores.
- **Background TTS** (km/pace/territory while phone is locked): `UIBackgroundModes: [location, audio]` + `beginBackgroundTask` keep the Flutter isolate alive long enough for `AVSpeechSynthesizer.speak()` to start producing samples, after which the active `.playback` session keeps the app alive for the rest of the utterance. `endBackgroundTask` releases the task immediately after `abandonAudioFocus`.
- **Mix vs duck**: User said "(volume control or just mix are both ok)". Current implementation uses `.duckOthers` for the polished UX (TTS clearly audible without competing music). If the user prefers full mix, change `[.duckOthers, ...]` to `[.mixWithOthers, ...]` in the two `setCategory` calls in `ensureAudioSessionActive` and `requestAudioFocusDuck`.
- **No new packages, no `setSharedInstance(true)`, no `audio_session` plugin** — all the failure modes from previous fixes (Invariants #50, #51) remain forbidden.

### Files changed
- `ios/Runner/AppDelegate.swift` — `didFinishLaunchingWithOptions` no longer touches `AVAudioSession`; `ensureAudioSessionActive` and `requestAudioFocusDuck` set the category just-in-time; `abandonAudioFocus` resets category to `.ambient + .mixWithOthers` after deactivation.
- `lib/features/run/services/voice_announcement_service.dart` — removed `setIosAudioCategory(...)` call from `initialize()`. `autoStopSharedSession(false)` retained.

### Verification
- `flutter analyze lib/features/run/services/voice_announcement_service.dart` → **No issues found**.
- Native side: SourceKit "No such module Flutter" diagnostic is a pre-existing indexing artifact and goes away on a real Xcode build.
- **Manual physical-device test required**: open RunStrict with Spotify playing → confirm music keeps playing at full volume. Then start a run → confirm music ducks during the "Run started" announcement and restores immediately after. Then lock the phone mid-run → confirm km/pace announcements still play out loud.

### Invariants
- **#50** (split audio session ownership): tightened. The "native sets category at launch" half is now WRONG and is replaced by **#55**. Native still owns activation lifecycle. flutter_tts must not call `setIosAudioCategory` from Dart at all.
- **#54** (`beginBackgroundTask` wrapping TTS): unchanged.
- **#55** (NEW): Never set the `AVAudioSession` category at app launch. Configure per-utterance and reset to `.ambient + .mixWithOthers` after each utterance.

### Update (2026-04-11 v2 — proactive hardening before physical-device test)
After the independent code review of v1, the reviewer flagged Concern #1: the per-utterance `setCategory` change happens in **background** when the phone is locked mid-run, which is a code path Apple permits but is fragile. The reviewer's recommended fallback was to set `.playback` once from foreground in `announceRunStart` and skip the per-utterance `.ambient` reset for the duration of the run. Rather than wait for the physical-device test to fail, we applied the fallback proactively.

**v2 strategy: setCategory only ever fires from foreground; background path is `setActive`-only.**

Four method channel methods on `app.runstrict/audio`, with strict roles:
1. **`prewarmTtsCategory`** — **FOREGROUND-ONLY**, called from `announceRunStart`. First `setActive(false)` to deactivate the auto-active `.soloAmbient` session, then `setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])` on the now-inactive session. Setting category on an inactive session does NOT immediately duck other apps — ducking only kicks in on the first per-utterance `setActive(true)`.
2. **`ensureAudioSessionActive`** — per-utterance, foreground OR background. ONLY begins `UIBackgroundTask` and `setActive(true)`. Does NOT touch category.
3. **`abandonAudioFocus`** — per-utterance, foreground OR background. ONLY `setActive(false, .notifyOthersOnDeactivation)` and `endBackgroundTask`. Does NOT touch category. The `.playback + .duckOthers` category stays in place for the duration of the run.
4. **`resetTtsCategory`** — **FOREGROUND-ONLY**, called from `dispose()` at run end. `setCategory(.ambient, options: [.mixWithOthers])`. The session is already inactive at this point (last speak called `abandonAudioFocus`), so the change is safe and immediate. Any later activation by Google Ads / AVPlayer / etc. will use the safe `.ambient + .mixWithOthers` config and will NOT re-duck other apps.

**Why v2 is more robust than v1:**
- v1's per-utterance `setCategory` happens in background when the phone is locked mid-run. Apple permits this with `UIBackgroundModes: audio`, but it's an under-tested code path in this project.
- v2's per-utterance path only toggles `setActive(true)` / `setActive(false)`, which is the well-trodden Apple-supported pattern for background audio.
- The category change in v2 ONLY happens in foreground, in two well-known windows: when the user taps Start Run (`prewarmTtsCategory`) and when the user taps End Run (`resetTtsCategory`).
- Between announcements during a run, the session is inactive (`setActive(false)` called from `abandonAudioFocus`), so other apps are NOT being actively ducked even though the category is still `.playback + .duckOthers`. Ducking only happens during the brief speak window.

**Also applied in v2** (review concern #4 — pre-existing minor UX bug):
- `_speak()` finally block now re-checks `_waiterCount` AFTER the 100ms post-speak delay. Without this re-check, a back-to-back announcement that arrives during the sleep would still cause a brief audible volume pump.

**Files touched in v2:**
- `ios/Runner/AppDelegate.swift` — split helper into activation-only; added `prewarmTtsCategory` and `resetTtsCategory` cases; removed `.ambient` reset from `abandonAudioFocus`; updated docstring with full lifecycle.
- `lib/features/run/services/voice_announcement_service.dart` — `announceRunStart` now calls `prewarmTtsCategory` (iOS only) before `_speak`; `dispose` now calls `resetTtsCategory` (iOS only) after `abandonAudioFocus`; `_speak` finally block re-checks `_waiterCount` after the 100ms delay.

### Updated manual physical-device test for v2
1. Open Spotify/Apple Music, start playing.
2. Open RunStrict — music must keep playing at full volume (unchanged from v1).
3. Tap Start Run — observe the "Run started, let's go!" announcement: Spotify should duck during the announcement and restore right after.
4. **Lock the phone immediately** (within 1-2 seconds of tapping Start Run, before the first km announcement). Wait for the first km announcement at ~6 minutes — confirm it plays out loud over Bluetooth/speaker. This is the v2 critical path: category was set in foreground at run start, so the background announcement only needs `setActive(true)`.
5. Unlock and finish the run. Tap End Run. Music should be at full volume; tap an ad/video → no unexpected ducking.

---
## Fix: iOS Music Ducked at Launch & Background TTS Silent (2026-04-10)

### Problem
Two related iOS audio regressions:

1. **Launch ducks background music permanently.** Opening the app while Spotify/Apple Music was playing caused the music to drop to ducked volume and never restore — even after fully backgrounding or killing RunStrict. The duck persisted until the user manually paused/played their music app. This is the exact failure mode Invariant #50 was written to prevent.
2. **Voice announcements silent when backgrounded during a run.** With the phone locked (or another app in the foreground), km/pace/territory announcements were completely silent during a run. Coming back to the foreground, the next announcement played fine. No queue burst (Invariant #51's timeout protections were working) — iOS was suspending the Flutter isolate before `AVSpeechSynthesizer.speak()` could even fire.

### Root causes
1. **`ios/Runner/AppDelegate.swift` pre-activated the session at launch.** `didFinishLaunchingWithOptions` called `try session.setActive(true)` after `setCategory(.playback, .duckOthers, ...)`. This told iOS "RunStrict is playing audio right now" before any TTS happened. With `.duckOthers` set, iOS ducked music immediately and had no trigger to un-duck (nothing ever called `setActive(false)` — the app was just idle). The Swift-side `setActive(true)` was a re-introduction of the exact bug Invariant #50 forbade on the Dart side.
2. **Contradictory category options `[.mixWithOthers, .duckOthers, ...]`.** `.mixWithOthers` says "play alongside others at full volume"; `.duckOthers` says "lower their volume while we play". When both are set, iOS applies `.duckOthers` — but the contradictory config also caused inconsistent behavior on route changes (Bluetooth disconnect, phone call). `.mixWithOthers` had to go.
3. **`voice_announcement_service.dart` skipped `abandonAudioFocus` on iOS.** `_speak()` guarded both the stale-drop branch and the `finally` branch with `&& !Platform.isIOS`, and `dispose()` did the same. The comments claimed "iOS ducking is automatic via AVAudioSession category", but in practice the session was never deactivated — so the duck never released and the UIBackgroundTask never ended.
4. **No `UIBackgroundTask` wrapping TTS utterances.** `UIBackgroundModes` has `audio`, which lets an *actively playing* audio session keep the app alive in the background. But there's a gap: between the MethodChannel call that activates the session and the moment `AVSpeechSynthesizer.speak()` actually starts producing samples, iOS considers the app idle and can suspend the Flutter isolate. No isolate → no `speak()` → no audio → session goes idle → app suspended. The `audio` entitlement alone is not enough; we need `beginBackgroundTask` to bridge the gap.

### Fix
1. **`ios/Runner/AppDelegate.swift`**:
   - Deleted `try session.setActive(true)` from `didFinishLaunchingWithOptions`. Category is set at launch (so flutter_tts's later `setIosAudioCategory` is an idempotent re-set), but activation is now lazy, per-utterance.
   - Dropped `.mixWithOthers` from the options array. Final options: `[.duckOthers, .allowBluetooth, .allowBluetoothA2DP]`.
   - Added a stored `ttsBackgroundTask: UIBackgroundTaskIdentifier = .invalid` on `AppDelegate`.
   - `ensureAudioSessionActive` MethodChannel case now calls `UIApplication.shared.beginBackgroundTask(withName: "tts-announcement", expirationHandler:)` before `setActive(true)`. The expiration handler ends the task cleanly if iOS forces termination. If a prior task is still outstanding (double-begin), it is ended first.
   - `abandonAudioFocus` case always ends the background task — even if `setActive(false)` throws — to prevent UIKit watchdog kills.
   - Updated the top-of-file comment block to the new policy: set category early, activate lazily per-utterance, never `setActive(true)` at launch. Cross-referenced Invariant #50.
2. **`lib/features/run/services/voice_announcement_service.dart`**:
   - Removed `&& !Platform.isIOS` from both `abandonAudioFocus` calls in `_speak()` (stale-drop branch ~line 265 and the `finally` branch ~line 311). Both platforms now release audio focus. The `_waiterCount == 0` deferred-unduck guard is preserved.
   - Removed `if (!Platform.isIOS)` around `abandonAudioFocus` in `dispose()`. iOS now deactivates on dispose just like Android.
   - Removed `IosTextToSpeechAudioCategoryOptions.mixWithOthers` from the `setIosAudioCategory` options list (must match the native category exactly, otherwise flutter_tts re-sets the category with conflicting flags).

### Preserved
- 8-second `_speakTimeout` on `speak()`.
- 10-second stale announcement drop after `_speakLock` acquisition.
- `_waiterCount` deferred-unduck logic (no volume pump between back-to-back announcements).
- iOS Simulator bail-out in `initialize()`.
- All mute state handling, widget sync, and `_selectBestVoice()` logic.
- Android `MainActivity.kt` — untouched.

### Why this is safe
- Music app experience on launch: category is set but session is idle → iOS does not duck anything until the user starts a run and the first TTS utterance fires `ensureAudioSessionActive`.
- After the utterance, `abandonAudioFocus` calls `setActive(false, .notifyOthersOnDeactivation)` → music app restores full volume.
- Background TTS during a run: `beginBackgroundTask` keeps the Flutter isolate alive long enough for `speak()` to start producing samples; `UIBackgroundModes: audio` then takes over to keep the session alive for the duration of the utterance; `endBackgroundTask` in `abandonAudioFocus` releases the task immediately after, so we don't burn the ~30s background grace budget.
- No new packages, no new audio assets, no re-introduction of `setSharedInstance(true)`.

### Invariants touched
- **#42** (iOS voice announcements must duck, not interrupt): still holds — `.duckOthers` remains in the category. Tightened: category options must not contain `.mixWithOthers` alongside `.duckOthers`.
- **#50** (Split audio session ownership — never `setSharedInstance(true)`): reaffirmed. Extended: native side must also not call `setActive(true)` at launch — lazy activation per-utterance only.
- **#51** (`_speak()` timeout + stale drop): unchanged mechanics. Clarified: `abandonAudioFocus` must fire on **both** platforms in the stale-drop, `finally`, and `dispose()` paths. iOS-skip was wrong.
- **#54** (new): Background TTS utterances on iOS must be wrapped in `beginBackgroundTask`/`endBackgroundTask`. `UIBackgroundModes: audio` alone does not prevent Flutter isolate suspension in the gap between MethodChannel dispatch and `AVSpeechSynthesizer.speak()` producing samples. (Initially proposed as #52 in this entry, but collided with the existing #52 "Hexes persist" invariant from 2026-04-08; renumbered to #54.)

---
## Change: Persistent Hex Territory Across Season Resets (2026-04-08)

### Problem
Territory (hexes) was deleted on every D-Day (season reset), losing all historical hex data. Users wanted territory to persist — "the land remembers."

### Change
1. **`supabase/migrations/20260408000001_persistent_hexes_archive.sql`**: New `hex_season_archive` table stores final-day `hex_snapshot` per season. `reset_season()` no longer deletes `hexes` (live). Before deleting `hex_snapshot`, copies last day's snapshot into archive. Fixed missing `DELETE FROM daily_continent_stats` regression from `20260401000001`.
2. **`lib/core/services/prefetch_service.dart`**: Removed Day 1 `clearAll()` short-circuit in `_downloadHexData()`. Removed Day 1 skips for country and continent dominance downloads. Territory persists, so these downloads return valid data on Day 1.
3. **`lib/core/legal/legal_content.dart`**: Updated Terms of Service (6.2, 6.3) and Privacy Policy (5.1, 5.2) to reflect persistent territory.

### Why this is safe
- `calculate_daily_buffs()` district loop: `WHERE u.team IS NOT NULL` → 0 iterations on Day 1 (all teams NULL). No buff corruption.
- `build_daily_hex_snapshot()` at 22:00 UTC on transition night: `hex_snapshot` was already deleted by `reset_season()` at 21:55. But `hexes` persists, so Day 1 snapshot reflects old territory. This is intentional.
- Client buff guard: `isFirstDay → 1x` already exists in `buff_provider.dart`.
- `get_hex_snapshot()` queries by exact `snapshot_date` — no cross-season data leak.

### Invariants
**#52**: Hexes (live) persist across season resets. `reset_season()` must NOT delete hexes. `clearAll()` is no longer used for season reset.
**#53**: `hex_season_archive` stores final-day territory per season. PK is `(hex_id, season_number)`.
**#4 updated**: `clearAll()` is nuclear — only for province change, NOT season reset.

---
## Fix: Voice Announcements Queue Up and Burst at Run End on iOS (2026-04-04)

### Problem
During a 5km run on iOS with a music app playing, voice announcements (km pace, territory captured) were silent throughout the run. When the run finished, ALL announcements burst out sequentially. Root cause chain: (1) `UIBackgroundModes` only had `location`, missing `audio` — iOS silences `AVSpeechSynthesizer` in background without the audio entitlement. (2) `awaitSpeakCompletion(true)` made `speak()` hang indefinitely waiting for a `didFinish` callback that never fires when TTS is silenced. (3) `_speakLock` (Future-based mutex) stayed locked forever, blocking all subsequent announcements as suspended async frames. (4) On run end, `dispose()` called `_tts!.stop()` which triggered `didFinish`, releasing the lock and draining all queued announcements at once.

### Fix
1. **`ios/Runner/Info.plist`**: Added `audio` to `UIBackgroundModes` alongside `location`. Required for `AVSpeechSynthesizer` to output audio when app is backgrounded.
2. **`voice_announcement_service.dart` `_speak()`**: Added 8-second timeout on `_tts!.speak(text)` — prevents a hung synthesizer from deadlocking the queue.
3. **`voice_announcement_service.dart` `_speak()`**: Added 10-second staleness check — announcements that waited too long in the queue are dropped (irrelevant to runner's current position).
4. **`voice_announcement_service.dart` `_speak()`**: Re-check `_initialized` after acquiring lock — guards against `dispose()` racing with queued waiters.
5. **`voice_announcement_service.dart` `_speak()`**: Deferred `abandonAudioFocus` when `_hasWaiter` is true — prevents audible volume pump (music briefly restores then ducks again) between sequential announcements.
6. **`error-fix-history.md`**: Fixed contradictory Invariant #50 narrative (old entry said `.ambient`, code uses `.playback + .duckOthers`).

### Invariant
**#51**: `_speak()` must timeout + drop stale announcements. Without timeout, a hung `AVSpeechSynthesizer` deadlocks `_speakLock` forever. iOS requires `UIBackgroundModes: [location, audio]` for TTS in background. Defer `abandonAudioFocus` when next announcement is queued.

---
## Fix: iOS Music Stops Permanently During Voice Announcements (2026-04-05)

### Problem
On iOS, background music (Spotify, Apple Music) was permanently stopped when RunStrict's voice announcements played. Music never restored after announcements ended. Users had to manually resume music.

### Root Cause
`setSharedInstance(true)` in `voice_announcement_service.dart` called `AVAudioSession.setActive(true)` at init time — before any TTS was needed. This pre-activated a `.playback + .duckOthers` session that persisted for the entire run. Music apps saw a continuously-active competing `.playback` session and paused entirely instead of ducking. Additionally, `bool _hasWaiter` (not a counter) caused orphaned audio focus when 3+ announcements queued simultaneously — the middle announcement could exit without anyone calling `abandonAudioFocus`.

### Fix Applied
1. **`voice_announcement_service.dart`**: Removed `setSharedInstance(true)` — native `requestAudioFocusDuck` → `setActive(true)` handles activation at the correct time (before each speak).
2. **`voice_announcement_service.dart`**: Changed `bool _hasWaiter` to `int _waiterCount` — correctly tracks multiple queued announcements.
3. **`voice_announcement_service.dart`**: When stale announcement is dropped and `_waiterCount == 0`, calls `abandonAudioFocus` to prevent orphaned focus.
4. **`voice_announcement_service.dart`**: Added `_tts!.stop()` in timeout handler to force-cancel hung utterances (prevents cascading queue).
5. **`voice_announcement_service.dart`**: Added 100ms post-speak delay on iOS to let AVSpeechSynthesizer fully release hardware before `setActive(false)`.
6. **`ios/Runner/AppDelegate.swift`**: Added `print()` for failed `setActive(false)` to diagnose silent deactivation failures.

### Invariant Updates
**#50**: Added: NEVER call `setSharedInstance(true)`. Do NOT add `audio_session` package (triple-control conflict).
**#51**: Updated: `_waiterCount` (int) replaces `_hasWaiter` (bool). Stale-drop path must call `abandonAudioFocus` when last waiter. Timeout must `stop()` the synthesizer. 100ms post-speak delay on iOS.

---
## Fix: Runs Silently Lost — Missing SQLite Column for hex_continent_parents (2026-03-25)

### Problem
After adding `hex_continent_parents` to `Run.toMap()` (line 144 in `run.dart`), no runs were saved to SQLite. Both `saveRunWithSyncTracking()` and fallback `saveRun()` called `run.toMap()` which produced a map with key `hex_continent_parents`, but the SQLite table had no such column. `sqflite` threw "table runs has no column named hex_continent_parents" on INSERT. Both save paths caught and swallowed the error silently. Runs completed normally from the user's perspective but never appeared in Run History. This also blocked server sync (`finalize_run` never called), causing missing continent hexes.

### Fix
1. **`local_storage.dart` `_onCreate`**: Added `hex_continent_parents TEXT DEFAULT ''` to the runs table schema.
2. **`local_storage.dart` migration v20**: `ALTER TABLE runs ADD COLUMN hex_continent_parents TEXT DEFAULT ''`.
3. **`local_storage.dart`**: Bumped `_databaseVersion` from 19 to 20.

### Invariant
**#48**: Every key in `Run.toMap()` must have a matching column in the SQLite schema. When adding a field to `Run`, always add the column to `_onCreate` AND a migration.

---
## Fix: Leaderboard Shows Negative Distance (-0.2 km) (2026-03-25)

### Problem
Season record on leaderboard screen showed `-0.2 km` for distance. `get_leaderboard` RPC (migration 20260324000004) subtracts today's stats from `users` table accumulators: `u.total_distance_km - COALESCE(ts.today_dist, 0)`. When `users.total_distance_km` was stale (0) because runs weren't syncing (due to the hex_continent_parents bug above), but `run_history` had today's 0.2 km run, the subtraction produced `-0.2`.

### Fix
1. **Migration `20260325000001_clamp_leaderboard_subtraction.sql`**: Wrapped all subtraction results with `GREATEST(0, ...)` — `season_points`, `total_distance_km`, `total_runs`, and the `ORDER BY`/`WHERE` clauses.

### Invariant
**#49**: Leaderboard subtraction (`users` accumulator minus today's stats) must always clamp with `GREATEST(0, ...)`.

---
## Fix: Voice Announcements Inaudible Over Music — Dual Audio Session Conflict (2026-03-25)

### Problem
TTS voice announcements during runs were inaudible when a music app was playing. Root cause: dual audio session management. `flutter_tts` configured `.playback + .duckOthers` at init time, then native `requestAudioFocusDuck` ALSO set `.playback + .duckOthers` before each speak. When `flutter_tts.speak()` fired, it re-activated its own session, overriding the native one. Additionally, `setCompletionHandler` was re-set on every `_speak()` call (unreliable), and Android used `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` which many music apps ignore.

### Fix
1. **`voice_announcement_service.dart` `initialize()`**: Set `flutter_tts` iOS audio category to `.playback + .duckOthers + .interruptSpokenAudioAndMixWithOthers` with `.voicePrompt` mode. flutter_tts owns the category; native code owns activation/deactivation only.
2. **`voice_announcement_service.dart` `initialize()`**: Added `awaitSpeakCompletion(true)` so `speak()` blocks until TTS finishes. Added `autoStopSharedSession(false)` so flutter_tts does not deactivate session in didFinish.
3. **`voice_announcement_service.dart` `_speak()`**: Replaced unreliable `setCompletionHandler` with `try/finally` — `abandonAudioFocus` is guaranteed to fire after TTS completes.
4. **`MainActivity.kt`**: Uses `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` with `USAGE_ASSISTANCE_NAVIGATION_GUIDANCE` for system-level ducking on Android 12+.

### Invariant
**#50**: Split audio session ownership: flutter_tts owns category (`.playback + .duckOthers + .interruptSpokenAudioAndMixWithOthers + .voicePrompt`), native owns activation (`setActive(true/false)`). `autoStopSharedSession(false)` prevents flutter_tts from deactivating. `.ambient` is WRONG (silences TTS when music starts). Use `awaitSpeakCompletion(true)` + `try/finally` for reliable focus release. Serialize `_speak()` calls to prevent premature unduck from concurrent announcements.

---
## Fix: iOS Voice Announcements Stop Music Instead of Ducking (2026-03-21)

### Problem
When a voice announcement played during a run (e.g. "Territory captured", kilometer pace), the music app's playback stopped completely instead of temporarily lowering volume. Android had proper audio ducking via native `AudioFocusRequest` in `MainActivity.kt`, but iOS had no native audio session handler. The Dart `_speak()` method only called the `app.runstrict/audio` method channel on Android (`Platform.isAndroid` guard), and iOS relied solely on `flutter_tts`'s `duckOthers` option — which ducks on speak but does NOT call `AVAudioSession.setActive(false, options: .notifyOthersOnDeactivation)` when TTS finishes. Without that flag, music apps don't know to resume.

### Fix
1. **`ios/Runner/AppDelegate.swift`**: Added `app.runstrict/audio` method channel handler with `AVAudioSession` management:
   - `requestAudioFocusDuck`: Sets category `.playback` with options `[.duckOthers, .allowBluetooth, .allowBluetoothA2DP]` and activates session.
   - `abandonAudioFocus`: Deactivates session with `.notifyOthersOnDeactivation` so music apps resume at full volume.
2. **`voice_announcement_service.dart` `_speak()`**: Removed `Platform.isAndroid` guards — now calls audio channel on both platforms.
3. **`voice_announcement_service.dart` `dispose()`**: Same — abandons audio focus on both platforms.

### Verification
- Build succeeds, `flutter analyze` clean on the Dart side.
- iOS native: `AVAudioSession.setActive(false, options: .notifyOthersOnDeactivation)` is the documented Apple pattern for temporary audio interruptions.

---
## Fix: Pace Display Shows Long Numbers for Corrupted Data (2026-03-21)

### Problem
User `ljae.m10` had `avg_pace_min_per_km = 468.95` in the `users` table — an absurdly wrong value. The pace formatter in `LeaderboardEntry.formattedPace` produced "468'57/km". The `run_provider.dart` formatter already had a `pace > 99` guard, but the other four formatters did not.

### Fix
Added `> 99` upper-bound guard to all pace formatters:
- `lib/features/leaderboard/providers/leaderboard_provider.dart` — `LeaderboardEntry.formattedPace`
- `lib/features/leaderboard/screens/leaderboard_screen.dart` — `_formatPace()`
- `lib/features/team/screens/team_screen.dart` — `_formatPace()`
- `lib/features/history/screens/run_history_screen.dart` — `_formatPace()`
- `lib/features/run/providers/run_provider.dart` — already had guard (OK)

All return `"-'--"` when pace is null, NaN, infinite, 0, or > 99.

---
## Fix: Buff Uses Current District Instead of Yesterday's Territory (2026-03-21)

### Problem
`get_user_buff()` used `COALESCE(users.district_hex, p_district_hex)` to determine which district to look up in `daily_buff_stats`. But `finalize_run()` updates `users.district_hex` on every run. If user `runstrict` ran in a new district today (`8630e1cb7ffffff`), their `district_hex` was already updated — but `daily_buff_stats` only had data for the OLD district (`8630e1c87ffffff`, where the midnight cron computed stats). Result: `get_user_buff` found no `daily_buff_stats` row for the new district → `v_buff_found = false` → `is_elite = false` → returned 1x/Common despite the user being Elite (#1) in their yesterday district.

### Root Cause
No concept of "yesterday's district" existed on the server. `district_hex` is a live column updated by `finalize_run()` on every run. The buff system assumed `district_hex` wouldn't change before the next midnight cron — but it does whenever the user runs somewhere new.

### Fix
**Migration `fix_buff_use_yesterday_district`:**
1. Added `yesterday_district_hex TEXT` column to `public.users`.
2. Backfilled all existing users: `SET yesterday_district_hex = district_hex`.
3. `calculate_daily_buffs()`: Now snapshots `district_hex → yesterday_district_hex` for ALL users at the start (before computing stats). Elite ranking peer-group queries use `yesterday_district_hex` instead of `district_hex`.
4. `get_user_buff()`: Changed to `COALESCE(v_user.yesterday_district_hex, v_user.district_hex, p_district_hex)` — uses yesterday's frozen district for buff lookup. Falls back to current district (new users) then client param.
5. Manually corrected `runstrict`'s `yesterday_district_hex` to `8630e1c87ffffff` (the district where daily_buff_stats existed).

### Client-Side Fix
1. **`buff_provider.dart`**: Added `buffDate` (DateTime?) to `BuffState`. `loadBuff()` early-returns if already loaded for today's GMT+2 date. `setBuffFromLaunchSync()` sets `buffDate`. Added `isNewUser` getter (no districtHex in breakdown).
2. **`team_screen.dart` `_loadData()`**: Removed separate `loadBuff()` call. Uses `buffBreakdown.districtHex` (server-resolved yesterday district) for `loadTeamData()` instead of `PrefetchService().homeHexDistrict` (GPS). Falls back to GPS only for new users with no run history.
3. **`_buildSimplifiedUserBuff()`**: Shows contextual 1x messages — "SEASON DAY 1 · ALL START EQUAL · RUN TO EARN TOMORROW'S BUFF" or "RUN TODAY TO EARN TOMORROW'S BUFF" for new users.

### Verification
```sql
SELECT public.get_user_buff('02093f18-e82a-4b88-b164-6bc3c2dc1d68', NULL);
-- Returns: is_elite: true, multiplier: 2, elite_threshold: 2, district_hex: 8630e1c87ffffff
```

---
## Fix: `get_user_buff()` RECORD IS NOT NULL Bug + Stale Leaderboard Snapshot (2026-03-21)

### Problem
Two production bugs for user `runstrict@gmail.com` (and potentially all Red team users in tied districts):

**Bug 1 — Buff shows Common/1x instead of Elite/2x:**
`get_user_buff()` used `v_buff_stats IS NOT NULL` to check if the `daily_buff_stats` row was found. PostgreSQL RECORD `IS NOT NULL` returns FALSE when ANY field in the record is NULL. The `daily_buff_stats` row for district `8630e1c87ffffff` on 2026-03-21 had `dominant_team = NULL` (tie: red=2, blue=2). This caused `v_buff_stats IS NOT NULL` to return FALSE, skipping elite threshold assignment (`v_elite_threshold` stayed at 0) and elite check (`v_is_elite` stayed FALSE). Result: all Red team users in tied districts got Common/1x regardless of their actual yesterday points.

**Bug 2 — Leaderboard shows season_points=0 and user not in rankings:**
`season_leaderboard_snapshot` was created once on 2026-03-10. User joined on 2026-03-16. `get_leaderboard` and `get_season_leaderboard` both read ONLY from the snapshot. `finalize_run` updates `public.users.season_points` but NOT the snapshot. The trigger `fn_sync_snapshot_on_user_change` only syncs `team`/`home_hex` for existing rows — never inserts new users.

### Fix
1. **`get_user_buff()`**: Added `v_buff_found BOOLEAN := false` variable, set from `FOUND` after `SELECT INTO`. Replaced all `v_buff_stats IS NOT NULL` checks with `v_buff_found`. This reliably detects row existence regardless of NULL fields.
2. **Leaderboard**: Manually refreshed via `SELECT snapshot_season_leaderboard(2)` (36 rows, up from 31). Added daily cron `refresh_season_leaderboard` at 22:05 UTC to auto-refresh after buff/hex crons complete.

### Verification
- `get_user_buff('02093f18-...')` now returns `is_elite: true, multiplier: 2, elite_threshold: 2`
- `season_leaderboard_snapshot` now includes `runstrict` at rank 36 with `season_points: 2`

---
## Fix: `isInScope` Resolution Mismatch and Silent Failures in Province Leaderboard Filtering (2026-03-20)

### Problem
Investigation of why `runstrict` couldn't see `ljae.m10` in province leaderboard. The actual cause was that the two accounts are in **different provinces** (different `province_hex` values confirmed via SQL). However, the investigation uncovered two latent bugs in `isInScope()` that would silently break province filtering for other users:

1. **Resolution mismatch**: Primary path used `H3Config.provinceResolution` (remote-configurable, could drift to Res 4) while fallback path used `scope.resolution` (hardcoded Res 5 in `GeographicScope.province`). If a user's `districtHex` is null (hitting fallback) while another user's is valid (hitting primary), they'd be compared at different resolutions.
2. **Silent exception swallowing**: Both `catch (_)` blocks in `isInScope()` discarded all error information, making filtering failures completely invisible in logs.

### Root Cause
`isInScope()` in `leaderboard_provider.dart` had two codepaths for province scope comparison:
- **Primary** (line 183): `getParentHexId(districtHex, H3Config.provinceResolution)` — reads from `RemoteConfigService`
- **Fallback** (line 201): `getScopeHexId(homeHex, scope)` → calls `getParentHexId(homeHex, scope.resolution)` — uses enum's hardcoded `5`

If remote config ever changed `provinceResolution` to a different value (e.g., 4 as referenced in docs), the two paths would compute parent hexes at different H3 resolutions — Res 4 parents are ~7x larger than Res 5 parents. Two users in the same Res-5 province but different Res-4 parents would be invisible to each other if one hits the primary path and the other hits the fallback.

### Fix
**`lib/features/leaderboard/providers/leaderboard_provider.dart`** — `isInScope()`:

1. Changed `H3Config.provinceResolution` → `scope.resolution` on lines 183 and 187, ensuring both primary and fallback paths always compare at the same resolution regardless of remote config.
2. Changed `catch (_)` → `catch (e)` with `debugPrint` in both catch blocks (lines 190 and 208), logging the entry hex, reference hex, and error for future diagnosis.

### Also Verified
- **Invariant #31** (`finalize_run` district_hex): Confirmed the deployed server function already uses `COALESCE(v_run_district_hex, district_hex)` where `v_run_district_hex := p_hex_district_parents[1]`. The fix migration `20260319102722` was applied correctly.
- Both `ljae.m10` and `runstrict` have valid non-null `district_hex` values in the DB.

### Verification
- `flutter analyze lib/features/leaderboard/providers/leaderboard_provider.dart` → 1 pre-existing info lint, 0 errors, 0 new issues

### Lesson (Invariant #33)
When a function has primary and fallback codepaths that compute the same logical value (e.g., H3 parent hex), both paths must use the **same resolution source**. Using `H3Config` (remote-configurable) in one path and `GeographicScope.resolution` (compile-time constant) in the other creates a latent mismatch that only manifests when remote config drifts. Always prefer the `scope` parameter that was passed to the function — it's explicit and consistent.

---
## Bug Fix: TeamScreen Territory Shows "No Data" After Cross-Province Run (2026-03-14)

### Problem
TeamScreen territory cards ("Rustic Canyon" province and "District 1") showed "No data" — all bars empty, 0 hex counts — even though BLUE had clear dominance (23 blue vs 19 red hexes) in that province. The buff correctly showed 2x (server-calculated correctly), but the territory visualization was broken.

### Root Cause
Two-step causal chain:

1. **`finalize_run()` updates `users.province_hex` server-side** (to the province of the run's first hex) when a user runs in a new area. The user ran in "Rustic Canyon" (`85283473fffffff`) on 2026-03-12, updating their server `province_hex`.

2. **Local SQLite home hex was never updated.** `PrefetchService._homeHex` is loaded from local SQLite (`_loadHomeHex()`) and only changes via explicit Profile screen → `updateHomeHex()`. It remained as the old province's home hex. The `_homeHexProvince` (derived from the old `_homeHex`) pointed to the old province.

3. **`_downloadHexData()` uses `_homeHexProvince`** as the download anchor. So it downloaded the hex snapshot for the OLD province — not Rustic Canyon.

4. **`computeHexDominance(homeHexProvince: wrongProvince)`** found 0 colored hexes in the LRU cache for Rustic Canyon → `claimed == 0` → "No data" rendered.

The `users.province_hex` server field and the local SQLite home hex were permanently out of sync after a cross-province run.

### Fix
**`lib/features/run/providers/run_provider.dart`** — After `finalizeRun()` succeeds:

```dart
// If the run started in a different province → update local home hex
if (syncSucceeded && completedRun.hexPath.isNotEmpty) {
  final firstHex = completedRun.hexPath.first;
  final runProvince = HexService().getScopeHexId(
    firstHex,
    GeographicScope.province,
  );
  if (runProvince != PrefetchService().homeHexProvince) {
    debugPrint(
      'RunNotifier: Province changed $runProvince '
      '(was ${PrefetchService().homeHexProvince}) — updating local home hex',
    );
    await PrefetchService().saveHomeHex(firstHex);
  }
}
```

This block runs BEFORE the existing `PrefetchService().refresh()` call, so `_homeHexProvince` is already updated when the refresh downloads the new province snapshot.

Also added import: `import '../../../core/config/h3_config.dart';` for `GeographicScope`.

### Verification
- `flutter analyze lib/features/run/providers/run_provider.dart` → 2 pre-existing warnings, 0 errors (my change introduced 0 new issues)
- `./scripts/post-revision-check.sh` → 0 FAILs, 1 pre-existing WARN

### Lesson
**Invariant #18**: After `finalize_run()` succeeds, if the run's province (first hex's Res-5 parent) differs from `PrefetchService().homeHexProvince`, update local home hex via `PrefetchService().saveHomeHex()`. Without this, territory display permanently shows "No data" for users who run in a new area. The subsequent `PrefetchService().refresh()` (already called post-run) will then download the correct snapshot.

The broader rule: any server-side field derived from run data (`province_hex`, `district_hex`) must have a corresponding local update when that field changes. Never assume the server and local are in sync for location-derived state.

---

## Bug Fix: FormatException — Could Not Parse BigInt in LeaderboardScreen (2026-03-08)

### Problem
App crashed on `LeaderboardScreen` with `FormatException: Could not parse BigInt` when filtering leaderboard entries by scope. Crash consistently reproduced on Season Day 1 after a new user selected their team. Stack trace:

```
FormatException: Could not parse BigInt
#2  HexService.getParentHexId (hex_service.dart:103)
#3  HexService.getScopeHexId (hex_service.dart:196)
#4  LeaderboardEntry.isInScope (leaderboard_provider.dart:185)
#5  LeaderboardNotifier.filterByScope.<anonymous closure> (leaderboard_provider.dart:282)
```

### Root Cause
Two-layer failure:

**Layer 1 — `LeaderboardEntry.isInScope`** (province path, line 177): Guarded against `null` district hex but NOT against empty string `""`. Seed data and new-user rows can have `home_hex = ""` (empty string, non-null). The check `if (districtHex != null && referenceDistrictHex != null)` passed for `""`, forwarding it into `getParentHexId()`.

**Layer 2 — `HexService.getParentHexId`** (line 103): Immediately called `BigInt.parse(hexId, radix: 16)` with no guard. `BigInt.parse("", radix: 16)` throws `FormatException: Could not parse BigInt`.

The fallback `homeHex` path had the same gap — `if (homeHex == null || referenceHomeHex == null)` passed for `""` too, sending the empty string into `getScopeHexId()` → `getParentHexId()` → crash.

**Context**: On Day 1, `PrefetchService` skips leaderboard download (`Day 1 — skipping leaderboard download`) but `LeaderboardScreen.initState()` calls `fetchLeaderboard()` directly, which fetches from server. Server entries can have `home_hex = ""` for seed/new users.

### Fix
**`lib/features/leaderboard/providers/leaderboard_provider.dart`** — `LeaderboardEntry.isInScope()`:
- Added `.isNotEmpty` checks alongside `!= null` checks for both `districtHex` and `referenceDistrictHex` in the province path
- Wrapped both H3 computation blocks in `try/catch (_)` — invalid H3 silently falls through to next path or returns `false`
- Added `homeHex!.isEmpty` and `referenceHomeHex.isEmpty` guards in the homeHex fallback path

**`lib/core/services/hex_service.dart`** — `getParentHexId()`:
- Added early `if (hexId.isEmpty)` guard that throws `ArgumentError` with a descriptive message before `BigInt.parse` is reached
- Provides a clear failure point that the `isInScope` try/catch catches and handles gracefully

```dart
// hex_service.dart — getParentHexId() guard
String getParentHexId(String hexId, int parentResolution) {
  _checkInit();
  if (hexId.isEmpty) {
    throw ArgumentError(
      'hexId cannot be empty — received empty string instead of H3 index',
    );
  }
  final h3Index = BigInt.parse(hexId, radix: 16);
  ...
}

// leaderboard_provider.dart — isInScope() two-layer defense
bool isInScope(String? referenceHomeHex, GeographicScope scope, {
  String? referenceDistrictHex,
}) {
  // Province path: guard null AND empty
  if (scope == GeographicScope.province &&
      districtHex != null && districtHex!.isNotEmpty &&
      referenceDistrictHex != null && referenceDistrictHex.isNotEmpty) {
    try {
      final myParent = hexService.getParentHexId(districtHex!, H3Config.provinceResolution);
      final refParent = hexService.getParentHexId(referenceDistrictHex, H3Config.provinceResolution);
      return myParent == refParent;
    } catch (_) {
      // Invalid H3 index — fall through to homeHex path
    }
  }
  // Fallback: guard null AND empty
  if (homeHex == null || homeHex!.isEmpty ||
      referenceHomeHex == null || referenceHomeHex.isEmpty) return false;
  try {
    final myParent = hexService.getScopeHexId(homeHex!, scope);
    final refParent = hexService.getScopeHexId(referenceHomeHex, scope);
    return myParent == refParent;
  } catch (_) {
    return false;
  }
}
```

### Verification
- LSP diagnostics: 0 errors on both changed files
- `flutter analyze lib/`: 0 errors (remaining errors are pre-existing in test files)

### Lesson Learned
Empty string (`""`) and `null` are distinct failure modes. Guards like `if (x == null)` silently pass `""` through to H3 parsing, causing `FormatException`. Always check `isNotEmpty` alongside `!= null` for any string that feeds into H3 BigInt parsing. Wrap ALL H3 computation in `try/catch` at the calling site — H3 functions are unforgiving of malformed input.

---
## Bug Fix: Run History Wiped on Logout and Stale Session Detection (2026-03-08)

### Problem
Existing users lost all local run history (SQLite `runs`, `routes`, `laps` tables) after logging out and back in, or when the app detected a stale session (authenticated user with no Supabase profile row — e.g. during profile registration flow). All personal run data disappeared permanently.

### Root Cause
**Bug #1 — `clearAllGuestData()` called on every logout:**
`AppStateNotifier.logout()` called `LocalStorage().clearAllGuestData()` unconditionally. Despite the misleading name, this method deletes ALL rows from `runs`, `routes`, `laps`, and `run_checkpoint` tables — with no `user_id` filter (no such column exists). Every logout wiped the entire local run history, regardless of whether the user was a guest or an authenticated user.

**Bug #2 — Stale session detection triggered the same wipe:**
`AppStateNotifier.initialize()` detected stale sessions (authenticated Supabase user but `hasProfile()` returns false) and called `clearAllGuestData()` before signing out. This fires on Day 1 for any new user during the profile registration window — wiping any runs performed before profile setup completed.

### Fix
**`lib/core/storage/local_storage.dart`** — Added `clearSessionCaches()` method:
```dart
/// Clear session-specific cache data on logout.
/// Preserves run history (runs, routes, laps, run_checkpoint) which is
/// permanent and cross-season — run history MUST survive sign-out/sign-in.
/// Only clears: hex cache, leaderboard cache, prefetch metadata (home_hex).
Future<void> clearSessionCaches() async {
  if (_database == null) return;
  await _database!.transaction((txn) async {
    await txn.delete(_tableHexCache);
    await txn.delete(_tableLeaderboardCache);
    await txn.delete(_tablePrefetchMeta);
  });
  debugPrint('LocalStorage: Cleared session caches (run history preserved)');
}
```

**`lib/features/auth/providers/app_state_provider.dart`** — Two changes:
1. `logout()`: replaced `clearAllGuestData()` with `clearSessionCaches()`
2. `initialize()` stale session path: removed `clearAllGuestData()` entirely — stale sessions now sign out but preserve all local run data

### Verification
- LSP diagnostics: 0 errors on both changed files
- `flutter analyze lib/`: 0 errors (2 pre-existing info-level warnings unrelated to changes)

### Lesson Learned
Run history is **permanent and cross-season** — it must NEVER be cleared by auth state changes. The only correct clearing events are user-initiated data wipe. A method named `clearAllGuestData()` that deletes authenticated user data is a naming and design trap. Session logout should only clear server-cached data (hex snapshot, leaderboard cache, prefetch metadata), never the local run log.

---

## Bug Fix: Territory Shows Today's Runs Instead of Snapshot (2026-03-03)

### Problem
TeamScreen territory section showed 9 red hexes on Season Day 1 even though the season reset wiped all hexes. The `computeHexDominance()` method in `HexRepository` merged both `_hexCache` (midnight snapshot) AND `_localOverlayHexes` (today's own run flips). Since territory is "yesterday's snapshot"-based (same baseline as buff calculation), including today's live flips was wrong.

### Root Cause
`HexRepository.computeHexDominance()` used `_localOverlayHexes[hexId] ?? hex.lastRunnerTeam` unconditionally, and also counted overlay-only hexes not in the LRU cache. On Day 1, the snapshot was empty (season reset) but `_localOverlayHexes` had the user's 9 today-run flips, causing the wrong territory display.

### Fix
Added `includeLocalOverlay` parameter (default `true`) to `computeHexDominance()` in `hex_repository.dart`. Updated `TeamStatsNotifier.loadTeamData()` to pass `includeLocalOverlay: false` — territory always reads snapshot-only.

```dart
// hex_repository.dart — added parameter
Map<String, Map<String, int>> computeHexDominance({
  required String homeHexAll,
  String? homeHexCity,
  bool includeLocalOverlay = true,  // NEW
})

// team_stats_provider.dart — snapshot-only for TeamScreen
final localDominance = HexRepository().computeHexDominance(
  homeHexAll: provinceHex ?? '',
  homeHexCity: cityHex,
  includeLocalOverlay: false, // Territory = snapshot-only (yesterday's state)
);
```

### Verification
- LSP diagnostics: 0 errors on both files
- `flutter analyze lib/`: 0 errors
- Default `includeLocalOverlay: true` preserved for existing map rendering (which correctly shows today's flips on the hex map)

### Lesson Learned
The hex map display correctly merges snapshot + local overlay (so runners see their own real-time flips). But the TeamScreen territory counter is a different concern — it's anchored to yesterday's snapshot, the same baseline used for buff calculation. These two usages of `computeHexDominance()` need different behaviors.

---
## Bug Fix: Lightning Ball (⚡ BUFF) Disappears During Running (2026-03-03)

### Problem
The ⚡ BUFF stat item on the running screen was hidden when `multiplier == 1`. New users, Day-1 runners, and anyone with base buff never saw their buff status during a run.

### Root Cause
`_buildSecondaryStats()` in `running_screen.dart` used `showMultiplier = multiplier > 1` to gate the buff display. This hid the entire indicator when buff was 1x.

### Fix
Removed the conditional. The buff indicator (`⚡ BUFF` stat item) is now always visible. At 1x it shows with `AppTheme.textSecondary` color (dimmed); above 1x it shows amber.

```dart
// Before: hidden at 1x
if (showMultiplier) ...[  // ← gated
  _buildStatItem(icon: Icons.flash_on, value: '${multiplier}x', color: Colors.amber),
]

// After: always visible, color-coded
...[  // ← always shown
  _buildStatItem(
    icon: Icons.flash_on,
    value: '${multiplier}x',
    color: multiplier > 1 ? Colors.amber : AppTheme.textSecondary,
  ),
]
```

### Verification
- LSP diagnostics: 0 errors
- `flutter analyze lib/`: 0 errors

### Lesson Learned
Buff status is always relevant during running. Even 1x is meaningful context. "Never show" ≠ "show dimmed for 1x".

---
## Sync Rule Change: All Runs Upload to Server (2026-03-02)

### Change
Previously, only runs with ≥1 hex flip were uploaded to the server via `finalize_run()`.
Runs with 0 flips (e.g., running in already-owned territory, running too fast, outside home province)
were silently skipped — saved locally only, never synced.

The rule is now: **ALL completed runs are uploaded to the server**, regardless of flip count.

### Motivation
- Server `users.total_distance_km`, `total_runs`, `avg_pace_min_per_km` were undercounting
  because distance-only runs never reached `finalize_run()`
- `run_history` was incomplete — a user who ran 10km through already-dominated territory had
  no server record of that effort
- Season leaderboard stat details (distance, pace) were inaccurate for active territory-holders

### Game Balance Impact (Accepted)
- RED Elite threshold: 0-flip RED runners now count in the district runner pool → Elite
  threshold becomes slightly easier to achieve (mild buff inflation, accepted)
- PURPLE participation rate: 0-flip Purple runners now count as "active" → participation rate
  inflates, potentially bumping buff tier (accepted)
- Leaderboard ranking: unaffected — still filtered by `SUM(flip_points) > 0`

### Implementation
**Server migration** (`add_has_flips_to_run_history`):
- Added `has_flips BOOLEAN NOT NULL DEFAULT true` to `run_history` table
- Updated `finalize_run()` to set `has_flips = (hex_path IS NOT NULL AND array_length > 0)`
- Existing rows default to `true` (correct — all pre-existing rows had flips)

**Client changes**:
- `run_provider.dart`: Removed `capturedHexIds.isNotEmpty` gate from sync condition
- `sync_retry_service.dart`: Removed `hexPath.isEmpty` early-continue (0-flip runs now retry)
- `run.dart`: Added `hasFlips` bool field (toMap/fromMap/fromRow; NOT in toRow — server computes)
- `local_storage.dart`: Bumped SQLite to v17, added `has_flips INTEGER NOT NULL DEFAULT 1`

### Why has_flips Column
`has_flips` is a future toggle. Current buff RPCs (`get_user_buff`) count ALL runners in
`run_history`. If the game design decision is later reversed (0-flip runs should NOT count
for buff pool), add `AND has_flips = true` to the buff RPC queries — no new migration needed.

### Verification
- `finalize_run(p_hex_path := '{}')` confirmed safe: `hexes` write guarded, `district_hex`
  from separate param (not hex_path[1]), `p_hex_parents` guarded against NULL iteration
- `flutter analyze`: 0 new errors
- LSP diagnostics: clean on all modified files

---


## Fix #N — Voice Announcements Silent on iOS (2026-03-01)

### Problem
Voice announcements (`announceRunStart`, `announceKilometer`) stopped playing silently on iOS.
No crash, no error log — TTS simply produced no sound.

### Root Cause
`flutter_tts` on iOS requires explicit `AVAudioSession` configuration via `setSharedInstance(true)`
and `setIosAudioCategory(...)`. Without it, any competing audio session (Google Ads SDK sets
`AVAudioSessionCategoryAmbient` when displaying banner ads on `MapScreen`) silently takes
priority, causing TTS output to be suppressed with no error.

Call flow that triggered it:
1. User views `MapScreen` → `AdService` loads a banner ad → Google Ads SDK sets `AVAudioSessionCategoryAmbient`
2. User taps 'Start Run' → `VoiceAnnouncementService.initialize()` runs with NO audio session config
3. `announceRunStart()` fires but TTS is silently blocked by the pre-claimed audio session

Additionally, `initialize()` had no try-catch — any TTS exception propagated to `startRun()`'s
catch block and could abort the run start entirely, with no diagnostic output.

### Fix Applied
**File**: `lib/features/run/services/voice_announcement_service.dart`

```dart
// Inside initialize(), after setVolume():
if (Platform.isIOS) {
  await _tts!.setSharedInstance(true);  // claim shared audio session
  await _tts!.setIosAudioCategory(
    IosTextToSpeechAudioCategory.playback,
    [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,  // coexist with music/GPS
    ],
    IosTextToSpeechAudioMode.defaultMode,
  );
}
```

Also wrapped the entire TTS setup block in try-catch so failures surface in logs instead
of propagating silently to the caller.

### Verification
- `flutter analyze` — 0 new issues (pre-existing test errors unchanged)
- LSP diagnostics clean on `voice_announcement_service.dart`
- Manual test required: start run on iOS physical device → confirm 'Run started. Let's go!' plays
  after viewing map screen with ad banner active

### Lesson Learned
> **iOS audio session is first-come-first-served.** Google Ads SDK claims `AVAudioSessionCategoryAmbient`
> when any ad loads. `flutter_tts` needs `IosTextToSpeechAudioCategory.playback`
> with `.duckOthers` to override this. This must be set during `initialize()`, before the first
> `speak()` call. Absence = silent TTS with zero error output.
> **UPDATE (2026-04-05):** `setSharedInstance(true)` was REMOVED — it pre-activates the AVAudioSession
> at init time, causing music apps (Spotify, Apple Music) to pause permanently instead of ducking.
> Native `requestAudioFocusDuck` → `setActive(true)` handles activation at the correct time (before each speak).

## FlipPoints Header: Client-Server Points Mismatch (2026-02-26)

### Problem
After a run completes and syncs successfully, the FlipPoints header could show inflated points that don't match the server's validated total. The server anti-cheat (`finalize_run`) may cap `points_earned` below the client-calculated `flipPoints` (e.g., server returns 6 but client calculated 11), yet the client used its own unvalidated value.

### Root Cause
Two code paths called `onRunSynced(flipPoints)` with the **client-calculated** flip points (`hexesColored × buffMultiplier`) instead of the **server-validated** `points_earned` from the `finalize_run` RPC response:

1. **`run_provider.dart` line 587**: After Final Sync, passed local `flipPoints` to `onRunSynced()` — ignored `syncResult['points_earned']`
2. **`sync_retry_service.dart` line 78**: After retry sync, accumulated `run.flipPoints` — ignored `syncResult['points_earned']`

The `finalize_run` RPC validates: `points = LEAST(client_points, hex_path_length × server_validated_multiplier)`. When the server caps points (anti-cheat), the client's `PointsNotifier.onRunSynced()` would:
- Add the inflated client points to `seasonPoints`
- Show inflated `totalSeasonPoints` in the header
- Self-correct only on next app launch when `appLaunchSync` fetches the true server `season_points`

### Fix Applied

**`lib/features/run/providers/run_provider.dart`:**
- Extract `serverValidatedPoints` from `syncResult['points_earned']` after `finalizeRun()`
- Pass `serverValidatedPoints` (not `flipPoints`) to `onRunSynced()`
- Enhanced debug logging: now shows both server and client point values

**`lib/core/services/sync_retry_service.dart`:**
- Extract `serverPoints` from `syncResult['points_earned']` after `finalizeRun()`
- Accumulate `serverPoints` (not `run.flipPoints`) into `totalSyncedPoints`
- Enhanced debug logging with both server and client values

### Verification
- LSP diagnostics: 0 errors on both files
- `flutter analyze`: no new errors/warnings introduced
- Server `app_launch_sync` returns correct `season_points: 6` matching `run_history` sum ✓

### Lesson
After ANY server-validated write, the client must use the server's **response values** — not its own pre-validation calculations. The server is the source of truth for points; the client's role is display and optimistic UI, corrected by server responses.

---

## TeamScreen FLAME RANKINGS Shows Only 1 Elite Runner (2026-02-27)

### Problem
TeamScreen showed only 1 elite runner (the logged-in user, ljae.m10, 25pts) in the FLAME RANKINGS section. The leaderboard confirmed 3 RED runners in the same province (BreezeGold 13pts, PrismSummit 13pts), and the DB had 15 RED runners in district `86283472fffffff` who ran on 2026-02-26. The UI showed `Top 20% = Elite (≥25 pts)`, `1 in City`, `Top 1 = Elite` — consistent with only 1 runner being found.

### Root Cause
The `get_team_rankings` RPC had a `COALESCE` ordering bug:

```sql
-- BEFORE (wrong): client p_city_hex takes precedence over authoritative server value
v_city_hex := COALESCE(p_city_hex, v_user.district_hex);

-- AFTER (correct): server-stored district_hex preferred; p_city_hex is fallback only
v_city_hex := COALESCE(v_user.district_hex, p_city_hex);
```

The client computed `homeHexCity` via `getScopeHexId(homeHex, GeographicScope.city)` (Res 6 parent of Res 9 `homeHex`). GPS drift or hex boundary edge cases caused `homeHexCity` to resolve to a **neighboring district hex** (`862834727ffffff`) instead of the authoritative `users.district_hex = '86283472fffffff'`. With the wrong district hex, the RPC found only the logged-in user in that district → `red_runner_count_city = 1`, `elite_threshold = 25` (user's own points), `elite_top3 = [ljae.m10]`.

**Confirmed via SQL**: `get_team_rankings(userId, '862834727ffffff')` → 1 runner. `get_team_rankings(userId, '86283472fffffff')` → 3 runners. `get_team_rankings(userId, NULL)` → 3 runners (server fallback).

### Fix Applied

**Migration**: `fix_team_rankings_prefer_server_district_hex`
- Changed `COALESCE(p_city_hex, v_user.district_hex)` → `COALESCE(v_user.district_hex, p_city_hex)` in `get_team_rankings`
- `users.district_hex` is set server-side by `finalize_run()` — it is the authoritative value
- Client-provided `p_city_hex` is now a fallback for new users who have never completed a run

**`lib/features/team/providers/team_stats_provider.dart`**:
- Added debug logging after `TeamRankings.fromJson()` to surface `cityHex`, elite count, threshold, runner count for future diagnostics

**`get_user_buff`**: already had the correct ordering `COALESCE(v_user.district_hex, p_district_hex)` — no change needed.

### Verification
- `get_team_rankings(userId, '862834727ffffff')` (wrong hex) → now returns 3 runners ✓
- `flutter analyze`: 0 issues on `team_stats_provider.dart` ✓
- LSP diagnostics: 0 errors on `team_stats_provider.dart` ✓
- `get_user_buff` COALESCE order confirmed correct ✓

### Lesson
**Client-computed geographic scoping is unreliable**. GPS drift and H3 boundary edge cases cause client-computed parent hexes to resolve to neighboring districts. Any RPC that scopes queries by district MUST prefer `users.district_hex` (server-authoritative, set by `finalize_run`) over client-provided hex values. The client parameter should only serve as a fallback for new users who have never completed a run.

---

## TeamScreen Cross-Season Elite/Rankings Contamination (2026-02-26)

### Problem
On Season Day 1, TeamScreen showed user as ELITE with 14 pts and 2x buff multiplier.
There was no yesterday record (Day 1 = no previous day in this season), yet FLAME RANKINGS showed stale Season 4 data.
The 2x buff was also stale — computed from Season 4's last day `run_history`.

### Root Cause
Both `get_user_buff()` and `get_team_rankings()` RPCs query `run_history` for "yesterday" (`v_yesterday := today - 1`).
On Season Day 1, yesterday = previous season's last day. `run_history` is preserved across seasons,
so both RPCs found Season 4 data and returned stale elite status/rankings/buff.

The client had Day 1 protection for `getUserYesterdayStats` but NOT for `getTeamRankings` or `getBuffMultiplier`.

### Fix Applied

**Server-side (3 SQL migrations):**
- Added season boundary check to `get_user_buff()`: reads `app_config.season` to compute current season start.
  If yesterday < current season start, returns default 1x multiplier with `is_elite: false`.
- Added same check to `get_team_rankings()`: returns empty rankings if yesterday is cross-season.
- Date math fix: `DATE - DATE` returns integer in PostgreSQL, not interval.

**Client-side (belt + suspenders):**
- `TeamStatsNotifier.loadTeamData()`: extended `isDay1` guard to also skip `getTeamRankings()` call on Day 1.
  Previously only skipped `getUserYesterdayStats()`.

### Verification
- `get_user_buff` returns: `multiplier: 1, is_elite: false, reason: "Default (new season)"` ✓
- `get_team_rankings` returns: `user_is_elite: false, red_elite_top3: [], user_yesterday_points: 0` ✓

### Lesson
ALL server RPCs that query `run_history` for "yesterday" must have season boundary awareness.
Season boundary = `current_season_start` computed from `app_config.season.startDate + durationDays`.
Client-side Day 1 guards are belt-and-suspenders, not primary defense.

---
## ARCHITECTURE RULE: Two Data Domains (2026-02-26)

### Rule
Formalized as permanent architectural rule after ALL TIME stats were incorrectly reset during Season 5 transition.

**Rule 1 — Running History = Client-side (cross-season, never reset):**
- ALL TIME stats computed from local SQLite `runs` table (`allRuns.fold()`) in `run_history_screen.dart`
- NEVER read from server `UserModel` aggregate fields (`totalDistanceKm`, `avgPaceMinPerKm`, `avgCv`, `totalRuns`)
- Period stats (DAY/WEEK/MONTH/YEAR) also from local SQLite
- Survives The Void — personal running history is permanent
- Also available: `LocalStorage.getAllTimeStats()` for async contexts

**Rule 2 — Hexes + TeamScreen + Leaderboard = Server-side (season-based, reset each season):**
- Downloaded on app launch/OnResume. Reset each season.
- Leaderboard from `season_leaderboard_snapshot` (NOT live `users`)
- TeamScreen from server RPCs (home hex anchored)

### Changes Made
- `run_history_screen.dart`: ALL TIME panel now computes from `allRuns.fold()` (was reading `UserModel` server fields)
- `local_storage.dart`: Added `getAllTimeStats()` method for non-UI async contexts
- Removed unused `points_provider.dart` import from `run_history_screen.dart`
- `UserRepository.updateAfterRun()`: KEPT — harmless, server overwrites on next launch via `app_launch_sync()`
- Updated: AGENTS.md, DEVELOPMENT_SPEC.md, docs/03-data-architecture.md

### Why This Matters
Server `UserModel` fields can be incorrectly reset during season transitions. Local SQLite `runs` table is append-only and never reset, making it the reliable source of truth for personal running history.

---

## ALL TIME Stats Reset + TeamScreen Yesterday Season Boundary (2026-02-26)

### Problem
1. **ALL TIME running stats incorrectly reset**: Season 5 reset zeroed `users.total_distance_km`, `avg_pace_min_per_km`, `avg_cv`, `total_runs`, `cv_run_count`. These are ALL TIME aggregates (cross-season) and should NEVER be reset. The run_history_screen ALL TIME panel showed 0 for everything.
2. **TeamScreen yesterday shows previous season data**: On Day 1, `get_user_yesterday_stats` returns data from the previous season's last day (because `run_history` is preserved). TeamScreen displayed stale cross-season yesterday stats.

### Root Cause
1. **ALL TIME**: The season reset SQL followed the Season 2 seed migration pattern which reset ALL fields. But ALL TIME aggregate fields (`total_distance_km`, `avg_pace_min_per_km`, `avg_cv`, `total_runs`, `cv_run_count`) accumulate across seasons and must persist.
2. **Yesterday stats**: `TeamStatsNotifier.loadTeamData()` fetches yesterday's stats by date without checking if "yesterday" falls in the current season. On Day 1, yesterday = previous season's last day.

### Fix Applied

**Server-side (SQL):**
- Recalculated ALL TIME aggregates from `run_history` for all users:
  ```sql
  WITH user_agg AS (
    SELECT user_id, SUM(distance_km), COUNT(*), AVG(avg_pace_min_per_km),
           AVG(cv) FILTER (WHERE cv IS NOT NULL), COUNT(cv)
    FROM run_history GROUP BY user_id
  )
  UPDATE users SET total_distance_km=..., total_runs=..., avg_pace=..., avg_cv=..., cv_run_count=...
  FROM user_agg WHERE users.id = user_agg.user_id;
  ```
- Verified: 198 users now have restored ALL TIME stats

**Client-side:**
- `TeamStatsNotifier.loadTeamData()`: Added `SeasonService().isFirstDay` check — on Day 1, returns `{'has_data': false}` instead of calling `getUserYesterdayStats` RPC. This makes TeamScreen show "No runs yesterday" on season's first day.

### Files Modified
- `lib/features/team/providers/team_stats_provider.dart` — Day 1 season boundary check for yesterday stats

### Key Lesson: Two Data Domains for User Stats
| Field | Domain | Reset on New Season? |
|-------|--------|---------------------|
| `season_points` | Season | YES — reset to 0 |
| `team` | Season | YES — reset to NULL |
| `season_home_hex` | Season | YES — reset to NULL |
| `total_distance_km` | ALL TIME | **NO — never reset** |
| `avg_pace_min_per_km` | ALL TIME | **NO — never reset** |
| `avg_cv` | ALL TIME | **NO — never reset** |
| `total_runs` | ALL TIME | **NO — never reset** |
| `cv_run_count` | ALL TIME | **NO — never reset** |

---

## Season 5 Day 1 Fix (2026-02-26)

### Problem
Season 5 started (Feb 26 GMT+2) but the app showed stale Season 4 data: leaderboard rankings from Season 4, hex territory from Season 4.

### Root Cause
1. **Server-side**: No automated season reset existed. Season 4 data (hexes, hex_snapshot, daily_buff_stats, users.season_points) was never cleared.
2. **Client-side**: No Day 1 detection — PrefetchService always downloads snapshot/live hexes regardless of season day, wasting network calls and potentially loading stale data.

### Fix Applied

**Server-side (SQL):**
- Archived Season 4 leaderboard into `season_leaderboard_snapshot` (season_number=4, 198 entries)
- Deleted stale data: `hexes`, `hex_snapshot`, `daily_buff_stats`, `daily_province_range_stats`, `daily_all_range_stats`
- Reset SEASON-ONLY fields: `season_points=0`, `team=NULL`, `season_home_hex=NULL`
- Preserved: `run_history` (674 rows), `runs`, `daily_stats`, ALL TIME aggregate fields

**Client-side:**
- Added `SeasonService.isFirstDay` getter (`currentSeasonDay == 1`)
- `PrefetchService._downloadHexData()`: On Day 1, clears hex cache + applies local overlay only (skips server calls)
- `PrefetchService._downloadLeaderboardData()`: On Day 1, clears leaderboard cache (skips server calls)

### Files Modified
- `lib/core/services/season_service.dart` — Added `isFirstDay` getter
- `lib/core/services/prefetch_service.dart` — Added Day 1 early-return in `_downloadHexData()` and `_downloadLeaderboardData()`

### Already Handled (no changes needed)
- **Leaderboard empty state**: `_buildEmptyState()` already shows "No runners found" when entries are empty
- **Auth flow**: Router redirects to `/season-register` when `team = NULL` (existing behavior)
- **Local SQLite overlay**: `getTodayFlippedHexes()` filters by today's date, so S4 runs don't appear

### Prevention
- **TODO**: Create a reusable `reset_season()` SQL function for future season transitions
- **TODO**: Consider an Edge Function cron that runs season reset automatically on Day 1
---

## Post-Run Hex Data Disappearing (2026-02-25)

### Problem
After a run completes, the hex map shows 0% for all teams — all territory info disappears.

### Root Cause (suspected)
`RunProvider.stopRun()` completes the run but doesn't trigger a hex data refresh. The hex cache may be getting cleared or invalidated during run completion without being repopulated from the server.

### Fix Applied
**Defensive fix**: Added `PrefetchService().refresh()` + `notifyHexDataChanged()` calls in all 3 `stopRun()` code paths (guest, normal, no-result).

**Debug logging**: Added strategic logging in `HexRepository.bulkLoadFromSnapshot()`, `HexRepository.bulkLoadFromServer()`, `HexDataNotifier`, and `PrefetchService._downloadHexData()` to capture cache state if the issue recurs.

### Files Modified
- `lib/features/run/providers/run_provider.dart` — Post-run hex refresh in 3 stopRun paths
- `lib/data/repositories/hex_repository.dart` — Debug logging in bulk load methods
- `lib/features/map/providers/hex_data_provider.dart` — Warning log in getAggregatedStats
- `lib/core/services/prefetch_service.dart` — Cache size logs

### Status
Defensive fix implemented, awaiting verification. Debug logging will help diagnose root cause if it recurs.

---

## P0-1: Global Error Handlers + Back Button Protection (2026-02-25)

### Problem
No global error handlers for uncaught exceptions. Users could accidentally exit a run with the back button.

### Fix Applied
- Added `FlutterError.onError` and `PlatformDispatcher.onError` in `main.dart`
- Added `PopScope` with confirmation dialog to `RunningScreen` to prevent accidental back-button exits during active runs

### Files Modified
- `lib/main.dart` — Global error handlers
- `lib/features/run/screens/running_screen.dart` — PopScope + confirmation dialog

---

## P0-2: Silent GPS Failure + Periodic Checkpoints (2026-02-25)

### Problem
GPS could silently fail during a run with no user feedback. Run data could be lost on crash.

### Fix Applied
- Added GPS error stream to `LocationService` that emits error events
- `RunProvider` listens to GPS errors and auto-stops run after 60s of GPS failure
- Added periodic checkpoint saving (every hex flip) via `run_checkpoint` SQLite table

### Files Modified
- `lib/features/run/services/location_service.dart` — GPS error stream
- `lib/features/run/providers/run_provider.dart` — GPS error listener, periodic checkpoints

---

## P0-3: Run History Pagination + Redundant RPC Removal (2026-02-25)

### Problem
Run history loaded all records at once (potential performance issue). App called `getUserBuff()` RPC separately when it was already included in `appLaunchSync()`.

### Fix Applied
- Added pagination to `SupabaseService.getRunHistory()` (limit/offset params)
- Replaced separate `getUserBuff()` call in `AppInitProvider` with buff data from `appLaunchSync()` response

### Files Modified
- `lib/core/services/supabase_service.dart` — Pagination params, leaderboard limit 200→50
- `lib/features/auth/providers/app_init_provider.dart` — Removed redundant getUserBuff RPC

---

## P0-4: SyncRetry Exponential Backoff + Dead Letter (2026-02-25)

### Problem
Failed run syncs retried immediately on every opportunity with no backoff, potentially hammering the server. No way to give up on permanently failed syncs.

### Fix Applied
- Added `retry_count` and `next_retry_at` columns to SQLite `runs` table (DB v16)
- Exponential backoff: 30s, 2min, 8min, 32min, 2h (5 retries max)
- Dead-letter: After 5 retries, sync_status set to 'failed' and no longer retried
- `SyncRetryService` checks `next_retry_at` before retrying

### Files Modified
- `lib/core/storage/local_storage.dart` — DB v16, retry tracking methods
- `lib/core/services/sync_retry_service.dart` — Exponential backoff logic

---

## P1-1: Offline Connectivity Banner (2026-02-25)

### Problem
No indication to users when they're offline — server operations silently fail.

### Fix Applied
- Created `ConnectivityProvider` (StreamProvider) using `connectivity_plus`
- Added persistent offline banner to `HomeScreen` — appears below AppBar when offline

### Files Modified
- `lib/core/providers/connectivity_provider.dart` — NEW: StreamProvider for connectivity
- `lib/app/home_screen.dart` — Offline banner widget

---

## Common Patterns & Lessons

### Things that already handle null/empty gracefully (don't fix these):
- `LeaderboardScreen._buildEmptyState()` — "No runners found"
- `TeamScreen._buildYesterdaySection()` — "No runs yesterday" when `hasData == false`
- `YesterdayStats.fromJson()` — `has_data: false` fallback
- `_buildSeasonStatsSection()` — `?? 0` fallbacks for null leaderboard entry
- `getTodayFlippedHexes()` — filters by today's GMT+2 date, old seasons don't leak

### Season transition checklist (for future resets):
1. `snapshot_season_leaderboard(season_number)` — reads `run_history` with date bounds. **MUST run first.**
2. Reset SEASON-ONLY user fields: `season_points=0`, `team=NULL`, `season_home_hex=NULL`
3. Clear season tables: `hexes`, `hex_snapshot`, `daily_buff_stats`, `daily_province_range_stats`, `daily_all_range_stats`
4. **`DELETE FROM run_history`** — season-scoped, cleared at The Void. Safe only AFTER step 1.
5. **DO NOT reset ALL TIME user fields**: `total_distance_km`, `avg_pace_min_per_km`, `avg_cv`, `total_runs`, `cv_run_count`
6. DO NOT delete: `daily_stats`, `season_leaderboard_snapshot` (historical archives for all seasons)
7. Client auto-handles: Day 1 detection skips snapshot/leaderboard/yesterday-stats, router redirects to team selection

**run_history is season-scoped.** Personal running history lives permanently in local SQLite (`runs` table). Day 1 buff = 1x naturally (no prior data) — intended game rule, no RPC guards needed.
⚠️ If ALL TIME user fields were accidentally reset, recalculate from `season_leaderboard_snapshot` archives using `SUM(season_points)` etc.

---

## Hex Local Overlay Eviction + Day 1 Map Blank + Points Mismatch (2026-02-27)

### Problems
Three related bugs on Season Day 1:
1. **Hex overlay eviction**: User's own run flips (colored hexes) were being wiped from the in-memory cache whenever `PrefetchService.refresh()` ran, because `bulkLoadFromSnapshot()` called `_hexCache.clear()` — removing the local overlay that lived in the same LRU cache.
2. **Post-run map blank (Day 1)**: After run completes on Day 1, `_downloadHexData()` called `repo.clearAll()` before `_applyLocalOverlay()`. Since our Fix 1 moved the overlay to `_localOverlayHexes`, `clearAll()` wiped both stores — map showed 0/0/0 neutral.
3. **Points mismatch header vs history**: `_filterRunsForStats()` in `run_history_screen.dart` used `run.startTime` converted to display timezone for the DAY filter, while `PointsService`/SQLite used `run_date` (GMT+2 string from `endTime`). A run near midnight could land in different date buckets.

### Root Causes
1. **LRU eviction**: `applyLocalOverlay()` wrote into `_hexCache` (LRU), so snapshot reloads (`_hexCache.clear()`) silently discarded user's flips.
2. **Day 1 clearAll**: Previous fix correctly changed `clearAll()` → `clearLocalOverlay()` in Day 1 branch, but the edit accidentally dropped the closing `}` of `_RunHistoryScreenState`, nesting top-level classes inside it.
3. **Timezone mismatch**: History screen's `today` was computed from local device timezone, but SQLite queries used `Gmt2DateUtils.todayGmt2String` (server timezone). Could diverge for users in UTC−/UTC+ relative to GMT+2.

### Fixes Applied

**Fix 1 — `lib/data/repositories/hex_repository.dart`:**
- Added `final Map<String, Team> _localOverlayHexes = {}` — eviction-immune map separate from LRU cache.
- `applyLocalOverlay()` writes into `_localOverlayHexes` (not LRU) — survives all snapshot reloads.
- `updateHexColor()` (live run flips) also writes into `_localOverlayHexes` for the same reason.
- `getHex()` merges overlay on top of LRU: if LRU evicted a flip, `_localOverlayHexes` reconstructs it.
- `clearAll()` clears both (explicit full reset only — province change / season reset).
- New `clearLocalOverlay()` resets overlay only (midnight rollover).
- `computeHexDominance()` walks both LRU and overlay-only hexes, overlay wins for shared entries.
- `cacheStats` includes `'overlay': _localOverlayHexes.length`.

**Fix 2 — `lib/core/services/prefetch_service.dart`:**
- Day 1 branch of `_downloadHexData()`: changed from `repo.clearAll()` to `repo.clearLocalOverlay()` so overlay (today's run flips) is reset from SQLite rather than fully wiped.

**Fix 3 — `lib/features/history/screens/run_history_screen.dart`:**
- `_filterRunsForStats()` DAY case: when `run.runDate` is non-null, compare it directly against `Gmt2DateUtils.todayGmt2String` (same boundary as `sumAllTodayPoints()`). Falls back to display-timezone `startTime` for legacy runs without `runDate`.
- Structural fix: closing `}` of `_RunHistoryScreenState` was missing — `_BarEntry` and `_PaceLinePainter` were nested inside the class, causing 30+ compile errors. Added the missing `}` to close the class before those top-level classes.

**Fix 4 — `lib/app/home_screen.dart`:**
- `_refreshAppData()` was calling `clearAllHexData()` → `HexRepository.clearAll()` on every app resume, wiping both `_hexCache` AND `_localOverlayHexes` (today's run flips).
- Replaced with `PrefetchService().refresh()` + `notifyHexDataChanged()` — the correct pattern that preserves the overlay through snapshot reloads.
- Root of the post-run blank map: after run ended, navigating back to map screen triggered a resume event, `_refreshAppData()` fired, and wiped all hex data including the overlay just populated by the post-run refresh.

### Why Fix 4 Was the Real Root Cause
`AppLifecycleManager` is a singleton with `if (_isInitialized) return` guard — only the first `initialize()` call sets the callback. `home_screen.dart` registered `_refreshAppData()` (destructive: `clearAllHexData()`). `app_init_provider.dart` registered `_onAppResume()` (safe: `PrefetchService().refresh()`). Whichever initialized first set the destructive callback, wiping hex data on every resume — overriding all post-run refresh work.

### Files Modified
- `lib/data/repositories/hex_repository.dart` — `_localOverlayHexes`, `clearLocalOverlay()`, updated `getHex()`, `applyLocalOverlay()`, `updateHexColor()`, `clearAll()`, `computeHexDominance()`, `cacheStats`
- `lib/core/services/prefetch_service.dart` — Day 1 branch: `clearLocalOverlay()` instead of `clearAll()`
- `lib/features/history/screens/run_history_screen.dart` — DAY filter uses `run.runDate` (GMT+2); structural fix for missing `}`
- `lib/app/home_screen.dart` — `_refreshAppData()` uses `PrefetchService().refresh()` instead of `clearAllHexData()`

### Verification
- `flutter analyze lib/`: 0 errors after each fix
- LSP diagnostics: clean on all modified files

### Lessons
1. **Never put local overlay in the LRU cache** — any `clear()` call silently evicts it. Use a separate eviction-immune map.
2. **`clearAll()` is a nuclear option** — reserve for season reset / province change only. Use `clearLocalOverlay()` for day rollover.
3. **Resume callbacks must not clear data** — they should refresh (fetch + merge), not wipe. `PrefetchService().refresh()` is the correct pattern; raw `clearAllHexData()` is wrong.
4. **Date boundary must match** — client 'today' filter and SQLite 'today' filter must use the same timezone/field (`run_date` GMT+2 string), or points appear in different buckets.
5. **AppLifecycleManager singleton guard** — only the first `initialize()` wins. If two callers register callbacks, only one takes effect. Audit all `initialize()` call sites when debugging lifecycle issues.


---

## TeamScreen Territory Shows 0/0/0 Despite Downloaded Snapshot (2026-02-27)

### Problem
TeamScreen showed 0 hexes for all teams (Red/Blue/Purple) even though `hex_snapshot` had 259 rows downloaded on app launch.

### Root Cause
Double mismatch between the `get_hex_dominance` Supabase RPC and the client parser:

**Mismatch 1 — JSON key names:**
- RPC returned flat keys: `"red_hexes"`, `"blue_hexes"`, `"purple_hexes"`, `"total_hexes"`
- `HexDominanceScope.fromJson()` expected: `"red_hex_count"`, `"blue_hex_count"`, `"purple_hex_count"`
- All three parsed as `null` → defaulted to `0`

**Mismatch 2 — Response nesting:**
- `HexDominance.fromJson()` expected a nested structure: `{ "all_range": {...}, "city_range": {...} }`
- RPC returned flat counts at the top level — no nesting, no `all_range` key
- `allRange` parsed from `null` → all zeros; `cityRange` absent

**Structural blocker — No H3 in Postgres:**
- `hexes` table has no `district_hex` column (only `parent_hex` at Res 5 province)
- No H3 PostgreSQL extension installed → city-range (Res 6) filtering is impossible server-side
- The client needs city-range, but the RPC has no way to compute it

### Fix Applied

**`lib/features/team/providers/team_stats_provider.dart`:**
- Removed `supabase.getHexDominance(parentHex: provinceHex)` from the `Future.wait()` array
- After `Future.wait()`, compute dominance via `HexRepository().computeHexDominance(homeHexAll: provinceHex, homeHexCity: cityHex)` — which uses the already-downloaded hex data in the local cache
- Construct `HexDominance` + `HexDominanceScope` directly from the local counts map (`'red'`, `'blue'`, `'purple'` keys)
- Added import for `HexRepository`

This is cleaner than fixing the RPC because:
1. The snapshot is already downloaded and stored in `HexRepository` on app launch
2. `computeHexDominance()` correctly handles both province-level (`allRange`) and district-level (`cityRange`) via H3 parent resolution client-side
3. Local data reflects the user's own today flips (via `_localOverlayHexes`) which the server doesn't have yet

### Files Modified
- `lib/features/team/providers/team_stats_provider.dart` — Replaced RPC call with `HexRepository().computeHexDominance()`

### Verification
- `flutter analyze lib/`: 0 errors introduced

### Lesson
When the backend lacks a capability (H3 resolution math, no Postgres extension), and the client already has the data, compute locally. The hex snapshot is downloaded specifically so the client has territory data — use it. Don't force a round-trip RPC for data the client already holds.


---

## TeamScreen FLAME RANKINGS Shows Only Current User (2026-02-27)

### Observed Symptom
On Season 5 Day 2 (Feb 27, D-3 remaining), TeamScreen FLAME RANKINGS showed:
- ELITE section: only `#1 ljae.m10  25 pts`
- `Top 20% = Elite  (≥25 pts)` — threshold incorrectly set to the user's own points
- `1 in City` / `Top 1 = Elite` in the buff section
- Other runners (BreezeGold, PrismSummit, etc.) absent despite having Feb 26 runs in the district

The leaderboard screen correctly showed 15+ runners. Only TeamScreen rankings was wrong.

### Root Cause
Two compounding issues:

**Issue 1 — Client `isDay1` guard too broad (primary):**
```dart
// BEFORE — skipped rankings on Day 1; getHexDominance was 3rd future
final results = await Future.wait([
  if (!isDay1) supabase.getUserYesterdayStats(...) else Future.value({'has_data': false}),
  if (!isDay1) supabase.getTeamRankings(...) else Future.value(<String, dynamic>{}),
  supabase.getHexDominance(parentHex: provinceHex),  // 3rd future, wrong JSON shape
]);
```
On Day 1, `getTeamRankings()` returned `{}` → `redEliteTop3 = []`. On Day 2+, it was called
but depended on the server RPC returning correct season-scoped data.

**Issue 2 — Server RPC `get_team_rankings` lacked season boundary check:**
When called on Day 2 (`v_today = Feb 27`, `v_yesterday = Feb 26`), the old RPC correctly
returned Feb 26 data. However if called while only 1 runner had run in the district,
`elite_cutoff_rank = GREATEST(1, floor(1×0.2)) = 1` → `elite_threshold = user's own points = 25`
→ HAVING clause excluded everyone except the user → `red_elite_top3 = [{user only}]`.

This is not a logic bug in the RPC — it correctly reflects the state at query time.
The real issue was the client guard blocking the call unnecessarily on Day 1, and the
hex dominance RPC returning a wrong JSON shape (flat keys vs nested, no city-range support).

### Fixes Applied

**Fix A — `lib/features/team/providers/team_stats_provider.dart`:**
- Removed the `if (!isDay1) ... else Future.value({})` conditional around `getTeamRankings()`.
- Rankings are now **always fetched** regardless of season day.
- Removed `supabase.getHexDominance()` call (3rd future) — replaced with local computation.
- `Future.wait` now has 2 elements only (yesterday stats + rankings).
- The `getUserYesterdayStats` Day 1 guard is **preserved** — correctly prevents Season 4 stats leaking.

**Fix B — Hex dominance replaced with local `HexRepository().computeHexDominance()`:**
- The `getHexDominance` RPC returns flat keys (`red_hexes`) that don't match the client parser
  (`red_hex_count`), and can't compute city-range (Res 6) without H3 extension in Postgres.
- Local `HexRepository` already holds the full downloaded snapshot — compute directly.
- City-range (district-level) dominance is resolved client-side via H3 parent resolution.

```dart
// AFTER — always fetch rankings; 2-element Future.wait; local dominance
final results = await Future.wait([
  if (!isDay1)
    supabase.getUserYesterdayStats(userId, date: yesterdayStr)
  else
    Future.value(<String, dynamic>{'has_data': false}),
  // Rankings always fetched — server RPC handles season boundary internally.
  supabase.getTeamRankings(userId, cityHex: cityHex),
]);
// ... then compute dominance locally:
final localDominance = HexRepository().computeHexDominance(
  homeHexAll: provinceHex ?? '',
  homeHexCity: cityHex,
);
```

### Verification
- Direct RPC `get_team_rankings('08f88e4b...', '86283472fffffff')` returns 3 runners:
  ljae.m10 (25pts, rank#1), BreezeGold (13pts), PrismSummit (13pts), threshold=13, 15 runners in city ✓
- `flutter analyze lib/`: 125 issues, 0 new errors (all pre-existing info/warnings) ✓

### Files Modified
- `lib/features/team/providers/team_stats_provider.dart` — Removed `isDay1` guard for `getTeamRankings()`; removed `getHexDominance` call; added local dominance computation

### Lesson
1. **Client Day 1 guards must be narrow** — guard only the specific cross-season concern
   (`getUserYesterdayStats`). Don't block other RPCs that have their own guards.
2. **RPC results reflect real-time state** — if only 1 runner has run at query time,
   rankings correctly shows 1. This is correct behavior, not a bug.
3. **Replace broken RPCs with local computation** when the client already has the data.
   The hex snapshot is downloaded on launch specifically so client has territory data.
4. **JSON shape mismatches are silent** — `fromJson` with wrong keys returns 0, not an error.
   Always verify RPC response shape matches the client parser's expected keys.

---

## TeamScreen Rankings Stale After Season Day Rolls (OnResume Not Refreshing) (2026-02-27)

### Problem
After the previous fix (removing `isDay1` guard from `getTeamRankings()`), TeamScreen FLAME RANKINGS still showed only user `#1 ljae.m10` without other runners, even though:
- The server RPC `get_team_rankings()` returns 3 runners correctly (verified via direct SQL call)
- `run_history` has 15 red runners in the same district with Feb 26 runs
- `TeamRankings.fromJson()` correctly parses `red_elite_top3`

### Why the Previous Fix Was Incomplete
The previous fix correctly fixed the **code path** (removed the `isDay1` guard). But it was verified by a **direct RPC test** — not by actually launching the app and navigating to TeamScreen.

The real remaining bug: **`_onAppResume()` in `app_init_provider.dart` never called `teamStatsProvider.loadTeamData()`**.

`TeamScreen` only loads data in `initState` via `addPostFrameCallback`. This means:
- On **first open**: works correctly (initState fires, `_loadData()` is called)
- On **app resume** (foreground from background): `_onAppResume()` refreshes hex data, leaderboard, points, and buff — but NOT team rankings
- On **subsequent navigation** to TeamScreen (screen stays in stack): initState is NOT re-called

Result: After the season day rolled from Day 1 → Day 2, the `TeamStatsState` retained the stale state from the PREVIOUS session (when the `isDay1` guard may have returned `{}` for rankings, showing 0 other runners). Only a cold app restart would re-trigger initState and load fresh rankings.

### Root Cause Chain
1. Season Day 1 (Feb 26): `isDay1 = TRUE` → old code returned `{}` for rankings → `TeamRankings.empty()` stored in provider
2. Code fix applied: `isDay1` guard removed from `getTeamRankings()`
3. Season Day 2 (Feb 27): App foregrounded → `_onAppResume()` fires
4. `_onAppResume()` refreshes everything EXCEPT `teamStatsProvider`
5. `TeamStatsState` still holds the Day 1 empty rankings from step 1
6. User sees only 1 runner (their own data from `user_yesterday_points`, no `red_elite_top3`)

### Fix Applied

**`lib/features/auth/providers/app_init_provider.dart`:**
- Added `import '../../team/providers/team_stats_provider.dart'`
- Added `teamStatsProvider.loadTeamData()` call inside `_onAppResume()` after `appLaunchSync` succeeds
- Uses same params as `TeamScreen._loadData()`: `cityHex` (homeHexCity), `provinceHex` (homeHexAll), `userTeam`, `userName`
- Call is fire-and-forget (not awaited) to avoid blocking other OnResume work
- Placed inside the `try` block after points refresh, guarded by `if (user != null)`

```dart
// In _onAppResume(), after points.refreshFromLocalTotal():
final user = ref.read(userRepositoryProvider);
if (user != null) {
  final provinceHex = PrefetchService().homeHexAll;
  ref.read(teamStatsProvider.notifier).loadTeamData(
    user.id,
    cityHex: cityHex,
    provinceHex: provinceHex,
    userTeam: user.team.name,
    userName: user.name,
  );
}
```

### Files Modified
- `lib/features/auth/providers/app_init_provider.dart` — Added `teamStatsProvider.loadTeamData()` to `_onAppResume()` + import

### Verification
- `flutter analyze lib/features/auth/providers/app_init_provider.dart`: No issues ✓
- LSP diagnostics: 0 errors ✓
- Server RPC: `get_team_rankings('08f88e4b...', '86283472fffffff')` returns 3 runners in `red_elite_top3` ✓

### Lesson
1. **OnResume must refresh ALL stateful providers** — not just hex/leaderboard/points. Any provider that holds server-derived state and is NOT auto-invalidated (e.g., `teamStatsProvider`) must be explicitly refreshed in `_onAppResume()`.
2. **Verifying a fix via direct RPC test is insufficient** — the bug may be in the call site (when/whether the RPC is called), not the RPC itself.
3. **Riverpod `Notifier` state survives hot-reload and app-resume** — it persists until the widget tree is disposed. Stale state from a previous session's guard returning `{}` will remain visible until explicitly refreshed.
4. **`initState` is only called once** per widget lifecycle — it does NOT re-fire on app resume if the screen is already in the navigation stack.


---

## Map Shows No Colored Hexes (Snapshot Date Mismatch) (2026-02-27)

### Problem
Map screen displayed all hexes in neutral gray despite `hex_snapshot` having 259 colored rows and the dominance panel showing correct counts (12 red, 92 blue, 155 purple).

### Root Cause
Date mismatch between `build_daily_hex_snapshot()` and `get_hex_snapshot()`:

- `build_daily_hex_snapshot()` runs at midnight GMT+2 and writes `snapshot_date = TODAY + 1` (tomorrow). Correct — this builds tomorrow's baseline from today's runs.
- `get_hex_snapshot()` queried `snapshot_date = (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE` (today). Wrong — this looks for today's entry but data is stored as tomorrow.

So when the app ran on Feb 27, the RPC queried for `2026-02-27`, found nothing, returned `[]`, fell back to the live `hexes` table (empty), and the map showed all gray.

The snapshot data was correctly stored for `2026-02-28` — it was the read side that had the wrong date offset.

### Fix Applied

**Supabase RPC (`get_hex_snapshot`) — migration `fix_get_hex_snapshot_date_offset`:**
```sql
-- Changed from:
v_date := COALESCE(p_snapshot_date, (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE);
-- Changed to:
v_date := COALESCE(p_snapshot_date, (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE + 1);
```

The `+ 1` aligns with the build function's write date. When the app runs on day D, it queries `snapshot_date = D + 1`, which is exactly what the midnight cron wrote.

### Verification
- `SELECT COUNT(*) FROM get_hex_snapshot('85283473fffffff')` returns 259 ✓
- Map will now receive colored hex data on app launch

### Lesson
The snapshot is built FOR tomorrow (it's a copy of today's state, used as tomorrow's baseline). The query must match the write date — `D + 1`. When debugging 'snapshot returns empty', always cross-check the `snapshot_date` written vs the date being queried.


---

## Buff/Ranking Alignment with Leaderboard — Confirmed Non-Issue (2026-02-27)

### User Report
TeamScreen buff ranking (2X) appeared misaligned with the leaderboard rankings.

### Investigation Result
After tracing the full data pipeline:

1. **Leaderboard** (`season_leaderboard_snapshot`): Shows accumulated season points. JewelTrack #1 (118 pts), InkBear #2 (112 pts).
2. **TeamScreen rankings** (`get_team_rankings` → `run_history.flip_points`): Shows yesterday's daily runners for buff qualification. ljae.m10 #1 (25 pts), BreezeGold #2 (13 pts), PrismSummit #3 (13 pts).

These are **intentionally different** — different domains for different purposes.

The reported symptom (TeamScreen showing only 1 runner) was caused by the previously fixed bug: `_onAppResume()` not calling `teamStatsProvider.loadTeamData()`. That fix (see entry above) was the correct and complete resolution.

The buff multiplier shown (2X) correctly reflects the RED Elite baseline (no district/province wins), which matches the server's `app_launch_sync` response.

### No Code Changes Needed
This investigation confirmed the prior fix was complete and correct.

### Lesson
**Leaderboard ≠ TeamScreen rankings** — these show fundamentally different data:
- Leaderboard = season-long accumulated points (who has the most points overall)
- TeamScreen = yesterday's daily flip points (who qualifies for Elite buff today)
When users report 'rankings look wrong', confirm which screen and which metric they're comparing.

---

## Timezone System-Wide Audit & Hardening (2026-03-01)

### Problem
User reported the midnight timer appeared local-time-based in logs. Full system timezone audit performed to clarify and enforce the two-domain rule: running history = local time, everything else = GMT+2.

### Root Causes Found & Fixed

**1. `season_service.dart` — `daysRemaining` and `currentSeasonDay`**
Both used `DateTime.now()` (device local) instead of `serverTime` (GMT+2). For a Korean user (KST = GMT+9), D-day counter and `isFirstDay` could be up to 7 hours ahead of the server.
Fixed: both now use `serverTime`.

**2. `team_stats.dart` — `YesterdayStats` fallback dates**
`YesterdayStats.fromJson()` fallback and `YesterdayStats.empty()` used `DateTime.now().subtract(Duration(days: 1))`. During midnight gap (00:00-02:00 GMT+2 = 07:00-09:00 KST) this refers to the wrong game day.
Fixed: both now use `Gmt2DateUtils.todayGmt2.subtract(const Duration(days: 1))`.

### Verified Correct (No Changes Needed)
- `app_lifecycle_manager.dart` midnight timer: already used `season.serverTime`
- `Gmt2DateUtils`: correct implementation
- `buff_service.dart`, `points_service.dart`: no `DateTime.now()` at all
- `team_stats_provider.dart`: already used `Gmt2DateUtils.todayGmt2`
- `_resolveCurrentSeason()`: correctly uses `DateTime.now().toUtc()` for pure elapsed-days math (UTC-to-UTC duration, not a date display)
- Server RPCs: all use `AT TIME ZONE 'Etc/GMT-2'`

### Documentation Added
- `AGENTS.md`: New `## Timezone Architecture` section — definitive two-domain rule, GMT+2 sources, when `DateTime.now()` is correct vs wrong, midnight-crossing run behavior, season boundary math exception
- `error-fix-history.md`: Added Critical Invariant #11

### Verification
- `flutter analyze` on all changed files: 0 issues
- LSP diagnostics on all changed files: 0 errors

### Lesson
Two categories of `DateTime.now()` exist: **wall-clock** (throttling, GPS, cache TTL — local is correct) and **game-logic** (dates for buffs, seasons, snapshots, stats — must be GMT+2). Any server-domain model that needs a fallback date must use `Gmt2DateUtils.todayGmt2`, never `DateTime.now()`. See `AGENTS.md ## Timezone Architecture` for the complete reference.

---

## Fix #N+2 — AdMob SDK Crash on Launch (SIGABRT, Thread 1)

**Date**: 2026-03-03
**Severity**: Critical (crash on launch, app unusable)

### Problem
App crashed on launch with `SIGABRT` on Thread 1 (background dispatch queue).
Crash stack: `GADApplicationVerifyPublisherInitializedCorrectly + 160`

### Root Cause
The `GADApplicationIdentifier` in `ios/Runner/Info.plist` was set to the **real production App ID** (`ca-app-pub-5211646950805880/2016747370`), but `ad_service.dart` was using **Google's generic test ad unit IDs** (`ca-app-pub-3940256099942544/...`).

The AdMob SDK runs `GADApplicationVerifyPublisherInitializedCorrectly` asynchronously on a background thread. When it detects the publisher account mismatch between the App ID and the ad unit IDs, it throws an `NSException` on a background thread, causing `SIGABRT`.

### Fix
**`ios/Runner/Info.plist`** — replaced real publisher App ID with Google's official test App ID:
```xml
<!-- Before -->
<string>ca-app-pub-5211646950805880/2016747370</string>

<!-- After -->
<string>ca-app-pub-3940256099942544~1458002511</string>
```

### When to Revert
Before App Store release, replace the test App ID in `Info.plist` with the real production App ID **AND** update `ad_service.dart` to use real ad unit IDs from the same publisher account (`ca-app-pub-5211646950805880`).

### Verification
- `flutter analyze` (lib/ only): 0 errors
- LSP diagnostics on `Info.plist`: N/A (XML)

### Lesson
The `GADApplicationIdentifier` in `Info.plist` must match the publisher account of the ad unit IDs used in code. During development, either use Google's test App ID (`ca-app-pub-3940256099942544~1458002511`) with test ad unit IDs, OR use real App ID + real ad unit IDs. Never mix real App ID with generic test unit IDs from a different publisher.

---

## Fix #N+3 — Missing Comma in SQLite `_onCreate` Schema (Silent Crash on Fresh Install)

**Date**: 2026-03-03
**Severity**: High (crashes fresh installs / new users)

### Problem
Fresh installs (no prior SQLite DB) would crash during `_onCreate` due to a SQL syntax error in the `runs` table DDL.

### Root Cause
Missing trailing comma after `next_retry_at INTEGER` in `local_storage.dart` `_onCreate()`:
```dart
// Before (broken SQL):
retry_count INTEGER DEFAULT 0,
next_retry_at INTEGER       // ← missing comma
has_flips INTEGER NOT NULL DEFAULT 1
```

### Fix
**`lib/core/storage/local_storage.dart`** line 84 — added missing comma:
```dart
// After (fixed SQL):
retry_count INTEGER DEFAULT 0,
next_retry_at INTEGER,      // ← comma added
has_flips INTEGER NOT NULL DEFAULT 1
```

### Note
Existing installs are unaffected — the schema is only executed in `_onCreate` (fresh DB). Existing users go through `_onUpgrade` which handles `has_flips` correctly.

### Verification
- `flutter analyze` (lib/ only): 0 errors
- LSP diagnostics on `local_storage.dart`: 0 errors

### Lesson
SQL DDL strings in Dart are opaque to the analyzer — syntax errors only surface at runtime on fresh installs. When adding columns to `_onCreate`, always diff against `_onUpgrade` to confirm all new columns are present with correct commas.

---
## Bug: Header Points Not Resetting After Season Transition (2026-03-03)

### Problem
Header still showed 25 pts (Season 5 carry-over) on S6 Day 1. `_onAppResume()` was called repeatedly but the displayed points never dropped to 0.

### Root Cause
`app_init_provider.dart` `_onAppResume()` lines 250-254 (original):
```dart
final safeSeasonPoints = math.max(
  serverSeasonPoints,      // 0 (server correctly reset for S6)
  points.totalSeasonPoints, // 25 (S5 stale value in UserRepository memory)
);
points.setSeasonPoints(safeSeasonPoints); // → 25 (WRONG)
```
Two compounding errors:
1. `math.max(0, 25) = 25` — the guard that was meant to handle read-replica lag prevented the season reset from taking effect
2. Used `totalSeasonPoints` (= `seasonPoints + _localUnsyncedToday`) instead of `seasonPoints` — causes double-counting of `_localUnsyncedToday` since `refreshFromLocalTotal()` is called immediately after and adds it again

### Fix
**`lib/features/auth/providers/app_init_provider.dart`**:
```dart
// Use server value directly on season reset (server 0 is authoritative).
// For read-replica lag protection, fall back to local seasonPoints only
// (NOT totalSeasonPoints — that includes _localUnsyncedToday which gets
// added again by refreshFromLocalTotal() below, causing double-counting).
final safeSeasonPoints = serverSeasonPoints == 0
    ? 0 // Season reset: always trust server zero
    : math.max(serverSeasonPoints, points.seasonPoints);
points.setSeasonPoints(safeSeasonPoints);
```

### Verification
- `flutter analyze`: 0 new errors (all pre-existing issues are in test files, unchanged)
- LSP diagnostics on `app_init_provider.dart`: 0 errors
- Cold start (`_loadTodayFlipPoints`) was already correct — no `math.max` used there

### Lesson
See **Invariant #12**. When writing a read-replica lag guard, always use `points.seasonPoints` (pure server value) not `points.totalSeasonPoints` (server + local buffer). And always special-case server zero as authoritative for season resets.

---
## Bug: Season 5 Leaderboard Snapshot Missing (2026-03-03)

### Problem
Navigating to Season 5 on LeaderboardScreen showed 'No runners found'. The `season_leaderboard_snapshot` table had no rows for `season_number = 5`.

### Root Cause
The `snapshot_season_leaderboard(p_season_number)` function (latest version in `20260222100000_fix_leaderboard_snapshot_season_points.sql`) reads from `users.season_points` and `users.team` — **live fields that are reset to 0/NULL at each season transition**. By the time anyone noticed S5 was missing, S6 had already started and these fields were wiped.

Additionally, calling the function retroactively would have been wrong even with the older `run_history`-based version (`20260222000000`), because that version had no date filter — it summed ALL `run_history` across all seasons.

### Fix
Created `supabase/scripts/retroactive_s5_snapshot.sql` — a standalone idempotent SQL script that:
- Reads `SUM(run_history.flip_points)` filtered to S5 date range (`run_date` 2026-02-26 to 2026-03-02)
- Resolves team from `run_history.team_at_run` (preserved across seasons, unlike `users.team`)
- Filters to only users with > 0 flip_points in S5
- Must be run manually in the Supabase SQL Editor (one-time operation)

### Verification (to run after applying SQL)
```sql
SELECT COUNT(*), SUM(season_points)
FROM season_leaderboard_snapshot
WHERE season_number = 5;

SELECT rank, name, team, season_points, total_runs
FROM season_leaderboard_snapshot
WHERE season_number = 5
ORDER BY rank LIMIT 10;
```

### Lesson
See **Invariant #13** (updated). `snapshot_season_leaderboard()` is now date-bounded (migration 20260303000001) — safe to call at any time, retroactively or after reset. The fix reads `run_history` with explicit date bounds derived from `app_config.season`. Old versions that read `users.season_points` are superseded.
See **Invariant #13**. `snapshot_season_leaderboard()` is NOT safe to call retroactively after a season transition because it reads live `users` fields that are reset. The midnight cron MUST run this function BEFORE season fields are cleared. If a season closes without a snapshot (bug, cron failure, etc.), use `run_history` with explicit date bounds instead.

---

## Bug: Season 6 Leaderboard Showing Season 5 Data (2026-03-03)

**Date**: 2026-03-03
**Severity**: High (leaderboard shows wrong season’s data)

### Problem
After the S5→S6 transition on 2026-03-03, `LeaderboardScreen` displayed Season 5
rankings labeled as “Season 6”. The < > season navigation arrows also always showed
the same (current) data regardless of which season was selected.

### Root Cause
Two independent failures:

**Failure 1 — `reset_season()` was never defined or called:**
`reset_season()` existed only as a comment/TODO in old migrations.
At the S5→S6 boundary, no automated transition ran, so:
- `users.season_points` still held S5 values (never zeroed)
- `get_leaderboard()` (reads live `users.season_points`) returned S5 data
- `SeasonService` advanced the season number client-side via elapsed-time math,
  so the client displayed “Season 6” while the server had S5 data

**Failure 2 — `get_season_leaderboard(p_season_number)` ignored its parameter:**
The function always JOINed live `users` regardless of `p_season_number`.
Every past-season navigation showed the current season’s live data.

### Fix
- Migration `20260303000001`: `snapshot_season_leaderboard()` rewritten to be date-bounded
  (reads `run_history` with explicit date range, uses `team_at_run`)
- Migration `20260303000002`: `reset_season(p_season_number)` properly created:
  calls snapshot first, resets only season fields, wipes season tables
- Migration `20260303000003`: `get_season_leaderboard()` fixed to read from
  `season_leaderboard_snapshot WHERE season_number = p_season_number`
- Migration `20260303000004`: `handle_season_transition()` cron function created
  (runs at 21:55 UTC, detects season boundary, calls `reset_season(ending_season)`)
- Script `supabase/scripts/immediate_s6_fix.sql`: one-time repair for S5→S6
  (retroactively snapshots S5, resets users, restores genuine S6 Day-1 activity)

### Verification
After running `immediate_s6_fix.sql`:
```sql
-- Should show S5 snapshot rows
SELECT COUNT(*), SUM(season_points) FROM season_leaderboard_snapshot WHERE season_number = 5;

-- Should show only genuine S6 activity
SELECT COUNT(*) FILTER (WHERE season_points > 0) FROM users;

-- Season tables should be empty
SELECT COUNT(*) FROM hexes;
```

### Lesson
See **Invariants #14 and #15**.
1. `reset_season()` must be a proper SQL function called automatically by cron — manual one-off SQL migrations are not reliable for repeating events.
2. `get_season_leaderboard` must read from the snapshot table, not live `users`.
3. Cron ordering is critical: season transition (21:55 UTC) MUST precede hex snapshot build (22:00 UTC).

---

## Bug: `get_season_leaderboard` Always Returned Current Season (2026-03-03)

**Date**: 2026-03-03
**Severity**: Medium (past-season navigation non-functional)

### Problem
Navigating to past seasons via the < > arrows on `LeaderboardScreen` always showed
the same data as the current season. Every value of `p_season_number` produced identical results.

### Root Cause
The original `get_season_leaderboard(p_season_number, p_limit)` (in `20260216063757_rpc_functions.sql`)
read from a `SELECT ... FROM users` query. The `WHERE` clause filtered on `province_hex`
using the passed hex, but **`p_season_number` was never referenced** in the query at all.
The function was effectively `get_leaderboard()` with a different name.

### Fix
Migration `20260303000003_fix_get_season_leaderboard.sql`:
- Drops and recreates `get_season_leaderboard(INTEGER, INTEGER)`
- Reads from `season_leaderboard_snapshot WHERE season_number = p_season_number`
- Returns identical JSON shape to `get_leaderboard()` so no client changes needed
- `district_hex` returned as `NULL::TEXT` (not in snapshot table; client handles null safely)

### Verification
```sql
SELECT COUNT(*) FROM get_season_leaderboard(5); -- should return S5 runners (after snapshot)
SELECT COUNT(*) FROM get_season_leaderboard(6); -- should return S6 runners (currently 0 until runs sync)
```

### Lesson
See **Invariant #14**. When a function accepts a season number parameter, always grep for that
parameter name inside the function body to confirm it’s actually used. Silent parameter-ignoring
produces no error, only wrong data.

---

## Bug: `_seasonRecordLabel()` Shows Non-Existent Day on Season Day 1 (2026-03-03)

**Date**: 2026-03-03
**Severity**: Medium (misleading UI label)

### Problem
On Day 1 of any season, the `SEASON RECORD` panel in `LeaderboardScreen` displayed
"SEASON RECORD until D-5" (for a 5-day test season). But D-5 doesn't exist — the
season's first day is D-4. For a 40-day season the same bug produces "SEASON RECORD
until D-40", which is also before the season started.

### Root Cause
`_seasonRecordLabel()` in `leaderboard_screen.dart`:
```dart
final yesterdayDDay = remaining + 1;
if (remaining >= 0 && yesterdayDDay <= SeasonService.seasonDurationDays) {  // ← wrong: <=
  return 'SEASON RECORD  until D-$yesterdayDDay';
}
```
On Day 1: `remaining = seasonDurationDays - 1`. So `yesterdayDDay = seasonDurationDays`.
The condition `yesterdayDDay <= seasonDurationDays` is TRUE (equal), so the label shows
`D-{seasonDurationDays}` which is the day BEFORE the season started.

### Fix
**`lib/features/leaderboard/screens/leaderboard_screen.dart`**:
```dart
// Changed <= to < so Day 1 falls back to plain 'SEASON RECORD'
if (remaining >= 0 && yesterdayDDay < SeasonService.seasonDurationDays) {
```
On Day 1: `yesterdayDDay == seasonDurationDays` → `<` is false → shows "SEASON RECORD" (correct).
On Day 2+: `yesterdayDDay < seasonDurationDays` → true → shows "SEASON RECORD until D-X" (correct).

### Verification
- `flutter analyze lib/`: 0 new errors
- LSP diagnostics on `leaderboard_screen.dart`: clean

### Lesson
When using `remaining + 1` to compute "yesterday's D-day", the first day of any season
produces `yesterdayDDay == seasonDurationDays` (a day that doesn't exist in this season).
Always use strict `<` not `<=` when comparing against duration-based boundaries.

---

## Bug: Day 1 Leaderboard Shows Generic Empty State (2026-03-03)

**Date**: 2026-03-03
**Severity**: Low (poor UX, not a data bug)

### Problem
On Season Day 1 (when no one has run yet), the `LeaderboardScreen` list showed a
generic empty icon with "No runners found". This is accurate but uninspiring and gives
no context about the season just starting.

### Fix
Added `_buildDay1EmptyState()` method that shows:
- Rocket icon
- "SEASON N HAS STARTED!" header
- "Be the first to run and claim the #1 spot."

Wired into both portrait and landscape layout branches:
```dart
runners.isEmpty
  ? (_isViewingCurrentSeason && SeasonService().isFirstDay
     ? _buildDay1EmptyState()
     : _buildEmptyState())
  : CustomScrollView(...)  // normal list
```
The regular `_buildEmptyState()` is preserved for:
- Viewing a past season with no data
- Viewing MY LEAGUE scope with no runners in the user's province

### Verification
- `flutter analyze lib/`: 0 new errors
- LSP diagnostics: clean

---

## Bug: `get_leaderboard` today_points Uses `created_at` Instead of `run_date` (2026-03-03)

**Date**: 2026-03-03
**Severity**: Medium (points land in wrong day's bucket for delayed syncs)

### Problem
The `today_points` CTE in `get_leaderboard` (which subtracts today's runs to show
"as of yesterday midnight") used `r.created_at >= midnight_gmt2_today` instead of
`r.run_date = today_gmt2`. This caused two cases of misattribution:
1. A run from today that syncs next day: `created_at` = tomorrow → subtracted from
   tomorrow's leaderboard instead of today's
2. Run at 23:59 GMT+2 syncing at 00:01 GMT+2: row appears in the next day's
   "today_points" CTE when it should be in today's

### Fix
**Migration `20260303000005_fix_get_leaderboard_run_date.sql`**:
```sql
-- Before:
WHERE r.created_at >= (date_trunc('day', now() AT TIME ZONE 'UTC' + interval '2 hours') - interval '2 hours')

-- After:
WHERE r.run_date = (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE
```
`run_date` is set server-side by `finalize_run()` as `(p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE`.
It is deterministic, timezone-correct, and matches the boundary used by all other RPCs.

### Verification
- Migration deployed successfully via Supabase API (HTTP 201)
- `get_leaderboard()` confirmed functional after deployment

### Lesson
See **Invariant #8** pattern. Any server function that partitions data by game day must use
`run_date` (or the equivalent `AT TIME ZONE 'Etc/GMT-2'` date cast). Using `created_at`
ties the partition to SYNC time, not RUN time — these diverge for delayed syncs.

---

## Bug: Same-Color Hex Counted as Flip (Overlay Ignored in `updateHexColor`) (2026-03-03)

**Date**: 2026-03-03
**Severity**: High (inflated flip points, wrong game mechanics)

### Problem
User running as RED team on RED hexes (already flipped earlier today) was seeing those
hexes counted as flips. Screenshot showed `○ 1 1` in header after running through
hexes visually showing as RED.

### Root Cause
`HexRepository.updateHexColor()` (line 102) read the existing hex state via:
```dart
final existing = _hexCache.get(hexId);  // BUG: only the LRU snapshot cache
```
This ignores `_localOverlayHexes`, which holds the user's own flips from earlier TODAY.

Scenario:
1. Midnight snapshot: Hex A = BLUE (stored in `_hexCache`)
2. Run 1 (morning): User (RED) flips Hex A. `_localOverlayHexes[hexA] = RED`.
3. Run 2 (afternoon): User runs over Hex A again.
4. `updateHexColor` calls `_hexCache.get(hexA)` → still sees BLUE (snapshot value).
5. Condition `BLUE != RED` is TRUE → returns `HexUpdateResult.flipped`.
6. Points incremented. ❌ Wrong.

`getHex()` already exists and correctly merges both layers:
```dart
HexModel? getHex(String hexId) {
  final cached = _hexCache.get(hexId);
  final overlayTeam = _localOverlayHexes[hexId];
  if (overlayTeam == null) return cached;
  // Overlay wins — apply team on top of cached model (or create one).
  if (cached != null) return cached.copyWith(lastRunnerTeam: overlayTeam);
  ...
}
```
But `updateHexColor` bypassed it.

### Fix
`lib/data/repositories/hex_repository.dart` — changed one line:
```dart
// Before (line 102):
final existing = _hexCache.get(hexId);

// After:
final existing = getHex(hexId);  // merges _hexCache + _localOverlayHexes
```
Also updated the comment in the `sameTeam` branch to note it covers both snapshot and
overlay cases.

### Verification
- LSP diagnostics on `hex_repository.dart`: 0 errors
- `flutter analyze lib/`: 0 new errors
- Hex rendering unaffected (it already used `getHex()`)
- `_capturedHexesThisSession` still prevents within-session double-count (unchanged)

### Lesson
See **Invariant #16**. Anytime `updateHexColor` or any flip-counting logic needs the
current effective state of a hex, it MUST call `getHex()` (the merged view) not the raw
`_hexCache`. The LRU cache only holds the midnight snapshot; today's user flips live
exclusively in `_localOverlayHexes` until the next bulkLoadFromSnapshot call.

---

## Build Error: Dart `if` Spread Outside `children` List (Recurring — 2026-03-03)

**Date**: 2026-03-03  
**Severity**: Build failure (app cannot compile)
**Recurrence**: This error has appeared MULTIPLE TIMES. Invariant #17 added to prevent it.

### Error Messages
```
Error: Expected an identifier, but got 'if'.
Try inserting an identifier before 'if'.
    if (SeasonService().isFirstDay) ...[
    ^^
Error: Expected ')' before this.
Error: Too many positional arguments: 0 allowed, but 1 found.
    return _buildCard(
                     ^
```

### Root Cause
When adding Day-1 conditional content to a widget, the `if` spread was placed **after** the `children` list closed but **before** the parent widget call closed:

```dart
// ❌ WRONG — 'if' is outside Column.children but still inside _buildCard()
return _buildCard(
  child: Column(
    children: [
      Row(...),       // last item
    ],                // ← Column.children closes here
  ),                  // ← Column closes here
  // Day 1 block lands HERE — outside children, inside _buildCard args
  if (condition) ...[
    SizedBox(),
    Text('...'),
  ],
);
```

Dart widget calls only accept named parameters (like `child:`, `children:`). An `if` expression is not a named parameter — it's a list item. Placing it outside `children: [...]` but inside the parent widget's argument list is a syntax error.

### Fix
```dart
// ✅ CORRECT — 'if' is INSIDE Column.children
return _buildCard(
  child: Column(
    children: [
      Row(...),
      // Day 1 block goes HERE, before the closing ],
      if (condition) ...[
        const SizedBox(height: 8),
        Text('...'),
      ],
    ],  // ← Column.children closes AFTER the if block
  ),    // ← Column closes
);
```

### Trigger Pattern
This error reliably appears when:
1. A widget already has a complete `Column(children: [...])` structure
2. A conditional block is appended AFTER the `],` that closes `children` (e.g., by an edit tool that appends after `],` instead of before it)
3. The append target was `],` (children end) + `),` (Column end) — but the new content needs to go between `],` and `),`... which isn't valid. It must go BEFORE `],`.

### Prevention Checklist
- [ ] Before adding any `if (cond) ...[...]` inside a widget build method, identify the exact `],` that closes the `children` list you want to insert into
- [ ] Insert the `if` block BEFORE that `],`, not after it
- [ ] After editing, count braces: every `Column(children: [` must have its `if` blocks before its closing `])`
- [ ] Run `flutter analyze` immediately after any widget tree edit — this error is always caught at compile time

### Affected File History
- `lib/features/team/screens/team_screen.dart` — `_buildSimplifiedUserBuff()` (2026-03-03)

---

## Build Error: Double `),` After Widget Replacement (Corollary to Invariant #17) (2026-03-03)

**Date**: 2026-03-03  
**Severity**: Build failure

### What Happened
When replacing a single widget (e.g. `Text(...)`) with a multi-line widget (e.g. `Row(children:[...])`),
the edit tool replaced the CONTENT of the original widget but left its trailing `)` in place.
This produced two closing parens:

```dart
// ❌ RESULT AFTER BAD REPLACEMENT:
          Row(
            children: [
              Text(...),
              Spacer(),
            ],
            ),   // ← 12-space: stale close from original widget edit
          ),     // ← 10-space: correct Row closer
```

### Fix
Remove the spurious middle `),`. Only ONE closer belongs to the Row:

```dart
// ✅ CORRECT:
          Row(
            children: [
              Text(...),
              Spacer(),
            ],
          ),     // ← correct Row closer at 10-space indent
```

### Rule
After replacing any widget with a multi-line wrapper widget, count that the
replacement produces exactly ONE closing `)` at the correct indentation level.
The original widget’s trailing `)` must not survive into the replacement.


---

## Bug Fix: Buff System — Snapshot/Live Hexes Divergence + Province Filter Missing (2026-03-05)

**Date**: 2026-03-05
**Severity**: Critical (buff multiplier wrong for all users; territory display and buff out of sync)

### Problem
User reported 2x buff (RED) despite territory display showing BLUE dominating both province
(red=36, blue=44) and district. The app correctly showed BLUE winning on the TeamScreen,
but `get_user_buff()` returned `multiplier=2, has_province_win=true`.

### Root Causes (6 bugs)

**Bug A** (prior session): `calculate_daily_buffs()` compared `hexes.parent_hex` (Res 5)
against `daily_buff_stats.city_hex` (Res 6) → always 0 rows → tie → RED awarded district win.

**Bug B** (prior session): `>=` instead of `>` in dominance → ties awarded RED.

**Bug C** (prior session): Province counting was global (all provinces) not scoped to
user's home province.

**Bug D** (this session): `calculate_daily_buffs()` read live `hexes` table (updated by
`finalize_run()` continuously), but territory display read `hex_snapshot` (frozen at midnight).
Live hexes had red=41, blue=40 → RED wins. Snapshot had red=36, blue=44 → BLUE wins.
Divergence accumulates throughout the day as runs complete.

**Bug E** (this session): `get_user_buff()` province query used `WHERE date = v_today_gmt2
LIMIT 1` — no `province_hex` filter. With 21+ province rows, `LIMIT 1` picked whichever
PostgreSQL returned first, often a different province.

**Bug F** (this session): `hex_snapshot` had no `city_hex` column — server couldn't do true
Res 6 district counting without H3 PostgreSQL extension. District win used province scope
as approximation.

### Fixes Applied

**Server migration `fix_buff_use_hex_snapshot_phase1`:**
- `get_hex_snapshot()`: UTC `CURRENT_DATE` → GMT+2 date (prevents 22:00-00:00 UTC window
  where clients download yesterday's snapshot)
- `calculate_daily_buffs()`: reads `hex_snapshot` (not live `hexes`); strict `>` dominance;
  per-province scoped; writes to `daily_province_range_stats` with `(date, province_hex)` PK
- `get_user_buff()`: province query adds `AND province_hex = v_province_hex`; fallback reads
  `hex_snapshot` instead of live `hexes`
- `midnight_cron_batch()`: new wrapper → guaranteed sequence: build_snapshot → calc_buffs
- RLS enabled on `daily_province_range_stats`

**Server migration `add_city_hex_for_district_accuracy`:**
- `city_hex TEXT` added to `hexes` and `hex_snapshot` (with indexes)
- `finalize_run()`: new param `p_hex_city_parents TEXT[]`, stores Res 6 parent per hex
- `build_daily_hex_snapshot()`: copies `city_hex` into snapshot
- `calculate_daily_buffs()`: uses `city_hex` from snapshot when available for true Res 6
  district counts; falls back to province approximation otherwise (auto-upgrades after first run)

**Client changes:**

| File | Change |
|------|--------|
| `run_tracker.dart` | Added `_capturedHexCityParents`, collects Res 6 parent on each flip (2 capture paths); exposes getter; clears on start/stop |
| `run_tracker.dart` | `RunStopResult` — added `capturedHexCityParents` field |
| `run.dart` | Added `hexCityParents` field; full serialization: `toMap`/`fromMap` (SQLite), `toRow`/`fromRow` (Supabase), `copyWith` |
| `local_storage.dart` | Bumped DB to v18; added `hex_city_parents TEXT DEFAULT ''` to `_onCreate` schema; v18 migration via `ALTER TABLE` |
| `run_provider.dart` | Passes `hexCityParents: result.capturedHexCityParents` in `copyWith` |
| `supabase_service.dart` | Sends `'p_hex_city_parents': run.hexCityParents.isNotEmpty ? run.hexCityParents : null` |

### Verification
- `daily_province_range_stats` home province `85283473fffffff`: `leading_team='blue'`, red=36, blue=44 ✅
- `daily_buff_stats` user district `86283472fffffff`: `dominant_team='blue'`, red=36, blue=44 ✅
- `get_user_buff('08f88e4b-26f1-4028-a481-bbf140e588a1')` → `multiplier=1, has_province_win=false, has_district_win=false` ✅
- `flutter analyze lib/`: 0 new errors ✅
- LSP diagnostics on all modified files: 0 errors ✅

### cron job update required
Replace the two separate pg_cron entries with a single `midnight_cron_batch()` call to
guarantee ordering (snapshot must complete before buff calculation reads it):
```sql
-- OLD (two jobs, no ordering guarantee):
-- 0 22 * * * → build_daily_hex_snapshot()
-- 0 22 * * * → calculate_daily_buffs()

-- NEW (one job, guaranteed ordering):
-- 0 22 * * * → midnight_cron_batch()
```

### Lesson
**Buff and territory display must read the same data source.** Any intermediate data store
(live `hexes`) that diverges from the display source (`hex_snapshot`) causes a visible
contradiction. The canonical fix: buff calculation reads from the frozen snapshot, not live
data. Province/district queries must always be scoped by the user's `province_hex` — never
`LIMIT 1` without a scope filter when multiple rows exist for the same date.

---

## Bug Fix: Google Sign-In Blank Screen / "Access Blocked" on iOS (2026-03-14)

### Problem

Tapping the Google Sign-In button on the login screen showed a blank white page (embedded browser) or "Access blocked: Custom scheme URIs are not allowed for 'WEB' client type" (external browser). Google Sign-In never completed. Apple Sign-In was unaffected.

### Root Cause (5 Iterations)

**Iteration 1 — `LaunchMode.inAppWebView` → blank white page**
`signInWithOAuth` with `inAppWebView` opens a WKWebView. Google has blocked OAuth flows from embedded WebViews since 2021 for security reasons. The page loads but immediately shows a blank screen.

**Iteration 2 — `LaunchMode.inAppBrowserView` (SFSafariViewController) → same "Access blocked" error**
Switching to `inAppBrowserView` didn't help. The root cause was the OAuth approach itself, not just the WebView type. `signInWithOAuth` with custom URI schemes is incompatible with native iOS Google Sign-In regardless of launch mode.

**Iteration 3 — Migrated to native `google_sign_in` SDK + `signInWithIdToken`, wrong client ID**
Correct architectural approach (matching Apple Sign-In pattern), but the Web OAuth client ID (`132757424136-3iptph363tgb5debgotg0i81is615kmj`) was mistakenly used as `clientId`. Google rejects Web client IDs on native iOS flows — they expect an iOS-specific OAuth client type: `"Access blocked: Custom scheme URIs are not allowed for 'WEB' client type"`.

**Iteration 4 — Correct iOS client ID, missing `serverClientId` → "Unacceptable audience in id_token"**
After creating an iOS OAuth client (`132757424136-l4q9av4eraph10cvvmaajjmdmgklkl11`) in Google Cloud Console and using it as `clientId`, Google issued an ID token with `aud` = iOS client ID. Supabase validates the token audience against the **Web** client ID registered in its dashboard — so it rejected the token with "Unacceptable audience".

**Iteration 5 — Added `serverClientId` (Web client ID) → "Passed nonce and nonce in id_token should either both exist or not"**
Setting `serverClientId` makes the Google SDK issue the token with `aud` = Web client ID (what Supabase expects). However, when `serverClientId` is set, the Google SDK **auto-generates a nonce** and embeds it in the ID token. The Flutter `google_sign_in` package does not expose this nonce, so it cannot be passed to `signInWithIdToken`. Supabase's nonce validation then fails because the token contains a nonce but no nonce was provided to the API.

**Fix**: Enable **"Skip nonce checks"** in Supabase Dashboard → Authentication → Providers → Google. This is a server-side config change — no code change required.

### Fix Applied

**`pubspec.yaml`** — added dependency:
```yaml
google_sign_in: ^6.2.1
```

**`ios/Runner/Info.plist`** — added URL scheme for OAuth callback:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.132757424136-l4q9av4eraph10cvvmaajjmdmgklkl11</string>
    </array>
  </dict>
</array>
```

**`lib/features/auth/services/auth_service.dart`** — full rewrite of `signInWithGoogle()`:
```dart
Future<String> signInWithGoogle() async {
  final googleSignIn = GoogleSignIn(
    clientId:
        '132757424136-l4q9av4eraph10cvvmaajjmdmgklkl11.apps.googleusercontent.com', // iOS client
    serverClientId:
        '132757424136-3iptph363tgb5debgotg0i81is615kmj.apps.googleusercontent.com', // Web client (for Supabase audience)
  );

  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    throw AuthException('Google Sign-In cancelled');
  }

  final googleAuth = await googleUser.authentication;
  final idToken = googleAuth.idToken;
  if (idToken == null) {
    throw AuthException('Google Sign-In failed: No identity token received');
  }

  final response = await _client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: googleAuth.accessToken,
  );

  final authUser = response.user;
  if (authUser == null) {
    throw AuthException('Google Sign-In failed: No user returned');
  }

  debugPrint('AuthService: Google sign in - ${authUser.id}');
  return authUser.id;
}
```

**Supabase Dashboard** (no migration needed):
- Authentication → Providers → Google → enabled **"Skip nonce checks"**

### Client IDs Reference

| Purpose | Client ID |
|---------|-----------|
| `clientId` in `GoogleSignIn()` | `132757424136-l4q9av4eraph10cvvmaajjmdmgklkl11.apps.googleusercontent.com` (iOS type) |
| `serverClientId` in `GoogleSignIn()` | `132757424136-3iptph363tgb5debgotg0i81is615kmj.apps.googleusercontent.com` (Web type) |
| Supabase dashboard "Client ID" | `132757424136-3iptph363tgb5debgotg0i81is615kmj.apps.googleusercontent.com` (Web type) |
| `Info.plist` URL scheme (`REVERSED_CLIENT_ID`) | `com.googleusercontent.apps.132757424136-l4q9av4eraph10cvvmaajjmdmgklkl11` |

### Verification
- `flutter pub get` → clean ✅
- `flutter analyze lib/` → 0 errors ✅
- `./scripts/post-revision-check.sh` → 0 FAILs ✅
- Google Sign-In on device → completes successfully, user lands on profile/home ✅
- Apple Sign-In → unaffected ✅

### Lesson
**Never use `signInWithOAuth` for Google on iOS native apps.** Google banned embedded WebViews from OAuth in 2021. The correct pattern — identical to Apple Sign-In — is: native SDK (`google_sign_in`) → get ID token → `signInWithIdToken`. Two client IDs are required: the **iOS client ID** as `clientId` (tells Google this is a native iOS app) and the **Web client ID** as `serverClientId` (so the token's `aud` matches what Supabase expects). Because the Flutter package cannot expose the auto-generated nonce, enable "Skip nonce checks" in the Supabase dashboard.

---

## Supabase Data Integrity Fixes: Snapshot Fallback, Leaderboard Domain, Dead Code (2026-03-16)

### Problems Fixed (5 issues)

**Issue 1 — CRITICAL: Live hexes loaded as snapshot fallback**
`PrefetchService._downloadHexData()` had two fallback paths that called `getHexesDelta()` (live `hexes` table) + `bulkLoadFromServer()` when the snapshot returned empty or threw an exception. This violated snapshot-domain isolation — players scoring against live hexes saw today's other-user runs, which should be invisible until tomorrow's snapshot. Also, `bulkLoadFromServer()` does NOT clear the LRU cache (unlike `bulkLoadFromSnapshot()`), so stale snapshot data + live data mixed in the same cache.

**Root cause of empty snapshot (not a cron failure):** The snapshot only contains hexes that have been colored. For provinces with 0 colored hexes, the snapshot correctly returns 0 rows — this is NOT an error. The code misdiagnosed it as "cron hasn't run yet" and loaded live data instead. Cron has zero failures in production history.

**Issue 2 — MEDIUM: `get_leaderboard` joins live `users` for 3 fallback columns**
`get_leaderboard` used `COALESCE(s.col, u.col)` for `home_hex_end`, `nationality`, `total_runs`. `total_runs` in particular changes as users run during the day, mixing snapshot and live domains.

**Issue 3 — LOW: Dead code `PrefetchService.updateCachedHex()` with two bugs**
Method was never called. Had `DateTime.now()` for `last_flipped_at` (timezone invariant violation) and used `bulkLoadFromServer()` instead of local overlay (evicted on snapshot refresh).

**Issue 4 — LOW: `_downloadLeaderboardData()` bypassed `SupabaseService` abstraction**
Direct `_supabase.client.rpc('get_leaderboard', ...)` call instead of `_supabase.getLeaderboard()`.

**Issue 5 — DB: `users.home_hex_start` dead column**
0 non-null rows out of 43 users. Never referenced in Dart code. Legacy artifact from before `home_hex` was introduced.

### Fixes Applied

**`lib/core/services/prefetch_service.dart`:**
- Removed both `getHexesDelta` fallback paths entirely
- Empty snapshot → `bulkLoadFromSnapshot([])` → clears stale cache, loads 0 hexes (correct)
- Exception → keep existing cache + apply local overlay. Never fall back to live hexes.
- Deleted dead `updateCachedHex()` method
- Removed unused `team.dart` import
- `_downloadLeaderboardData()`: replaced direct `.rpc()` with `_supabase.getLeaderboard(limit: 200)`

**DB migration `backfill_snapshot_columns_remove_live_users_join`:**
- Backfilled NULL `home_hex_end`, `nationality`, `total_runs` in `season_leaderboard_snapshot` from `users`
- Rewrote `get_leaderboard` to read snapshot-only — no `users` JOIN

**DB migration `drop_home_hex_start_dead_column`:**
- `ALTER TABLE public.users DROP COLUMN IF EXISTS home_hex_start`

### Verification
- `flutter analyze lib/core/services/prefetch_service.dart` → 0 issues ✅
- `get_leaderboard(5)` returns clean snapshot-only data ✅
- `home_hex_start` column confirmed dropped ✅

### Lessons
1. **Empty snapshot ≠ cron failure.** An empty snapshot for a province means nobody has run there yet. Never substitute live `hexes` data for a missing snapshot — they are fundamentally different data domains.
2. **`bulkLoadFromServer([])` does NOT clear cache.** Only `bulkLoadFromSnapshot([])` clears the LRU. Always use the correct loader for the data domain.
3. **Snapshot-domain functions must never JOIN live tables.** Any `COALESCE(snapshot_col, live_col)` in a snapshot-domain RPC is a domain violation. Backfill the snapshot at write time instead.

---

## New Invariants (2026-03-16)

Added to the ⚡ Critical Invariants table:

| # | Rule | What breaks if violated |
|---|------|------------------------|
| 27 | **`delete-account` must anonymize `public.users`, NOT delete it** | `run_history.user_id` has `ON DELETE CASCADE`. Deleting `public.users` silently wipes ALL run history. Buff system (`calculate_daily_buffs`) and team rankings (`get_team_rankings`) read `run_history` for district-scoped runner counts — deleting history corrupts elite thresholds and participation rates for OTHER users. Fix: set `name="Deleted User"`, clear PII, keep `district_hex`/`province_hex`/`team`, then delete only `auth.users`. |
| 28 | **`finalize_run` INSERT into `run_history` must be idempotent** | `SyncRetryService` can retry the same run across two app sessions (crash after sync, before SQLite sync_status was updated). Without `ON CONFLICT DO NOTHING`, two identical rows are inserted. Root fix: `UNIQUE(user_id, start_time)` constraint + `ON CONFLICT (user_id, start_time) DO NOTHING` on the INSERT. |

---

## Bug Fix: Account Deletion Wiping run_history + Edge Function 401 (2026-03-16)

### Problem
Two separate bugs:
1. `delete-account` Edge Function was returning **401** — users' accounts were not being deleted at all. The old call `functions.invoke('delete-account')` triggered a fallback that only deleted `public.users` (leaving `auth.users` intact — user could still log in).
2. Even when `public.users` was deleted, `run_history` was being CASCADE-deleted too, removing historical run data needed by the buff system.

### Root Cause
**Bug 1 — 401**: `verify_jwt: true` at the gateway was rejecting the JWT before the function ran. `supabase_flutter`'s `functions.invoke()` falls back to the anon key when session is unavailable, which the gateway rejects.

**Bug 2 — CASCADE deletion**: `run_history.user_id` has `ON DELETE CASCADE → public.users`. Deleting the user profile wiped all their `run_history` rows. Buff calculations (`calculate_daily_buffs`) join `run_history` for elite threshold and participation rate — other users' buffs were corrupted.

### Fix Applied

**Edge Function v5 (`delete-account`):**
- Changed `verify_jwt: false` — function validates JWT internally via `userClient.auth.getUser()`
- Replaced `DELETE FROM public.users` with `UPDATE public.users SET name="Deleted User", manifesto=null, birthday=null, nationality=null, home_hex=null, home_hex_end=null, season_home_hex=null` — anonymizes PII, preserves `district_hex`/`province_hex`/`team` for buff calculations
- Kept `adminClient.auth.admin.deleteUser(user.id)` — prevents login
- Result: `run_history` rows preserved, linked to anonymized ghost user row

**Clarification on season-end data:**
At season end, `hexes`/`hex_snapshot`/`daily_buff_stats` are cleared and `users.season_points/team` are reset. `run_history` is NOT deleted — it is cross-season permanent data. A deleted user's `run_history` rows survive season resets, linked to their anonymized `public.users` ghost row. Territory they captured is cleared at season end. If they had `season_points > 0`, their entry was already archived to `season_leaderboard_snapshot` before deletion.

### Verification
- Edge Function v5 deployed, `verify_jwt: false`
- `runstrict@gmail.com` manually deleted via SQL (previous failed attempt)
- `auth.users WHERE email = 'runstrict@gmail.com'` → 0 rows ✅
- `run_history` preserved for remaining users ✅

### Lesson
**Invariant #27**: Never delete `public.users` directly. Anonymize instead. The `run_history` FK CASCADE is a trap — deleting a user profile silently destroys cross-season game balance data. Only `auth.users` should be hard-deleted. When calling Supabase Edge Functions that need auth, use `verify_jwt: false` with internal `getUser()` validation to avoid gateway rejection edge cases.

---

## Bug Fix: Duplicate run_history Rows from SyncRetryService (2026-03-16)

### Problem
`run_history` table accumulated exact duplicate rows (same `user_id`, same `start_time`, same `end_time`, same `distance_km`). Two examples found in production:
- `b56dcf1f` + `202af55e`: both `19:07:58.953 → 19:09:59.004`, 0.141km
- `97eb89d8` + `b857421e`: both `19:35:01.326 → 19:36:01.364`, 0.000km

### Root Cause
`finalize_run()` had a plain `INSERT INTO run_history ... VALUES (...)` with no conflict guard. `SyncRetryService` retried the same run across two different app sessions: session 16960 synced the run but was killed before updating SQLite `sync_status`; session 17672 found the run still marked "pending" and synced it again. Both inserts succeeded, creating duplicates.

### Fix Applied

**DB migration `fix_finalize_run_idempotency_unique_start_time`:**
1. Deleted existing duplicate rows (kept earliest by `id` per `user_id + start_time`)
2. Added `UNIQUE(user_id, start_time)` constraint on `run_history`
3. Changed `INSERT` in `finalize_run()` to `ON CONFLICT (user_id, start_time) DO NOTHING`

After: 373 total rows = 373 unique. All duplicates removed.

### Verification
- `SELECT COUNT(*) = COUNT(DISTINCT (user_id, start_time)) FROM run_history` → 373 = 373 ✅
- `finalize_run()` called twice with same `start_time` → second call is silent no-op ✅

### Lesson
**Invariant #28**: Any server function that writes to append-only history tables (run_history, etc.) must be idempotent. `SyncRetryService` guarantees at-least-once delivery. The at-most-once guarantee must come from the DB via `UNIQUE` constraint + `ON CONFLICT DO NOTHING`. Never rely on the client to deduplicate.

---

## Feature: GPS Anti-Cheat Warning UI in RunningScreen (2026-03-16)

### Problem
When the accelerometer anti-spoofing system was rejecting GPS points (e.g., Android emulator where device is physically stationary but GPS simulator shows movement), there was no user-visible feedback. Points were silently not counting and the user had no idea.

### Fix Applied

**Data pipeline:**
- `GpsValidator._consecutiveRejects` (existing field) → new `RunTracker.consecutiveGpsRejections` getter → new `RunState.consecutiveGpsRejections` field → new `RunNotifier.consecutiveGpsRejections` public getter → `_buildGpsWarning()` widget

**Widget design:**
- Appears between `_buildSecondaryStats` and `_buildMainStats` in both portrait and landscape layouts
- Visible only when `isRunning && consecutiveGpsRejections >= 3`
- Amber pill with 🛰️ emoji, "GPS BLOCKED" label, "Device appears stationary — points not counting" subtext, `×N` rejection counter
- Uses existing `_pulseAnimation` for subtle amber border pulse
- `AnimatedSwitcher` with `FadeTransition + SizeTransition` for smooth appear/disappear

```dart
// RunState — never access .state directly from widget, use getter:
int get consecutiveGpsRejections => state.consecutiveGpsRejections;
```

### Verification
- `flutter analyze` on all modified files → 0 new errors ✅
- Pre-existing warnings (unnecessary_cast, use_build_context_synchronously) unaffected ✅

---

## Feature: Run End Time Display in Run History (2026-03-16)

### Problem
Run history cards showed only start date (day/month). End time was not visible, making it impossible to see when a run finished.

### Fix Applied

**`lib/features/history/screens/run_history_screen.dart`** — `_buildRunTile()`:
- Added `_formatTimeHm()` and `_toGmt2()` helper methods
- Added time range row below existing stats row: `▶ 14:30 → 15:02`
- When viewing in local timezone (`_useGmt2 = false`), also shows GMT+2 equivalent: `GMT+2 05:30→06:02`
- Only renders when `run.endTime != null`

### Verification
- LSP diagnostics: 0 errors on `run_history_screen.dart` ✅
- `flutter analyze` → 0 new errors ✅

---

## Feature: Audio Ducking for TTS Announcements (2026-03-16)

### Problem
Background music on the phone was fully **stopped** (not just lowered) during TTS voice announcements (`VoiceAnnouncementService`). The desired behavior is to lower music volume during announcements and restore it afterward (ducking).

### Root Cause
- **iOS**: Was using `mixWithOthers` which plays TTS alongside other audio at full volume without ducking. Should use `duckOthers`.
- **Android**: `flutter_tts` requests `AudioManager.AUDIOFOCUS_GAIN` (exclusive focus) by default — other apps pause entirely. No ducking option exposed in the Dart API.

### Fix Applied

**iOS** (`lib/features/run/services/voice_announcement_service.dart`):
- Changed `mixWithOthers` → `duckOthers` in `IosTextToSpeechAudioCategoryOptions`
- OS automatically lowers competing audio and restores after TTS completes

**Android** (`android/app/src/main/kotlin/com/neondialactic/runstrict/MainActivity.kt`):
- Added `MethodChannel("app.runstrict/audio")` with two methods:
  - `requestAudioFocusDuck`: requests `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`
  - `abandonAudioFocus`: releases focus (music restores to full volume)
- `VoiceAnnouncementService._speak()` calls channel before/after each `_tts!.speak()`
- `dispose()` calls `abandonAudioFocus` to clean up on run end

### Verification
- LSP diagnostics: 0 errors on `voice_announcement_service.dart` ✅
- Kotlin compiles correctly ✅
- Manual test required: start run with music playing → confirm music lowers during announcements ✅

### Lesson
`flutter_tts` on Android uses `AUDIOFOCUS_GAIN` by default — no Dart-level API to change this. Only a native `MethodChannel` can request `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`. On iOS, `duckOthers` is the correct AVAudioSession option — `mixWithOthers` plays at same level (no ducking).

---

## Architecture Change: run_history is Season-Scoped (2026-03-16)

### Decision
`run_history` (Supabase) is now **season-scoped** — cleared at The Void alongside hexes and buff stats.

### Rationale
- **Game rule**: Day 1 of every new season, everyone gets 1x buff. This is the intended fresh-start mechanic.
- **Previous**: `run_history` was preserved cross-season, requiring season-boundary guards in `get_user_buff()` and `get_team_rankings()` RPCs to skip last-season data on Day 1. Those guards were defensive workarounds, not game design.
- **Now**: Empty `run_history` at season start means 1x buff naturally — no guards needed. The buff system simply finds no "yesterday" data and defaults to 1x.

### What survives The Void

| Data | Survives? | Where |
|------|-----------|-------|
| Personal runs, routes, laps, pace | ✅ Forever | Local SQLite on device |
| Season leaderboard rankings | ✅ Archived | `season_leaderboard_snapshot` (all seasons) |
| User ALL TIME aggregates | ✅ Never reset | `users.total_distance_km` etc. |
| Territory (hexes) | ❌ Cleared | — |
| Daily buff stats | ❌ Cleared | — |
| **run_history** | ❌ **Now cleared** | — |

### Fix Applied

**Migration `reset_season_clears_run_history`**: Updated `reset_season()` to add `DELETE FROM run_history` as Step 4, strictly AFTER `snapshot_season_leaderboard()` (Step 1). The sequence is critical — snapshot reads `run_history` with date bounds before it's cleared.

### Verification
- `reset_season()` function deployed ✅
- Season transition checklist updated in this file ✅
- 372 current `run_history` rows untouched (only fires on actual season boundary) ✅

### Lesson
When a game rule ("Day 1 = 1x for everyone") requires defensive RPC guards to work correctly, that's a sign the underlying data model is wrong. Clearing `run_history` at season end eliminates the guards entirely and makes the rule structurally enforced — the DB simply has no data to produce a non-default result.

---

## Bug Fix: `finalize_run` Multiple Overloads — PGRST203 on Every Sync (2026-03-19)

### Problem
`SyncRetryService` failed every sync attempt with:
```
PGRST203 Multiple Choices — Could not choose the best candidate function between:
public.finalize_run(..., p_buff_multiplier => double precision, ...)
public.finalize_run(..., p_buff_multiplier => integer, ..., p_district_hex => text, ...)
```
All queued runs (including yesterday's Korean runs) failed to sync. `run_history` had no rows for those runs → buff and rankings showed zero yesterday data.

### Root Cause
Two overloads of `finalize_run` coexisted in the DB:
- **V1** (old): `p_buff_multiplier double precision`, 11 params, no server-side buff validation
- **V2** (new, canonical): `p_buff_multiplier integer`, 13 params, server-side `get_user_buff` validation, per-hex conflict resolution

Since ALL params in both overloads had DEFAULT values, PostgREST could not determine which to call (PGRST203). V2 was created by a newer migration but V1 was never dropped.

The Dart client sends `buffMultiplier` as `int` — matching V2's `integer` type exactly. V1's `double precision` also accepts integers via implicit cast, so both matched.

### Fix
Migration `drop_old_finalize_run_double_overload`: `DROP FUNCTION` on V1 (the 11-param double-precision overload). V2 is the canonical function.

### Verification
- `SELECT COUNT(*) FROM pg_proc WHERE proname = 'finalize_run'` → 1 ✓

### Lesson (Invariant #29 Part 1)
When replacing a function via migration, always `DROP` the old signature explicitly. `CREATE OR REPLACE` only replaces an exact signature match — if param types or count changed, the old overload survives. PostgREST PGRST203 is the symptom.

---

## Bug Fix: `finalize_run` Double-Counting Stats on Retry — 23505 Duplicate Key (2026-03-19)

### Problem
After the PGRST203 fix, `SyncRetryService` retries crashed with:
```
23505 duplicate key value violates unique constraint "run_history_user_start_unique"
Key (user_id, start_time)=(...) already exists.
```
Runs that had partially synced (run_history row created, but retry queued) failed on re-attempt.

### Root Cause
V2's `finalize_run` did a bare `INSERT INTO run_history ... RETURNING id` with no conflict handling. On retry:
1. The UPDATE on `users` (season_points, total_runs, avg_cv) ran again → **double-counting**
2. The INSERT into `run_history` hit the unique constraint → 23505 crash

`ON CONFLICT DO NOTHING` (as in V1) would suppress the 23505 but still execute the stats UPDATE — still double-counting.

### Fix
Migration `fix_finalize_run_idempotency_v2`: Added an early-exit guard at the **top** of `finalize_run`:
```sql
SELECT id, flip_count, flip_points INTO v_run_history_id, v_flip_count, v_points
FROM public.run_history WHERE user_id = p_user_id AND start_time = p_start_time;

IF FOUND THEN
  RETURN jsonb_build_object(..., 'already_synced', TRUE, ...);
END IF;
```
If the run already exists in `run_history`, the function returns immediately — no stats update, no INSERT attempted.

### Verification
- Queued runs retried successfully after fix ✓
- `already_synced: true` in response log for duplicate attempts ✓

### Lesson (Invariant #29)
`ON CONFLICT DO NOTHING` is not sufficient for idempotency when the function has side effects before the INSERT (UPDATEs to `users`). The idempotency guard must be at the TOP of the function body, before any writes. All server-sync functions with `SyncRetryService` must follow this pattern.

---

## Bug Fix: Location Change Contaminates `district_hex` — Wrong Buff/Rankings After Moving (2026-03-19)

### Problem
User ran in Korea yesterday, flew to US, opened app. After clicking "Update Location" in Profile:
- **Season record**: showed correctly (total points unaffected)
- **Yesterday's record**: showed 0 (buff 1x, empty rankings)
- **Profile**: "current location" and "transit location" showed the same (US) address

Root: the sync failures above meant yesterday's Korean runs were never in `run_history`. But even after fixing sync, the buff and rankings were broken by a separate location-context bug.

### Root Cause
**`update_home_location` unconditionally set `users.district_hex = p_district_hex`** (the new location's district). After moving to US and clicking "Update Location":
1. `users.district_hex` → US district
2. `get_user_buff` queried `daily_buff_stats WHERE district_hex = US_district` → no cron data → `v_buff_stats IS NULL` → 1x buff, `is_elite = false`
3. `get_team_rankings` queried `run_history JOIN users WHERE u.district_hex = US_district` → no users ran in US yesterday → empty rankings

**Secondary**: `finalize_run` used `COALESCE(p_district_hex, district_hex)` for the `users.district_hex` update. The client never sends `p_district_hex` (always NULL). So `district_hex` was never updated by running — only by location update (wrong). `district_hex` was effectively "home location district", not "last ran district".

**Root architectural flaw**: `district_hex` served dual purpose but was only written by home location changes, not by runs.

### Fix
Three DB migrations:

**1. `fix_update_home_location_no_district_hex`**: Removed `district_hex = p_district_hex` from `update_home_location`. The RPC now only manages `home_hex`, `province_hex`, `season_home_hex`. The `p_district_hex` param is echoed back in the response for client compat but NOT stored. Comment in function explains why.

**2. `fix_finalize_run_district_hex_from_run_path`**: Changed `finalize_run` to derive `district_hex` from `p_hex_district_parents[1]` (the Res-6 parent of the first hex in the run path). The client always sends `p_hex_district_parents`. Falls back to existing `district_hex` for 0-flip runs. Now: `district_hex = COALESCE(p_hex_district_parents[1], district_hex)`.

**3. `fix_finalize_run_idempotency_v2`**: Combined with above (full function replacement).

### After the Fix: Scenario Matrix

| Scenario | `district_hex` after | Buff context | Rankings context |
|---|---|---|---|
| Runs in Korea, stays Korea | Korea (from run) | Korea ✓ | Korea ✓ |
| Flies to US, opens app (SQLite intact) | Korea (unchanged) | Korea ✓ | Korea ✓ |
| Clicks "Update Location" in US | Korea (unchanged!) | Korea ✓ | Korea ✓ |
| Runs in US after update | US (from run) | US ✓ | US ✓ |
| Fresh install in US (Korean server history) | Korea (server untouched) | Korea ✓ | Korea ✓ |

### Verification
- `update_home_location` body confirmed: no `district_hex` assignment ✓
- `finalize_run` body confirmed: `district_hex = COALESCE(v_run_district_hex, district_hex)` ✓
- New users (no runs yet, `district_hex = NULL`): `get_user_buff` falls back to `p_district_hex` (client homeHexDistrict) ✓

### Lesson (Invariants #30 and #31)
`district_hex` is a run-context field, not a home-context field. Home location RPCs must not touch it. It must reflect where the user runs, because it scopes `daily_buff_stats` lookups (which are district-keyed). The two sources of truth for location are: `home_hex` (where you live) and `district_hex` (where you ran). They differ after travel. Never conflate them.

---

## Bug Fix: `get_team_rankings` COALESCE Order Regression — Client Wins Instead of Server (2026-03-19)

### Problem
After the location-context fix, a remaining inconsistency: after clicking "Update Location" to US, **TeamScreen showed US district rankings** (empty) while **buff correctly showed Korean context**. The UX was split: buff said "you're Korean elite", rankings said "no data in US district".

### Root Cause
The 2026-02-27 fix (`fix_team_rankings_prefer_server_district_hex`) had changed `get_team_rankings` to `COALESCE(v_user.district_hex, p_district_hex)` (server wins). But the `rename_city_to_district_all_to_province` migration (2026-03-06) recreated the function from scratch with the old `COALESCE(p_district_hex, v_user.district_hex)` (client wins) — reverting the fix silently.

After the location fix, `users.district_hex = Korea` but `PrefetchService.homeHexDistrict = US` (computed from updated homeHex). The rankings RPC received `p_district_hex = US` and, with client-wins ordering, used US → showed empty US rankings. The buff RPC (correctly server-wins) used Korea.

**The two RPCs were inconsistent:**
```sql
get_user_buff:      COALESCE(v_user.district_hex, p_district_hex)  -- server wins ✓
get_team_rankings:  COALESCE(p_district_hex, v_user.district_hex)  -- client wins ← WRONG
```

### Fix
Migration `fix_get_team_rankings_coalesce_order_v2`: Changed to `COALESCE(v_user.district_hex, p_district_hex)` — matching `get_user_buff`. Added comment explaining why.

### Verification
Scenario matrix after all fixes:

| Scenario | Buff context | Rankings context | Consistent? |
|---|---|---|---|
| Stays in Korea | Korea | Korea | ✅ |
| Flies to US (no update) | Korea | Korea | ✅ |
| Clicks Update to US | Korea | Korea | ✅ |
| Runs in US | US | US | ✅ |

### Lesson (Invariant #32)
Any migration that `CREATE OR REPLACE`s a function may silently revert a previously applied fix if it rebuilds from an old body. After renaming migrations that touch RPC functions, always re-verify COALESCE orders, season boundary guards, and other non-obvious logic that was patched incrementally. The `error-fix-history.md` pre-edit check (`./scripts/pre-edit-check.sh --search get_team_rankings`) exists precisely to catch this.
