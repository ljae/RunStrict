# RunStrict Data Architecture Optimization

## TL;DR

> **Quick Summary**: Remove all data duplication across RunStrict's data layer by introducing Repository pattern, unified Run model, and delta sync for hexes. This reduces memory footprint, simplifies state management, and minimizes data transfer.
> 
> **Deliverables**:
> - Unified `Run` model replacing RunSession/RunSummary/RunHistoryModel
> - `UserRepository` as single source of truth for user data
> - `HexRepository` consolidating two separate hex caches
> - `LeaderboardRepository` consolidating prefetch and provider caches
> - Delta sync for hexes (only download changes since last_prefetch_time)
> - Dead code removal (sync_queue is legacy)
> 
> **Estimated Effort**: Large (2-3 weeks)
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Task 1 (Run model) → Task 5 (Provider refactor) → Task 8 (Final integration)

---

## Context

### Original Request
User wants to optimize the RunStrict Flutter app data architecture to:
1. List all screens with numbering and show links between them
2. Remove duplicated data - store minimum size, one data used everywhere
3. Use local calculation where possible to reduce download volume
4. App prefetches on launch/resume → save local → calculate local
5. After run end, upload to server (handle unsynced data display)
6. Server calculates rankings and hex colors
7. Optimize for minimum data download
8. Share variables across the app properly

### Interview Summary
**Key Discussions**:
- Test Strategy: TDD confirmed (RED-GREEN-REFACTOR for each task)
- 8 major data duplication issues identified across models, providers, caches
- Repository pattern agreed upon for centralized state management

**Research Findings**:
- RunSession/RunSummary/RunHistoryModel have 80% field overlap (12/9/10 fields)
- PointsService._seasonPoints duplicates AppStateProvider._currentUser.seasonPoints
- Two separate LRU caches for hex data exist (wasted memory)
- sync_queue is LEGACY - superseded by runs.sync_status column
- PrefetchService downloads ALL 3,800 hexes on every refresh (no delta)

### Metis Review
**Identified Gaps** (addressed):
- sync_queue refactoring unnecessary - it's legacy dead code → Changed to removal task
- Need explicit guardrails for offline-first and backward compatibility
- Need migration path for in-flight runs during deployment

---

## Screen Map (with Data Dependencies)

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           SCREEN NAVIGATION MAP                             │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────────┐                                                       │
│  │ 1. AppInitializer│────────┬──────────────────────────────────────┐      │
│  │   (entry point) │        │                                      │      │
│  └────────┬────────┘        │                                      │      │
│           │                 │                                      │      │
│    ┌──────┴──────┐   ┌──────┴────────┐                             │      │
│    │ hasUser?    │   │ hasUser?      │                             │      │
│    │ NO          │   │ YES           │                             │      │
│    ▼             │   ▼               │                             │      │
│  ┌───────────────┴┐ ┌───────────────┐│                             │      │
│  │2. SeasonRegister│ │ 4. HomeScreen ││◄────────────────────────┐  │      │
│  │  Screen        │ │   (hub)       ││                         │  │      │
│  └───────┬────────┘ └───────┬───────┘│                         │  │      │
│          │                  │        │                         │  │      │
│  ┌───────┴────────┐         │        │                         │  │      │
│  │3. TeamSelection │         │        │                         │  │      │
│  │  Screen (legacy)│         │        │                         │  │      │
│  └────────────────┘         │        │                         │  │      │
│                             │        │                         │  │      │
│           ┌─────────────────┴────────┴─────────────────┐       │  │      │
│           │          5 TABS (Bottom Navigation)        │       │  │      │
│           │                                            │       │  │      │
│   ┌───────┴───────┬───────────┬───────────┬───────────┴───────┐│  │      │
│   │               │           │           │                   ││  │      │
│   ▼               ▼           ▼           ▼                   ▼│  │      │
│ ┌────────┐  ┌──────────┐  ┌────────┐  ┌────────────┐  ┌─────────┐│      │
│ │5. Map  │  │6. Running│  │7. Team │  │8. RunHistory│  │9. Leader ││      │
│ │ Screen │  │  Screen  │  │ Screen │  │   Screen   │  │  board   ││      │
│ └────────┘  └──────────┘  └───┬────┘  └────────────┘  │  Screen ││      │
│                               │                       └─────────┘│      │
│                               │                                  │      │
│                    ┌──────────┴───────────┐                      │      │
│                    │                      │                      │      │
│                    ▼                      ▼                      │      │
│              ┌───────────┐         ┌─────────────┐               │      │
│              │10. Profile│         │11. Traitor  │───────────────┘      │
│              │   Screen  │         │ GateScreen  │ (defect → refresh)   │
│              └───────────┘         └─────────────┘                      │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### Screen Data Dependencies

