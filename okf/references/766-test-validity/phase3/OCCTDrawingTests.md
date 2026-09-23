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
| Length Dimension | Point-to-point distance | `OCCTDimensionCreateLengthFromPoints` | `GetValue() + 0.1` (red as written, `:16`); ctor nil: the old `dim!` inside `#expect` would crash the run rather than fail; rewritten to `guard` | rewritten, ctor nil: `:21` | ✔ | PASS |
| Length Dimension | Diagonal distance | `OCCTDimensionCreateLengthFromPoints` | `GetValue() + 0.1` (red as written, `:23`); ctor nil: the old `dim!` inside `#expect` would crash the run rather than fail; rewritten to `guard` | rewritten, ctor nil: `:30` | ✔ | PASS |
| Length Dimension | 3D distance | `OCCTDimensionCreateLengthFromPoints` | `GetValue() + 0.1` (red as written, `:31`); ctor nil: the old `dim!` inside `#expect` would crash the run rather than fail; rewritten to `guard` | rewritten, ctor nil: `:39` | ✔ | PASS |
| Length Dimension | Edge length measurement | `OCCTDimensionCreateLengthFromEdge` | edge ctor nil: **green** as written, and the original never reached its assertion on a clean tree either (it passed a wire-typed shape, which the bridge refuses); rewritten to pass the edge and pin 7 | rewritten, edge ctor nil: `:57` | ✔ | PASS |
| Length Dimension | Face-to-face distance equals box dimension | `OCCTDimensionCreateLengthFromFaces` | face ctor nil: **green** as written (`if let`); rewritten to `guard` | rewritten: `:73` | ✔ | PASS |
| Length Dimension | Geometry contains valid first and second points | `OCCTDimensionGetGeometry` | length geometry second point x + 1 (red as written, `:72`); ctor nil now recorded | rewritten, ctor nil: `:82` | ✔ | PASS |
| Length Dimension | Custom value overrides measured | `OCCTDimensionSetCustomValue` | `GetValue() + 0.1` (red as written, `:80`, `:82`); ctor nil now recorded | rewritten, ctor nil: `:97` | ✔ | PASS |
| Normal Projection | Project line onto sphere near surface | `OCCTShapeNormalProjection` | return the input line unprojected: **green** as written (non-nil and `isValid`); rewritten | rewritten: `:22` edge count, `:23` bounds | ✔ | PASS |
| Normal Projection | Project line outside sphere | `OCCTShapeNormalProjection` | return the input line unprojected: **green** as written (non-nil only); rewritten | rewritten: `:22`, `:23` | ✔ | PASS |
