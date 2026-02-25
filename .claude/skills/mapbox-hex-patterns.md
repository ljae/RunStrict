# Mapbox Hex Grid Patterns — RunStrict

> Activated when editing Dart files in `lib/features/map/`. Covers hex rendering, scope boundaries, and navigation camera.

## Hex Grid Rendering: GeoJsonSource + FillLayer

**Why**: `PolygonAnnotationManager.deleteAll() + createMulti()` causes visible flash. GeoJsonSource swaps data atomically.

### Setup Pattern
```dart
// Step 1: Create GeoJsonSource
await mapboxMap.style.addSource(
  GeoJsonSource(id: _hexSourceId, data: '{"type":"FeatureCollection","features":[]}'),
);

// Step 2: Create FillLayer with placeholder values
// NOTE: mapbox_maps_flutter FillLayer has strict typing - fillColor expects int?, not List
await mapboxMap.style.addLayer(
  FillLayer(
    id: _hexLayerId,
    sourceId: _hexSourceId,
    fillColor: Colors.grey.toARGB32(),  // placeholder
    fillOpacity: 0.3,
    fillOutlineColor: Colors.grey.toARGB32(),
    fillAntialias: true,
  ),
);

// Step 3: Apply data-driven expressions via setStyleLayerProperty
// This bypasses the strict typing limitation
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-color', ['to-color', ['get', 'fill-color']],
);
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-opacity', ['get', 'fill-opacity'],
);
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-outline-color', ['to-color', ['get', 'fill-outline-color']],
);
```

### GeoJSON Feature Format
```json
{
  "type": "Feature",
  "geometry": { "type": "Polygon", "coordinates": [...] },
  "properties": {
    "fill-color": "#FF003C",
    "fill-opacity": 0.3,
    "fill-outline-color": "#FF003C"
  }
}
```

### Hex Visual States
| State | Fill Color | Opacity | Border |
|-------|-----------|---------|--------|
| Neutral | #2A3550 | 0.15 | Gray (#6B7280), 1px |
| Blue | Blue light | 0.3 | Blue, 1.5px |
| Red | Red light | 0.3 | Red, 1.5px |
| Purple | Purple light | 0.3 | Purple, 1.5px |
| Capturable | Team color | 0.3 | Pulsing (2s, 1.2x scale + glow) |
| Current | Team color | 0.5 | 2.5px |

## Scope Boundary Layers

### Province Boundary (`scope-boundary-source` / `scope-boundary-line`)
- **PROVINCE scope**: Merged outer boundary of all ~7 district hexes — irregular polygon
- **DISTRICT scope**: Single district hex boundary
- **ZONE scope**: Hidden
- Styling: white, 8px, 15% opacity, 4px blur, solid

### District Boundaries (`district-boundary-source` / `district-boundary-line`)
- **PROVINCE scope**: Dashed outlines for each district hex
- **DISTRICT/ZONE scope**: Hidden
- Styling: white, 3px, 12% opacity, 2px blur, dashed [4,3]

### Merged Outer Boundary Algorithm (`_computeMergedOuterBoundary`)
1. Collect all directed edges from district hex boundaries
2. Remove shared internal edges (opposite-direction cancel out)
3. Chain remaining outer edges into closed polygon loop
4. Use 7-decimal coordinate precision for edge matching (~1cm)

## Navigation Camera (route_map.dart)

### Architecture
| Aspect | Implementation |
|--------|---------------|
| Bearing | GPS heading (primary), route-calculated (fallback, last 5 points, min 3m) |
| Camera Follow | Tracks `liveLocation` — follows ALL GPS points including rejected |
| Animation | 1800ms (undershoots 2s GPS polling for smooth transitions) |
| Route Updates | Keep-latest pattern (queue pending, process after current) |
| Marker Position | 67.5% from top; camera padding = 0.35 × viewport height |

### GPS Heading Flow
```
LocationPoint.heading → RunProvider.liveHeading (RunState)
  → RunningScreen → RouteMap.liveHeading
  → _updateNavigationCamera() (primary bearing)
```

### Camera-Follows-Rejected-GPS
When GPS rejected by RunTracker: `routeVersion` unchanged but `liveLocation` updates.
`didUpdateWidget` detects this → calls `_updateCameraForLiveLocation()`.

### Keep-Latest Pattern
```dart
// In _processRouteUpdate():
// If _isProcessingRouteUpdate == true → _pendingRouteUpdate = true
// After current completes → check flag → process again
```

## H3 Hex System

- **Resolution 9**: ~175m edge length (capture hexes)
- **Resolution 8**: Zone scope (~461m)
- **Resolution 6**: District scope (~3.2km)
- **Resolution 4**: Province scope (regional)
- Package: `h3_flutter`

## Key Files
| File | Purpose |
|------|---------|
| `lib/features/map/widgets/hexagon_map.dart` | GeoJsonSource hex rendering + scope boundaries |
| `lib/features/map/widgets/route_map.dart` | Navigation camera during runs |
| `lib/features/map/widgets/smooth_camera.dart` | 60fps camera interpolation |
| `lib/features/map/widgets/glowing_marker.dart` | Animated location marker |
| `lib/features/map/screens/map_screen.dart` | Main map screen with scope toggle |
