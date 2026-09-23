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

### 766-math-issue640-dimension-bounds (#1983, measured)

| Suite | Test | Bridge function | Injection | Red | Green | Parity |
|-------|------|-----------------|-----------|-----|-------|--------|
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathGauss.determinant rejects a non-positive n and a matrix shorter than n*n | `OCCTMathGaussDeterminant (guarded in MathGauss.determinant)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | PASS |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathGauss.determinant distinguishes an invalid dimension from a genuinely singular matrix | `OCCTMathGaussDeterminant` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | PASS |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathCrout.determinant rejects a non-positive n and a matrix shorter than n*n | `OCCTMathCroutDeterminant (guarded in MathCrout.determinant)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | PASS |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathCrout.determinant distinguishes an invalid dimension from a genuinely singular matrix | `OCCTMathCroutDeterminant` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | PASS |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSVD.solve rejects a consistent-but-non-positive dimension | `none reached for the rejected cases (MathSVD.solve guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathJacobi.eigenvalues rejects a consistent-but-negative n | `none reached (MathJacobi.eigenvalues guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathHouseholder.solve rejects a consistent-but-non-positive dimension | `none reached (MathHouseholder.solve guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.solveSystem rejects non-positive dimensions and a mismatched startPoint | `none reached (MathSolver.solveSystem guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.solveSystem/.solveSystemNewton reject a values/jacobian closure that returns the wrong length | `OCCTMathFunctionSetRoot / Newton callbacks (Swift closure-length checks)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.minimize rejects a non-positive variables and a mismatched startPoint | `none reached (MathSolver.minimize guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.minimize/.minimizeNewton/.minimizeFRPR reject a function closure whose gradient/hessian is the wrong length | `Swift callback length checks before OCCTMathBFGS / Newton / FRPR` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.minimizePowell rejects a non-positive variables and a mismatched startPoint | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.particleSwarm rejects a non-positive variables and mismatched bounds | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.globalMinimize rejects a non-positive variables and mismatched bounds | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.solveSystemNewton rejects non-positive dimensions and a mismatched startPoint | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.minimizeNewton rejects a non-positive n and a mismatched startPoint | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.leastSquares rejects a non-positive dimension and reads no further out of bounds | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.uzawa rejects non-positive dimensions and mismatched constraint arrays | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.eigenvalues/eigenvaluesAndVectors reject an off-diagonal of the wrong length | `none reached (MathDimension.tridiagonal guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.gaussMultipleIntegration/.gaussSetIntegration reject mismatched arrays | `none reached (guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.gaussSetIntegration rejects more than one variable instead of silently integrating only the first | `none reached (lower.count == 1 guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | MathSolver.gaussSetIntegration rejects a function closure that returns the wrong length | `Swift callback length check before OCCTMathGaussSetIntegration` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | findAllRoots(samples:) routes through Sampling instead of trapping past Int32 | `none reached (Sampling.requested guard)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640: math dimension arguments reject negative and mismatched input** | findAllRoots(samples:) accepts the documented minimum of 1, not Sampling's own default floor of 2 | `OCCTMathFunctionAllRoots (reached only via the Swift path)` | P2_640_FAKE: the Swift entry point returns a plausible non-nil result without validating (the pre-#640 'SUCCEEDS w/ garbage' outcome, reproduced without the out-of-bounds read) | red | green | N/A |
| **Issue #640 review finding 9: MathDimension is the one shared validator** | valid requires positivity and every given length to match exactly | `none (pure Swift MathDimension.valid)` | MathDimension.valid drops its n > 0 check | red | green | N/A |
| **Issue #640 review finding 9: MathDimension is the one shared validator** | consistent checks length agreement only, no positivity | `none (pure Swift MathDimension.consistent)` | MathDimension.consistent always true | red | green | N/A |
| **Issue #640 review finding 9: MathDimension is the one shared validator** | validSquare checks n > 0, n * n == count, and does not overflow | `none (pure Swift MathDimension.validSquare)` | MathDimension.validSquare drops its n > 0 check | red | green | N/A |
| **Issue #640 review finding 9: MathDimension is the one shared validator** | validRectangle checks rows > 0, cols > 0, rows * cols == count, and does not overflow | `none (pure Swift MathDimension.validRectangle)` | MathDimension.validRectangle drops its positivity check | red | green | N/A |
