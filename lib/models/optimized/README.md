# Optimized Data Architecture

## Data Classification (Hot vs Cold)

### HOT DATA (Season-scoped, Reset on D-Day)
- `hexes/` - Last runner team colors
- `seasonStats/` - Current season flip points

### WARM DATA (Aggregated, Preserved)
- `dailyStats/` - Daily aggregated stats (distance, pace, flips)
- `users/` - User profile (team resets, points reset)

### COLD DATA (Historical, Never deleted)
- `runArchive/` - Completed run summaries (no routes)
- `routeArchive/` - GPS routes (compressed, optional download)

## Memory Management Strategy

1. **LRU Cache** for hex data (max 500 hexes in memory)
2. **Pagination** for run history (load 20 at a time)
3. **Lazy Loading** for routes (only when viewing detail)
4. **Batch Writes** for Supabase (reduce write operations)

## Season Reset Protocol

On D-Day:
1. Archive `seasonStats/` → `seasonArchive/{seasonId}/`
2. Clear `hexes/` collection
3. Reset `users/{userId}.seasonPoints` to 0
4. Reset `users/{userId}.team` to null (re-selection)
5. Preserve `dailyStats/` and `runArchive/`