| # | Screen | Providers Used | Data Dependencies |
|---|--------|----------------|-------------------|
| 1 | AppInitializer | AppStateProvider, RunProvider, LeaderboardProvider | User session, prefetch status |
| 2 | SeasonRegisterScreen | AppStateProvider | Team selection, username |
| 3 | TeamSelectionScreen | AppStateProvider | Team selection (legacy) |
| 4 | HomeScreen | AppStateProvider, RunProvider, LeaderboardProvider, PointsService, BuffService | User team, points, buff, season |
| 5 | MapScreen | HexDataProvider, PrefetchService | Hex colors, user location |
| 6 | RunningScreen | RunProvider, HexDataProvider, PointsService, BuffService | Active run, GPS, captured hexes |
| 7 | TeamScreen | TeamStatsProvider, AppStateProvider | Yesterday stats, rankings, dominance |
| 8 | RunHistoryScreen | RunProvider (runHistory), LocalStorage | Past runs, calendar data |
| 9 | LeaderboardScreen | LeaderboardProvider, PrefetchService | Rankings, scope filtering |
| 10 | ProfileScreen | AppStateProvider | User profile, manifesto, stats |
| 11 | TraitorGateScreen | AppStateProvider | Team defection |

---

## Work Objectives

### Core Objective
Eliminate data duplication by introducing Repository pattern as single source of truth for User, Hex, and Leaderboard data, while unifying three overlapping Run models into one.

### Concrete Deliverables
- `lib/models/run.dart` - Unified Run model
- `lib/repositories/user_repository.dart` - Single source of truth for user data
- `lib/repositories/hex_repository.dart` - Consolidated hex cache
- `lib/repositories/leaderboard_repository.dart` - Consolidated leaderboard cache
- `lib/services/supabase_service.dart` - Delta sync RPC for hexes
- Updated providers using repositories instead of internal state
- Removed dead code (sync_queue, legacy run models)

### Definition of Done
- [ ] `flutter analyze` reports 0 errors
- [ ] `flutter test` all existing tests pass + new tests for repositories
- [ ] No duplicate data storage for user points, team, hex cache, leaderboard
- [ ] Hex prefetch uses delta sync (downloads only changed hexes)
- [ ] Memory footprint reduced (single cache instead of dual)

### Must Have
- Offline-first architecture preserved (local SQLite still primary)
- Backward compatibility with existing local_user.json and SQLite data
- All existing functionality works identically after refactor
- TDD approach with tests for all new code

### Must NOT Have (Guardrails)
- DO NOT change UI components or screens (refactoring data layer only)
- DO NOT change Supabase schema (only add new RPC for delta sync)
- DO NOT break offline-first (local data must work without server)
- DO NOT change external API contracts (RunSummary.toRow() shape preserved for server sync)
- DO NOT remove functionality - only consolidate duplicates
- DO NOT over-abstract - repositories are thin wrappers, not enterprise frameworks

---

## Verification Strategy (TDD)

### Test Decision
- **Infrastructure exists**: YES (flutter_test, 5 existing test files)
- **User wants tests**: TDD
- **Framework**: flutter_test

### TDD Workflow for Each Task

Each TODO follows RED-GREEN-REFACTOR:

