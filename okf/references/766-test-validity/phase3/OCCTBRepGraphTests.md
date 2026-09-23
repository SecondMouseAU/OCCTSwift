# Phase 3: OCCTBRepGraphTests Injection Matrix

**Target**: `OCCTBRepGraphTests` (18 tests) — BRepGraph traversal, attributes, queries
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🟡 P2 (graph traversal, thread safety)

---

## Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **BRepGraph Builder RemoveNode** | BRepGraph Builder RemoveNode | Graph mutation | Remove node removal |
| **BRepGraph Shell Extended** | BRepGraph Shell Extended | Graph traversal | Remove shell traversal |
| **Split (1-to-N) mapping round-trips** | Split (1-to-N) mapping round-trips | Graph mapping | Remove mapping |
| **BRepGraph CompSolid Count** | BRepGraph CompSolid Count | Graph query | Remove count |
| **findDerivedOrSelf** | findDerivedOrSelf: returns derivatives, [] for deleted, [original] for untouched | Graph query | Remove query |
| **BRepGraph Edge Queries** | BRepGraph Edge Queries | Graph query | Remove edge query |
| **BRepGraph Builder AddFaceToShell** | BRepGraph Builder AddFaceToShell | Graph mutation | Remove face addition |
| **BRepGraph Shell Queries** | BRepGraph Shell Queries | Graph query | Remove shell query |
| **Graph history absorb** | Graph history absorb | Graph history | Remove history absorb |
| **v0.141 BRepGraph history record readback** | v0.141 BRepGraph history record readback | Graph history | Remove history readback |
| **BRepGraph Vertex Geometry** | BRepGraph Vertex Geometry | Graph geometry | Remove geometry query |
| **BRepGraph Builder AddShellToSolid** | BRepGraph Builder AddShellToSolid | Graph mutation | Remove shell addition |
| **BRepGraph Edge Sampling** | BRepGraph Edge Sampling | Graph query | Remove edge sampling |
| **BRepGraph Builder Deferred** | BRepGraph Builder Deferred | Graph mutation | Remove deferred mode |
| **alongEdge on helical thread** | alongEdge on a helical thread edge does not silently return the cylinder's centerline | Edge traversal | Remove alongEdge |
| **alongEdge on T-branch** | alongEdge on a T-branch between two non-coaxial cylinders falls back to the chord | Edge traversal | Remove alongEdge |
| **v0.142 ConstructionAxis resolution** | v0.142 ConstructionAxis resolution | Graph axis | Remove axis resolution |
| **deferredModeToggle()** | deferredModeToggle() | Graph mutation | Remove deferred toggle |
| **v0.142 ConstructionAxis resolution** | alongEdge | Axis along edge | line-branch direction not normalized |
| **v0.142 ConstructionAxis resolution** | alongEdgeCylindricalRimUsesRevolutionAxis | Axis along edge | revolution-axis redirect skipped |
| **v0.142 ConstructionAxis resolution** | alongEdgePartialCylinderUsesAxisNotChord | Axis along edge | revolution-axis redirect skipped |
| **v0.142 ConstructionAxis resolution** | alongEdgeStandaloneCircleNoAdjacentFaceDegenerate | Axis along edge | chord fallback degeneracy check removed |
| **v0.142 ConstructionAxis resolution** | alongEdgeBranchWithDisagreeingAxesFallsBackToChord | Axis along edge | axesAgree always true |
| **v0.142 ConstructionAxis resolution** | alongEdgeCylindricalRimOriginStaysNearRimNotSurfaceBase | Axis along edge | revolution-axis redirect skipped |
| **v0.142 ConstructionAxis resolution** | alongEdgeStraightSeamReparameterizedAsBSplineKeepsChord | Axis along edge | coaxial cross-section check skipped |
| **v0.142 ConstructionAxis resolution** | alongEdgeEllipticalRimDoesNotSilentlyReturnCenterline | Axis along edge | coaxial cross-section check skipped |
| **v0.142 ConstructionAxis resolution** | alongEdgeGenuinelyDegenerateEdgeNextToCleanCylinderStillDegenerate | Axis along edge | zero-length guard removed |
| **v0.142 ConstructionAxis resolution** | alongEdgeConeStraightSeamReparameterizedAsBSplineKeepsChord | Axis along edge | coaxial cross-section check skipped |
| **v0.142 ConstructionAxis resolution** | alongEdgeSignTracksEdgeTopologyNotSurfaceConvention | Axis along edge | sign flip removed |
| **v0.142 ConstructionAxis resolution** | alongEdgeHelicalEdgeDoesNotSilentlyReturnCenterline | Axis along edge | coaxial cross-section check skipped |
| **v0.142 ConstructionAxis resolution** | coincidentPointsDegenerate | Axis through points | degeneracy check removed |
| **v0.142 ConstructionAxis resolution** | parallelIntersectionDegenerate | Axis from planes | degeneracy check removed |
| **v0.142 ConstructionAxis resolution** | normalToFaceCylinderPrimaryAxis | Axis normal to face | axis-kind list replaced |
| **v0.142 ConstructionAxis resolution** | normalToFaceCylinderOriginOnAxis | Axis normal to face | axis-kind list replaced |
| **v0.142 ConstructionAxis resolution** | normalToFaceTorusOriginOnAxis | Axis normal to face | axis-kind list replaced |
| **v0.142 ConstructionAxis resolution** | normalToFacePlaneFallback | Axis normal to face | projection ignored, UV midpoint used |
| **v0.142 ConstructionAxis resolution** | normalToFaceExtrusionFallsBackToNormal | Axis normal to face | extrusion treated as an axis |
| **v0.142 ConstructionAxis resolution** | normalToFaceSphereFallsBackToNormal | Axis normal to face | sphere treated as an axis |
| **v0.142 ConstructionAxis resolution** | normalToFaceFreeFormVariesWithPoint | Axis normal to face | projection ignored, UV midpoint used |
| **v0.142 ConstructionAxis resolution** | normalToFaceOriginIsOnFaceNotRawPoint | Axis normal to face | raw point returned |
| **v0.142 ConstructionAxis resolution** | alongEdgeUndefinedStartTangentFailsLoudNotSilent | Axis along edge | undefined tangent accepted |
| **v0.142 ConstructionAxis resolution** | coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise | Axis along edge | edge tolerance ignored |

