# Team Screen Implementation

## TL;DR

> **Quick Summary**: Create a comprehensive Team Screen that displays yesterday's stats, hex dominance across ALL/City ranges, team rankings with buff explanations, and a Purple defection gate - replacing the History tab in navigation.
> 
> **Deliverables**:
> - `lib/screens/team_screen.dart` - Main UI with 5 sections
> - `lib/providers/team_stats_provider.dart` - State management for team data
> - `lib/widgets/neon_manifesto_widget.dart` - Reusable neon glow text widget
> - `supabase/migrations/009_team_stats.sql` - Server-side RPC functions
> - Modified `home_screen.dart` with TeamScreen at index 2
> - Modified `supabase_service.dart` with new RPC wrappers
> 
> **Estimated Effort**: Medium (3-4 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (SQL) → Task 4 (Service) → Task 5 (Provider) → Task 6 (Screen)

---

## Context

### Original Request
Create a Team Screen that replaces Crew Screen with:
1. Yesterday's User Record Panel (run_history ALL-TIME style)
2. Hex Status Panel (ALL Range + City Range proportional bars)
3. Team Comparison Section (RED Elite/Common, BLUE Union rankings)
4. Buff Explanation (current + hypothetical)
5. Purple Change Button (strict warning, confirmation)

Profile display: User ID + 12-char manifesto with neon glow, no avatars.

### Research Findings
**Pattern Sources Identified**:
- `run_history_screen.dart:1003-1106` - ALL-TIME stats panel design
- `map_screen.dart:341-526` - TeamStatsOverlay with proportional bars
- `map_screen.dart:357-370` - Glassmorphism with BackdropFilter
- `leaderboard_provider.dart` - Provider pattern with ChangeNotifier
- `buff_service.dart:6-45` - BuffBreakdown model structure
- `app_config.dart:160-277` - Buff thresholds (Elite 20%, participation rates)

**Existing Infrastructure**:
- `daily_buff_stats` table - City-level buff calculations
- `daily_all_range_stats` table - Server-wide hex dominance
- `get_user_buff` RPC - Returns multiplier breakdown
- `run_history` table - Historical run data for yesterday's stats

### Gap Analysis (Self-Identified)

**Questions Addressed**:
1. Team Comparison Layout: Show BOTH Elite + Common for RED side (user sees their group highlighted)
2. Data Fetching: New RPC functions for server-side calculations (cleaner)
3. Navigation: Replace History at index 2 (user specified "in place of CrewScreen")

**Guardrails Applied**:
- No avatar/icon images in profile display
- 12-character manifesto limit enforced
- Neon glow uses team color (not hardcoded)
- No real-time subscriptions (fetch on load only)

**Edge Cases to Handle**:
- New user with no yesterday data → Show "No runs yesterday" placeholder
- User not in any Elite/Common group → Show appropriate fallback
- Purple user viewing screen → Different layout (no "other team" comparison)

---

## Work Objectives

### Core Objective
Implement a Team Screen that provides users with comprehensive team-based information including their yesterday's performance, territorial dominance, team rankings, buff mechanics, and path to Purple defection.

### Concrete Deliverables
- `lib/screens/team_screen.dart` - ~400-500 lines
- `lib/providers/team_stats_provider.dart` - ~150 lines
- `lib/widgets/neon_manifesto_widget.dart` - ~60 lines
- `supabase/migrations/009_team_stats.sql` - ~200 lines
- Modified `lib/services/supabase_service.dart` - +30 lines
- Modified `lib/screens/home_screen.dart` - +10 lines

### Definition of Done
- [ ] `flutter analyze` returns 0 errors on all new/modified files
- [ ] TeamScreen accessible via navigation index 2
- [ ] Yesterday's stats display correctly (or placeholder if no data)
- [ ] Hex dominance bars show accurate counts from database
- [ ] Team rankings show top 3 per group with user position highlighted
- [ ] Buff explanation matches `get_user_buff` response
- [ ] Purple gate shows confirmation before defection
- [ ] Manifesto renders with neon glow effect

### Must Have
- Yesterday's stats panel with Distance, Pace, Flips, Stability
- Dual hex status (ALL Range + City Range) with proportional bars
- Team comparison showing rankings by group
- Current buff explanation with reason
- Hypothetical buff display ("If you were BLUE: Xx")
- Purple gate with strict warning text
- Neon manifesto styling with team color

### Must NOT Have (Guardrails)
- No avatar/icon images in any profile display
- No real-time WebSocket subscriptions
- No crew-related functionality (deprecated system)
- No 3D rendering or complex animations
- No hardcoded buff values (use BuffConfig from remote config)
- No client-side buff calculation (always use server RPC)
- No storing derived data in local state (fetch fresh on load)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test, bun test available)
- **User wants tests**: TDD for business logic, manual verification for UI
- **Framework**: flutter test

