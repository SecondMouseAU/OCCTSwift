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
| Angle Dimension | Right angle from three points | `OCCTDimensionCreateAngleFromPoints` | `OCCTDimensionGetValue`: `GetValue() + 0.1` | `:18` `abs(dim.degrees - 90.0) < 1e-4` | ✔ | PASS |
| Angle Dimension | 60-degree angle | `OCCTDimensionCreateAngleFromPoints` | `OCCTDimensionGetValue`: `GetValue() + 0.1` | `:30` `abs(dim.degrees - 60.0) < 0.1` | ✔ | PASS |
| Angle Dimension | 180-degree angle (straight line) | `OCCTDimensionCreateAngleFromPoints` | `OCCTDimensionGetValue`: `GetValue() + 0.1` | `:42` `abs(dim.degrees - 180.0) < 0.1` | ✔ | PASS |
| Angle Dimension | Angle geometry has center point | `OCCTDimensionGetGeometry` | `OCCTDimensionGetGeometry` angle case: `centerPoint[0] = cp.X() + 1` | `:55` `abs(g.centerPoint.x) < 1e-6 && ...` | ✔ | PASS |
| Angle Dimension | Angle between perpendicular faces is 90 degrees | `OCCTDimensionCreateAngleFromFaces` | value + 0.1 (red at old `:73`); ctor `return nullptr` was GREEN under the old `if let`, rewritten to `guard` | rewritten: `:74` `Issue.record` (nil), value + 0.1 at `:80` | ✔ | PASS |
| emitAngular sweep matches Angular.value for reflex ray pairs (#1169) | Rays 200 degrees apart draw the 160-degree (non-reflex) arc, matching Angular.value | `emitAngular (Swift, DrawingDispatch.swift)` | `emitAngular`: reflex branch `sweep > .pi` to `sweep > 99` | `:33` `abs(sweepDeg - 160.0) < 1e-6` | ✔ | N/A (pure Swift: DXFWriter arc emission, no OCCT call) |
| #914 review, third pass: auto-centermark position matches the drawing's own projected frame | centermark for an off-axis cylinder matches the projected circle's own bounding-box center | `OCCTDrawingCreate` | `perpendicularBasis`: `return (up, right)` | `:68` `simd_length(mark.centre - projectedCentre) < 1e-6` (both marks) | ✔ | PASS |
| v0.147 Drawing.addAutoCentermarks | Cylinder top view produces one centermark | `OCCTDrawingCreate` | `testCircleVisibility`: `dotAxis < 0.1` to `> 0.1` | `:22` `result.added.count == 2` | ✔ | PASS |
| v0.147 Drawing.addAutoCentermarks | Cylinder side view skips edge-on circles | `OCCTDrawingCreate` | `testCircleVisibility`: `dotAxis < 0.1` to `> 0.1` | `:35` `result.added.isEmpty`, `:36` skipped (now pinned `== 2`) | ✔ | PASS |
| v0.147 Drawing.addAutoCentermarks | minRadius filters small holes | `OCCTDrawingCreate` | `testCircleVisibility`: `radius >= minRadius` to `>= 0` | `:50` `result.added.isEmpty` | ✔ | PASS |
