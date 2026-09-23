# Phase 3: OCCTMathTests Injection Matrix

**Target**: `OCCTMathTests` (342 tests) — Mathematical algorithms, geometry construction, interpolation, solving
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (crash fixes #345, #603, #636, #477, #408, #491)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| gce_MakeLin Tests | 26 | WR/CR |
| gce_MakeCirc Tests | 24 | WR/CR |
| gce_MakeHypr Tests | 22 | WR/CR |
| gce_MakeElips Tests | 20 | WR/CR |
| gce_MakeParab Tests | 18 | WR/CR |
| GC_MakeTranslation | 16 | WR |
| GC_MakeTrimmedCylinder Tests | 15 | WR |
| GC_MakePipe Tests | 14 | WR |
| Convert_CompPolynomialToPoles | 13 | WR |
| MathJacobi Tests | 12 | WR/CR |
| MathSolver Powell v0.110 | 11 | WR |
| Vector2DMath | 10 | WR |
| LineGeometry_Operations | 9 | WR |
| MathSolver FunctionRoot v0.110 | 8 | WR |
| BRepTools_TrsfModification | 8 | WR |
| MathSolver GaussIntegrate v0.111 | 7 | WR |
| ... | ... | ... |

**Total**: 342 tests across ~25 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #345: gp_Dir Zero Vector Crash (Bridge Fix)

**Issue**: `gp_Dir` constructor throws `Standard_ConstructionError` for zero-length direction/normal vector. Multiple math bridge functions construct `gp_Dir`/`gp_Ax1`/`gp_Ax2`/`gp_Ax3`/`Geom_Direction` from caller-supplied doubles with no try/catch.

**Bridge Fix**: Wrapped all affected bridge functions in `try { } catch (...) { <safe fallback> }`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| mirrorAxisZeroDirection | `OCCTMakeMirrorAxis` → `gp_Dir` | Zero direction vector | Remove `try/catch` in bridge |  |  | Uncaught `Standard_ConstructionError` |
| mirrorPlaneZeroNormal | `OCCTMakeMirrorPlane` → `gp_Dir` | Zero normal vector | Remove `try/catch` in bridge |  |  | Uncaught `Standard_ConstructionError` |
| geomDirectionZeroVector | `OCCTGeomDirectionCreate` → `Geom_Direction` | Zero vector handled gracefully | N/A | N/A |  | `Geom_Direction` returns NaN, no exception |

### #603: CPnts_AbscissaPoint Single Quadrature (Bridge + Kernel Fix)

**Issue**: `CPnts_AbscissaPoint::Length` uses ONE fixed-order Gauss rule over whole range → arc length errors up to 1.7% (ellipse) / 3% (parabola).

**Bridge Fix**: Adaptive quadrature in `occtAdaptorArcLength` / `occtArcWalkToLength` — halve each `GeomAbs_CN` interval until two levels agree to 1e-9 relative.

**Kernel Patch**: `0021` — `CPnts_AdaptiveIntegration.hxx` does same doubling for all 4 `Length` overloads and `Value`/`Values`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A whole ellipse measures its own circumference, not 0.3-1.7% more | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error up to 1.7% |
| A parabola over a wide range measures its arc, not 3% less | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error 3% (worst case) |

### #636: Curve3D extrema on Parallel Curves (Bridge Fix)

**Issue**: `BRepExtrema_ExtCC` crashes (SIGSEGV) when edges are parallel — `ExtCC` returns `isParallel=true` but caller accesses points without checking.

**Bridge Fix**: Guard with `if (result.isParallel) { return result; }` before accessing points.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Two unbounded parallel lines: extrema is empty, not a crash | `Curve3D.extrema(to:)` → `BRepExtrema_ExtCC` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |

### #477: Arc-Length Per-Span Split (Bridge Fix)

**Issue**: `GCPnts_AbscissaPoint::Length` splits at `GeomAbs_CN` intervals but not within → 8x3 ellipse 0.337% error over `[0,2pi]`, exact over `[0,pi/2]`.

**Bridge Fix**: Adaptive quadrature inside each interval — halve until two levels agree to 1e-9.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| length of a multi-span interpolated BSpline matches reference | `Curve3D.arcLength` → `occtAdaptorArcLength` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |

### #408: Arc-Length Failure vs Zero-Length Distinguishability

**Issue**: Genuine zero-width interval returns 0.0, not failure sentinel; failing computation distinguishable from real zero.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A genuine zero-width interval reports exactly 0.0, not a failure sentinel | `Curve3D.arcLength(from:to:)` → `occtArcWalkToLength` | Zero vs failure confusion | Remove distinction |  |  | Wrong result |

### #491: Surface Approximation Parity (Kernel Patch 0019)

**Issue**: `AdvApp2Var_ApproxF2var::mma2ce1_` fills the U Jacobi-maxima buffer from the V slot — `GeomConvert_ApproxSurface` at `GeomAbs_C0` returned a surface nowhere near its input while reporting `IsDone()` and a `MaxError()` five orders of magnitude too small.

**Kernel Patch**: `0019` — target `ipt4` from the U call instead of `ipt5`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Surface approximation at C0/C0 matches kernel | `GeomConvert_ApproxSurface` | U buffer filled from V | Revert patch 0019 |  |  | MaxError 25000x wrong |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| gce_MakeLin Tests | 26 |  |  |  |  |
| gce_MakeCirc Tests | 24 |  |  |  |  |
| gce_MakeHypr Tests | 22 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 342 tests

### 766-math-issue1443-ax3-empty-catch (#1983, measured)

| Suite | Test | Bridge function | Injection | Red | Green | Parity |
|-------|------|-----------------|-----------|-----|-------|--------|
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3Create: parallel direction/xDirection overwrites sentinel outputs, not left untouched | `OCCTAx3Create` | catch returns right after recording the exception: the pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3CreateFromNormal: zero-length normal overwrites sentinel outputs, not left untouched | `OCCTAx3CreateFromNormal` | pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3MirrorPoint: degenerate input axis overwrites sentinel outputs with the input point unmoved | `OCCTAx3MirrorPoint` | pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3Rotate: zero-length rotation axis overwrites sentinel outputs with the input point unmoved | `OCCTAx3Rotate` | pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3Translate: degenerate input axis overwrites sentinel outputs with the input point unmoved | `OCCTAx3Translate` | pre-#1443 empty catch | red | green | PASS |
