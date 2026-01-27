# Map Screen Flashing Bug Fix

## Context

### Original Request
Fix the map screen flashing/flickering when user selects "All" filter (geographic scope). The visual artifact is a brief white/transparent flash before hexes reappear.

### Interview Summary
**Key Discussions**:
- Root cause: `deleteAll()` + `createMulti()` pattern in `_updateHexagons()` (lines 439-441, 497)
- "All" view renders ~3,700 hexes at zoom level 10, making flash very visible
- User chose GeoJSON Source Migration approach over double-buffering or diff-based updates
- Labels (emojis) do NOT flash - only polygon fills
- No smooth transitions needed - instant updates, just eliminate the flash

**Research Findings**:
- Mapbox Flutter SDK `GeoJsonSource.updateGeoJSON(data)` provides atomic dataset replacement
- `FillLayer` supports all needed properties: `fillColor`, `fillOpacity`, `fillOutlineColor`
- `autoMaxZoom: true` recommended for high-frequency updates to prevent artifacts
- Current `PolygonAnnotationManager` is designed for small interactive datasets, not 3,700+ polygons

### Gap Analysis (Self-Review)
**Identified Gaps** (all resolved):
- Layer ordering: Use `belowLayerId` to ensure fill layer renders below labels
- Source/Layer IDs: Define as constants for consistency
- Style readiness: Check `mapboxMap.style` before adding source
- Feature IDs: Use hex ID as GeoJSON feature ID for potential future partial updates
- Cleanup: Remove source and layer in `dispose()`

---

## Work Objectives

### Core Objective
Eliminate visual flashing when updating hex polygons by migrating from AnnotationManager to GeoJSON Source + FillLayer, which supports atomic dataset replacement.

### Concrete Deliverables
- Modified `lib/widgets/hexagon_map.dart` with GeoJSON-based polygon rendering
- No changes to label rendering (`PointAnnotationManager` - works fine)
- No changes to route rendering (`PolylineAnnotationManager` - works fine)

### Definition of Done
- [ ] Switching to "All" filter shows no visible flash/flicker
- [ ] All hex colors render correctly (red, blue, purple, neutral)
- [ ] User's current hex is highlighted correctly
- [ ] Opacity logic preserved (user hex: 0.5, neutral: 0.15, colored: 0.3)
- [ ] App runs without errors on iOS simulator

### Must Have
- Atomic hex polygon updates (no intermediate empty frame)
- Same visual appearance as current implementation
- Same hex color logic and opacity values
- User hex highlighting maintained

### Must NOT Have (Guardrails)
- DO NOT modify `PointAnnotationManager` (labels) - not in scope
- DO NOT modify `PolylineAnnotationManager` (routes) - not in scope
- DO NOT add opacity transitions - user confirmed instant updates preferred
- DO NOT implement diff-based partial updates - atomic replacement is sufficient
- DO NOT refactor beyond the polygon rendering concern
- DO NOT change the hex data model or provider logic

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Flutter test framework)
- **User wants tests**: Manual-only
- **Framework**: N/A - manual verification

### Manual QA Procedures
Each TODO includes specific manual verification steps for the iOS Simulator.

---

## Task Flow

```
Task 1 (Setup GeoJSON infrastructure)
    ↓
Task 2 (Build GeoJSON FeatureCollection)
    ↓
Task 3 (Replace polygon rendering in _updateHexagons)
    ↓
Task 4 (Cleanup and dispose)
    ↓
Task 5 (Final verification)
```

## Parallelization

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | None | Foundation - must be first |
| 2 | 1 | Needs source ID constant |
| 3 | 1, 2 | Needs both infrastructure and builder |
| 4 | 3 | Cleanup after main implementation |
| 5 | 4 | Final verification after all changes |

---

## TODOs