**Task Structure:**
1. **RED**: Write failing test first
   - Test file: `test/{layer}/{name}_test.dart`
   - Test command: `flutter test test/{file}`
   - Expected: FAIL (test exists, implementation doesn't)
2. **GREEN**: Implement minimum code to pass
   - Command: `flutter test test/{file}`
   - Expected: PASS
3. **REFACTOR**: Clean up while keeping green
   - Command: `flutter test`
   - Expected: ALL PASS (no regressions)

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Unified Run model (no dependencies)
├── Task 2: UserRepository (no dependencies)
├── Task 3: HexRepository (no dependencies)
└── Task 4: LeaderboardRepository (no dependencies)

Wave 2 (After Wave 1):
├── Task 5: Provider refactoring (depends: 2, 3, 4)
└── Task 6: Delta sync implementation (depends: 3)

Wave 3 (After Wave 2):
├── Task 7: Dead code removal (depends: 1, 5)
└── Task 8: Integration & cleanup (depends: 5, 6, 7)

Wave 4 (Final):
└── Task 9: Final verification & documentation (depends: all)

Critical Path: Task 1 → Task 5 → Task 7 → Task 8 → Task 9
Parallel Speedup: ~50% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 5, 7 | 2, 3, 4 |
| 2 | None | 5 | 1, 3, 4 |
| 3 | None | 5, 6 | 1, 2, 4 |
| 4 | None | 5 | 1, 2, 3 |
| 5 | 1, 2, 3, 4 | 7, 8 | 6 |
| 6 | 3 | 8 | 5 |
| 7 | 1, 5 | 8 | None |
| 8 | 5, 6, 7 | 9 | None |
| 9 | All | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Dispatch |
|------|-------|---------------------|
| 1 | 1, 2, 3, 4 | `delegate_task(category="quick", load_skills=["moai-lang-flutter"], run_in_background=true)` x4 |
| 2 | 5, 6 | `delegate_task(category="unspecified-high", load_skills=["moai-lang-flutter"], run_in_background=true)` x2 |
| 3 | 7, 8 | `delegate_task(category="quick", load_skills=["moai-lang-flutter"], run_in_background=true)` x2 |
| 4 | 9 | Final verification (sequential) |

---

## TODOs

---

### - [ ] 1. Create Unified Run Model

**What to do**:
1. Create `lib/models/run.dart` with unified fields
2. Implement computed getters (NOT stored): `endTime`, `distanceKm`, `avgPaceMinPerKm`, `stabilityScore`, `flipPoints`
3. Implement `fromMap()`, `toMap()`, `fromRow()`, `toRow()` for all storage formats
4. Implement `copyWith()` for immutable updates
5. Add transient fields for active runs: `route`, `hexesPassed`, `currentHexId`
6. Write comprehensive tests covering all conversions and edge cases

**Must NOT do**:
- DO NOT remove existing RunSession/RunSummary/RunHistoryModel yet (done in Task 7)
- DO NOT change toRow() output shape (server expects specific format)
- DO NOT store computed fields (avgPaceMinPerKm, stabilityScore)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Single file creation with clear spec, straightforward implementation
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter/Dart expertise for model patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 2, 3, 4)
- **Blocks**: Tasks 5, 7
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References** (existing code to follow):
- `lib/models/run_session.dart:1-137` - Current RunSession structure with getters pattern
- `lib/models/run_summary.dart:1-102` - RunSummary with toMap/fromMap/toRow/fromRow pattern
- `lib/models/run_history_model.dart:1-116` - RunHistoryModel structure

**API/Type References** (contracts to implement against):
- `lib/models/team.dart` - Team enum for teamAtRun field
- `lib/models/location_point.dart` - LocationPoint for transient route field

**Test References** (testing patterns to follow):
- `test/models/lap_model_test.dart` - Model testing pattern with group/test structure

**WHY Each Reference Matters**:
- `run_session.dart`: Shows existing getter pattern for derived fields (paceMinPerKm, distanceKm)
- `run_summary.dart`: Shows exact toRow() format required for server sync - MUST preserve this shape
- `run_history_model.dart`: Shows additional fields like userId needed for history

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] Test file created: `test/models/run_test.dart`
- [ ] Tests cover: all computed getters return correct values
- [ ] Tests cover: toMap/fromMap roundtrip preserves data
- [ ] Tests cover: toRow/fromRow roundtrip preserves data (server format)
- [ ] Tests cover: edge cases (zero distance, null cv, etc.)
- [ ] `flutter test test/models/run_test.dart` → PASS

**Automated Verification:**
```bash
# Agent runs:
flutter test test/models/run_test.dart --reporter=expanded
# Assert: All tests pass, 0 failures
# Assert: Coverage includes Run model

flutter analyze lib/models/run.dart
# Assert: 0 errors, 0 warnings
```

**Commit**: YES
- Message: `feat(models): add unified Run model with computed getters`
- Files: `lib/models/run.dart`, `test/models/run_test.dart`
- Pre-commit: `flutter test test/models/run_test.dart`

---

### - [ ] 2. Create UserRepository