### Automated Verification

**For Flutter Widget/Provider changes** (using flutter test):
```bash
# Run widget tests
flutter test test/screens/team_screen_test.dart

# Run provider tests  
flutter test test/providers/team_stats_provider_test.dart

# Run all tests
flutter test
```

**For SQL RPC functions** (using psql/supabase):
```bash
# Test RPC via Supabase CLI
supabase functions invoke get_user_yesterday_stats --data '{"p_user_id": "test-uuid"}'
```

**For Integration** (using flutter run):
```bash
# Visual verification on simulator
flutter run -d ios
# Navigate to Team tab, verify all sections render
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Infrastructure):
├── Task 1: Create SQL migrations (009_team_stats.sql)
├── Task 2: Create NeonManifestoWidget
└── Task 3: Create placeholder TeamScreen with navigation

Wave 2 (After Wave 1):
├── Task 4: Add RPC wrappers to SupabaseService
└── Task 5: Create TeamStatsProvider

Wave 3 (After Wave 2):
├── Task 6: Implement full TeamScreen UI sections
└── Task 7: Implement Purple Gate confirmation flow

Wave 4 (After Wave 3):
└── Task 8: Integration testing and polish

Critical Path: Task 1 → Task 4 → Task 5 → Task 6
Parallel Speedup: ~40% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 4, 5 | 2, 3 |
| 2 | None | 6 | 1, 3 |
| 3 | None | 6 | 1, 2 |
| 4 | 1 | 5, 6 | None |
| 5 | 4 | 6 | None |
| 6 | 2, 3, 5 | 7 | None |
| 7 | 6 | 8 | None |
| 8 | 7 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1, 2, 3 | 3 parallel sisyphus-junior agents |
| 2 | 4, 5 | 2 sequential (4 then 5) |
| 3 | 6, 7 | 2 sequential (6 then 7) |
| 4 | 8 | 1 integration task |

---

## TODOs

- [ ] 1. Create SQL Migrations for Team Stats RPCs

  **What to do**:
  - Create `supabase/migrations/009_team_stats.sql`
  - Implement `get_user_yesterday_stats(p_user_id UUID)` RPC:
    - Query `run_history` for user's runs on yesterday's date
    - Return: distance_km, avg_pace, flip_count, stability_score (derived from CV)
    - Handle no-data case: return nulls with `has_data: false`
  - Implement `get_team_rankings(p_user_id UUID, p_city_hex TEXT)` RPC:
    - For RED: Return Elite group (top 20%) top 3 + Common group top 3
    - For BLUE: Return Union top 3
    - Include user's rank within their group
    - Use yesterday's flip_points for Elite threshold
  - Implement `get_hex_dominance(p_city_hex TEXT)` RPC:
    - Return ALL Range hex counts (from daily_all_range_stats)
    - Return City Range hex counts (from daily_buff_stats)
    - Include dominant_team for each scope
  - Add indexes for performance on run_history(user_id, run_date)

  **Must NOT do**:
  - Do NOT modify existing RPC functions (get_user_buff, etc.)
  - Do NOT create tables (use existing daily_buff_stats, daily_all_range_stats)
  - Do NOT include real-time subscriptions

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex SQL logic with joins, CTEs, and window functions
  - **Skills**: []
    - No specific skill needed - pure SQL
  - **Skills Evaluated but Omitted**:
    - `supabase-*` skills: Not needed for raw SQL migration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5 (need RPC functions deployed)
  - **Blocked By**: None (can start immediately)

  **References** (CRITICAL):
  
  **Pattern References**:
  - `supabase/migrations/008_buff_system.sql:70-216` - calculate_daily_buffs pattern for CTE usage
  - `supabase/migrations/008_buff_system.sql:224-370` - get_user_buff for JSONB return pattern
  
  **API/Type References**:
  - `lib/models/daily_running_stat.dart:1-89` - Expected fields for yesterday stats
  - `lib/services/buff_service.dart:6-45` - BuffBreakdown structure for reference
  
  **Database References**:
  - `supabase/migrations/008_buff_system.sql:17-45` - daily_buff_stats table structure
  - `supabase/migrations/001_initial_schema.sql` - run_history table structure

  **WHY Each Reference Matters**:
  - `008_buff_system.sql` shows exact CTE patterns and JSONB construction used in project
  - `daily_running_stat.dart` defines the exact field names expected by Flutter
  - Existing tables provide the data sources for aggregations

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs via Supabase SQL Editor or psql:
  
  # 1. Deploy migration
  supabase db push
  
  # 2. Verify functions exist
  SELECT routine_name FROM information_schema.routines 
  WHERE routine_schema = 'public' 
  AND routine_name IN ('get_user_yesterday_stats', 'get_team_rankings', 'get_hex_dominance');
  # Assert: Returns 3 rows
  
  # 3. Test get_user_yesterday_stats (with existing user)
  SELECT public.get_user_yesterday_stats('existing-user-uuid');
  # Assert: Returns JSONB with keys: distance_km, avg_pace, flip_count, stability_score, has_data
  
  # 4. Test with non-existent user
  SELECT public.get_user_yesterday_stats('00000000-0000-0000-0000-000000000000');
  # Assert: Returns JSONB with has_data: false
  ```

  **Evidence to Capture**:
  - [ ] Screenshot of successful migration deployment
  - [ ] Query results showing all 3 functions created

  **Commit**: YES
  - Message: `feat(db): add team stats RPC functions for yesterday stats and rankings`
  - Files: `supabase/migrations/009_team_stats.sql`
  - Pre-commit: N/A (SQL file)