- [ ] 1. Add GeoJSON Source and FillLayer infrastructure

  **What to do**:
  - Add constant IDs at top of `_HexagonMapState`: `static const _hexSourceId = 'hex-source';` and `static const _hexLayerId = 'hex-fill-layer';`
  - In `_onMapCreated`, after existing annotation manager creation, add GeoJSON source setup:
    ```dart
    await mapboxMap.style.addSource(GeoJsonSource(
      id: _hexSourceId,
      data: '{"type":"FeatureCollection","features":[]}',
      autoMaxZoom: true,
    ));
    await mapboxMap.style.addLayer(FillLayer(
      id: _hexLayerId,
      sourceId: _hexSourceId,
      fillColor: Colors.transparent.value,
      fillOpacity: 0.3,
    ));
    ```
  - Note: FillLayer color/opacity will be per-feature via GeoJSON properties

  **Must NOT do**:
  - Do NOT remove `_polygonManager` yet (will remove in Task 3)
  - Do NOT modify label or polyline manager setup

  **Parallelizable**: NO (foundation task)

  **References**:
  
  **Pattern References**:
  - `lib/widgets/hexagon_map.dart:164-169` - Current annotation manager creation pattern (follow similar async/await structure)
  
  **API/Type References**:
  - Mapbox `GeoJsonSource` class - requires `id` and `data` parameters
  - Mapbox `FillLayer` class - requires `id` and `sourceId` parameters
  
  **External References**:
  - Mapbox Flutter docs: GeoJsonSource supports `autoMaxZoom` for high-frequency updates

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Run app: `flutter run -d ios`
  - [ ] App launches without crashes
  - [ ] Map screen loads (hexes may still use old rendering - that's OK)
  - [ ] No console errors about missing source/layer

  **Commit**: NO (groups with Task 2, 3)

---

- [ ] 2. Create GeoJSON FeatureCollection builder method

  **What to do**:
  - Add new private method `_buildHexGeoJson(List<String> hexIds)` that returns a GeoJSON string
  - For each hex ID:
    - Get boundary from `HexService().getHexBoundary(hexId)`
    - Get hex data from `_hexProvider.getHex(hexId, hexCenter)`
    - Determine colors and opacity using existing logic (lines 471-489)
    - Build GeoJSON Feature with Polygon geometry and properties for fill styling
  - Return complete FeatureCollection as JSON string
  - Use `dart:convert` for JSON encoding

  **GeoJSON Feature structure**:
  ```json
  {
    "type": "Feature",
    "id": "hexId",
    "geometry": {
      "type": "Polygon",
      "coordinates": [[[lng, lat], [lng, lat], ...]]
    },
    "properties": {
      "fill-color": "#RRGGBB",
      "fill-opacity": 0.3,
      "fill-outline-color": "#RRGGBB"
    }
  }
  ```

  **Must NOT do**:
  - Do NOT change any color/opacity logic - copy exactly from existing code
  - Do NOT call this method yet (Task 3 will integrate it)

  **Parallelizable**: NO (depends on Task 1 for constants)

  **References**:
  
  **Pattern References**:
  - `lib/widgets/hexagon_map.dart:446-492` - Existing hex iteration and color logic (COPY this logic exactly)
  - `lib/widgets/hexagon_map.dart:471-489` - Color and opacity determination (isUserHex, teamColor, fillColor, opacity)
  
  **API/Type References**:
  - `lib/services/hex_service.dart:33-39` - `getHexBoundary()` returns `List<LatLng>`
  - `lib/providers/hex_data_provider.dart:78-117` - `getHex()` returns `HexModel`
  
  **Documentation References**:
  - GeoJSON spec: Polygon coordinates are `[[[lng, lat], ...]]` (array of rings, each ring is array of positions)
  - Note: GeoJSON uses [longitude, latitude] order (opposite of LatLng)

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Code compiles without errors: `flutter analyze`
  - [ ] Method exists and is callable (will test in Task 3)

  **Commit**: NO (groups with Task 3)

---

- [ ] 3. Replace polygon rendering in _updateHexagons

  **What to do**:
  - In `_updateHexagons()`, REMOVE these lines (439-441, 494-497):
    ```dart
    await _polygonManager!.deleteAll();
    // ... later ...
    await _polygonManager!.createMulti(polygonOptions);
    ```
  - REMOVE the `polygonOptions` list building (lines 444-492)
  - REPLACE with single atomic update:
    ```dart
    final geoJson = _buildHexGeoJson(hexIds);
    final source = await _mapboxMap!.style.getSource(_hexSourceId);
    if (source is GeoJsonSource) {
      await source.updateGeoJSON(geoJson);
    }
    ```
  - REMOVE `_polygonManager` field declaration and initialization
  - Keep ALL label rendering code unchanged (lines 499-541)

  **Must NOT do**:
  - Do NOT change label rendering logic
  - Do NOT change the debounce timer or trigger logic
  - Do NOT change the `onScoresUpdated` callback logic
  - Do NOT change any other parts of `_updateHexagons`

  **Parallelizable**: NO (depends on Tasks 1, 2)

  **References**:
  
  **Pattern References**:
  - `lib/widgets/hexagon_map.dart:378-555` - Full `_updateHexagons()` method to modify
  - `lib/widgets/hexagon_map.dart:439-441` - Lines to DELETE (deleteAll)
  - `lib/widgets/hexagon_map.dart:494-497` - Lines to DELETE (createMulti)
  
  **API/Type References**:
  - Mapbox `GeoJsonSource.updateGeoJSON(String)` - atomic data replacement
  - Mapbox `StyleManager.getSource(String)` - retrieves source by ID
  
  **WHY Each Reference Matters**:
  - Lines 439-441 are the DELETE portion causing the flash
  - Lines 494-497 are the CREATE portion that restores hexes
  - The gap between DELETE and CREATE is what causes the visible flash
  - Replacing with `updateGeoJSON()` makes this atomic (no intermediate state)

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Run app: `flutter run -d ios`
  - [ ] Navigate to Map screen
  - [ ] Hexes render with correct colors (red/blue/purple/neutral)
  - [ ] Switch to "All" filter - **NO FLASH should occur**
  - [ ] Switch between Zone/City/All filters multiple times - smooth transitions
  - [ ] User's current hex is highlighted (brighter opacity)
  - [ ] Pan/zoom map - hexes update smoothly without flash

  **Commit**: NO (groups with Task 4)

---

- [ ] 4. Cleanup: Remove PolygonAnnotationManager and add dispose logic

  **What to do**:
  - REMOVE `PolygonAnnotationManager? _polygonManager;` field (line 42)
  - REMOVE `_polygonManager = await _mapboxMap!.annotations.createPolygonAnnotationManager();` from `_onMapCreated` (lines 164-165)
  - REMOVE `_polygonManager = null;` from `dispose()` (line 581)
  - REMOVE guard checks for `_polygonManager` in `_updateHexagons` (lines 380-385)
  - ADD source/layer cleanup in `dispose()`:
    ```dart
    // Clean up GeoJSON source and layer
    if (_mapboxMap != null) {
      try {
        await _mapboxMap!.style.removeLayer(_hexLayerId);
        await _mapboxMap!.style.removeSource(_hexSourceId);
      } catch (e) {
        debugPrint('Error cleaning up hex layer/source: $e');
      }
    }
    ```

  **Must NOT do**:
  - Do NOT remove `_labelManager` or `_polylineManager`
  - Do NOT change any other dispose logic

  **Parallelizable**: NO (depends on Task 3)

  **References**:
  
  **Pattern References**:
  - `lib/widgets/hexagon_map.dart:577-586` - Current dispose() method structure
  - `lib/widgets/hexagon_map.dart:42` - `_polygonManager` declaration to remove
  - `lib/widgets/hexagon_map.dart:164-165` - Manager creation to remove
  
  **API/Type References**:
  - Mapbox `StyleManager.removeLayer(String)` - removes layer by ID
  - Mapbox `StyleManager.removeSource(String)` - removes source by ID

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Code compiles: `flutter analyze` shows no errors
  - [ ] Run app and navigate to Map screen - works normally
  - [ ] Navigate away from Map screen and back - no crashes
  - [ ] Hot restart app (`r` in terminal) - no memory leak warnings

  **Commit**: YES
  - Message: `fix(map): eliminate hex flashing via GeoJSON source migration`
  - Files: `lib/widgets/hexagon_map.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 5. Final end-to-end verification

  **What to do**:
  - Comprehensive manual testing of all map functionality
  - Verify the flash bug is completely fixed
  - Verify no regressions in existing functionality

  **Must NOT do**:
  - Do NOT make any code changes in this task
  - This is verification only

  **Parallelizable**: NO (final step)

  **References**:
  
  **Documentation References**:
  - Original bug report: Flash occurs when selecting "All" filter at zoom ~10 with ~3,700 hexes

  **Acceptance Criteria**:

  **Manual Execution Verification (comprehensive):**
  
  **Flash Bug Verification:**
  - [ ] Start at Zone view (zoom 15) - hexes render
  - [ ] Switch to City view - no flash
  - [ ] Switch to All view (zoom 10, ~3,700 hexes) - **NO FLASH**
  - [ ] Switch back to Zone - no flash
  - [ ] Repeat 3x to confirm consistency

  **Existing Functionality:**
  - [ ] Hex colors correct: Red hexes are red, Blue are blue, Purple are purple, Neutral are gray
  - [ ] User hex highlighted with higher opacity (0.5 vs 0.3)
  - [ ] Labels (emojis) still render on colored hexes at zoom ≥13
  - [ ] Pan map - hexes update (150ms debounce)
  - [ ] Zoom in/out - hex count adjusts appropriately
  - [ ] Route line renders during active run (if testable)
  - [ ] User location marker works correctly

  **No Regressions:**
  - [ ] No console errors during normal usage
  - [ ] No memory warnings during extended use
  - [ ] Hot reload works: `r` in terminal

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 4 | `fix(map): eliminate hex flashing via GeoJSON source migration` | `lib/widgets/hexagon_map.dart` | `flutter analyze` |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze           # Expected: No issues found
flutter run -d ios        # Expected: App runs, switch to "All" filter, no flash
```

### Final Checklist
- [ ] "All" filter shows no visible flash/flicker
- [ ] All hex colors render correctly
- [ ] User hex highlighting works
- [ ] Labels (emojis) render correctly
- [ ] Route line unaffected
- [ ] No console errors
- [ ] Code passes `flutter analyze`