**What to do**:
1. Create `lib/repositories/user_repository.dart` as singleton
2. Hold single `UserModel` instance as source of truth
3. Implement persistence to local_user.json (migrate from AppStateProvider)
4. Implement `notifyListeners()` via ChangeNotifier
5. Add methods: `getUser()`, `updateUser()`, `updateSeasonPoints()`, `defectToPurple()`
6. Write tests for all state changes and persistence

**Must NOT do**:
- DO NOT change local_user.json format (backward compatible)
- DO NOT remove AppStateProvider._currentUser yet (Task 5)
- DO NOT add server sync logic here (that stays in AuthService)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Single repository file with clear responsibilities
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter Provider/ChangeNotifier patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 1, 3, 4)
- **Blocks**: Task 5
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References** (existing code to follow):
- `lib/providers/app_state_provider.dart:35-74` - Local user persistence pattern (_saveLocalUser, _loadLocalUser)
- `lib/providers/hex_data_provider.dart:42-45` - Singleton pattern with ChangeNotifier
- `lib/services/prefetch_service.dart:126-128` - Singleton factory pattern

**API/Type References** (contracts to implement against):
- `lib/models/user_model.dart` - UserModel with toJson/fromJson

**Test References** (testing patterns to follow):
- `test/services/remote_config_service_test.dart` - Service/singleton testing pattern

**WHY Each Reference Matters**:
- `app_state_provider.dart:35-74`: Exact persistence logic to migrate (file path, JSON encode/decode)
- `hex_data_provider.dart:42-45`: Singleton + ChangeNotifier combo used successfully
- `user_model.dart`: UserModel.toJson/fromJson format must be preserved for backward compat

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] Test file created: `test/repositories/user_repository_test.dart`
- [ ] Tests cover: singleton returns same instance
- [ ] Tests cover: updateSeasonPoints notifies listeners
- [ ] Tests cover: defectToPurple changes team, preserves points
- [ ] Tests cover: persistence roundtrip (save → load)
- [ ] `flutter test test/repositories/user_repository_test.dart` → PASS

**Automated Verification:**
```bash
# Agent runs:
flutter test test/repositories/user_repository_test.dart --reporter=expanded
# Assert: All tests pass

flutter analyze lib/repositories/user_repository.dart
# Assert: 0 errors
```

**Commit**: YES
- Message: `feat(repositories): add UserRepository as single source of truth`
- Files: `lib/repositories/user_repository.dart`, `test/repositories/user_repository_test.dart`
- Pre-commit: `flutter test test/repositories/user_repository_test.dart`

---

### - [ ] 3. Create HexRepository

**What to do**:
1. Create `lib/repositories/hex_repository.dart` as singleton
2. Consolidate LRU cache from HexDataProvider + Map cache from PrefetchService
3. Implement single `LruCache<String, HexModel>` with configurable size
4. Add methods: `getHex()`, `updateHexColor()`, `bulkLoadFromServer()`, `clearAll()`
5. Track `lastPrefetchTime` for delta sync
6. Expose `locationStream` for user location sharing
7. Write tests for cache behavior and state updates

**Must NOT do**:
- DO NOT change HexModel structure
- DO NOT remove HexDataProvider/PrefetchService caches yet (Task 5)
- DO NOT implement delta sync here (Task 6)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Repository consolidating existing cache logic
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter state management patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 1, 2, 4)
- **Blocks**: Tasks 5, 6
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References** (existing code to follow):
- `lib/providers/hex_data_provider.dart:26-32` - LRU cache setup and max size config
- `lib/providers/hex_data_provider.dart:148-193` - updateHexColor logic with HexUpdateResult
- `lib/services/prefetch_service.dart:142-143` - Map cache pattern for hex data
- `lib/utils/lru_cache.dart` - LruCache implementation

**API/Type References** (contracts to implement against):
- `lib/models/hex_model.dart` - HexModel structure
- `lib/providers/hex_data_provider.dart:12` - HexUpdateResult enum

**Test References** (testing patterns to follow):
- `test/services/lap_service_test.dart` - Service testing with mock data

