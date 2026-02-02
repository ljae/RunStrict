# Draft: Team Screen Implementation

## Requirements (confirmed from user request)

### Layout Structure (top to bottom)
1. **Yesterday's User Record Panel** - Same design as run_history's ALL-TIME panel (glassmorphism)
2. **Hex Status Panel** - ALL Range (left) + City Range (right) with proportional bars
3. **Team Comparison Section** - User's team (left) vs Other team (right)
4. **Buff Explanation** - Why today's buff is X, what it would be if on other team
5. **Purple Change Button** - Strict warning, confirmation flow

### Profile Display Rules
- No avatar/icon images
- Show: User ID + 12-char manifesto with neon glow styling
- Manifesto changes affect tomorrow's display for others

## Technical Decisions

### Files to Create
- `lib/screens/team_screen.dart` - Main screen
- `lib/providers/team_stats_provider.dart` - Team comparison data provider
- `supabase/migrations/009_team_stats.sql` - RPC functions

### Files to Modify
- `lib/screens/home_screen.dart` - Add TeamScreen at navigation index 2
- `lib/services/supabase_service.dart` - Add RPC wrappers for team stats

## Research Findings

### Existing Patterns (from codebase exploration)

**Glassmorphism Pattern** (map_screen.dart:357-370):
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(14),
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
      // content
    ),
  ),
);
```

**Stats Panel Pattern** (run_history_screen.dart:1003-1106):
- Container with `AppTheme.surfaceColor.withOpacity(0.3)`
- Row layout with flex-based sections
- Vertical dividers: `Container(width: 1, height: 32, color: Colors.white.withOpacity(0.06))`
- Typography: `GoogleFonts.sora` for values, `GoogleFonts.inter` for labels

**Proportional Bar Pattern** (map_screen.dart:408-439):
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(3),
  child: SizedBox(
    height: 6,
    child: Row(
      children: [
        if (stats.redCount > 0)
          Expanded(flex: stats.redCount, child: Container(color: AppTheme.athleticRed)),
        if (stats.blueCount > 0)
          Expanded(flex: stats.blueCount, child: Container(color: AppTheme.electricBlue)),
        // ...
      ],
    ),
  ),
);
```

**Provider Pattern** (from leaderboard_provider.dart):
```dart
class TeamStatsProvider with ChangeNotifier {
  final SupabaseService _supabaseService;

  TeamStatsProvider({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService();

  // State + notifyListeners()
}
```

### BuffBreakdown Model (buff_service.dart:6-45)
- multiplier, baseBuff, allRangeBonus
- reason, team, cityHex
- isCityLeader, isElite

### Buff Configuration (app_config.dart:160-277)
- RED Elite: Top 20% (redEliteThreshold=0.20)
  - Elite + City Leader: 3x
  - Elite + Non-Leader: 2x
  - Common: 1x
- BLUE Union:
  - City Leader: 2x
  - Non-Leader: 1x
- All Range Bonus: +1x for RED/BLUE if team dominates server-wide
- PURPLE:
  - ≥60% participation: 3x
  - 30-60%: 2x
  - <30%: 1x
  - No All Range bonus

### Home Screen Navigation (home_screen.dart)
- Current 4 tabs: Map(0), Run(1), History(2), Leaderboard(3)
- Replace History at index 2 with TeamScreen
- Icon should be `Icons.groups_rounded` (team icon)

### Existing RPC Patterns (supabase_service.dart)
```dart
final result = await client.rpc('function_name', params: {'p_param': value});
```

### Migration Naming Convention
- Sequential: `009_team_stats.sql`
- Function pattern: `CREATE OR REPLACE FUNCTION public.function_name(...) RETURNS JSONB`

## Open Questions

1. **Yesterday's Stats**: What specific fields to show?
   - Confirmed: Distance, Pace, Flips, Stability (same as ALL-TIME panel)
   - Source: `run_history` table filtered by yesterday's date

2. **Team Comparison Data**: What to show for each team?
   - RED: Elite group (top 20%) top 3 + Common group top 3
   - BLUE: Top 3 runners
   - User's position within their group

3. **Neon Glow for Manifesto**: How to style?
   - Use team color with shadow glow effect
   - Multiple stacked shadows for bloom effect

## Scope Boundaries

### INCLUDE
- Yesterday's stats panel
- Dual hex status (ALL + City)
- Team comparison with rankings
- Buff explanation with hypothetical
- Purple gate with confirmation

### EXCLUDE
- Avatar/icon display
- Real-time updates (fetch on screen load)
- Crew-related features (deprecated)
- Complex animations (keep simple)
