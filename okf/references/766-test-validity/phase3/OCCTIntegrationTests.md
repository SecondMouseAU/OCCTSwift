# Phase 3: OCCTIntegrationTests Injection Matrix

**Target**: `OCCTIntegrationTests` (19 tests) — Cross-domain workflows, numerical integration
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🟢 P3 (isolated cross-domain workflows)

---

## Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| KronrodIntegration | integrateSin | Numerical accuracy | Remove adaptive quadrature |
| KronrodIntegration | adaptive | Numerical accuracy | Remove adaptive quadrature |
| GaussMultipleIntegration | integrate2D | Numerical accuracy | Remove adaptive quadrature |
| GaussSetIntegration | integrateSet | Numerical accuracy | Remove adaptive quadrature |
| Integration: Mounting Bracket | mountingBracketFullWorkflow | Cross-domain workflow | Remove workflow step |
| Integration: Fluent Composition Chain | fluentChainVolumeDecreases | Cross-domain workflow | Remove chain step |
| Integration: Z-Level Slicing | cylinderWithHolesSlicing | Cross-domain workflow | Remove slicing step |
| Integration: Hole Detection | plateWithHolesSection | Cross-domain workflow | Remove detection step |
| Integration: Degenerate Resilience | oversizedFilletReturnsNil | Degenerate handling | Remove nil check |
| Integration: Degenerate Resilience | zeroDepthDrill | Degenerate handling | Remove nil check |
| Integration: Degenerate Resilience | selfUnion | Degenerate handling | Remove nil check |
| Integration: OBB Tightness | obbTighterThanAABBForRotatedShape | Geometry accuracy | Remove OBB computation |
| Integration: Memory Stress | thousandBoxesNoLeak | Memory management | Remove leak check |
| Integration: Pocket Clearing | pocketSectionAndOffset | Cross-domain workflow | Remove pocket step |
| Integration: Scallop Analysis | surfaceCurvatureVariation | Geometry analysis | Remove curvature check |
| Integration: Bottle Profile | bottleShapeWorkflow | Cross-domain workflow | Remove workflow step |
| Integration: Cross-Section Regression | cylinderConsistentCircularSections | Geometry accuracy | Remove regression check |
| Integration: Tolerance Cascade | booleanWithSharedEdgeAndGap | Tolerance handling | Remove cascade check |
| Integration: Format Fidelity BREP | brepStringRoundTrip | Format fidelity | Remove round-trip check |

---

## Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| KronrodIntegration/integrateSin | OCCTMathKronrodIntegration | Numerical accuracy | Return 0.0 instead of integral | ✅ | ✅ | Basic Kronrod returns ~2.0 for sin(x) on [0,π]; defect makes it return 0.0, test fails on `abs(r.value - 2.0) < 1e-6` |
| KronrodIntegration/adaptive | OCCTMathKronrodIntegrationAdaptive | Numerical accuracy | Skip adaptive refinement | ✅ | ✅ | Adaptive should converge to 1e-10 tolerance; defect returns coarse result, test fails on `abs(r.value - 2.0) < 1e-8` |
| GaussMultipleIntegration/integrate2D | OCCTMathGaussMultipleIntegration | Numerical accuracy | Return 0.0 instead of integral | ✅ | ✅ | 2D integral of x²+y² on [0,1]² = 2/3; defect makes it return 0.0, test fails on `abs(r - 2.0/3.0) < 1e-6` |
| GaussSetIntegration/integrateSet | OCCTMathGaussSetIntegration | Numerical accuracy | Return nil instead of result | ✅ | ✅ | Set integration of [x, x²] on [0,2] = [2, 8/3]; defect returns nil, test fails on `result != nil` |
| Mounting Bracket | OCCTShapeCreateBox/Union/Fillet/Drill/Chamfer | Cross-domain workflow | Skip union step (return first operand) | ✅ | ✅ | Union of base+wall required; defect returns base only, volume check fails on `vUnion > 0` |
| Fluent Composition Chain | OCCTShapeFillet/Drill/Chamfer/Shell | Cross-domain workflow | Skip fillet step | ✅ | ✅ | Volume should decrease at each stage; defect skips fillet, v2==v1, test fails on `v3 < v2` |
| Z-Level Slicing | OCCTShapeSectionWiresAtZ | Cross-domain workflow | Return empty array | ✅ | ✅ | 10 slices should all be non-empty; defect returns [], test fails on `allSlicesNonEmpty` |
| Hole Detection | OCCTShapeSectionWiresAtZ | Cross-domain workflow | Return only outer wire | ✅ | ✅ | Should detect 5 wires (outer+4 holes); defect returns 1 wire, test fails on `wires.count == 5` |
| oversizedFilletReturnsNil | OCCTShapeFillet | Degenerate handling | Return shape instead of nil | ✅ | ✅ | Radius 20 > edge/2 (5) should return nil; defect returns shape, test fails on `result == nil` |
| zeroDepthDrill | OCCTShapeDrillHole | Degenerate handling | Return nil for valid through-hole | ✅ | ✅ | depth=0 means through-hole; defect returns nil, test fails on `drilled.isValid` |
| selfUnion | OCCTShapeUnionEx | Degenerate handling | Return nil for valid self-union | ✅ | ✅ | Union of box with itself should succeed; defect returns nil, test fails on `result != nil` |
| OBB Tightness | OCCTShapeOBB | Geometry accuracy | Return AABB as OBB | ✅ | ✅ | OBB should be tighter for rotated box; defect returns AABB, test fails on `obbVolume <= aabbVolume * 1.01` |
| Memory Stress | OCCTShapeCreateBox | Memory management | Leak handle (don't release) | ✅ | ✅ | Volume should be consistent; defect leaks memory, test may pass but ASan detects leak |
| Pocket Clearing | OCCTShapeSubtractEx | Cross-domain workflow | Skip subtraction (return outer) | ✅ | ✅ | Pocket volume < outer volume; defect returns outer, test fails on `pv < ov` |
| Scallop Analysis | OCCTSurfaceCurvature | Geometry analysis | Return 0.0 for all curvatures | ✅ | ✅ | Sphere curvature = 1/R²; defect returns 0, test fails on `abs(gauss - expectedGaussian) < 0.001` |
| Bottle Profile | OCCTShapeCreateRevolution/Union/Fillet/Shell | Cross-domain workflow | Skip shell step | ✅ | ✅ | Shelled volume < solid volume; defect skips shell, test fails on `shelledVol < solidVolume` |
| Cross-Section Regression | OCCTShapeSectionWiresAtZ | Geometry accuracy | Return varying lengths | ✅ | ✅ | All sections should have same circumference; defect returns varying, test fails on `abs(len - first) < 0.01` |
| Tolerance Cascade | OCCTShapeUnionEx/SubtractEx | Tolerance handling | Skip gap check | ✅ | ✅ | Gapped union volume should ≈ sum; defect ignores gap, volume wrong, test fails on `abs(gVol - sum) < 1.0` |
| BREP Round-trip | OCCTShapeWriteBREP/ReadBREP | Format fidelity | Corrupt BREP string | ✅ | ✅ | Round-trip should preserve volume/area/faces/edges; defect corrupts, test fails on property comparisons |

---

## Bridge-Kernel Parity Checks

For each test, run ground-truth C++ comparison:
1. Write C++ test calling OCCT kernel directly
2. Run same inputs through Swift bridge
3. Compare outputs bit-for-bit (integers) or 1e-12 relative (doubles)
4. Document any discrepancies

---

## Progress Tracking

| Test | Red→Green Done | Parity Done | PR Ready |
|------|----------------|-------------|----------|
| KronrodIntegration/integrateSin | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| KronrodIntegration/adaptive | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| GaussMultipleIntegration/integrate2D | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| GaussSetIntegration/integrateSet | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Mounting Bracket | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Fluent Composition Chain | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Z-Level Slicing | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Hole Detection | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Degenerate Resilience (3) | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| OBB Tightness | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Memory Stress | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Pocket Clearing | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Scallop Analysis | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Bottle Profile | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Cross-Section Regression | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| Tolerance Cascade | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |
| BREP Round-trip | ✅ 2026-09-19 | ✅ 2026-09-19 | ✅ |

**Total**: 19 tests