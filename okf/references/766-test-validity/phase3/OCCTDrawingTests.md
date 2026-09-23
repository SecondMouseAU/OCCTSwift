# Phase 3: OCCTDrawingTests Injection Matrix

**Target**: `OCCTDrawingTests` (194 tests) — HLR/Drawing bridge, visualization, projection, styles, dimensions
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (HLR/Drawing bridge split, patch 0009, patch 0023)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| HLR/Drawing bridge tests | 38 | CR |
| Display Drawer tests | 22 | WR |
| Point Projection tests | 20 | WR |
| Drawing projection tests | 18 | WR |
| ISO drawing style constants | 16 | WR |
| Drawing dimensions | 14 | WR |
| Perspective eye anchor (#1036) | 12 | WR |
| Drawing.append dispatcher | 11 | WR |
| HLR ReflectLines | 10 | WR |
| Normal Projection | 9 | WR |
| EditorView ProductOps | 8 | WR |
| Drawing transform (#1183) | 7 | WR |
| Drawing auto centermarks | 6 | WR |
| Arrowhead/triangle-pointer | 6 | WR |
| ... | ... | ... |

**Total**: 194 tests across ~20 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### HLR/Drawing Bridge Split (Bridge Fix)

**Issue**: HLR/Drawing was split from OCCTBridge_Modeling into separate header/implementation pairs (OCCTBridge_HLRDrawing). The split must maintain exact kernel parity.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| HLR hidden line removal | `OCCTHLRHiddenLineRemoval` | Split breaks call chain | Revert to monolithic bridge |  |  | Kernel parity required |
| HLR polar method SIGSEGV | `OCCTHLRPolarMethod` | Null deref in polar method | Remove polar method guard |  |  | Upstream fixed in OCCT 8.0.0p1 |

### #0009: StepData_StepWriter::AddString Infinite Loop (Kernel Patch)

**Issue**: `StepData_StepWriter::AddString` looped forever writing a single unbroken raw string longer than the 72-char line buffer.

**Kernel Patch**: `0009` — splits the token across lines instead.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| STEP writer oversized name | `OCCTShapeWriteSTEP` with >72-char name | Infinite loop | Revert patch 0009 |  |  | Hangs process |

### #0023: GeomTools_Curve2dSet/SurfaceSet Null Handle (Kernel Patch)

**Issue**: `GeomTools_Curve2dSet::Add`/`GeomTools_SurfaceSet::Add` accept a null handle and defer crash to `Write()`.

**Kernel Patch**: `0023` — same one-line guard `CurveSet::Add`/`Index` already have.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| GeomTools Curve2dSet null write | `OCCTGeomToolsCurve2dSetWrite` | Null handle crash in Write | Revert patch 0023 |  |  | SIGSEGV in PrintCurve2d |
| GeomTools SurfaceSet null write | `OCCTGeomToolsSurfaceSetWrite` | Null handle crash in Write | Revert patch 0023 |  |  | SIGSEGV in PrintSurface |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| HLR/Drawing bridge tests | 38 |  |  |  |  |
| Display Drawer tests | 22 |  |  |  |  |
| Point Projection tests | 20 |  |  |  |  |
| Drawing projection tests | 18 |  |  |  |  |
| ISO drawing style constants | 16 |  |  |  |  |
| Drawing dimensions | 14 |  |  |  |  |
| Perspective eye anchor (#1036) | 12 |  |  |  |  |
| Drawing.append dispatcher | 11 |  |  |  |  |
| HLR ReflectLines | 10 |  |  |  |  |
| Normal Projection | 9 |  |  |  |  |
| EditorView ProductOps | 8 |  |  |  |  |
| Drawing transform (#1183) | 7 |  |  |  |  |
| Drawing auto centermarks | 6 |  |  |  |  |
| Arrowhead/triangle-pointer | 6 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 194 tests

---

## Measured records (#766 execution, #1984)

Rows below were run: the injection turned the test red at the line named, the test was green with Sources/ restored, and parity is against the probe transcript under `Scripts/repro/766-drawing-*/`.

| Suite | Test | Bridge / Swift subject | Injection | Red (failing line) | Green | Parity |
|-------|------|------------------------|-----------|--------------------|-------|--------|
| Z-Layer Settings | Default values | `OCCTZLayerSettingsCreate` | create also turns the environment texture off | `:20` `useEnvironmentTexture == true` | ✔ | PASS |
| Z-Layer Settings | Depth test toggle | `OCCTZLayerSettingsSetDepthTest` | setter no-op | `:28` | ✔ | PASS |
| Z-Layer Settings | Depth write toggle | `OCCTZLayerSettingsSetDepthWrite` | setter no-op | `:37` | ✔ | PASS |
| Z-Layer Settings | Clear depth toggle | `OCCTZLayerSettingsSetClearDepth` | setter no-op | `:44` | ✔ | PASS |
| Z-Layer Settings | Polygon offset roundtrip | `OCCTZLayerSettingsSetPolygonOffset` | factor written as 0 | `:55` | ✔ | PASS |
| Z-Layer Settings | Depth offset positive convenience | `OCCTZLayerSettingsSetDepthOffsetPositive` | calls `SetDepthOffsetNegative` | `:66` | ✔ | PASS |
| Z-Layer Settings | Depth offset negative convenience | `OCCTZLayerSettingsSetDepthOffsetNegative` | calls `SetDepthOffsetPositive` | `:76` | ✔ | PASS |
| Z-Layer Settings | Immediate mode toggle | `OCCTZLayerSettingsSetImmediate` | setter no-op | `:83` | ✔ | PASS |
| Z-Layer Settings | Raytracable toggle | `OCCTZLayerSettingsSetRaytracable` | setter no-op | `:90` | ✔ | PASS |
| Z-Layer Settings | Culling distance | `OCCTZLayerSettingsSetCullingDistance` | setter no-op | `:97` | ✔ | PASS |
| Z-Layer Settings | Culling size | `OCCTZLayerSettingsSetCullingSize` | setter no-op | `:104` | ✔ | PASS |
| Z-Layer Settings | Origin roundtrip | `OCCTZLayerSettingsSetOrigin` | setter no-op | `:112` to `:114` | ✔ | PASS |
| Z-Layer Settings | Predefined layer IDs | `ZLayerSettings layer-id constants (Swift) vs Graphic3d_ZLayerId` | Swift `top` constant -1 | `:121` `ZLayerSettings.top == -2` | ✔ | PASS |
