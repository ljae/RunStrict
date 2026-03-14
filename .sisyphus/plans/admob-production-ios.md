# AdMob Production IDs — iOS + Android

## TL;DR

> **Quick Summary**: Replace all test AdMob IDs with real production IDs for both iOS and Android.
>
> **Deliverables**:
> - `ios/Runner/Info.plist` → real iOS App ID
> - `android/app/src/main/AndroidManifest.xml` → real Android App ID
> - `lib/core/services/ad_service.dart` → real iOS + Android banner ad unit IDs
>
> **Estimated Effort**: Quick (3 files, 5 lines)
> **Parallel Execution**: NO — sequential
> **Critical Path**: Task 1 + Task 2 + Task 3 → F1

---

## Context

### Original Request
Switch all test Google AdMob IDs to real production IDs for both iOS and Android.

### Key Constraint (from error-fix-history.md Fix #N+2)
**The App ID publisher in platform config MUST match the publisher of ad unit IDs in `ad_service.dart`.** Mixing publishers causes `GADApplicationVerifyPublisherInitializedCorrectly` → SIGABRT crash on launch.

All four IDs share publisher `ca-app-pub-5211646950805880` ✅ — safe to proceed.

### Production IDs

| Platform | Type | ID |
|----------|------|----|
| iOS | App ID (`Info.plist`) | `ca-app-pub-5211646950805880~6418697246` |
| iOS | Banner Ad Unit (`ad_service.dart`) | `ca-app-pub-5211646950805880/8533648712` |
| Android | App ID (`AndroidManifest.xml`) | `ca-app-pub-5211646950805880~6410194042` |
| Android | Banner Ad Unit (`ad_service.dart`) | `ca-app-pub-5211646950805880/4698345485` |

### Test IDs Being Replaced

| Platform | Type | Old Test ID |
|----------|------|-------------|
| iOS | App ID | `ca-app-pub-3940256099942544~1458002511` |
| iOS | Banner Ad Unit | `ca-app-pub-3940256099942544/2934735716` |
| Android | App ID | `ca-app-pub-3940256099942544~3347511713` |
| Android | Banner Ad Unit | `ca-app-pub-3940256099942544/6300978111` |

---

## Work Objectives

### Must Have
- `Info.plist` `GADApplicationIdentifier` = `ca-app-pub-5211646950805880~6418697246`
- `AndroidManifest.xml` `APPLICATION_ID` = `ca-app-pub-5211646950805880~6410194042`
- `ad_service.dart` iOS branch = `ca-app-pub-5211646950805880/8533648712`
- `ad_service.dart` Android branch = `ca-app-pub-5211646950805880/4698345485`
- Zero test IDs (`ca-app-pub-3940256099942544`) remaining in any of these 3 files

### Must NOT Have
- Do NOT change ad loading logic, ad formats, or AdService class structure
- Do NOT touch any other keys in `Info.plist` or `AndroidManifest.xml`

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed.

### QA Policy
- `post-revision-check.sh` J1 rule validates publisher match automatically
- `flutter analyze` must pass with 0 errors
- `grep` confirms zero test IDs remain in the 3 modified files

---

## Execution Strategy

```
Wave 1 (all 3 files — do together):
├── Task 1: Update ios/Runner/Info.plist [quick]
├── Task 2: Update android/.../AndroidManifest.xml [quick]
└── Task 3: Update lib/core/services/ad_service.dart [quick]

Wave FINAL:
└── Task F1: Verify via post-revision-check.sh + flutter analyze
```

---

## TODOs

- [ ] 1. Update iOS App ID in Info.plist

  **What to do**:
  - Open `ios/Runner/Info.plist`
  - Find lines 54-56 (the `GADApplicationIdentifier` block):
    ```xml
    <key>GADApplicationIdentifier</key>
    	<!-- DEV: Google test App ID. For production: use ca-app-pub-5211646950805880~6418697246 AND update ad_service.dart with real ad unit IDs. Never mix publisher accounts. -->
    	<string>ca-app-pub-3940256099942544~1458002511</string>
    ```
  - Replace with:
    ```xml
    <key>GADApplicationIdentifier</key>
    	<!-- PRODUCTION: Real AdMob App ID. Must match publisher of ad unit IDs in ad_service.dart. Never mix publisher accounts → SIGABRT. -->
    	<string>ca-app-pub-5211646950805880~6418697246</string>
    ```

  **Must NOT do**: Do not touch any other plist keys.

  **Recommended Agent Profile**: `quick`, skills: []

  **Acceptance Criteria**:
  - [ ] `grep -A2 'GADApplicationIdentifier' ios/Runner/Info.plist` shows `ca-app-pub-5211646950805880~6418697246`
  - [ ] No `ca-app-pub-3940256099942544` remains in `Info.plist`

