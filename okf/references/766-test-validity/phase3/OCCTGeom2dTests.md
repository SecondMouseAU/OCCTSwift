# Phase 3: OCCTGeom2dTests Injection Matrix

**Target**: `OCCTGeom2dTests` (545 tests) — 2D geometry, curves, adaptors
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (crash fixes #345, #603, #636, #477 in 2D)

---

## Test Inventory by Suite (Top by Count)

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| BSpline Curve 2D Manipulation Tests | 22 | WR |
| Curve2D Primitive Tests | 18 | WR |
| Curve2D Operations Tests | 17 | WR |
| BSplineCurve 2D Completions v121 | 15 | WR |
| **Arc length stops being one quadrature per span (#603, 2D)** | **14** | **CR/WR (#603)** |
| Curve2D Conic Factory Families | 13 | WR |
| Analytical conversion contract (#492) | 12 | WR |
| Bezier Curve 2D Manipulation Tests | 11 | WR |
| Curve2D Plane Projection Tests | 10 | WR |
| The nearest point is on the curve, not on its basis (#539) | 10 | WR |
| Curve2D Conic Family Tests | 10 | WR |
| Curve2D Continuity Queries v0.120.0 | 9 | WR |
| Curve2D arc-length accuracy on multi-span curves (#477) | 9 | CR/WR (#477) |
| Issue #211/#212, EdgeCurve arc-length adaptor | 9 | CR/WR |
| v0.114.0 - Curve2D DN | 8 | WR |
| Curve2D Extras v0.109 | 8 | WR |
| v0.115.0 - GCPnts Expansion (2D) | 7 | WR |
| GeomEval, Circular Helix Curve (2D) | 7 | WR |
| GeomEval, Elliptical Helix Curve | 7 | WR |
| Geom2dAdaptor Curve Tests | 7 | WR |
| Geom2dGccSolver Tests | 7 | WR |
| Geom2d_Hatching Tests | 7 | WR |
| Geom2d_Bisector Tests | 7 | WR |
| Geom2d_Conversion Tests | 7 | WR |
| ... | ... | ... |

**Total**: 545 tests across ~70 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #345: gp_Dir2d Zero Vector Crash (Bridge Fix)

**Issue**: `gp_Dir2d` constructor throws `Standard_ConstructionError` for zero-length direction vector.

**Bridge Fix**: Wrapped constructors in `try { } catch (...) { <safe fallback> }`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| mirrorAxisZeroDirection (2D) | `OCCTMakeMirror2dAxis` → `gp_Dir2d` | Zero direction vector | Remove `try/catch` |  |  | SIGABRT |
| geomDirection2dZeroVector | `OCCTGeomDirection2dCreate` → `Geom2d_Direction` | Zero vector handled | N/A | N/A |  | Graceful |

### #603: CPnts_AbscissaPoint 2D Single Quadrature (Bridge + Kernel Fix)

**Issue**: `CPnts_AbscissaPoint::Length` on 2D curves uses single quadrature → arc length errors.

**Bridge Fix**: Adaptive quadrature in `occtAdaptorArcLength` (2D version).

**Kernel Patch**: `0021` — applies to 2D as well.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A whole ellipse measures its own circumference (2D) | `Curve2D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error up to 1.7% |
| A parabola over a wide range measures its arc (2D) | `Curve2D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error 3% |
| The closed forms stay exact (2D) | `Curve2D.arcLength` → closed-form | Control | No injection |  |  | Line/circle |
| Accurate sub-ranges sum to whole (2D) | `Curve2D.arcLength(from:to:)` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| parameterAtLength walks correctly (2D) | `Curve2D.parameterAtLength` | Single quadrature | Remove adaptive quadrature |  |  | Inverse wrong |

### #636: Curve2D extrema on Parallel Curves (Bridge Fix)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Two unbounded parallel lines: extrema is empty (2D) | `Curve2D.extrema(to:)` → `Geom2dAPI_ExtremaCurveCurve` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |
| Two bounded parallel segments: extrema is empty (2D) | `Curve2D.extrema(to:)` → `Geom2dAPI_ExtremaCurveCurve` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |

### #477: Arc-Length Per-Span Split (2D) (Bridge Fix)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| length of a multi-span interpolated BSpline matches reference (2D) | `Curve2D.arcLength` → `occtAdaptorArcLength` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |
| length(from:to:) over a sub-range matches reference (2D) | `Curve2D.arcLength(from:to:)` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |

---

## Injection Matrix: Borrowed Handles (Curve2D *Properties)

**From #965**: 7 `*Properties` views in Curve2D.swift stored raw handles. Fixed by conforming to `NativeHandleView`.

| Test | Properties Type | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| every Curve2D *Properties accessor keeps its parent alive | Circle/Ellipse/Hyperbola/Parabola/Line/BSpline/Bezier | Raw handle storage | Revert to `fileprivate let handle` |  |  | SIGSEGV (use-after-free) |
| a view outliving its parent still reads the right values | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |
| a view outliving its parent survives 400 intervening allocations | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |

---

## Injection Matrix: Null-Handle Guards (Curve2D Entry Points)

From `check-null-handle-guards.py` ALLOWED table - 8 Curve2D entry points need `curve.IsNull()` guard.

| Bridge Function | OCCT Call | Test Coverage | Injection Status |
|-----------------|-----------|---------------|------------------|
| `OCCTGeomLibToolParameter2D` | `GeomLib_Tool::Parameter` | Geom2dTests | |
| `OCCTExtremaLocateExtCC2d` | `Geom2dAdaptor_Curve` | Geom2dTests | |
| `OCCTGeom2dConvertApproxArcsSegments` | `Geom2dAdaptor_Curve` | Geom2dTests | |
| `OCCTGeom2dConvertApproxArcsSegments` (local handle) | `BRep_Tool::CurveOnSurface` | StressTests | |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| BSpline Curve 2D Manipulation Tests | 22 |  |  |  |  |
| Curve2D Primitive Tests | 18 |  |  |  |  |
| Curve2D Operations Tests | 17 |  |  |  |  |
| BSplineCurve 2D Completions v121 | 15 |  |  |  |  |
| **Arc length stops being one quadrature per span (#603, 2D)** | **14** |  |  |  |  |
| Curve2D Conic Factory Families | 13 |  |  |  |  |
| Analytical conversion contract (#492) | 12 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 545 tests

### #1979 executed: `Transform2DCompositionTests.swift`, `Transform2DCreationTests.swift`

Probe: `Scripts/repro/766-geom2d-transform-vector/`. Every row was run red with the injection applied and green after it was reverted.

| Test | Bridge function | Injection | Red | Green | Parity | Notes |
|---|---|---|---|---|---|---|
| Transform2D Composition::inverted | `OCCTTransform2DInverted` | returns a copy, not the inverse | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Composition::composed | `OCCTTransform2DComposed` | composes with itself | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Composition::powered | `OCCTTransform2DPowered` | power n - 1 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Composition::matrixValues | `OCCTTransform2DGetValues` | a12 + 1e-3 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Composition::applyToCurve | `OCCTTransform2DApplyToCurve` | transform not applied to the copy | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require`; far end now pinned |
| Transform2D Creation::identity | `OCCTTransform2DCreateIdentity` | scale 2 instead of identity | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Creation::translation | `OCCTTransform2DCreateTranslation` | dx + 1 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Creation::rotation | `OCCTTransform2DCreateRotation` | angle negated | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Creation::scale | `OCCTTransform2DCreateScale` | factor + 1 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Creation::mirrorPoint | `OCCTTransform2DCreateMirrorPoint` | mirror point x + 1 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Transform2D Creation::mirrorAxis | `OCCTTransform2DCreateMirrorAxis` | rotation by 0.1 instead of the mirror | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
