# Plan: Formalize Date/Time Management Rules & Fix Remaining Issues

## Context
After fixing two timezone bugs (wrong `run_date` from local DateTime, yesterday stats not showing), the user wants to formalize the date/time management approach across the codebase and documentation:
- **Local system**: Uses device local timezone (history screen has GMT+2/local toggle)
- **Server-bound data**: Must use UTC timestamps so server computes correct GMT+2 dates
- **Server**: All date logic based on GMT+2 (D-Day system, snapshots, buff calculations)

## Current State (What's Already Correct)
- `run_tracker.dart:165` — `DateTime.now().toUtc()` for startTime (**already fixed**)
- `run.dart:116` — `DateTime.now().toUtc()` for endTime (**already fixed**)
- `gmt2_date_utils.dart:8` — calls `.toUtc()` internally (**correct**)
- `run_provider.dart:433` — passes `DateTime.now()` to `Gmt2DateUtils.toGmt2DateString()` which calls `.toUtc()` internally (**correct**)
- `season_service.dart:59` — `DateTime.now().toUtc()` for season resolution (**correct**)

## Changes Required

### 1. Fix `season_service.dart` — daysRemaining/currentSeasonDay use wrong timezone
**File**: `lib/core/services/season_service.dart`

**Problem**: Lines 113 and 121 use `DateTime.now()` (local time) but `seasonEndDate`/`seasonStartDate` are derived from UTC. For a user in KST (UTC+9), the countdown can be off by up to 9 hours near midnight.

**Fix**: Use `DateTime.now().toUtc()` in both `daysRemaining` (line 113) and `currentSeasonDay` (line 121):
```dart
int get daysRemaining {
  final now = DateTime.now().toUtc();  // was: DateTime.now()
  ...
}

int get currentSeasonDay {
  final now = DateTime.now().toUtc();  // was: DateTime.now()
  ...
}
```

### 2. Fix `prefetch_service.dart:547` — local time in server context
**File**: `lib/core/services/prefetch_service.dart`

**Problem**: `updateCachedHex()` uses `DateTime.now().toIso8601String()` for `last_flipped_at`. This is a local-only cache operation (not sent to server), but for consistency with the delta-sync conflict resolution (`lastFlippedAt` comparisons), it should use UTC.

**Fix**:
```dart
'last_flipped_at': DateTime.now().toUtc().toIso8601String(),
```

### 3. Fix `local_storage.dart:884` — endTime fallback
**File**: `lib/core/storage/local_storage.dart`

**Problem**: Line 884 uses `run.endTime ?? DateTime.now()` as a fallback. Since `endTime` is now always UTC, the fallback should also be UTC for consistency.

**Fix**:
```dart
run.endTime ?? DateTime.now().toUtc(),
```

### 4. Add DateTime/Timezone Rules section to AGENTS.md
**File**: `AGENTS.md`

Add a new section under "Architecture Rules" documenting the three timezone domains:

```markdown
### DateTime & Timezone Rules

Three timezone contexts exist — never mix them:

| Context | Timezone | Usage | Example |
|---------|----------|-------|---------|
| **Server-bound** | UTC | Timestamps sent to Supabase | `DateTime.now().toUtc()` |
| **Server date logic** | GMT+2 | run_date, snapshots, D-Day, buffs | `AT TIME ZONE 'Etc/GMT-2'` (SQL) |
| **Local display** | Device local | UI timestamps, calendar, countdown | `DateTime.now()` or `.toLocal()` |

**Rules:**
1. All timestamps sent to server MUST use `DateTime.now().toUtc()` — never bare `DateTime.now()`
2. Server computes `run_date` from `end_time AT TIME ZONE 'Etc/GMT-2'` — client never sends `run_date`
3. For GMT+2 date calculations on client, use `Gmt2DateUtils` (calls `.toUtc()` internally)
4. `Gmt2DateUtils` reads `serverTimezoneOffsetHours` from RemoteConfig (currently 2)
5. Local UI display (history, calendar) uses device timezone by default, with GMT+2 toggle
6. Throttling timestamps (prefetch, lifecycle) can use local `DateTime.now()` — not server-bound
7. Season dates (`seasonStartDate`, `seasonEndDate`) are UTC — comparisons must use `.toUtc()`
```

### 5. Update DEVELOPMENT_SPEC.md
**File**: `DEVELOPMENT_SPEC.md`

Add a brief cross-reference to the timezone rules in AGENTS.md under the data architecture section.

## Files to Modify
1. `lib/core/services/season_service.dart` — lines 113, 121 (2 changes)
2. `lib/core/services/prefetch_service.dart` — line 547 (1 change)
3. `lib/core/storage/local_storage.dart` — line 884 (1 change)
4. `AGENTS.md` — add DateTime & Timezone Rules section
5. `DEVELOPMENT_SPEC.md` — add cross-reference

## Files NOT Changed (Already Correct)
- `gmt2_date_utils.dart` — already uses `.toUtc()` internally
- `run_tracker.dart:165` — already fixed to `.toUtc()`
- `run.dart:116` — already fixed to `.toUtc()`
- `run_provider.dart:433` — feeds into `Gmt2DateUtils` which handles UTC conversion
- `season_service.dart:59` — already uses `.toUtc()`
- Calendar/history UI code — correctly uses local time for display
- Throttling code (repositories, lifecycle) — local time is appropriate

## Verification
1. `flutter analyze` — no new warnings
2. Review `season_service.dart` — `daysRemaining` and `currentSeasonDay` now use UTC, consistent with season date computation
3. Grep `DateTime.now()` across `*.dart` — all server-bound usages use `.toUtc()`, UI-only usages use local
4. Read AGENTS.md timezone section — rules are clear and complete