---

## Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| BRepGraph Builder RemoveNode | OCCTBRepGraphBuilderRemoveNode | Graph mutation | Remove node removal | ✅ | ✅ |  |
| BRepGraph Shell Extended | OCCTBRepGraphShellExtended | Graph traversal | Remove shell traversal | ✅ | ✅ |  |
| Split (1-to-N) mapping | OCCTBRepGraphSplitMapping | Graph mapping | Remove mapping | ✅ | ✅ |  |
| BRepGraph CompSolid Count | OCCTBRepGraphCompSolidCount | Graph query | Remove count | ✅ | ✅ |  |
| findDerivedOrSelf | OCCTBRepGraphFindDerivedOrSelf | Graph query | Remove query | ✅ | ✅ |  |
| BRepGraph Edge Queries | OCCTBRepGraphEdgeQueries | Graph query | Remove edge query | ✅ | ✅ |  |
| BRepGraph Builder AddFaceToShell | OCCTBRepGraphBuilderAddFaceToShell | Graph mutation | Remove face addition | ✅ | ✅ |  |
| BRepGraph Shell Queries | OCCTBRepGraphShellQueries | Graph query | Remove shell query | ✅ | ✅ |  |
| Graph history absorb | OCCTBRepGraphHistoryAbsorb | Graph history | Remove history absorb | ✅ | ✅ |  |
| v0.141 history record readback | OCCTBRepGraphHistoryReadback | Graph history | Remove history readback | ✅ | ✅ |  |
| BRepGraph Vertex Geometry | OCCTBRepGraphVertexGeometry | Graph geometry | Remove geometry query | ✅ | ✅ |  |
| BRepGraph Builder AddShellToSolid | OCCTBRepGraphBuilderAddShellToSolid | Graph mutation | Remove shell addition | ✅ | ✅ |  |
| BRepGraph Edge Sampling | OCCTBRepGraphEdgeSampling | Graph query | Remove edge sampling | ✅ | ✅ |  |
| BRepGraph Builder Deferred | OCCTBRepGraphBuilderDeferred | Graph mutation | Remove deferred mode | ✅ | ✅ |  |
| alongEdge helical thread | OCCTBRepGraphAlongEdge | Edge traversal | Remove alongEdge | ✅ | ✅ |  |
| alongEdge T-branch | OCCTBRepGraphAlongEdge | Edge traversal | Remove alongEdge | ✅ | ✅ |  |
| v0.142 ConstructionAxis | OCCTBRepGraphConstructionAxis | Graph axis | Remove axis resolution | ✅ | ✅ |  |
| deferredModeToggle | OCCTBRepGraphDeferredModeToggle | Graph mutation | Remove deferred toggle | ✅ | ✅ |  |
| alongEdge | OCCTEdgeGetPointAtParam | Axis along edge | resolveEdgeDirection line branch returns (start, dir) unnormalized | ✅ | ✅ | Origin and direction now pinned as well as unit length |
| alongEdgeCylindricalRimUsesRevolutionAxis | OCCTFaceGetPrimaryAxis | Axis along edge | `if false, let axis = revolutionAxis(...)` | ✅ | ✅ |  |
| alongEdgePartialCylinderUsesAxisNotChord | OCCTFaceGetPrimaryAxis | Axis along edge | `if false, let axis = revolutionAxis(...)` | ✅ | ✅ |  |
| alongEdgeStandaloneCircleNoAdjacentFaceDegenerate | OCCTBRepGraphEdgeFaceIndices | Axis along edge | final chord fallback passes magnitude 1.0; zero-length guard removed | ✅ | ✅ |  |
| alongEdgeBranchWithDisagreeingAxesFallsBackToChord | OCCTFaceGetPrimaryAxis | Axis along edge | axesAgree returns true | ✅ | ✅ |  |
| alongEdgeCylindricalRimOriginStaysNearRimNotSurfaceBase | OCCTFaceGetPrimaryAxis | Axis along edge | `if false, let axis = revolutionAxis(...)` | ✅ | ✅ |  |
| alongEdgeStraightSeamReparameterizedAsBSplineKeepsChord | OCCTEdgeGetPointAtParam | Axis along edge | `true || coaxialCrossSection(...)` at the call site | ✅ | ✅ |  |
| alongEdgeEllipticalRimDoesNotSilentlyReturnCenterline | OCCTEdgeGetPointAtParam | Axis along edge | `true || coaxialCrossSection(...)` applied alone (the combined round-2 set left it green) | ✅ | ✅ | Resolves to .degenerate(zero-length edge) when correct; kernel ellipse length 33.06, closed |
| alongEdgeGenuinelyDegenerateEdgeNextToCleanCylinderStillDegenerate | OCCTEdgeGetPointAtParam | Axis along edge | `guard true || edge.length >= eps`; chord fallback check removed | ✅ | ✅ |  |
| alongEdgeConeStraightSeamReparameterizedAsBSplineKeepsChord | OCCTEdgeGetPointAtParam | Axis along edge | `true || coaxialCrossSection(...)` | ✅ | ✅ |  |
| alongEdgeSignTracksEdgeTopologyNotSurfaceConvention | OCCTEdgeGetTangent3D | Axis along edge | `if false && simd_dot(...) < 0` | ✅ | ✅ |  |
| alongEdgeHelicalEdgeDoesNotSilentlyReturnCenterline | OCCTEdgeGetPointAtParam | Axis along edge | `true || coaxialCrossSection(...)` | ✅ | ✅ |  |
| coincidentPointsDegenerate | OCCTShapeVertexPoint | Axis through points | throughPoints passes magnitude 1.0 | ✅ | ✅ |  |
| parallelIntersectionDegenerate | none (pure Swift: ConstructionAxis.intersectionOfPlanes) | Axis from planes | intersectionOfPlanes passes magnitude 1.0 | ✅ | ✅ |  |
| normalToFaceCylinderPrimaryAxis | OCCTFaceGetPrimaryAxis | Axis normal to face | `case .sphere, .extrusion:` in place of cylinder/cone/torus/revolution | ✅ | ✅ |  |
| normalToFaceCylinderOriginOnAxis | OCCTFaceGetPrimaryAxis | Axis normal to face | same | ✅ | ✅ | Kernel: vertex 1 is (5,0,0); its projection on the (0,0,1) axis is the origin |
| normalToFaceTorusOriginOnAxis | OCCTFaceGetPrimaryAxis | Axis normal to face | same | ✅ | ✅ | Kernel: vertex 0 is (25,0,0), height 0 on the (0,0,1) axis |
| normalToFacePlaneFallback | OCCTFaceGetNormalAtUV | Axis normal to face | projectedNormal returns face.uvMidpointSample() | ✅ | ✅ | Rewritten: unit length alone passed a wrong point; now pins (-5,-5,-5) and (-1,0,0) |
| normalToFaceExtrusionFallsBackToNormal | OCCTFaceGetPrimaryAxis | Axis normal to face | `case .sphere, .extrusion:` | ✅ | ✅ |  |
| normalToFaceSphereFallsBackToNormal | OCCTFaceGetPrimaryAxis | Axis normal to face | `case .sphere, .extrusion:` | ✅ | ✅ |  |
| normalToFaceFreeFormVariesWithPoint | OCCTFaceProjectPoint | Axis normal to face | projectedNormal returns face.uvMidpointSample() | ✅ | ✅ |  |
| normalToFaceOriginIsOnFaceNotRawPoint | OCCTFaceProjectPoint | Axis normal to face | projectedNormal returns (point, normal) instead of (projection.point, normal) | ✅ | ✅ |  |
| alongEdgeUndefinedStartTangentFailsLoudNotSilent | OCCTEdgeGetTangent3D | Axis along edge | nil tangent replaced by zero vector (R2); redirect skipped (R1) | ✅ | ✅ |  |
| coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise | OCCTEdgeGetPointAtParam | Axis along edge | crossSectionTolerance = floor only | ✅ | ✅ |  |

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
| BRepGraph Builder RemoveNode | ✅ | ✅ | ✅ |
| BRepGraph Shell Extended | ✅ | ✅ | ✅ |
| Split (1-to-N) mapping | ✅ | ✅ | ✅ |
| BRepGraph CompSolid Count | ✅ | ✅ | ✅ |
| findDerivedOrSelf | ✅ | ✅ | ✅ |
| BRepGraph Edge Queries | ✅ | ✅ | ✅ |
| BRepGraph Builder AddFaceToShell | ✅ | ✅ | ✅ |
| BRepGraph Shell Queries | ✅ | ✅ | ✅ |
| Graph history absorb | ✅ | ✅ | ✅ |
| v0.141 history record readback | ✅ | ✅ | ✅ |
| BRepGraph Vertex Geometry | ✅ | ✅ | ✅ |
| BRepGraph Builder AddShellToSolid | ✅ | ✅ | ✅ |
| BRepGraph Edge Sampling | ✅ | ✅ | ✅ |
| BRepGraph Builder Deferred | ✅ | ✅ | ✅ |
| alongEdge helical thread | ✅ | ✅ | ✅ |
| alongEdge T-branch | ✅ | ✅ | ✅ |
| v0.142 ConstructionAxis | ✅ | ✅ | ✅ |
| deferredModeToggle | ✅ | ✅ | ✅ |

**Total**: 18 tests