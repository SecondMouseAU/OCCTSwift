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
| v0.146 Cosmetic thread annotations | Side view produces two parallel centrelines | `DrawingAnnotation.cosmeticThreadSideView` | side view keeps only the top centreline | `:18` `anns.count == 2` | ✔ | N/A (pure Swift: DrawingAnnotation factories and the DXF/PDF/SVG writers, no OCCT call) |
| v0.146 Cosmetic thread annotations | End view returns three .arc DrawingAnnotation cases (ISO 6410 3/4 broken arc) | `DrawingAnnotation.cosmeticThreadEndView` | last arc ends at 3pi/2 | `:44` `abs(totalSweep - 7 * .pi / 4) < 1e-9` | ✔ | N/A (pure Swift: DrawingAnnotation factories and the DXF/PDF/SVG writers, no OCCT call) |
| v0.146 Cosmetic thread annotations | Drawing.addCosmeticThreadEndView adds 3 arc annotations directly to the drawing | `Drawing.addCosmeticThreadEndView` | `addCosmeticThreadEndView` does not append | `:63` `drawing.annotations.count == 3` | ✔ | N/A (pure Swift: DrawingAnnotation factories and the DXF/PDF/SVG writers, no OCCT call) |
| v0.146 Cosmetic thread annotations | #1179: a Drawing's cosmetic thread end view reaches DXF, PDF and SVG alike | `Drawing.addCosmeticThreadEndView` | `addCosmeticThreadEndView` does not append | `:93`, `:94`, `:95` arcs == 3 per writer | ✔ | N/A (pure Swift: DrawingAnnotation factories and the DXF/PDF/SVG writers, no OCCT call) |
| v0.146 Cosmetic thread annotations | #1179: cosmetic thread end view arcs extend Drawing.bounds() | `Drawing.addCosmeticThreadEndView` | `addCosmeticThreadEndView` does not append | `:119`, `:120` | ✔ | N/A (pure Swift: DrawingAnnotation factories and the DXF/PDF/SVG writers, no OCCT call) |
| v0.146 Cosmetic thread annotations | Drawing.addCosmeticThreadSide with callout adds 3 annotations | `Drawing.addCosmeticThreadSide` | side view keeps only the top centreline | `:138` `anns.count == 3` | ✔ | N/A (pure Swift: DrawingAnnotation factories and the DXF/PDF/SVG writers, no OCCT call) |
| v0.146 Cosmetic thread annotations | DXFWriter.addCosmeticThreadEndView emits three arcs | `DXFWriter.addCosmeticThreadEndView` | the DXFWriter wrapper emits nothing | `:148` `writer.entityCounts.arcs == 3` | ✔ | N/A (pure Swift: DrawingAnnotation factories and the DXF/PDF/SVG writers, no OCCT call) |
| Cylindrical Projection | Project wire onto box | `OCCTShapeProjectWire` | return the input wire unprojected: **green** as written (`result != nil`); rewritten | rewritten: `:39` `result.edges().count == 4`, `:17`/`:18` bbox | ✔ | PASS |
| Cylindrical Projection | Project edge onto sphere | `OCCTShapeProjectWire` | return the input wire unprojected: **green** as written; rewritten | rewritten: `:63` `result.edges().count == 4`, `:17`/`:18` bbox | ✔ | PASS |
| Diameter Dimension | Diameter of circle is twice radius | `OCCTDimensionCreateDiameterFromShape` | `GetValue() + 0.1` (red as written, `:16`); ctor `return nullptr` passes the old `if let`, rewritten to `guard` | rewritten, ctor nil: `:19` `Issue.record` | ✔ | PASS |
| Diameter Dimension | Diameter geometry has circle info | `OCCTDimensionGetGeometry` | diameter case `opposite = centre` (red as written, `:29`); ctor nil passes the old `if let`, rewritten; `circleRadius > 0` pinned to 5 | rewritten, ctor nil: `:31` `Issue.record` | ✔ | PASS |
| Diameter Dimension | Custom value on diameter | `OCCTDimensionSetCustomValue` | `GetValue() + 0.1` (red as written, `:41`); ctor nil passes the old `guard ... else { return }`, rewritten | rewritten, ctor nil: `:47` `Issue.record` | ✔ | PASS |
