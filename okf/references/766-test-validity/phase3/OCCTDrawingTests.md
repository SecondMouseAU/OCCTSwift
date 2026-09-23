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
| #1193: addCuttingPlaneLine direction projection | projectDirectionToPlane matches OCCT's gp_Ax2 canonical basis | `projectDirectionToPlane (Swift) vs gp_Ax2` | `perpendicularBasis` returns `(up, right)` | `:43` to `:46` | ✔ | PASS |
| #1193: addCuttingPlaneLine direction projection | addCuttingPlaneLine's traceStart/traceEnd/arrowDirection match a hand-derived projection | `Drawing.addCuttingPlaneLine (Swift) vs gp_Ax2` | `perpendicularBasis` returns `(up, right)` | `:87`, `:90`, `:93` | ✔ | PASS |
| perpendicularBasis unification: Drawing projection (#881) | projectPointToPlane's basis matches OCCT's gp_Ax2 canonical basis | `projectPointToPlane (Swift) vs gp_Ax2` | `perpendicularBasis` returns `(up, right)` | `:26` to `:29` | ✔ | PASS |
| perpendicularBasis unification: Drawing projection (#881) | projectAxisToPlane's basis matches OCCT's gp_Ax2 canonical basis | `projectAxisToPlane (Swift) vs gp_Ax2` | `perpendicularBasis` returns `(up, right)` | `:46`, `:47` | ✔ | PASS |
| Drawing.ProjectionType is honoured (#999) | Orthographic projects the box at its true size | `OCCTDrawingCreate` | `OCCTDrawingCreate` projector types swapped (perspective gets the orthographic projector, orthographic a focus-1e4 one) | `:38`, `:39` | ✔ | PASS |
| Drawing.ProjectionType is honoured (#999) | Perspective diverges from orthographic, and by the ratio the focal distance implies | `OCCTDrawingCreate` | `OCCTDrawingCreate` projector types swapped (perspective gets the orthographic projector, orthographic a focus-1e4 one) | `:58`, `:59`, `:60` | ✔ | PASS |
| Drawing.ProjectionType is honoured (#999) | The focal distance sets the scale, and a longer one converges on orthographic | `OCCTDrawingCreate` | `OCCTDrawingCreate` projector types swapped (perspective gets the orthographic projector, orthographic a focus-1e4 one) | `:80`, `:82` per focus | ✔ | PASS |
| Drawing.ProjectionType is honoured (#999) | A non-positive focal distance is refused rather than silently reinterpreted | `OCCTDrawingCreate` | `!(focus > 0)` check removed (0 and -100 are still refused by the reach guard; NaN is not) | `:100` (NaN) | ✔ | PASS |
| Drawing.ProjectionType is honoured (#999) | projectFast stays orthographic, which is all HLRBRep_PolyAlgo can do | `OCCTDrawingCreatePoly` | `OCCTDrawingCreatePoly` view tilted by 0.1 in x | `:115` | ✔ | PASS |