---

- [ ] 2. Create NeonManifestoWidget Component

  **What to do**:
  - Create `lib/widgets/neon_manifesto_widget.dart`
  - Implement reusable widget with neon glow effect using team color
  - Stack multiple Text shadows for bloom effect:
    ```dart
    shadows: [
      Shadow(color: teamColor.withOpacity(0.8), blurRadius: 4),
      Shadow(color: teamColor.withOpacity(0.6), blurRadius: 8),
      Shadow(color: teamColor.withOpacity(0.4), blurRadius: 16),
    ]
    ```
  - Accept parameters: text, teamColor, fontSize
  - Use GoogleFonts.sora for text style
  - Include fallback for empty manifesto: show "---" in muted style

  **Must NOT do**:
  - Do NOT create animation effects (static glow only)
  - Do NOT exceed 12 character display (truncate if needed)
  - Do NOT use hardcoded colors (use passed teamColor)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI widget with visual styling focus
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Neon glow styling expertise
  - **Skills Evaluated but Omitted**:
    - `frontend-design`: Overkill for single widget

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 6 (TeamScreen uses this widget)
  - **Blocked By**: None (can start immediately)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/theme/app_theme.dart:236-245` - glowShadow pattern for reference
  - `lib/theme/neon_theme.dart` - If exists, neon color definitions
  
  **API/Type References**:
  - `lib/models/team.dart:44-53` - Team.color getter for team colors
  
  **Style References**:
  - `lib/screens/run_history_screen.dart:1045-1052` - GoogleFonts.sora usage pattern

  **WHY Each Reference Matters**:
  - `app_theme.dart` shows existing shadow patterns to maintain consistency
  - `team.dart` provides the exact color values for each team
  - `run_history_screen.dart` shows how Sora font is used in similar contexts

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs:
  flutter analyze lib/widgets/neon_manifesto_widget.dart
  # Assert: No issues found
  
  # Widget test
  flutter test test/widgets/neon_manifesto_widget_test.dart
  # Assert: All tests pass
  ```

  **Widget Test Cases**:
  - [ ] Renders text with team color glow
  - [ ] Handles empty string → shows "---"
  - [ ] Handles 12+ characters → truncates
  - [ ] Different team colors produce different glows

  **Evidence to Capture**:
  - [ ] flutter analyze output showing 0 issues
  - [ ] test output showing all cases pass

  **Commit**: YES
  - Message: `feat(widgets): add NeonManifestoWidget with team-colored glow effect`
  - Files: `lib/widgets/neon_manifesto_widget.dart`, `test/widgets/neon_manifesto_widget_test.dart`
  - Pre-commit: `flutter analyze && flutter test test/widgets/neon_manifesto_widget_test.dart`

