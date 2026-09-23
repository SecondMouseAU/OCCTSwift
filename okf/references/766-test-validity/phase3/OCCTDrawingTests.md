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
