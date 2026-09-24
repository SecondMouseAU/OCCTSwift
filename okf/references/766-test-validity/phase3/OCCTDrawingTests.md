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
| v0.149 Drawing.addAutoDimensions | Box front view produces two linear dimensions | `OCCTShapeGetBounds (Shape.bounds) + perpendicularBasis` | `addAutoDimensions`: `width > 1e-9` to `width > 1e9` | `:23` `linearCount == 2` | ✔ | PASS |
| v0.149 Drawing.addAutoDimensions | Cylinder top view produces diameter + linear extents | `OCCTDrawingCreate + testCircleVisibility` | edge-on test inverted; width threshold 1e9 | `:41` `diaCount >= 1` (now `== 2`), `:42` `linearCount == 2` | ✔ | PASS |
| v0.149 Drawing.addAutoDimensions | Cylinder side view skips edge-on circles | `OCCTDrawingCreate + testCircleVisibility` | `testCircleVisibility`: `dotAxis < 0.1` to `> 0.1` | `:57` `diaCount == 0` | ✔ | PASS |
| v0.149 Drawing.addAutoDimensions | minRadius filters small circles | `OCCTDrawingCreate + testCircleVisibility` | `testCircleVisibility`: `radius >= minRadius` to `>= 0` | `:75` `diaCount == 0` | ✔ | PASS |
| v0.150 DrawingAnnotation.balloon | Balloon with leader emits circle + text + leader line | `emitBalloon (Swift, DrawingDispatch.swift)` | `emitBalloon`: drop `addCircle`; separately drop the leader | `:32` circles, `:34` lines | ✔ | N/A (pure Swift: DXF entity counts, the HLR baseline cancels) |
| v0.150 DrawingAnnotation.balloon | Balloon without leader emits circle + text only | `emitBalloon (Swift, DrawingDispatch.swift)` | `emitBalloon`: drop `addCircle` | `:63` circles | ✔ | N/A (pure Swift: DXF entity counts, the HLR baseline cancels) |
| v0.150 DrawingAnnotation.balloon | Drawing.addBalloon adds a .balloon annotation | `Drawing.addBalloon (Swift)` | `addBalloon`: skip `appendAnnotation` | `:80` `balloonCount == 1` | ✔ | N/A (pure Swift annotation store) |
| v0.150 DrawingAnnotation.balloon | Balloon transforms translate centre, scale radius, and translate leader | `DrawingAnnotation.transformed (Swift)` | `transformed` balloon arm: drop `radius *= scale` | `:94` `b.radius == 10` | ✔ | N/A (pure Swift 2D transform) |
| Camera Tests | Default state valid | `OCCTCameraGetEye` | `OCCTCameraGetEye` writes zeros | `:22` `eyeLen > 0` | ✔ | PASS |
| Camera Tests | Projection matrix non-identity | `OCCTCameraGetProjectionMatrix` | `OCCTCameraGetProjectionMatrix` writes identity | `:36` `!isIdentity` | ✔ | PASS |
| Camera Tests | View matrix changes with eye/center | `OCCTCameraGetViewMatrix` | `OCCTCameraSetEye` no-op | `:57` `abs(diff) > 1e-6 || abs(diff2) > 1e-6` | ✔ | PASS |
| Camera Tests | Project/Unproject roundtrip | `OCCTCameraProject / OCCTCameraUnproject` | `OCCTCameraUnproject`: `X() + 1` | `:74` `abs(recovered.x - original.x) < 0.1` | ✔ | PASS |
| Camera Tests | Orthographic mode produces different matrices | `OCCTCameraSetProjectionType` | `OCCTCameraSetProjectionType` ignores orthographic | `:98` `d > 1e-6` | ✔ | PASS |
| Camera Tests | Fit bounding box adjusts camera | `OCCTCameraFitBBox` | `OCCTCameraFitBBox`: skip `FitMinMax`. GREEN as written (centred box already at the origin), rewritten | rewritten: `:122` centre, `:124`, `:125` projected mid, `:135` widest corner | ✔ | PASS |
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
| Display Drawer | Default values | `OCCTDrawerCreate` | ctor also calls `SetDiscretisation(31)` | `:19` `drawer.discretisation == 30` | ✔ | PASS |
| Display Drawer | Deviation coefficient roundtrip | `OCCTDrawerSetDeviationCoefficient` | setter no-op | `:26` | ✔ | PASS |
| Display Drawer | Deviation angle roundtrip | `OCCTDrawerSetDeviationAngle` | setter no-op | `:34` | ✔ | PASS |
| Display Drawer | Maximal chordial deviation roundtrip | `OCCTDrawerSetMaximalChordialDeviation` | setter no-op | `:41` | ✔ | PASS |
| Display Drawer | Deflection type toggle | `OCCTDrawerSetTypeOfDeflection` | setter no-op | `:48` `drawer.deflectionType == .absolute` | ✔ | PASS |
| Display Drawer | Auto-triangulation toggle | `OCCTDrawerSetAutoTriangulation` | setter no-op | `:57` | ✔ | PASS |
| Display Drawer | Iso on triangulation toggle | `OCCTDrawerSetIsoOnTriangulation` | setter no-op | `:64` | ✔ | PASS |
| Display Drawer | Discretisation roundtrip | `OCCTDrawerSetDiscretisation` | setter no-op | `:71` | ✔ | PASS |
| Display Drawer | Face boundary draw toggle | `OCCTDrawerSetFaceBoundaryDraw` | setter no-op | `:78` | ✔ | PASS |
| Display Drawer | Wire draw toggle | `OCCTDrawerSetWireDraw` | setter no-op | `:85` | ✔ | PASS |
| v0.148 Drawing.append(_:) unified dispatcher | append single annotation | `Drawing.append(_: DrawingAnnotation)` | `append(_:)` annotation no-op | `:20` `drawing.annotations.count == 1` | ✔ | N/A (pure Swift: the drawing's annotation and dimension stores, no OCCT call) |
| v0.148 Drawing.append(_:) unified dispatcher | append factory output installs every annotation case | `Drawing.append(contentsOf: [DrawingAnnotation])` | `append(contentsOf:)` drops the last | `:36` `drawing.annotations.count == expectedCount` | ✔ | N/A (pure Swift: the drawing's annotation and dimension stores, no OCCT call) |
| v0.148 Drawing.append(_:) unified dispatcher | append GD&T feature control frame output | `Drawing.append(contentsOf: [DrawingAnnotation])` | `append(contentsOf:)` drops the last | `:51` `drawing.annotations.count == anns.count` | ✔ | N/A (pure Swift: the drawing's annotation and dimension stores, no OCCT call) |
| v0.148 Drawing.append(_:) unified dispatcher | append pre-built hatch survives round-trip (no consumer switch) | `Drawing.append(_: DrawingAnnotation)` | `append(_:)` annotation no-op | `:69` `Issue.record` | ✔ | N/A (pure Swift: the drawing's annotation and dimension stores, no OCCT call) |
| v0.148 Drawing.append(_:) unified dispatcher | append pre-built cutting-plane line survives round-trip | `Drawing.append(_: DrawingAnnotation)` | `append(_:)` annotation no-op | `:89` `Issue.record` | ✔ | N/A (pure Swift: the drawing's annotation and dimension stores, no OCCT call) |
| v0.148 Drawing.append(_:) unified dispatcher | append a pre-built dimension | `Drawing.append(_: DrawingDimension)` | `append(_:)` dimension no-op | `:102` `drawing.dimensions.count == 1` | ✔ | N/A (pure Swift: the drawing's annotation and dimension stores, no OCCT call) |
| v0.148 Drawing.append(_:) unified dispatcher | append dimensions batch | `Drawing.append(contentsOf: [DrawingDimension])` | `append(contentsOf:)` dimensions drops the last | `:119` `drawing.dimensions.count == 3` | ✔ | N/A (pure Swift: the drawing's annotation and dimension stores, no OCCT call) |
| v0.137 Drawing auto-centrelines (#64 ↔ #65) | Cylinder top view produces no centreline (axis collapses to point) | `OCCTShapeRevolutionAxes` | `OCCTShapeRevolutionAxes` skips cylindrical faces | `:20` `result.skipped.count == 1` | ✔ | PASS |
| v0.137 Drawing auto-centrelines (#64 ↔ #65) | Cylinder side view draws one centreline along axis | `OCCTShapeRevolutionAxes` | cylinders skipped (red `:34`, `:35`, `:39`); `projectAxisToPlane` swapping the view axes would leave the old count/style checks green, so the endpoints are now pinned | rewritten, axes swapped: `:42`, `:43` endpoints | ✔ | PASS |
| v0.137 Drawing auto-centrelines (#64 ↔ #65) | Box produces no centrelines (no revolution axes) | `OCCTShapeRevolutionAxes` | `OCCTShapeRevolutionAxes` reports a Z axis for every non-revolution face | `:58` `result.added.isEmpty` | ✔ | PASS |
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
| v0.161 EditorView Add/Remove + Ref setters | Add operations on a fresh box graph do not crash | `OCCTBRepGraphEdgeAddInternalVertex` | attachment refused: **green** as written (no assertions); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red; rewritten pins the return values | rewritten: `:25` `edgeAddInternalVertex(...) == 1`; nil graph `:18` | ✔ | PASS |
| v0.161 EditorView Add/Remove + Ref setters | Remove operations on invalid ref ids return false without crashing | `OCCTBRepGraphEdgeRemoveVertex` | `edgeRemoveVertex` returns true (red as written, `:33`); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | nil graph `:38` | ✔ | PASS |
| v0.161 EditorView Add/Remove + Ref setters | Edge / face / coedge ref setters operate on existing entities | `OCCTBRepGraphSetCoEdgeEdgeDefId` | `SetCoEdgeEdgeDefId` no-op: **green** as written (no assertions); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red; rewritten re-points coedge 0 and reads it back | rewritten: `:72` `graph.coedgeEdge(0) == 5`; nil graph `:63` | ✔ | PASS |
| v0.163 EditorView ProductOps assembly building | Create empty product and link to topology | `OCCTBRepGraphCreateEmptyProduct` | `createEmptyProduct` refused (red as written); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red; `>= 0` pinned to the kernel ids | `:17` `Issue.record` | ✔ | PASS |
| v0.163 EditorView ProductOps assembly building | Remove ops on bogus ids return false | `OCCTBRepGraphProductRemoveOccurrence` | `productRemoveOccurrence` returns true (red as written, `:54`); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | nil graph `:60` | ✔ | PASS |
| v0.163 EditorView ProductOps assembly building | Occurrence ref local location round-trip | `OCCTBRepGraphGetOccurrenceRefLocalLocation` | `linkProducts` drops the placement; graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | `:111`, `:112`, `:113`; nil graph `:72` | ✔ | PASS |
| v0.163 EditorView ProductOps assembly building | Child ref local location round-trip | `OCCTBRepGraphSetChildRefLocalLocation` | `SetChildRefLocalLocation` no-op | `:148` to `:166` (six) | ✔ | PASS |
| v0.163 EditorView ProductOps assembly building | Occurrence ref local location setter overwrites the placement linkProducts wrote | `OCCTBRepGraphSetOccurrenceRefLocalLocation` | `SetOccurrenceRefLocalLocation` no-op | `:223`, `:224`, `:225` | ✔ | PASS |
| v0.159 EditorView field setters | Vertex point and tolerance set then read back | `OCCTBRepGraphSetVertexPoint` | `SetVertexPoint` no-op (red as written, `:17` to `:19`); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | nil graph `:19` | ✔ | PASS |
| v0.159 EditorView field setters | Edge tolerance, range, and flags set then read back | `OCCTBRepGraphSetEdgeTolerance` | `SetEdgeTolerance` no-op (red as written, `:34`); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | nil graph `:37` | ✔ | PASS |
| v0.159 EditorView field setters | Face tolerance set then read back | `OCCTBRepGraphSetFaceTolerance` | `SetFaceTolerance` no-op (red as written, `:72`); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | nil graph `:74` | ✔ | PASS |
| v0.159 EditorView field setters | CoEdge/Wire/Shell setters do not crash on valid ids | `OCCTBRepGraphWireIsClosed` | wire/shell closure getters read false: **green** as written (capture-before/assert-unchanged); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red; closure now pinned before the coedge setters | rewritten: `:97`, `:98` | ✔ | PASS |
| v0.164 RepOps non-guard setters & cache entry inspection | Cached face mesh inspection on a fresh graph | `OCCTBRepGraphCachedFaceMeshIsPresent` | `CachedFaceMeshIsPresent` returns true (red as written, `:15`); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | nil graph `:16` | ✔ | PASS |
| v0.164 RepOps non-guard setters & cache entry inspection | Cached face mesh state after appendCachedTriangulation | `OCCTBRepGraphMeshAppendCachedTriangulation` | `SetCachedTriangulation` skipped; graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | `:41` to `:44`; nil graph `:36` | ✔ | PASS |
| v0.164 RepOps non-guard setters & cache entry inspection | Cached edge / coedge mesh accessors return absent on fresh graph | `OCCTBRepGraphCachedEdgeMeshIsPresent` | `CachedEdgeMeshIsPresent` returns true (red as written, `:52`); graph-create nil: **green** as written (`if let graph`); rewritten to `guard`, red | nil graph `:52` | ✔ | PASS |
| HLR ReflectLines Tests | reflect lines on sphere | `OCCTHLRReflectLines` | axes overridden to view down +X: **green** as written; rewritten (the original asserted only `count > 0` inside two `if let`s) | rewritten: `:20` edge count, `:21` bounds | ✔ | PASS |
| HLR ReflectLines Tests | reflect lines filtered by edge type | `OCCTHLRReflectLinesFiltered` | axes overridden to view down +X: **green** as written; rewritten (the original had no assertion) | rewritten: `:20`, `:21` | ✔ | PASS |
| Perspective eye anchor and the regime beyond it (#1036) | A shape wholly beyond the eye is refused, not drawn mirrored | `OCCTDrawingCreate` | reach guard disabled (`reach >= focus + 1e9`) | `:41` `== nil` | ✔ | PASS |
| Perspective eye anchor and the regime beyond it (#1036) | An eye plane cutting the shape is refused, not drawn half mirrored | `OCCTDrawingCreate` | reach guard disabled (`reach >= focus + 1e9`) | `:54` `== nil` | ✔ | PASS |
| Perspective eye anchor and the regime beyond it (#1036) | An eye exactly on a face is refused rather than divided by zero | `OCCTDrawingCreate` | reach guard disabled (`reach >= focus + 1e9`) | `:66` `== nil` | ✔ | PASS |
| Perspective eye anchor and the regime beyond it (#1036) | The eye is anchored at the world origin, so the scale follows the shape's position | `OCCTDrawingCreate` | projector focus `* 1.01`; separately the guard made over-strict (`reach >= focus - 2000`) | `:91`, `:92`, `:93`; over-strict guard `:88` `Issue.record` | ✔ | PASS |
| Perspective eye anchor and the regime beyond it (#1036) | A shape behind the picture plane still projects, shrunken and the right way round | `OCCTDrawingCreate` | projector focus `* 1.01`; separately the over-strict guard | `:119`, `:120`; over-strict guard `:115` | ✔ | PASS |
| Perspective eye anchor and the regime beyond it (#1036) | A focal distance just clear of the shape is accepted, however extreme the scale | `OCCTDrawingCreate` | over-strict guard (focus `* 1.01` leaves it green: `min > 0` and `max > 1000` both still hold) | `:136` `Issue.record` | ✔ | PASS |
| Drawing.ProjectionType is Hashable (#1059) | A ProjectionType keys a dictionary | `Drawing.ProjectionType (Swift)` | hand-written `==`/`hash(into:)` dropping `focus`; separately `Hashable` removed from the declaration | `:41`, `:42` (hand-written); compile errors `:37` | ✔ | N/A (pure Swift: the enum's Hashable/Equatable conformance, no OCCT call) |
| Drawing.ProjectionType is Hashable (#1059) | A set collapses equal cases and keeps distinct ones | `Drawing.ProjectionType (Swift)` | hand-written `==`/`hash(into:)` dropping `focus`; separately `Hashable` removed from the declaration | `:56`, `:58` (hand-written); compile error `:49` | ✔ | N/A (pure Swift: the enum's Hashable/Equatable conformance, no OCCT call) |
| Drawing.ProjectionType is Hashable (#1059) | Equal values hash equal, which Hashable requires and Equatable alone cannot give | `Drawing.ProjectionType (Swift)` | `Hashable` removed: fails to compile (`:64`, `:65` no member `hashValue`); the hand-written payload-dropping conformance leaves it green, as the file's own header says | compile errors `:64`, `:65` | ✔ | N/A (pure Swift: the enum's Hashable/Equatable conformance, no OCCT call) |
| Length Dimension | Point-to-point distance | `OCCTDimensionCreateLengthFromPoints` | `GetValue() + 0.1` (red as written, `:16`); ctor nil: the old `dim!` inside `#expect` would crash the run rather than fail; rewritten to `guard` | rewritten, ctor nil: `:21` | ✔ | PASS |
| Length Dimension | Diagonal distance | `OCCTDimensionCreateLengthFromPoints` | `GetValue() + 0.1` (red as written, `:23`); ctor nil: the old `dim!` inside `#expect` would crash the run rather than fail; rewritten to `guard` | rewritten, ctor nil: `:30` | ✔ | PASS |
| Length Dimension | 3D distance | `OCCTDimensionCreateLengthFromPoints` | `GetValue() + 0.1` (red as written, `:31`); ctor nil: the old `dim!` inside `#expect` would crash the run rather than fail; rewritten to `guard` | rewritten, ctor nil: `:39` | ✔ | PASS |
| Length Dimension | Edge length measurement | `OCCTDimensionCreateLengthFromEdge` | edge ctor nil: **green** as written, and the original never reached its assertion on a clean tree either (it passed a wire-typed shape, which the bridge refuses); rewritten to pass the edge and pin 7 | rewritten, edge ctor nil: `:57` | ✔ | PASS |
| Length Dimension | Face-to-face distance equals box dimension | `OCCTDimensionCreateLengthFromFaces` | face ctor nil: **green** as written (`if let`); rewritten to `guard` | rewritten: `:73` | ✔ | PASS |
| Length Dimension | Geometry contains valid first and second points | `OCCTDimensionGetGeometry` | length geometry second point x + 1 (red as written, `:72`); ctor nil now recorded | rewritten, ctor nil: `:82` | ✔ | PASS |
| Length Dimension | Custom value overrides measured | `OCCTDimensionSetCustomValue` | `GetValue() + 0.1` (red as written, `:80`, `:82`); ctor nil now recorded | rewritten, ctor nil: `:97` | ✔ | PASS |
| Normal Projection | Project line onto sphere near surface | `OCCTShapeNormalProjection` | return the input line unprojected: **green** as written (non-nil and `isValid`); rewritten | rewritten: `:22` edge count, `:23` bounds | ✔ | PASS |
| Normal Projection | Project line outside sphere | `OCCTShapeNormalProjection` | return the input line unprojected: **green** as written (non-nil only); rewritten | rewritten: `:22`, `:23` | ✔ | PASS |
| v0.149 DrawingDimension.ordinate | 3-feature ordinate emits origin cross + X + Y extensions per feature | `emitOrdinate` | a third origin-cross line; separately the dx/dy block gates loosened | `:29`; gates: `:29`, `:30` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| v0.149 DrawingDimension.ordinate | Empty features list emits only the origin cross | `emitOrdinate` | a third origin-cross line | `:37` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| v0.149 DrawingDimension.ordinate | Ordinate applies tolerance to every feature label | `emitOrdinateAxisFeature` | feature labels formatted with `.none` tolerance | `:55` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| v0.149 DrawingDimension.ordinate | Ordinate transforms translate origin and every feature position | `DrawingDimension.transformed` | feature positions not transformed | `:68` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| v0.149 DrawingDimension.ordinate | Ordinate Codable round-trip | `DrawingDimension.Ordinate (Codable)` | `CodingKeys` omitting `id` | `:87` `back == ord` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| v0.149 DrawingDimension.ordinate | Y-only feature (dx == 0) draws only the Y leader/tick/text, isolated from the X block | `emitOrdinate` | a third origin-cross line; separately the X block drawn whenever the feature is off the origin | `:109`; gates: `:109`, `:110` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| v0.149 DrawingDimension.ordinate | Feature exactly at the origin draws neither axis block | `emitOrdinate` | a third origin-cross line; separately the Y block always drawn | `:122`; gates: `:122`, `:123` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| v0.149 DrawingDimension.ordinate | X and Y axis blocks draw exact, independently-verified geometry | `emitOrdinateAxisFeature` | tick length 2.0 to 2.5 | `:155`, `:161` | ✔ | N/A (pure Swift: ordinate-dimension emission, transform and Codable, no OCCT call) |
| Point Projection Tests | Project point onto box face | `OCCTFaceProjectPoint` | distance and z + 0.005: **green** at the old 0.01 tolerance; tightened to 1e-9 | `:36`, `:37` | ✔ | PASS |
| Point Projection Tests | Project point onto sphere face with UV | `OCCTFaceProjectPoint` | distance and z + 0.005: **green** at the old 0.1 tolerance; tightened | `:54`, `:58` | ✔ | PASS |
| Point Projection Tests | All projections returns results | `OCCTFaceProjectPointAll` | distance + 0.05: **green** at the old 0.1 tolerance; tightened, count pinned to 1 | `:83` | ✔ | PASS |
| Point Projection Tests | Project point onto straight edge | `OCCTEdgeProjectPoint` | distance + 0.4: **green** under the old `0 < d < 3`; pinned to sqrt 2 | `:113` | ✔ | PASS |
| Point Projection Tests | Project point onto circular edge | `OCCTEdgeProjectPoint` | distance + 0.4: **green** at the old 0.5 tolerance; tightened | `:154` | ✔ | PASS |
| Polygon-Based HLR | Fast top view of box produces edges | `OCCTDrawingCreatePoly` | view tilted: **green** as written (non-nil only); rewritten (x + 0.1) | `:22`, `:23` | ✔ | PASS |
| Polygon-Based HLR | Fast isometric view of box | `OCCTDrawingCreatePoly` | view tilted: **green** as written (non-nil only); rewritten (x + 0.1) | `:23` | ✔ | PASS |
| Polygon-Based HLR | Fast projection of cylinder | `OCCTDrawingCreatePoly` | view tilted: **green** as written (non-nil only); rewritten (y + 0.1; an x tilt is parallel to this view and changes nothing) | `:23` | ✔ | PASS |
| Polygon-Based HLR | Fast projection has hidden edges | `OCCTDrawingCreatePoly` | view tilted: **green** as written (non-nil only); rewritten (x + 0.1) | `:22`, `:23` | ✔ | PASS |
| Polygon-Based HLR | Fast vs exact projection both succeed | `OCCTDrawingCreatePoly` | view tilted: **green** as written (non-nil only); rewritten (x + 0.1) | `:22`, `:23` (fast) | ✔ | PASS |
| Polygon-Based HLR | Custom deflection affects result | `OCCTDrawingCreatePoly` | view tilted: **green** as written (non-nil only); rewritten (x + 0.1) | `:22`, `:23` | ✔ | PASS |
| #1185 DrawingDimension.Radial/.Diameter share Circular | DrawingDimension.value: .radial reports radius, .diameter reports 2*radius | `DrawingDimension.value` | `.diameter` value returns the radius | `:21` | ✔ | N/A (pure Swift: the 2D DrawingDimension.Circular payload, no OCCT call) |
| #1185 DrawingDimension.Radial/.Diameter share Circular | DrawingDimension.id/.label read through for both .radial and .diameter | `DrawingDimension.id` | circular `id` reads nil | `:30`, `:32` | ✔ | N/A (pure Swift: the 2D DrawingDimension.Circular payload, no OCCT call) |
| #1185 DrawingDimension.Radial/.Diameter share Circular | DrawingDimension.transformed applies scale*p+translate for .diameter | `DrawingDimension.Circular.transformed` | circular transform leaves the radius unscaled | `:45` | ✔ | N/A (pure Swift: the 2D DrawingDimension.Circular payload, no OCCT call) |
| #1185 DrawingDimension.Radial/.Diameter share Circular | DrawingDimension.keyPoints for .radial and .diameter (previously untested) | `DrawingDimension.Circular.keyPoints` | third key point mirrored to `centre.x + radius` | `:56`, `:57` | ✔ | N/A (pure Swift: the 2D DrawingDimension.Circular payload, no OCCT call) |
| #1185 DrawingDimension.Radial/.Diameter share Circular | Drawing.addRadialDimension/addDiameterDimension route through Circular correctly | `Drawing.addDiameterDimension` | `.diameter` value returns the radius | `:91` `diameter.value == 12` | ✔ | N/A (pure Swift: the 2D DrawingDimension.Circular payload, no OCCT call) |
| Radius Dimension | Radius of circle wire | `OCCTDimensionCreateRadiusFromShape` | radius ctor nil: **green** as written (`if let`); rewritten to `guard` | rewritten: `:20` | ✔ | PASS |
| Radius Dimension | Radius geometry has circle center | `OCCTDimensionGetGeometry` | radius ctor nil: **green** as written; rewritten, `circleRadius > 0` pinned to 5 and the centre pinned | rewritten: `:32` | ✔ | PASS |
| Radius Dimension | Nil for non-circular shape | `OCCTDimensionIsValid` | `OCCTDimensionIsValid` always true: the old `!isValid || value >= 0` holds for any value 0 (tautology, not run separately); rewritten to `!isValid` | rewritten: `:49` `!dim.isValid` | ✔ | PASS |
