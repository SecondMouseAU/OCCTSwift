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