---

- [ ] 3. Create Placeholder TeamScreen with Navigation

  **What to do**:
  - Create `lib/screens/team_screen.dart` with placeholder structure
  - Add basic scaffold with "TEAM" title using existing AppBar pattern
  - Include placeholder widgets for each section (commented TODOs)
  - Import TeamScreen in `lib/screens/home_screen.dart`
  - Replace index 2 in `_screens` list with `TeamScreen()`
  - Change navigation icon at index 2 to `Icons.groups_rounded`
  - Verify navigation works (tap index 2 shows TeamScreen)

  **Must NOT do**:
  - Do NOT implement actual sections yet (placeholder only)
  - Do NOT add provider dependencies yet
  - Do NOT change other navigation indices

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file creation and import changes
  - **Skills**: []
    - No skills needed for scaffolding
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Overkill for placeholder

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 6 (provides file to implement)
  - **Blocked By**: None (can start immediately)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/screens/home_screen.dart:32-37` - _screens list structure
  - `lib/screens/home_screen.dart:248-266` - Navigation bar item structure
  - `lib/screens/leaderboard_screen.dart:1-50` - Screen scaffold pattern
  
  **Import References**:
  - `lib/screens/home_screen.dart:13-16` - Existing screen imports

  **WHY Each Reference Matters**:
  - `home_screen.dart:32-37` shows exact list structure to modify
  - Navigation bar structure shows how to update icon
  - `leaderboard_screen.dart` shows typical screen structure pattern

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs:
  flutter analyze lib/screens/team_screen.dart
  flutter analyze lib/screens/home_screen.dart
  # Assert: No issues found
  
  # Build verification
  flutter build ios --no-codesign
  # Assert: Build succeeds
  ```

  **Manual Verification (via flutter run)**:
  ```
  1. Launch app: flutter run -d ios
  2. Tap navigation index 2 (groups icon)
  3. Assert: TeamScreen placeholder appears with "TEAM" title
  4. Assert: Icon shows groups_rounded at index 2
  ```

  **Evidence to Capture**:
  - [ ] flutter analyze output for both files
  - [ ] Screenshot of navigation showing groups icon

  **Commit**: YES
  - Message: `feat(nav): add TeamScreen placeholder at navigation index 2`
  - Files: `lib/screens/team_screen.dart`, `lib/screens/home_screen.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 4. Add RPC Wrappers to SupabaseService

  **What to do**:
  - Add to `lib/services/supabase_service.dart`:
    - `getUserYesterdayStats(String userId)` → calls `get_user_yesterday_stats`
    - `getTeamRankings(String userId, String? cityHex)` → calls `get_team_rankings`
    - `getHexDominance(String? cityHex)` → calls `get_hex_dominance`
  - Follow existing RPC pattern: `client.rpc('name', params: {...})`
  - Return `Map<String, dynamic>` for JSONB responses
  - Handle null cityHex by passing null to RPC

  **Must NOT do**:
  - Do NOT modify existing RPC methods
  - Do NOT add error handling beyond what exists (keep consistent)
  - Do NOT add caching (provider handles that)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple method additions following existing pattern
  - **Skills**: []
    - No skills needed - copy existing pattern
  - **Skills Evaluated but Omitted**:
    - `supabase-*`: Pattern already established in file

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential)
  - **Blocks**: Task 5 (provider uses these methods)
  - **Blocked By**: Task 1 (RPC functions must exist in DB)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/services/supabase_service.dart:28-34` - getLeaderboard RPC pattern
  - `lib/services/supabase_service.dart:96-108` - getUserBuff pattern with JSONB return
  
  **Signature References**:
  - Task 1 RPC signatures (from 009_team_stats.sql)

  **WHY Each Reference Matters**:
  - Existing RPC methods show exact calling pattern
  - getUserBuff shows how to handle JSONB returns with fallbacks

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs:
  flutter analyze lib/services/supabase_service.dart
  # Assert: No issues found
  
  # Verify methods exist (grep)
  grep -n "getUserYesterdayStats\|getTeamRankings\|getHexDominance" lib/services/supabase_service.dart
  # Assert: 3 method definitions found
  ```

  **Evidence to Capture**:
  - [ ] flutter analyze output
  - [ ] grep output showing method locations

  **Commit**: YES
  - Message: `feat(service): add team stats RPC wrappers to SupabaseService`
  - Files: `lib/services/supabase_service.dart`
  - Pre-commit: `flutter analyze lib/services/supabase_service.dart`

---

- [ ] 5. Create TeamStatsProvider

  **What to do**:
  - Create `lib/providers/team_stats_provider.dart`
  - Extend `ChangeNotifier` following LeaderboardProvider pattern
  - Inject `SupabaseService` via constructor
  - State fields:
    - `YesterdayStats? yesterdayStats` (model with distance, pace, flips, stability)
    - `TeamRankings? rankings` (model with groups and user position)
    - `HexDominance? dominance` (model with ALL/City counts)
    - `bool isLoading`, `String? error`
  - Methods:
    - `loadTeamData(String userId, String? cityHex)` - fetches all data
    - `refresh(String userId, String? cityHex)` - force refresh
    - `clear()` - reset state
  - Create supporting model classes in same file or separate:
    - `YesterdayStats` - fromJson factory
    - `TeamRankings` - with nested group lists
    - `HexDominance` - ALL + City counts

  **Must NOT do**:
  - Do NOT cache across sessions (always fetch fresh)
  - Do NOT add real-time subscriptions
  - Do NOT duplicate BuffService logic (use existing for buff data)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: State management with model classes
  - **Skills**: []
    - Pattern established in codebase
  - **Skills Evaluated but Omitted**:
    - `vercel-react-best-practices`: Wrong framework

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Task 4)
  - **Blocks**: Task 6 (screen consumes this provider)
  - **Blocked By**: Task 4 (uses SupabaseService methods)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/providers/leaderboard_provider.dart:76-129` - Full provider pattern with loading/error
  - `lib/providers/hex_data_provider.dart` - Singleton vs DI comparison
  
  **Model References**:
  - `lib/models/daily_running_stat.dart:1-89` - Model with fromJson pattern
  - `lib/services/buff_service.dart:6-45` - BuffBreakdown model structure

  **WHY Each Reference Matters**:
  - `leaderboard_provider.dart` is the exact pattern to follow
  - Model files show fromJson/copyWith patterns used in project

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs:
  flutter analyze lib/providers/team_stats_provider.dart
  # Assert: No issues found
  
  # Unit tests
  flutter test test/providers/team_stats_provider_test.dart
  # Assert: All tests pass
  ```

  **Test Cases**:
  - [ ] loadTeamData sets isLoading during fetch
  - [ ] loadTeamData populates all three state fields
  - [ ] Error handling sets error string
  - [ ] clear() resets all state to initial

  **Evidence to Capture**:
  - [ ] flutter analyze output
  - [ ] test output with pass/fail counts

  **Commit**: YES
  - Message: `feat(provider): add TeamStatsProvider with yesterday stats and rankings`
  - Files: `lib/providers/team_stats_provider.dart`, `test/providers/team_stats_provider_test.dart`
  - Pre-commit: `flutter analyze && flutter test test/providers/team_stats_provider_test.dart`

---

- [ ] 6. Implement Full TeamScreen UI

  **What to do**:
  - Replace placeholder in `lib/screens/team_screen.dart` with full implementation
  - Wrap with `ChangeNotifierProvider<TeamStatsProvider>`
  - Implement 5 sections using Consumer pattern:
  
  **Section 1: Yesterday's Record Panel**
  - Copy styling from `_buildOverallStatsSection` in run_history_screen.dart
  - Show Distance, Pace, Flips, Stability in horizontal row
  - Handle no-data: show "No runs yesterday" message
  
  **Section 2: Hex Status Panel**
  - Split into left (ALL Range) and right (City Range)
  - Use proportional bar pattern from _TeamStatsOverlay
  - Show hex counts for RED/BLUE/PURPLE per scope
  - Highlight dominant team indicator
  
  **Section 3: Team Comparison**
  - Left side: User's team rankings by group
  - Right side: Other team rankings
  - For RED: Show Elite group + Common group
  - For BLUE: Show Union (single group)
  - Highlight user's position in their group
  - Profile display: User ID + NeonManifestoWidget (no avatar)
  
  **Section 4: Buff Explanation**
  - Use existing BuffBreakdown from BuffService
  - Display: "Your buff: {multiplier}x ({reason})"
  - Calculate hypothetical: "If you were {OTHER_TEAM}: Xx"
  - Use BuffConfig thresholds for hypothetical
  
  **Section 5: Purple Gate Button**
  - Show only if user is RED or BLUE
  - Button text: "CHAOS AWAITS"
  - Warning text: "No return to {current_team}" (strict, minimal)
  - Tap → confirmation dialog → navigate to TraitorGateScreen

  **Must NOT do**:
  - Do NOT add avatar/icon display anywhere
  - Do NOT implement real-time updates
  - Do NOT hardcode buff values (use BuffConfig)
  - Do NOT skip loading states

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Complex UI implementation with existing patterns
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Glassmorphism and layout expertise
  - **Skills Evaluated but Omitted**:
    - `frontend-design`: Using existing design patterns, not creating new

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential after Wave 2)
  - **Blocks**: Task 7 (Purple gate depends on screen)
  - **Blocked By**: Tasks 2, 3, 5 (needs widget, placeholder, provider)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/screens/run_history_screen.dart:1003-1106` - Yesterday stats panel styling
  - `lib/screens/map_screen.dart:341-526` - _TeamStatsOverlay proportional bars
  - `lib/screens/map_screen.dart:357-370` - Glassmorphism BackdropFilter pattern
  - `lib/screens/leaderboard_screen.dart:729-916` - Ranking display pattern
  
  **Widget References**:
  - `lib/widgets/neon_manifesto_widget.dart` - Created in Task 2
  
  **Service References**:
  - `lib/services/buff_service.dart:47-128` - BuffService for current buff
  - `lib/models/app_config.dart:160-277` - BuffConfig for hypothetical calculation
  
  **Navigation References**:
  - `lib/screens/traitor_gate_screen.dart` - Purple defection screen (existing)

  **WHY Each Reference Matters**:
  - run_history_screen.dart provides exact styling for stats panel
  - map_screen.dart shows proportional bar implementation
  - leaderboard_screen.dart shows ranking UI patterns
  - buff_service.dart provides current user's buff data
  - traitor_gate_screen.dart is navigation target for Purple gate

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs:
  flutter analyze lib/screens/team_screen.dart
  # Assert: No issues found
  
  # Build verification
  flutter build ios --no-codesign
  # Assert: Build succeeds
  ```

  **Manual Verification (via flutter run)**:
  ```
  1. Launch app: flutter run -d ios
  2. Navigate to Team tab
  3. Verify Section 1: Yesterday stats show or "No runs yesterday"
  4. Verify Section 2: Dual proportional bars visible
  5. Verify Section 3: Rankings show with user highlighted
  6. Verify Section 4: Buff explanation matches BuffService data
  7. Verify Section 5: Purple button visible (if not purple team)
  8. Screenshot: .sisyphus/evidence/task-6-team-screen.png
  ```

  **Evidence to Capture**:
  - [ ] flutter analyze output
  - [ ] Screenshot of completed Team Screen

  **Commit**: YES
  - Message: `feat(screen): implement TeamScreen with stats, rankings, and buff display`
  - Files: `lib/screens/team_screen.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 7. Implement Purple Gate Confirmation Flow

  **What to do**:
  - Add confirmation dialog to Purple Gate button in TeamScreen
  - Dialog design:
    - Title: "EMBRACE CHAOS?" (centered, BebasNeue)
    - Warning: "No return to {CURRENT_TEAM_NAME}" (muted text)
    - Two buttons: "CANCEL" (secondary), "DEFECT" (purple filled)
  - On confirm:
    - Call existing defection logic from TraitorGateScreen
    - Navigate to TraitorGateScreen or handle inline
  - Show Purple-specific view if user is already Purple:
    - City Purple runners count
    - Yesterday's Purple participation
    - Current participation rate → buff tier

  **Must NOT do**:
  - Do NOT create new defection logic (use existing)
  - Do NOT allow defection before D-140 (season check)
  - Do NOT show Purple gate to Purple users

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Dialog implementation with existing patterns
  - **Skills**: []
    - No special skills needed
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Simple dialog, not complex UI

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (after Task 6)
  - **Blocks**: Task 8 (integration testing)
  - **Blocked By**: Task 6 (button exists in screen)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/screens/traitor_gate_screen.dart` - Existing defection flow and checks
  - `lib/screens/profile_screen.dart:143-147` - TraitorGateButton pattern
  
  **Service References**:
  - `lib/services/season_service.dart` - isPurpleUnlocked check

  **WHY Each Reference Matters**:
  - traitor_gate_screen.dart contains existing defection logic
  - season_service.dart has D-140 check for Purple unlock

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs:
  flutter analyze lib/screens/team_screen.dart
  # Assert: No issues found
  ```

  **Manual Verification (via flutter run)**:
  ```
  1. Launch app as RED/BLUE user
  2. Navigate to Team tab
  3. Tap "CHAOS AWAITS" button
  4. Assert: Confirmation dialog appears
  5. Assert: Warning shows "No return to FLAME" or "No return to WAVE"
  6. Tap "CANCEL" - dialog dismisses
  7. Tap "DEFECT" - navigates to TraitorGateScreen
  8. Screenshot: .sisyphus/evidence/task-7-purple-gate.png
  ```

  **Evidence to Capture**:
  - [ ] Screenshot of confirmation dialog
  - [ ] Screenshot after defection navigation

  **Commit**: YES (groups with Task 6)
  - Message: `feat(screen): add Purple gate confirmation flow`
  - Files: `lib/screens/team_screen.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 8. Integration Testing and Polish

  **What to do**:
  - Run full `flutter analyze` on entire project
  - Run `flutter test` for all tests
  - Manual testing checklist:
    - [ ] Fresh user with no runs → proper fallbacks
    - [ ] RED Elite user → sees Elite ranking highlighted
    - [ ] RED Common user → sees Common ranking highlighted
    - [ ] BLUE user → sees Union ranking
    - [ ] Purple user → no Purple gate, sees Purple stats
    - [ ] Navigation between all tabs works
    - [ ] Buff explanation matches server response
  - Fix any visual polish issues
  - Verify on both iOS simulator and Android emulator if available

  **Must NOT do**:
  - Do NOT add new features
  - Do NOT refactor existing code
  - Do NOT change architecture

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Cross-cutting verification
  - **Skills**: [`systematic-debugging`]
    - `systematic-debugging`: If issues found
  - **Skills Evaluated but Omitted**:
    - `playwright`: Flutter app, not web

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (final)
  - **Blocks**: None (final task)
  - **Blocked By**: Task 7 (all features complete)

  **References** (CRITICAL):

  **All previous task outputs**

  **Acceptance Criteria**:

  **Automated Verification**:
  ```bash
  # Agent runs:
  flutter analyze
  # Assert: No issues found
  
  flutter test
  # Assert: All tests pass
  ```

  **Evidence to Capture**:
  - [ ] flutter analyze full output
  - [ ] flutter test full output
  - [ ] Screenshots of all user scenarios

  **Commit**: YES (if any fixes made)
  - Message: `fix(team): polish and integration fixes`
  - Files: (any files modified)
  - Pre-commit: `flutter analyze && flutter test`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(db): add team stats RPC functions` | 009_team_stats.sql | supabase deploy |
| 2 | `feat(widgets): add NeonManifestoWidget` | neon_manifesto_widget.dart, test | flutter test |
| 3 | `feat(nav): add TeamScreen placeholder` | team_screen.dart, home_screen.dart | flutter analyze |
| 4 | `feat(service): add team stats RPC wrappers` | supabase_service.dart | flutter analyze |
| 5 | `feat(provider): add TeamStatsProvider` | team_stats_provider.dart, test | flutter test |
| 6 | `feat(screen): implement TeamScreen UI` | team_screen.dart | flutter analyze |
| 7 | (groups with 6) | - | - |
| 8 | `fix(team): polish and integration` | (any) | flutter test |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze     # Expected: No issues found
flutter test        # Expected: All tests passing
flutter build ios --no-codesign  # Expected: Build succeeded
```

### Final Checklist
- [ ] All "Must Have" features present
- [ ] All "Must NOT Have" items absent
- [ ] All tests pass
- [ ] flutter analyze returns 0 issues
- [ ] Navigation works correctly
- [ ] All 5 sections render properly
- [ ] Purple gate confirmation works
- [ ] Manifesto has neon glow effect