**WHY Each Reference Matters**:
- `hex_data_provider.dart:148-193`: updateHexColor logic with session tracking - MUST preserve behavior
- `lru_cache.dart`: Existing LRU implementation to reuse
- `prefetch_service.dart:142-143`: Bulk load pattern for server data

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] Test file created: `test/repositories/hex_repository_test.dart`
- [ ] Tests cover: LRU eviction works correctly
- [ ] Tests cover: updateHexColor returns correct HexUpdateResult
- [ ] Tests cover: bulkLoadFromServer populates cache
- [ ] Tests cover: clearAll resets all state
- [ ] `flutter test test/repositories/hex_repository_test.dart` → PASS

**Automated Verification:**
```bash
# Agent runs:
flutter test test/repositories/hex_repository_test.dart --reporter=expanded
# Assert: All tests pass

flutter analyze lib/repositories/hex_repository.dart
# Assert: 0 errors
```

**Commit**: YES
- Message: `feat(repositories): add HexRepository consolidating dual caches`
- Files: `lib/repositories/hex_repository.dart`, `test/repositories/hex_repository_test.dart`
- Pre-commit: `flutter test test/repositories/hex_repository_test.dart`

---

### - [ ] 4. Create LeaderboardRepository

**What to do**:
1. Create `lib/repositories/leaderboard_repository.dart` as singleton
2. Consolidate PrefetchService._leaderboardCache and LeaderboardProvider._entries
3. Implement single list with scope filtering methods
4. Add methods: `getEntries()`, `filterByScope()`, `filterByTeam()`, `refresh()`
5. Track `lastFetchTime` for throttling
6. Write tests for filtering and caching

**Must NOT do**:
- DO NOT change LeaderboardEntry structure
- DO NOT remove existing caches yet (Task 5)
- DO NOT change scope filtering logic

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Repository consolidating existing leaderboard logic
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter state management patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 1, 2, 3)
- **Blocks**: Task 5
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References** (existing code to follow):
- `lib/providers/leaderboard_provider.dart:93-126` - fetchLeaderboard with throttling pattern
- `lib/providers/leaderboard_provider.dart:139-153` - filterByScope logic with home hex
- `lib/services/prefetch_service.dart:441-452` - getLeaderboardForScope filtering

**API/Type References** (contracts to implement against):
- `lib/providers/leaderboard_provider.dart:8-71` - LeaderboardEntry class
- `lib/config/h3_config.dart` - GeographicScope enum

**Test References** (testing patterns to follow):
- `test/services/remote_config_service_test.dart` - Service testing pattern

**WHY Each Reference Matters**:
- `leaderboard_provider.dart:139-153`: filterByScope logic uses HexService - MUST preserve
- `leaderboard_provider.dart:8-71`: LeaderboardEntry structure and fromJson pattern

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] Test file created: `test/repositories/leaderboard_repository_test.dart`
- [ ] Tests cover: filterByTeam returns correct subset
- [ ] Tests cover: filterByScope returns correct subset
- [ ] Tests cover: throttling prevents rapid re-fetches
- [ ] `flutter test test/repositories/leaderboard_repository_test.dart` → PASS

**Automated Verification:**
```bash
# Agent runs:
flutter test test/repositories/leaderboard_repository_test.dart --reporter=expanded
# Assert: All tests pass

flutter analyze lib/repositories/leaderboard_repository.dart
# Assert: 0 errors
```

**Commit**: YES
- Message: `feat(repositories): add LeaderboardRepository consolidating caches`
- Files: `lib/repositories/leaderboard_repository.dart`, `test/repositories/leaderboard_repository_test.dart`
- Pre-commit: `flutter test test/repositories/leaderboard_repository_test.dart`

---

### - [ ] 5. Refactor Providers to Use Repositories

**What to do**:
1. Update `AppStateProvider` to delegate to `UserRepository`
   - Keep `currentUser` getter but read from repository
   - Keep `updateSeasonPoints()` but delegate to repository
   - Remove internal `_currentUser` storage
2. Update `HexDataProvider` to delegate to `HexRepository`
   - Remove internal `_hexCache` (use repository)
   - Keep `_capturedHexesThisSession` (run-specific state)
3. Update `LeaderboardProvider` to delegate to `LeaderboardRepository`
   - Remove internal `_entries` (use repository)
4. Update `PointsService` to read from `UserRepository`
   - Remove internal `_seasonPoints` duplicate
5. Write integration tests verifying cross-provider consistency

**Must NOT do**:
- DO NOT change provider public APIs (screens use them)
- DO NOT break existing Consumer<Provider> usage
- DO NOT remove PointsService (it has unique hybrid calculation logic)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Multi-file refactoring with complex dependencies, needs careful state migration
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter Provider patterns and state management

