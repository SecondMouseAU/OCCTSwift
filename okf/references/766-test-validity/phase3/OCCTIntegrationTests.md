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
| KronrodIntegration/integrateSin | OCCTKronrodIntegrate | Numerical accuracy | Remove adaptive quadrature |  |  |  |
| KronrodIntegration/adaptive | OCCTKronrodIntegrate | Numerical accuracy | Remove adaptive quadrature |  |  |  |
| GaussMultipleIntegration/integrate2D | OCCTGaussMultipleIntegrate | Numerical accuracy | Remove adaptive quadrature |  |  |  |
| GaussSetIntegration/integrateSet | OCCTGaussSetIntegrate | Numerical accuracy | Remove adaptive quadrature |  |  |  |
| Mounting Bracket | OCCTShapeExtrude/Revolve | Cross-domain workflow | Remove workflow step |  |  |  |
| Fluent Composition Chain | OCCTShapeFuse/Transform | Cross-domain workflow | Remove chain step |  |  |  |
| Z-Level Slicing | OCCTShapeSection | Cross-domain workflow | Remove slicing step |  |  |  |
| Hole Detection | OCCTShapeHoles | Cross-domain workflow | Remove detection step |  |  |  |
| oversizedFilletReturnsNil | OCCTShapeFillet | Degenerate handling | Remove nil check |  |  |  |
| zeroDepthDrill | OCCTShapeDrill | Degenerate handling | Remove nil check |  |  |  |
| selfUnion | OCCTShapeFuse | Degenerate handling | Remove nil check |  |  |  |
| OBB Tightness | OCCTShapeOBB | Geometry accuracy | Remove OBB computation |  |  |  |
| Memory Stress | OCCTShapeBox | Memory management | Remove leak check |  |  |  |
| Pocket Clearing | OCCTShapePocket | Cross-domain workflow | Remove pocket step |  |  |  |
| Scallop Analysis | OCCTSurfaceCurvature | Geometry analysis | Remove curvature check |  |  |  |
| Bottle Profile | OCCTShapeRevolve | Cross-domain workflow | Remove workflow step |  |  |  |
| Cross-Section Regression | OCCTShapeSection | Geometry accuracy | Remove regression check |  |  |  |
| Tolerance Cascade | OCCTShapeFuse | Tolerance handling | Remove cascade check |  |  |  |
| BREP Round-trip | OCCTShapeWriteBREP | Format fidelity | Remove round-trip check |  |  |  |

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
| KronrodIntegration/integrateSin | ✅ | ✅ | ✅ |
| KronrodIntegration/adaptive | ✅ | ✅ | ✅ |
| GaussMultipleIntegration/integrate2D | ✅ | ✅ | ✅ |
| GaussSetIntegration/integrateSet | ✅ | ✅ | ✅ |
| Mounting Bracket | ✅ | ✅ | ✅ |
| Fluent Composition Chain | ✅ | ✅ | ✅ |
| Z-Level Slicing | ✅ | ✅ | ✅ |
| Hole Detection | ✅ | ✅ | ✅ |
| Degenerate Resilience (3) | ✅ | ✅ | ✅ |
| OBB Tightness | ✅ | ✅ | ✅ |
| Memory Stress | ✅ | ✅ | ✅ |
| Pocket Clearing | ✅ | ✅ | ✅ |
| Scallop Analysis | ✅ | ✅ | ✅ |
| Bottle Profile | ✅ | ✅ | ✅ |
| Cross-Section Regression | ✅ | ✅ | ✅ |
| Tolerance Cascade | ✅ | ✅ | ✅ |
| BREP Round-trip | ✅ | ✅ | ✅ |

**Total**: 19 tests