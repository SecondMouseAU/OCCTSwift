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
| v0.137 Drawing dimensions | Add linear dimension stores measurable value | `DrawingDimension.Linear.value` | `Linear.value` + 1 | `:21` `abs(d.value - 100) < 1e-9` | ✔ | N/A (pure Swift: 2D dimension values and the drawing's stores, no OCCT call) |
| v0.137 Drawing dimensions | Radial / diameter relate correctly | `DrawingDimension.value` | `.diameter` value returns the radius | `:40` `abs(d.value - 20) < 1e-9` | ✔ | N/A (pure Swift: 2D dimension values and the drawing's stores, no OCCT call) |
| v0.137 Drawing dimensions | Angular dimension computes angle between rays | `DrawingDimension.Angular.value` | `Angular.value` + 0.1 | `:56` `abs(d.value - .pi / 2) < 1e-9` | ✔ | N/A (pure Swift: 2D dimension values and the drawing's stores, no OCCT call) |
| v0.137 Drawing dimensions | Annotations separate from dimensions | `Drawing.addTextLabel` | `addTextLabel` does not append | `:70` `drawing.annotations.count == 3` | ✔ | N/A (pure Swift: 2D dimension values and the drawing's stores, no OCCT call) |
| v0.137 Drawing dimensions | clearAnnotations empties both collections | `DrawingAnnotationStore.clear` | `clear()` keeps annotations | `:86` `drawing.annotations.isEmpty` | ✔ | N/A (pure Swift: 2D dimension values and the drawing's stores, no OCCT call) |
| v0.144 ISO drawing style constants | DrawingLineWidth values match ISO 128-20 tiers | `DrawingLineWidth.thin` | `thin = .w018` | `:13` `DrawingLineWidth.thin.rawValue == 0.25` | ✔ | N/A (pure Swift: ISO style constants and lookup tables, no OCCT call) |
| v0.144 ISO drawing style constants | DrawingTextHeight.snap picks nearest ISO 3098 tier | `DrawingTextHeight.snap` | `snap` uses `max(by:)` | `:20`, `:21`, `:22` | ✔ | N/A (pure Swift: ISO style constants and lookup tables, no OCCT call) |
| v0.144 ISO drawing style constants | DrawingTextHeight.recommended varies by paper | `DrawingTextHeight.recommended` | A0/A1 return `.h70` | `:27` `recommended(forPaper: "A0") == .h50` | ✔ | N/A (pure Swift: ISO style constants and lookup tables, no OCCT call) |
| v0.144 ISO drawing style constants | DrawingScale factor and label | `DrawingScale.factor` | reduction factor `Double(n)` | `:34` `DrawingScale.reduction(2).factor == 0.5` | ✔ | N/A (pure Swift: ISO style constants and lookup tables, no OCCT call) |
| v0.144 ISO drawing style constants | strokeWidthMM returns ISO 128-20 line widths | `strokeWidthMM(for:)` | HATCH returns 0.25 | `:45` `strokeWidthMM(for: "HATCH") == 0.18` | ✔ | N/A (pure Swift: ISO style constants and lookup tables, no OCCT call) |
| v0.144 ISO drawing style constants | ArrowStyle length scales with line width | `DrawingArrowStyle.length(forLineWidth:)` | length `x 5` | `:51` `abs(L - 1.5) < 1e-9` | ✔ | N/A (pure Swift: ISO style constants and lookup tables, no OCCT call) |
| v0.144 ISO drawing style constants | DrawingScale preferred includes ISO series | `DrawingScale.preferred` | drops `.reduction(100)` | `:60` `labels.contains("1:100")` | ✔ | N/A (pure Swift: ISO style constants and lookup tables, no OCCT call) |