**Parallelization**:
- **Can Run In Parallel**: YES (with Task 6)
- **Parallel Group**: Wave 2 (with Task 6)
- **Blocks**: Tasks 7, 8
- **Blocked By**: Tasks 1, 2, 3, 4

**References**:

**Pattern References** (existing code to follow):
- `lib/providers/app_state_provider.dart:112-116` - setUser pattern to preserve
- `lib/providers/hex_data_provider.dart:136-140` - _capturedHexesThisSession (keep this)
- `lib/providers/run_provider.dart:73-75` - updatePointsService pattern for dependency injection

**API/Type References** (contracts to implement against):
- All public methods on AppStateProvider, HexDataProvider, LeaderboardProvider, PointsService

**Test References** (testing patterns to follow):
- `test/widget_test.dart` - App-level testing with MultiProvider

**WHY Each Reference Matters**:
- `app_state_provider.dart:112-116`: Public API that screens depend on - MUST preserve
- `hex_data_provider.dart:136-140`: Session-specific state that does NOT go in repository
- `run_provider.dart:73-75`: Dependency injection pattern for cross-provider communication

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] Test file created: `test/providers/provider_integration_test.dart`
- [ ] Tests cover: AppStateProvider.currentUser returns UserRepository data
- [ ] Tests cover: HexDataProvider.updateHexColor updates HexRepository
- [ ] Tests cover: LeaderboardProvider.entries returns LeaderboardRepository data
- [ ] Tests cover: PointsService.seasonPoints matches UserRepository
- [ ] `flutter test test/providers/` → ALL PASS

**Automated Verification:**
```bash
# Agent runs:
flutter test test/providers/ --reporter=expanded
# Assert: All provider tests pass

flutter test
# Assert: ALL existing tests still pass (no regressions)

flutter analyze lib/providers/
# Assert: 0 errors
```

**Commit**: YES
- Message: `refactor(providers): delegate to repositories as single source of truth`
- Files: `lib/providers/*.dart`, `test/providers/provider_integration_test.dart`
- Pre-commit: `flutter test`

---

### - [ ] 6. Implement Delta Sync for Hexes

**What to do**:
1. Add `last_prefetch_time` tracking to `HexRepository`
2. Create new Supabase RPC: `get_hexes_delta(p_parent_hex, p_since_time)`
3. Update `PrefetchService._downloadHexData()` to use delta sync
4. Fall back to full download if delta fails or first time
5. Update `LocalStorage` to persist `last_prefetch_time`
6. Write tests for delta vs full sync scenarios

**Must NOT do**:
- DO NOT change existing RPC contract (add new RPC, don't modify)
- DO NOT break full download fallback
- DO NOT require server schema migration (RPC only)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Cross-layer change (repository, service, Supabase RPC)
- **Skills**: [`moai-lang-flutter`, `supabase-sdk-patterns`]
  - `moai-lang-flutter`: Flutter service patterns
  - `supabase-sdk-patterns`: Supabase RPC best practices

**Parallelization**:
- **Can Run In Parallel**: YES (with Task 5)
- **Parallel Group**: Wave 2 (with Task 5)
- **Blocks**: Task 8
- **Blocked By**: Task 3

**References**:

**Pattern References** (existing code to follow):
- `lib/services/prefetch_service.dart:338-380` - _downloadHexData current implementation
- `lib/services/supabase_service.dart` - RPC call patterns
- `lib/storage/local_storage.dart:699-726` - prefetch metadata persistence

**API/Type References** (contracts to implement against):
- `lib/repositories/hex_repository.dart` - Repository to update

**External References** (libraries and frameworks):
- Supabase RPC docs: `https://supabase.com/docs/reference/dart/rpc`

**WHY Each Reference Matters**:
- `prefetch_service.dart:338-380`: Shows current full download pattern to optimize
- `local_storage.dart:699-726`: Shows how to persist metadata (reuse for last_prefetch_time)

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] Test file created: `test/services/delta_sync_test.dart`
- [ ] Tests cover: first download triggers full sync (no delta)
- [ ] Tests cover: subsequent download uses delta with timestamp
- [ ] Tests cover: failed delta falls back to full sync
- [ ] Tests cover: last_prefetch_time persists across app restart
- [ ] `flutter test test/services/delta_sync_test.dart` → PASS