---

- [ ] 2. Update Android App ID in AndroidManifest.xml

  **What to do**:
  - Open `android/app/src/main/AndroidManifest.xml`
  - Find lines 33-36 (the AdMob `meta-data` block):
    ```xml
    <!-- AdMob App ID (test ID - replace with real ID for production) -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-3940256099942544~3347511713"/>
    ```
  - Replace with:
    ```xml
    <!-- AdMob App ID (production) -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-5211646950805880~6410194042"/>
    ```

  **Must NOT do**: Do not touch any other meta-data tags or manifest entries.

  **Recommended Agent Profile**: `quick`, skills: []

  **Acceptance Criteria**:
  - [ ] `grep -A2 'APPLICATION_ID' android/app/src/main/AndroidManifest.xml` shows `ca-app-pub-5211646950805880~6410194042`
  - [ ] No `ca-app-pub-3940256099942544` remains in `AndroidManifest.xml`

---

- [ ] 3. Update both banner ad unit IDs in ad_service.dart

  **What to do**:
  - Open `lib/core/services/ad_service.dart`
  - Replace lines 16-25 (the `bannerAdUnitId` getter) entirely with:
    ```dart
    /// Production banner ad unit IDs.
    /// iOS: ca-app-pub-5211646950805880 (production)
    /// Android: ca-app-pub-5211646950805880 (production)
    static String get bannerAdUnitId {
      if (Platform.isAndroid) {
        return 'ca-app-pub-5211646950805880/4698345485'; // Android production banner
      } else if (Platform.isIOS) {
        return 'ca-app-pub-5211646950805880/8533648712'; // iOS production banner
      }
      throw UnsupportedError('Unsupported platform');
    }
    ```

  **Must NOT do**:
  - Do NOT change the `initialize()` method or class structure
  - Do NOT add conditional debug/release logic

  **Recommended Agent Profile**: `quick`, skills: []

  **Acceptance Criteria**:
  - [ ] `grep 'ca-app-pub-5211646950805880/4698345485' lib/core/services/ad_service.dart` → 1 match (Android)
  - [ ] `grep 'ca-app-pub-5211646950805880/8533648712' lib/core/services/ad_service.dart` → 1 match (iOS)
  - [ ] `grep 'ca-app-pub-3940256099942544' lib/core/services/ad_service.dart` → 0 matches

---

## Final Verification Wave

- [ ] F1. Post-revision check + flutter analyze

  Run `./scripts/post-revision-check.sh`. The J1 rule validates publisher match between `Info.plist` App ID and `ad_service.dart` ad unit IDs. Then `flutter analyze` for 0 errors.

  **Recommended Agent Profile**: `quick`, skills: []

  ```
  Scenario: J1 AdMob rule passes
    Steps:
      1. Run: ./scripts/post-revision-check.sh
      2. Assert: No FAIL on [J1]
      3. Run: flutter analyze
      4. Assert: 0 issues found
      5. Run: grep 'ca-app-pub-3940256099942544' ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml lib/core/services/ad_service.dart
      6. Assert: 0 matches (all test IDs gone)
  ```

---

## Commit Strategy

Single commit covering all 3 files:
- Message: `feat(ads): switch iOS and Android AdMob to production IDs`
- Files: `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `lib/core/services/ad_service.dart`
- Pre-commit: `./scripts/post-revision-check.sh --staged`

---

## Success Criteria

```bash
grep -A2 'GADApplicationIdentifier' ios/Runner/Info.plist
# → ca-app-pub-5211646950805880~6418697246

grep -A3 'APPLICATION_ID' android/app/src/main/AndroidManifest.xml
# → ca-app-pub-5211646950805880~6410194042

grep 'bannerAdUnitId' -A8 lib/core/services/ad_service.dart
# → Android: ca-app-pub-5211646950805880/4698345485
# → iOS:     ca-app-pub-5211646950805880/8533648712

grep 'ca-app-pub-3940256099942544' ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml lib/core/services/ad_service.dart
# → (no output — all test IDs gone)

./scripts/post-revision-check.sh
# → J1 PASS

flutter analyze
# → 0 issues
```
