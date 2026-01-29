# Draft: Stability Score & Distance UI Fixes

## Requirements (confirmed)

### Issue 1: Stability Score Not Shown in Run History
- **User Request**: Add stability score display to run history (both list and calendar views)
- **Current State**: 
  - `RunSession` model (used for history) does NOT have `cv` or `stabilityScore` fields
  - `RunSummary` model HAS these fields (`cv` field + `stabilityScore` getter)
  - `StorageService.getAllRuns()` returns `List<RunSession>` (the interface)
  - `LocalStorage.getAllRuns()` converts `RunSummary` → `RunSession`, losing CV data
  - History UI uses `RunSession` which lacks cv
- **Solution Approach**: 
  - Option A: Add `cv` field to `RunSession` and propagate through storage (SIMPLER)
  - Option B: Change `StorageService` interface to return `RunSummary` (BIGGER CHANGE)
  - **Decision**: Option A - Add `cv` field to `RunSession` (minimal change, maintains backward compatibility)

### Issue 2: Total Distance Not Shown for Ranks 4+
- **User Request**: Add total distance display for ranks 4+ in leaderboard
- **Current State**:
  - Podium cards (1-3) show: `${runner.totalDistanceKm.toStringAsFixed(0)}km` + stability
  - Rank tiles (4+) show: rank, avatar, name, stability badge, points, team dot
  - `LeaderboardEntry` HAS `totalDistanceKm` field
  - `_buildRankTile()` does NOT display distance
- **Solution**: Simply add distance display to `_buildRankTile()` matching podium pattern

## Technical Decisions

### RunSession Model Changes
- Add `cv` field as optional `double?`
- Add `stabilityScore` getter derived from `cv` (same logic as RunSummary)
- No breaking changes - cv is optional with null default

### LocalStorage.getAllRuns() Changes  
- Already parses `RunSummary.fromMap()` which includes cv
- Just need to pass cv to `RunSession` constructor

### UI Display Pattern
- Stability badge: Use existing `_getStabilityColor()` function
- Format: `{score}%` with color coding (Green ≥80, Yellow 50-79, Red <50)
- Distance: `{km}km` format matching podium

## Research Findings

### Existing Pattern: Podium Card Stability Display (leaderboard_screen.dart:766-798)
```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text('${runner.totalDistanceKm.toStringAsFixed(0)}km', style: ...),
    if (runner.stabilityScore != null) ...[
      // dot separator
      Text('${runner.stabilityScore}%', style: ...),
    ],
  ],
)
```

### Existing Pattern: Rank Tile Stability Badge (leaderboard_screen.dart:932-954)
```dart
if (runner.stabilityScore != null) ...[
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: _getStabilityColor(runner.stabilityScore!).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text('${runner.stabilityScore}%', style: ...),
  ),
  const SizedBox(width: 8),
],
```

### Stability Color Function (leaderboard_screen.dart:1058-1062)
```dart
Color _getStabilityColor(int score) {
  if (score >= 80) return const Color(0xFF22C55E); // Green
  if (score >= 50) return const Color(0xFFF59E0B); // Amber
  return const Color(0xFFEF4444); // Red
}
```

## Open Questions
- None - all requirements confirmed by user

## User Decisions (Confirmed)
1. **Stability Display Format**: Same as leaderboard (`{score}%` with color coding)
2. **Placement in Run Tile (List View)**: After pace in secondary stats row (time · pace · stability)
3. **Placement in Calendar Card**: After flips (far right)
4. **Placement in Rank Tile (4+)**: Between name and stability badge as small text "{distance}km"
5. **Null Handling**: Hide stability completely when null (matches leaderboard)

## Scope Boundaries
- INCLUDE: 
  - Add cv field to RunSession model
  - Update LocalStorage to pass cv to RunSession
  - Add stability badge to _buildRunTile() in run_history_screen.dart
  - Add stability badge to _buildRunCard() in run_calendar.dart
  - Add distance display to _buildRankTile() in leaderboard_screen.dart
- EXCLUDE:
  - Changing StorageService interface (too invasive)
  - Adding cv calculation logic (already exists in RunSummary)
  - Modifying RunProvider (uses RunSession correctly)
  - Backend changes (cv already stored)

## Test Strategy Decision
- **Infrastructure exists**: YES (flutter test exists per AGENTS.md)
- **User wants tests**: Not explicitly requested
- **QA approach**: Manual verification (visual UI changes)