**Automated Verification:**
```bash
# Agent runs:
flutter test test/services/delta_sync_test.dart --reporter=expanded
# Assert: All tests pass

flutter analyze lib/services/prefetch_service.dart lib/repositories/hex_repository.dart
# Assert: 0 errors
```

**Commit**: YES
- Message: `feat(sync): implement delta sync for hexes using since_time parameter`
- Files: `lib/repositories/hex_repository.dart`, `lib/services/prefetch_service.dart`, `supabase/migrations/*_delta_sync.sql`, `test/services/delta_sync_test.dart`
- Pre-commit: `flutter test test/services/delta_sync_test.dart`

---

### - [ ] 7. Remove Dead Code (Legacy Models & sync_queue)

**What to do**:
1. Delete `lib/models/run_session.dart` (replaced by Run)
2. Delete `lib/models/run_summary.dart` (replaced by Run)
3. Delete `lib/models/run_history_model.dart` (replaced by Run)
4. Update all imports to use new `lib/models/run.dart`
5. Verify `sync_queue` table has no orphaned data
6. Remove `sync_queue` methods from LocalStorage (queueSync, getPendingSyncs, etc.)
7. Add migration to drop `sync_queue` table (DB v10)
8. Run full test suite to verify no regressions

**Must NOT do**:
- DO NOT delete until Run model is fully tested and integrated
- DO NOT remove sync_queue if orphaned data exists (migrate first)
- DO NOT break any imports

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Deletion and cleanup task with clear checklist
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter import/export patterns

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 3 (sequential)
- **Blocks**: Task 8
- **Blocked By**: Tasks 1, 5

**References**:

**Pattern References** (existing code to follow):
- `lib/storage/local_storage.dart:751-846` - sync_queue methods to remove
- `lib/storage/local_storage.dart:162-319` - _onUpgrade pattern for DB migration

**Test References** (testing patterns to follow):
- Run full test suite: `flutter test`

**WHY Each Reference Matters**:
- `local_storage.dart:751-846`: Exact methods to remove (queueSync through cleanupSyncQueue)
- `local_storage.dart:162-319`: Shows how to add DB version upgrade for v10

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] Verify all tests pass BEFORE deletion
- [ ] Delete files one by one, run tests after each
- [ ] `flutter test` → ALL PASS (no regressions)

**Automated Verification:**
```bash
# Agent runs:
# First verify no orphaned sync_queue data:
# (This requires running app and checking SQLite - manual step)

# Then after deletions:
flutter test
# Assert: ALL tests pass

flutter analyze
# Assert: 0 errors (no dangling imports)

# Verify old files are gone:
ls lib/models/run_session.dart lib/models/run_summary.dart lib/models/run_history_model.dart 2>&1 | grep "No such file"
# Assert: All three files not found
```

**Commit**: YES
- Message: `chore(cleanup): remove legacy run models and dead sync_queue code`
- Files: DELETED: `lib/models/run_session.dart`, `lib/models/run_summary.dart`, `lib/models/run_history_model.dart`; MODIFIED: `lib/storage/local_storage.dart`
- Pre-commit: `flutter test`

---

### - [ ] 8. Integration & Final Cleanup

**What to do**:
1. Update `main.dart` provider setup to initialize repositories
2. Update `RunProvider` to use unified `Run` model
3. Update `RunTracker` to use unified `Run` model
4. Verify all screens work correctly with new architecture
5. Run full integration test
6. Performance test: measure memory usage before/after
7. Update comments/docs to reflect new architecture

**Must NOT do**:
- DO NOT change any screen UI
- DO NOT change external API contracts
- DO NOT skip integration testing

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Integration across all layers, requires careful verification
- **Skills**: [`moai-lang-flutter`, `systematic-debugging`]
  - `moai-lang-flutter`: Flutter app architecture
  - `systematic-debugging`: For troubleshooting integration issues

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 3 (sequential after Task 7)
- **Blocks**: Task 9
- **Blocked By**: Tasks 5, 6, 7

**References**:

**Pattern References** (existing code to follow):
- `lib/main.dart:76-98` - MultiProvider setup pattern
- `lib/providers/run_provider.dart:175-250` - startRun/stopRun flow to update
- `lib/services/run_tracker.dart` - RunTracker using RunSession (update to Run)

**Test References** (testing patterns to follow):
- `test/widget_test.dart` - App smoke test

**WHY Each Reference Matters**:
- `main.dart:76-98`: Where repositories need to be initialized
- `run_provider.dart:175-250`: Core run flow that uses Run model

**Acceptance Criteria**:

**TDD (tests first):**
- [ ] All existing tests pass: `flutter test`
- [ ] App launches without errors
- [ ] Can complete a run (start → GPS tracking → stop → save)
- [ ] Run history shows past runs correctly
- [ ] Leaderboard loads and filters correctly
- [ ] Hex map displays colors correctly

**Automated Verification:**
```bash
# Agent runs:
flutter test
# Assert: ALL tests pass

flutter analyze
# Assert: 0 errors

flutter run -d macos &
sleep 10
# Assert: App launches without crash
```

**Commit**: YES
- Message: `feat(integration): complete data architecture migration with repositories`
- Files: `lib/main.dart`, `lib/providers/run_provider.dart`, `lib/services/run_tracker.dart`
- Pre-commit: `flutter test`

---

### - [ ] 9. Final Verification & Documentation

**What to do**:
1. Run complete test suite
2. Verify memory footprint reduction (single cache vs dual)
3. Verify download volume reduction (delta sync)
4. Update AGENTS.md with new architecture documentation
5. Create migration notes for team

**Must NOT do**:
- DO NOT create new README files (only update existing)
- DO NOT skip any verification step

**Recommended Agent Profile**:
- **Category**: `writing`
  - Reason: Documentation update task
- **Skills**: [`moai-lang-flutter`]
  - `moai-lang-flutter`: Flutter architecture documentation

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 4 (final)
- **Blocks**: None (final task)
- **Blocked By**: All previous tasks

**References**:

**Documentation References**:
- `AGENTS.md` - Main documentation to update
- `README.md` - Project overview (update architecture section if exists)

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
flutter test
# Assert: ALL tests pass (100%)

flutter analyze
# Assert: 0 errors, 0 warnings

# Memory comparison (manual):
# Before: 2 hex caches (~800KB)
# After: 1 hex cache (~400KB)
# Savings: ~400KB
```

**Commit**: YES
- Message: `docs: update architecture documentation for repository pattern`
- Files: `AGENTS.md`
- Pre-commit: `flutter test`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(models): add unified Run model with computed getters` | `lib/models/run.dart`, `test/models/run_test.dart` | `flutter test test/models/run_test.dart` |
| 2 | `feat(repositories): add UserRepository as single source of truth` | `lib/repositories/user_repository.dart`, `test/repositories/user_repository_test.dart` | `flutter test test/repositories/user_repository_test.dart` |
| 3 | `feat(repositories): add HexRepository consolidating dual caches` | `lib/repositories/hex_repository.dart`, `test/repositories/hex_repository_test.dart` | `flutter test test/repositories/hex_repository_test.dart` |
| 4 | `feat(repositories): add LeaderboardRepository consolidating caches` | `lib/repositories/leaderboard_repository.dart`, `test/repositories/leaderboard_repository_test.dart` | `flutter test test/repositories/leaderboard_repository_test.dart` |
| 5 | `refactor(providers): delegate to repositories as single source of truth` | `lib/providers/*.dart`, `test/providers/provider_integration_test.dart` | `flutter test` |
| 6 | `feat(sync): implement delta sync for hexes using since_time parameter` | Multiple files | `flutter test test/services/delta_sync_test.dart` |
| 7 | `chore(cleanup): remove legacy run models and dead sync_queue code` | Multiple deletions | `flutter test` |
| 8 | `feat(integration): complete data architecture migration with repositories` | `lib/main.dart`, etc. | `flutter test` |
| 9 | `docs: update architecture documentation for repository pattern` | `AGENTS.md` | `flutter test` |

---

## Success Criteria

### Verification Commands
```bash
# All tests pass
flutter test
# Expected: All tests pass, 0 failures

# No analysis issues
flutter analyze
# Expected: 0 errors, 0 warnings

# App runs
flutter run -d macos
# Expected: App launches, all features work
```

### Final Checklist
- [ ] All "Must Have" present (offline-first, backward compat, TDD)
- [ ] All "Must NOT Have" absent (no UI changes, no schema changes, no broken APIs)
- [ ] All tests pass (existing + new)
- [ ] Memory footprint reduced (single cache)
- [ ] Download volume reduced (delta sync)
- [ ] No duplicate data storage
