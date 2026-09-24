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
| **BRepGraph Shape Reconstruction** | reconstructFace | Node to shape | ShapeFromNode returns Shell 0 for a Face request |
| **BRepGraph Shape Reconstruction** | reconstructSolid | Node to shape | ShapeFromNode returns Shell 0 for a Solid request |
| **BRepGraph Shape Reconstruction** | findNode | Shape to node | FindNode index + 1 |
| **BRepGraph Shape Reconstruction** | hasNodeFalseForUnrelated | Shape to node | HasNode always true |
| **BRepGraph Shape Reconstruction** | reconstructOccurrenceWithPlacement | Occurrence placement | LinkProducts drops the placement |
| **BRepGraph Shell Extended** | shellCompoundCount | Shell parents | compound count + 1 |
| **BRepGraph Shell Extended** | shellIsClosed | Shell closure | IsClosed negated |
| **BRepGraph Shell Queries** | shellSolids | Shell parents | solid index + 1 |
| **BRepGraph Solid Extended** | solidCompoundCount | Solid parents | compound count + 1 |
| **BRepGraph Solid Queries** | solidCompSolidCount | Solid parents | comp-solid count + 1 |
| **v0.142 ConstructionPlane resolution** | absolutePlane | Absolute plane | normal negated |
| **v0.142 ConstructionPlane resolution** | offsetFromFace | Offset plane | offset distance dropped |
| **v0.142 ConstructionPlane resolution** | byThreePoints | Plane through points | cross product operands swapped |
| **v0.142 ConstructionPlane resolution** | collinearPointsDegenerate | Plane through points | degeneracy check removed |
| **v0.142 ConstructionPlane resolution** | normalToEdge | Plane normal to edge | tangent negated |
| **v0.142 ConstructionPlane resolution** | tangentToFaceCylinderLocalNormal | Plane tangent to face | projection ignored, UV midpoint used |
| **v0.142 ConstructionPlane resolution** | tangentToFaceConeApexFallsBackToNormal | Plane tangent to face | apex fallback point replaced by UV midpoint |
| **v0.142 ConstructionPlane resolution** | tangentToFaceProjectionItselfFailsFallsBackToOnFaceOrigin | Plane tangent to face | raw point returned when projection fails |
| **v0.142 ConstructionPlane resolution** | tangentToFaceOriginIsOnFaceNotRawPoint | Plane tangent to face | raw point returned |
| **perpendicularBasis unification: ConstructionEntity (#881)** | placementInitMatchesGpAx2 | Canonical basis | cross operands swapped |
| **perpendicularBasis unification: ConstructionEntity (#881)** | throughAxisMatchesCanonicalBasis | Canonical basis | right vector negated |
| **perpendicularBasis unification: ConstructionEntity (#881)** | placementInitMatchesGpAx2ForAxisAlignedNormals | Canonical basis | cross operands swapped |
| **v0.142 ConstructionPoint resolution** | atVertex | Point at vertex | point shifted +1 in x |
| **v0.142 ConstructionPoint resolution** | midpointOfEdge | Point on edge | t 0.5 -> 0.25 |
| **v0.142 ConstructionPoint resolution** | parallelIntersectionFails | Axis/plane intersection | degeneracy check removed |
| **v0.142 ConstructionPoint resolution** | intersectionCorrect | Axis/plane intersection | sign of t flipped |
| **v0.142 ConstructionPoint resolution** | centroidOfFaceCylinderSurfaceInertia | Face centroid | centroid shifted +1 in x |
| **v0.142 ConstructionPoint resolution** | centroidOfFaceZeroAreaDegenerate | Face centroid | nil centroid replaced by origin |
| **v0.142 ConstructionPoint resolution** | atEdgeParameterMatchesFraction | Point on edge | t -> 1 - t |
| **v0.142 .containedIn now resolves** | faceInSolid | Contained-in recipe | child index + 1 |
| **v0.142 .containedIn now resolves** | faceInSolidOOB | Contained-in recipe | occurrence clamped |
| **v0.142 .containedIn now resolves** | ancestorMissing | Contained-in recipe | ancestor error remapped |
| **Graph history absorb (#290)** | absorbWritesRecords | History absorb | record count reads 0 |
| **Graph history absorb (#290)** | topFaceResolvesToTwoStrips | History absorb | long derivation list truncated |
| **Graph history absorb (#290)** | splitOfResolvesOccurrences | History absorb | record count reads 0 |
| **Graph history absorb (#290)** | createdByMatchesLabel | History absorb | record count reads 0 |
| **Graph history absorb (#290)** | withoutAbsorbNothingResolves | History absorb | node reported as its own derivative |
| **Graph history absorb (#290)** | untouchedNodeIsNotDeleted | History absorb | IsDeleted always true |
| **Chained WithFullHistory absorb (#336)** | chainedCutsAbsorbAcrossTwoHops | Chained absorb | record count reads 0 |
| **Chained WithFullHistory absorb (#336)** | nonIntersectingSecondCutAbsorbsNothing | Chained absorb | absorb writes a spurious record |
| **BRepGraph history record operation name at any length (#1078)** | opNameLengthReported | Record name length | length query off by one |
| **BRepGraph history record operation name at any length (#1078)** | nullBufferReportsTheLength | Record name length | length query off by one |
| **BRepGraph history record operation name at any length (#1078)** | shortBufferReportsTheFullLength | Record name length | length query off by one |
| **BRepGraph history record operation name at any length (#1078)** | malformedBufferArgumentsAreRefused | Record name length | negative max accepted |
| **v0.141 TopologyRef resolver** | literalValid | Literal recipe | literal index + 1 |
| **v0.141 TopologyRef resolver** | literalInvalid | Literal recipe | validity check removed |
| **v0.141 TopologyRef resolver** | createdByBasic | createdBy recipe | first replacement dropped |
| **v0.141 TopologyRef resolver** | createdByMissingOp | createdBy recipe | error names the wrong operation |
| **v0.141 TopologyRef resolver** | createdByOutOfRange | createdBy recipe | available count inflated |
| **v0.141 TopologyRef resolver** | createdByForwardWalk | createdBy recipe | first replacement dropped |
| **v0.141 TopologyRef resolver** | splitOf | splitOf recipe | replacements reversed |
| **v0.141 TopologyRef resolver** | splitOfOutOfRange | splitOf recipe | available count inflated |
| **v0.141 TopologyRef resolver** | ancestorMissing | splitOf recipe | ancestor error remapped |

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
| reconstructFace | OCCTBRepGraphShapeFromNode | Node to shape | Face/Solid request answered with Shell 0 | ✅ | ✅ | Rewritten: `face != nil` passed the wrong node; now pins type and area 100 |
| reconstructSolid | OCCTBRepGraphShapeFromNode | Node to shape | Face/Solid request answered with Shell 0 | ✅ | ✅ | Rewritten: `solid != nil` passed the wrong node; now pins type and volume 1000 |
| findNode | OCCTBRepGraphFindNode | Shape to node | outIndex = nid.Index + 1 | ✅ | ✅ | Rewritten: `node != nil` passed a wrong index; now pins (solid, 0) |
| hasNodeFalseForUnrelated | OCCTBRepGraphHasNode | Shape to node | return true | ✅ | ✅ |  |
| reconstructOccurrenceWithPlacement | OCCTBRepGraphLinkProducts | Occurrence placement | placement location replaced by identity | ✅ | ✅ | Kernel Shape(occurrence) already carries the (5,6,7) placement |
| shellCompoundCount | OCCTBRepGraphShellCompoundCount | Shell parents | return n + 1 | ✅ | ✅ |  |
| shellIsClosed | OCCTBRepGraphShellIsClosed | Shell closure | !IsClosed | ✅ | ✅ |  |
| shellSolids | OCCTBRepGraphShellSolidIndices | Shell parents | outIndices[i] = Index + 1 | ✅ | ✅ |  |
| solidCompoundCount | OCCTBRepGraphSolidCompoundCount | Solid parents | return n + 1 | ✅ | ✅ |  |
| solidCompSolidCount | OCCTBRepGraphSolidCompSolidCount | Solid parents | return n + 1 | ✅ | ✅ |  |
| absolutePlane | none (pure Swift: ConstructionPlane.absolute) | Absolute plane | Placement(origin:, normal: -normal) | ✅ | ✅ |  |
| offsetFromFace | OCCTFaceGetNormalAtUV | Offset plane | origin + 0 * distance * normal | ✅ | ✅ | Rewritten: unit length passed a plane never offset; now pins origin and normal |
| byThreePoints | OCCTShapeVertexPoint | Plane through points | simd_cross(pC - pA, pB - pA) | ✅ | ✅ | Rewritten: unit length passed a reversed normal |
| collinearPointsDegenerate | OCCTShapeVertexPoint | Plane through points | byThreePoints passes magnitude 1.0 | ✅ | ✅ |  |
| normalToEdge | OCCTEdgeGetTangent3D | Plane normal to edge | Placement(origin: point, normal: -tangent) | ✅ | ✅ | Rewritten: unit length passed a reversed tangent |
| tangentToFaceCylinderLocalNormal | OCCTFaceGetNormalAtUV | Plane tangent to face | projectedNormal returns face.uvMidpointSample() | ✅ | ✅ |  |
| tangentToFaceConeApexFallsBackToNormal | OCCTFaceGetNormalAtUV | Plane tangent to face | normal-nil branch returns (uvMidpointPoint, fallback) | ✅ | ✅ |  |
| tangentToFaceProjectionItselfFailsFallsBackToOnFaceOrigin | OCCTFaceProjectPoint | Plane tangent to face | projection-failed branch returns (point, fallbackNormal) | ✅ | ✅ |  |
| tangentToFaceOriginIsOnFaceNotRawPoint | OCCTFaceProjectPoint | Plane tangent to face | projectedNormal returns (point, normal) | ✅ | ✅ |  |
| placementInitMatchesGpAx2 | none (pure Swift: perpendicularBasis(to:)) | Canonical basis | up = cross(right, v) (R1); right negated (R2) | ✅ | ✅ | Kernel gp_Ax2 agrees to 1e-15 |
| throughAxisMatchesCanonicalBasis | OCCTEdgeGetPointAtParam | Canonical basis | right = -normalize(raw) | ✅ | ✅ |  |
| placementInitMatchesGpAx2ForAxisAlignedNormals | none (pure Swift: perpendicularBasis(to:)) | Canonical basis | up = cross(right, v) | ✅ | ✅ | All six cases red under injection; fixtures match gp_Ax2 |
| atVertex | OCCTShapeVertexPoint | Point at vertex | .atVertex maps $0 + (1,0,0) | ✅ | ✅ | Rewritten: |coords| < 20 passed a shifted point |
| midpointOfEdge | OCCTEdgeGetPointAtParam | Point on edge | midpointOfEdge evaluates t = 0.25 | ✅ | ✅ | Rewritten: |coords| < 20 passed a point a quarter of the way along |
| parallelIntersectionFails | none (pure Swift: intersectionOfAxisAndPlane) | Axis/plane intersection | requireNonDegenerate magnitude 1.0 | ✅ | ✅ |  |
| intersectionCorrect | none (pure Swift: intersectionOfAxisAndPlane) | Axis/plane intersection | axOrigin - t * axDir | ✅ | ✅ |  |
| centroidOfFaceCylinderSurfaceInertia | OCCTBRepGPropSinert | Face centroid | success(centroid + (1,0,0)) | ✅ | ✅ |  |
| centroidOfFaceZeroAreaDegenerate | OCCTBRepGPropSinert | Face centroid | centerOfMass ?? (0,0,0) | ✅ | ✅ |  |
| atEdgeParameterMatchesFraction | OCCTEdgeGetPointAtParam | Point on edge | atEdgeParameter evaluates 1 - t | ✅ | ✅ |  |
| faceInSolid | OCCTBRepGraphChildIndices | Contained-in recipe | NodeRef(kind:, index: $0 + 1) | ✅ | ✅ | Strengthened: kind alone passed a wrong index; now pins face 0 |
| faceInSolidOOB | OCCTBRepGraphChildIndices | Contained-in recipe | element(at: min(occurrence, count - 1)) | ✅ | ✅ |  |
| ancestorMissing | OCCTBRepGraphHistoryNbRecords | Contained-in recipe | resolveAncestor maps to .invalid | ✅ | ✅ |  |
| absorbWritesRecords | OCCTBRepGraphHistoryNbRecords | History absorb | return 0 | ✅ | ✅ | `> 0` tightened to the kernel's 11 |
| topFaceResolvesToTwoStrips | OCCTBRepGraphHistoryFindDerived | History absorb | total > 2 -> 1 | ✅ | ✅ |  |
| splitOfResolvesOccurrences | OCCTBRepGraphHistoryNbRecords | History absorb | return 0 | ✅ | ✅ |  |
| createdByMatchesLabel | OCCTBRepGraphHistoryGetRecordInfo | History absorb | NbRecords returns 0 | ✅ | ✅ |  |
| withoutAbsorbNothingResolves | OCCTBRepGraphHistoryFindDerived | History absorb | empty FindDerived returns the node itself | ✅ | ✅ |  |
| untouchedNodeIsNotDeleted | OCCTBRepGraphHistoryIsDeleted | History absorb | return true | ✅ | ✅ |  |
| chainedCutsAbsorbAcrossTwoHops | OCCTBRepGraphAddWithHistory | Chained absorb | NbRecords returns 0 | ✅ | ✅ |  |
| nonIntersectingSecondCutAbsorbsNothing | OCCTBRepGraphAddWithHistory | Chained absorb | extra Record() after every AddWithHistory | ✅ | ✅ |  |
| opNameLengthReported | OCCTBRepGraphHistoryGetRecordInfo | Record name length | length-only query returns srcLen + 1 | ✅ | ✅ |  |
| nullBufferReportsTheLength | OCCTBRepGraphHistoryGetRecordInfo | Record name length | length-only query returns srcLen + 1 | ✅ | ✅ | out-of-range -1 is bridge argument validation, no kernel counterpart |
| shortBufferReportsTheFullLength | OCCTBRepGraphHistoryGetRecordInfo | Record name length | length-only query returns srcLen + 1 | ✅ | ✅ |  |
| malformedBufferArgumentsAreRefused | OCCTBRepGraphHistoryGetRecordInfo | Record name length | early `outOpNameMax < 0` refusal removed; negative max treated as a length query | ✅ | ✅ |  |
| literalValid | none (pure Swift: TopologyRef.literal) | Literal recipe | success(NodeRef(kind:, index: + 1)), validity check removed | ✅ | ✅ |  |
| literalInvalid | none (pure Swift: TopologyRef.literal) | Literal recipe | same | ✅ | ✅ |  |
| createdByBasic | OCCTBRepGraphHistoryGetRecordMapping | createdBy recipe | repls.dropFirst() when collecting candidates | ✅ | ✅ |  |
| createdByMissingOp | OCCTBRepGraphHistoryGetRecordInfo | createdBy recipe | operationNotFound(opName + "?") | ✅ | ✅ |  |
| createdByOutOfRange | OCCTBRepGraphHistoryGetRecordMapping | createdBy recipe | available: count + 2 (and dropFirst) | ✅ | ✅ |  |
| createdByForwardWalk | OCCTBRepGraphHistoryFindDerived | createdBy recipe | repls.dropFirst() | ✅ | ✅ |  |
| splitOf | OCCTBRepGraphHistoryGetRecordMapping | splitOf recipe | element(at:, in: repls.reversed()) | ✅ | ✅ |  |
| splitOfOutOfRange | OCCTBRepGraphHistoryGetRecordMapping | splitOf recipe | available: count + 2 | ✅ | ✅ |  |
| ancestorMissing | OCCTBRepGraphHistoryGetRecordInfo | splitOf recipe | resolveAncestor maps to .invalid | ✅ | ✅ |  |

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
---

## Measured: Build, ValidateMutation and CoEdge Queries (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **BRepGraph Builder ValidateMutation** | validateCleanGraph | Mutation validation | return false |
| **BRepGraph Builder ValidateMutation** | validateAfterAddVertex | Mutation validation | return false |
| **BRepGraph Build** | buildFromBox | Graph build counts | NbEdges + 1, NbNodes + 1 |
| **BRepGraph Build** | buildParallel | Parallel build | return nullptr when parallel |
| **BRepGraph Build** | buildFromSphere | Graph build counts | NbEdges + 1 |
| **BRepGraph Build** | buildFromComplex | Graph validation | Validate returns false; NbEdges + 1 |
| **BRepGraph CoEdge Queries** | coedgeEdge | CoEdge query | edge index + 1 |
| **BRepGraph CoEdge Queries** | coedgeFace | CoEdge query | face index + 1 |
| **BRepGraph CoEdge Queries** | coedgeSeamPairNilForBox | Seam pair | no pair returns the coedge itself |
| **BRepGraph CoEdge Queries** | coedgeSeamPairForSphere | Seam pair | no pair returns the coedge itself |
| **BRepGraph CoEdge Queries** | coedgeHasPCurve | PCurve presence | false for odd coedges |
| **BRepGraph CoEdge Queries** | coedgeRange | CoEdge range | first/last swapped |

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| validateCleanGraph | OCCTBRepGraphBuilderValidateMutation | Mutation validation | return false | ✅ :14 `valid` | ✅ | Original also red; #require only |
| validateAfterAddVertex | OCCTBRepGraphBuilderValidateMutation | Mutation validation | return false | ✅ :24 `valid` | ✅ | Original also red; added vertex index pinned |
| buildFromBox | OCCTBRepGraphNbNodes | Graph build counts | NbEdges + 1, NbNodes + 1 | ✅ :18 `edgeCount == 12`, :25 `nodeCount == 58` | ✅ | `nodeCount > 0` pinned to 58, coedge count added |
| buildParallel | OCCTBRepGraphCreate | Parallel build | return nullptr when parallel | ✅ :30 `#require(BRepGraph(parallel: true))` | ✅ | Original also red (`graph != nil`) |
| buildFromSphere | OCCTBRepGraphNbEdges | Graph build counts | NbEdges + 1 | ✅ :41 `edgeCount == 3`, :43 | ✅ | Rewritten: `faceCount > 0`, `edgeCount >= 0` (always true) stayed green |
| buildFromComplex | OCCTBRepGraphValidate | Graph validation | Validate returns false; NbEdges + 1 | ✅ :53 `edgeCount == 15`, :55 `isValid` | ✅ | `faceCount > 6` pinned to 8 |
| coedgeEdge | OCCTBRepGraphCoEdgeEdge | CoEdge query | edge index + 1 | ✅ :16 `coedgeEdge(0) == 0` | ✅ | Rewritten: `>= 0 && < edgeCount` stayed green |
| coedgeFace | OCCTBRepGraphCoEdgeFace | CoEdge query | face index + 1 | ✅ :22 `coedgeFace(0) == 0` | ✅ | Rewritten: `>= 0 && < faceCount` stayed green |
| coedgeSeamPairNilForBox | OCCTBRepGraphCoEdgeSeamPair | Seam pair | no pair returns the coedge itself | ✅ :31 | ✅ | Original also red; now checks all 24 coedges |
| coedgeSeamPairForSphere | OCCTBRepGraphCoEdgeSeamPair | Seam pair | no pair returns the coedge itself | ✅ :41 `seamPair(0) == nil`, :43 | ✅ | Rewritten: asserted nothing (`let _ = foundSeam`) |
| coedgeHasPCurve | OCCTBRepGraphCoEdgeHasPCurve | PCurve presence | false for odd coedges | ✅ :53 (12 coedges) | ✅ | Rewritten: "any coedge has one" stayed green |
| coedgeRange | OCCTBRepGraphCoEdgeRange | CoEdge range | first/last swapped | ✅ :62, :63 | ✅ | Original also red (`first < last`); pinned |
## Measured: Compact, Compound, CompSolid, Copy, Counts and Deduplicate (#1986)
| **BRepGraph Compact** | compactBox | Compaction result | nodesAfter + 1 |
| **BRepGraph Compound Queries** | compoundQueriesOnCompound | Compound relations | child count + 1, parent count + 1 |
| **BRepGraph CompSolid Count** | compSolidCount | CompSolid count | always 0 |
| **BRepGraph Copy** | deepCopy | Graph copy | BRepGraph_Copy::Perform skipped |
| **BRepGraph Copy** | lightCopy | Graph copy | BRepGraph_Copy::Perform skipped |
| **BRepGraph Copy** | copyFace | Face copy | CopyNode of Kind::Wire |
| **BRepGraph Counts** | activeCounts | Active count | NbActive faces + 1 |
| **BRepGraph Counts** | geometryCounts | Geometry count | NbCoEdgeCurves2D + 1 |
| **BRepGraph Counts** | coedgeCounts | CoEdge count | Nb - 1 |
| **BRepGraph Deduplicate** | deduplicateBox | Deduplication result | surface/curve counts swapped |
| compactBox | OCCTBRepGraphCompact | Compaction result | nodesAfter + 1 | ✅ :19, :25 | ✅ | Rewritten: `nodesAfter > 0` stayed green |
| compoundQueriesOnCompound | OCCTBRepGraphCompoundChildCount | Compound relations | child count + 1, parent count + 1 | ✅ :18 `compoundChildCount(0) == 2`, :20 | ✅ | `>= 1` / `>= 2` pinned (child +1 was not caught) |
| compSolidCount | OCCTBRepGraphNbCompSolids | CompSolid count | always 0 | ✅ :16 `compSolidCount == 1` | ✅ | Rewritten: `== 0` alone passed a counter stuck at 0 |
| deepCopy | OCCTBRepGraphCopy | Graph copy | BRepGraph_Copy::Perform skipped | ✅ :15 to :18 | ✅ | Original also red |
| lightCopy | OCCTBRepGraphCopy | Graph copy | BRepGraph_Copy::Perform skipped | ✅ :25 to :27 | ✅ | Original also red |
| copyFace | OCCTBRepGraphCopyFace | Face copy | CopyNode of Kind::Wire | ✅ :35 `faceCount == 1` | ✅ | Original also red |
| activeCounts | OCCTBRepGraphNbActiveFaces | Active count | NbActive faces + 1 | ✅ :12 | ✅ | Original also red |
| geometryCounts | OCCTBRepGraphNbCurves2D | Geometry count | NbCoEdgeCurves2D + 1 | ✅ :24 `curve2DCount == 24` | ✅ | Rewritten: `curve2DCount > 0` stayed green |
| coedgeCounts | OCCTBRepGraphNbCoEdges | CoEdge count | Nb - 1 | ✅ :30 | ✅ | Original also red |
| deduplicateBox | OCCTBRepGraphDeduplicate | Deduplication result | surface/curve counts swapped | ✅ :15, :16 | ✅ | Original also red; rewrite counts added |
## Measured: Durable UID (#1986)
| **BRepGraph Durable UID** | nodeUIDRoundTrip | UID resolution | resolved index + 1; UID mint fails |
| **BRepGraph Durable UID** | uidFromAnotherGraphDoesNotResolve | UID provenance | Swift provenance guards dropped; UID mint fails |
| **BRepGraph Durable UID** | uidDoesNotCrossIdenticallyBuiltGraphs | UID provenance | Swift provenance guards dropped; UID mint fails |
| **BRepGraph Durable UID** | uidSurvivesAFullCopyAndNamesTheSameFace | UID across copy | copy mints fresh instanceID; UID mint fails |
| **BRepGraph Durable UID** | uidSurvivesATranslationAndNamesTheSameFace | UID across transform | translation mints fresh instanceID; UID mint fails |
| **BRepGraph Durable UID** | uidDoesNotCrossACopiedOutFace | UID provenance | Swift provenance guards dropped; UID mint fails |
| **BRepGraph Durable UID** | outOfRangeCounterDoesNotResolve | UID range | HasNodeUID always true |
| **BRepGraph Durable UID** | unstampedUIDResolvesNowhere | UID provenance | Swift provenance guards dropped; UID mint fails |
| **BRepGraph Durable UID** | uidSurvivesCompactionOfItsOwnGraph | UID across compaction | compaction re-mints instanceID; UID mint fails |
| **BRepGraph Durable UID** | uidCodableCarriesProvenance | UID provenance | Swift provenance guards dropped; UID mint fails |
| **BRepGraph Durable UID** | refAndItemUIDsDoNotCrossGraphs | UID provenance | Swift provenance guards dropped; UID mint fails |
| **BRepGraph Durable UID** | itemUIDOfNode | Item UID | resolved index + 1; UID mint fails |
| nodeUIDRoundTrip | OCCTBRepGraphNodeFromUID | UID resolution | resolved index + 1; UID mint fails | ✅ :25 Issue.record / index mismatch | ✅ | Original also red under both |
| uidFromAnotherGraphDoesNotResolve | OCCTBRepGraphNodeFromUID | UID provenance | Swift provenance guards dropped; UID mint fails | ✅ cross-graph resolve / :48 #require | ✅ | Guards now #require |
| uidDoesNotCrossIdenticallyBuiltGraphs | OCCTBRepGraphNodeFromUID | UID provenance | Swift provenance guards dropped; UID mint fails | ✅ twin resolve / :66 #require | ✅ | Rewritten: `guard let uid ... else { return }` passed with the mint failing |
| uidSurvivesAFullCopyAndNamesTheSameFace | OCCTBRepGraphCopy | UID across copy | copy mints fresh instanceID; UID mint fails | ✅ instanceID / :106 #require | ✅ | Rewritten: `guard let uid ... else { continue }` skipped every face with the mint failing |
| uidSurvivesATranslationAndNamesTheSameFace | OCCTBRepGraphTransformTranslation | UID across transform | translation mints fresh instanceID; UID mint fails | ✅ instanceID / :125 #require | ✅ | Rewritten: `continue` on a missing UID skipped every face |
| uidDoesNotCrossACopiedOutFace | OCCTBRepGraphCopyFace | UID provenance | Swift provenance guards dropped; UID mint fails | ✅ lifted resolve / :148 #require | ✅ | Guards now #require |
| outOfRangeCounterDoesNotResolve | OCCTBRepGraphHasNodeUID | UID range | HasNodeUID always true | ✅ `!graph.contains(uid: bogus)` | ✅ | Original also red |
| unstampedUIDResolvesNowhere | OCCTBRepGraphNodeFromUID | UID provenance | Swift provenance guards dropped; UID mint fails | ✅ unstamped resolve / :175 #require | ✅ | Rewritten: `guard let real ... else { return }` passed with the mint failing |
| uidSurvivesCompactionOfItsOwnGraph | OCCTBRepGraphCompact | UID across compaction | compaction re-mints instanceID; UID mint fails | ✅ instanceID / :189 #require | ✅ | Rewritten: guard-return passed with the mint failing; resolved index pinned |
| uidCodableCarriesProvenance | OCCTBRepGraphNodeFromUID | UID provenance | Swift provenance guards dropped; UID mint fails | ✅ legacy resolve / :202 #require | ✅ | Rewritten: guard-return passed with the mint failing |
| refAndItemUIDsDoNotCrossGraphs | OCCTBRepGraphRefFromUID | UID provenance | Swift provenance guards dropped; UID mint fails | ✅ cross-graph resolve / :226 #require | ✅ | Rewritten: both halves were `if let` and asserted nothing with the mint failing |
| itemUIDOfNode | OCCTBRepGraphItemFromUID | Item UID | resolved index + 1; UID mint fails | ✅ `resolved.index == 0` / :244 #require | ✅ | Rewritten: `if let item` passed with the mint failing |
## Measured: Edge Def and Edge Geometry (#1986)
| **BRepGraph Edge Def Details** | edgeStartEndVertex | Edge vertices | start reads EndVertexId |
| **BRepGraph Edge Def Details** | edgeIsClosedOnBox | Edge closure | IsClosed always true (separate run) |
| **BRepGraph Edge Def Details** | edgeClosedConsistency | Edge closure | IsClosed always false |
| **BRepGraph Edge Geometry** | edgeTolerance | Edge tolerance | tolerance x 10 |
| **BRepGraph Edge Geometry** | edgeNotDegenerated | Degenerate edge | always false |
| **BRepGraph Edge Geometry** | edgeSameParameter | SameParameter | negated |
| **BRepGraph Edge Geometry** | edgeSameRange | SameRange | negated |
| **BRepGraph Edge Geometry** | edgeRange | Edge range | first/last swapped |
| **BRepGraph Edge Geometry** | edgeHasCurve | Edge curve presence | always true |
| **BRepGraph Edge Geometry** | edgeMaxContinuity | Stubbed query | constant 0 -> 1 |
| **BRepGraph Edge Geometry** | edgeNotClosedOnFace | Seam on face | IsSeamOnFace always false |
| edgeStartEndVertex | OCCTBRepGraphEdgeStartVertex | Edge vertices | start reads EndVertexId | ✅ start list mismatch | ✅ | Rewritten: range check passed start == end |
| edgeIsClosedOnBox | OCCTBRepGraphEdgeIsClosed | Edge closure | IsClosed always true (separate run) | ✅ :29 `!graph.isEdgeClosed(i)` | ✅ | Box half of the closure pair: catches always-true; edgeClosedConsistency catches always-false |
| edgeClosedConsistency | OCCTBRepGraphEdgeIsClosed | Edge closure | IsClosed always false | ✅ closed list mismatch | ✅ | Rewritten: `if isEdgeClosed` loop asserted nothing when no edge reported closed |
| edgeTolerance | OCCTBRepGraphEdgeTolerance | Edge tolerance | tolerance x 10 | ✅ `edgeTolerance(0) == 1e-7` | ✅ | Rewritten: `tol > 0` stayed green |
| edgeNotDegenerated | OCCTBRepGraphEdgeIsDegenerated | Degenerate edge | always false | ✅ sphere list mismatch | ✅ | Strengthened: box-only loop passed a constant false; sphere poles added |
| edgeSameParameter | OCCTBRepGraphEdgeIsSameParameter | SameParameter | negated | ✅ :38 | ✅ | Original also red |
| edgeSameRange | OCCTBRepGraphEdgeIsSameRange | SameRange | negated | ✅ :50 | ✅ | Original also red |
| edgeRange | OCCTBRepGraphEdgeRange | Edge range | first/last swapped | ✅ `range.first == 0` | ✅ | Original also red; pinned |
| edgeHasCurve | OCCTBRepGraphEdgeHasCurve | Edge curve presence | always true | ✅ sphere list mismatch | ✅ | Strengthened: box-only loop passed a constant true |
| edgeMaxContinuity | OCCTBRepGraphEdgeMaxContinuity | Stubbed query | constant 0 -> 1 | ✅ `edgeMaxContinuity(0) == 0` | ✅ | Pins the documented stub; `cont >= 0` held for every Int32. Finding: the API reports an uncomputed value |
| edgeNotClosedOnFace | OCCTBRepGraphEdgeIsClosedOnFace | Seam on face | IsSeamOnFace always false | ✅ `sg.isEdgeClosedOnFace(edgeIndex: 1, faceIndex: 0)` | ✅ | Strengthened: box-only check passed a constant false |
## Measured: Edge Queries and Edge Sampling (#1986)
| **BRepGraph Edge Queries** | edgeFaceCount | Edge face count | NbFaces + 1 |
| **BRepGraph Edge Queries** | edgeFaces | Edge faces | face index + 1 |
| **BRepGraph Edge Queries** | noBoundaryEdges | Boundary edge | always false |
| **BRepGraph Edge Queries** | allManifoldEdges | Manifold edge | always true |
| **BRepGraph Edge Queries** | edgeAdjacency | Edge adjacency | edge not excluded from its own adjacency |
| **BRepGraph Edge Sampling** | sampleBoxEdge | Edge sampling | step = range / count |
| **BRepGraph Edge Sampling** | sampleSinglePoint | Edge sampling | single sample taken at mid-range (separate run) |
| **BRepGraph Edge Sampling** | sampleEdgeWithoutCurve | Sampling guard | Swift ignores bridge result count |
| **BRepGraph Edge Sampling** | sampleZeroCount | Sampling guard | zero count returns one point |
| **BRepGraph Edge Sampling** | sampleSphereEdge | Edge sampling | step = range / count; result count ignored |
| edgeFaceCount | OCCTBRepGraphEdgeNbFaces | Edge face count | NbFaces + 1 | ✅ `faceCount(of: 0) == 2` | ✅ | Original also red; #require only |
| edgeFaces | OCCTBRepGraphEdgeFaceIndices | Edge faces | face index + 1 | ✅ `faces(of: 0) == [0, 2]` | ✅ | Strengthened: `count == 2` passed wrong indices (original red only through the NbFaces count) |
| noBoundaryEdges | OCCTBRepGraphEdgeIsBoundary | Boundary edge | always false | ✅ `face.isBoundaryEdge(i)` x4 | ✅ | Strengthened: closed box alone passed a constant false; lifted face added |
| allManifoldEdges | OCCTBRepGraphEdgeIsManifold | Manifold edge | always true | ✅ `!face.isManifoldEdge(i)` x4 | ✅ | Strengthened: closed box alone passed a constant true |
| edgeAdjacency | OCCTBRepGraphEdgeAdjacentIndices | Edge adjacency | edge not excluded from its own adjacency | ✅ `adjacentEdges(of: 0) == [1, 3, 8, 9]` | ✅ | Rewritten: `count > 0` stayed green |
| sampleBoxEdge | OCCTBRepGraphSampleEdgeCurve | Edge sampling | step = range / count | ✅ `points[9] == (-5, -5, 5)`, spacing | ✅ | Rewritten: `dist(first, last) > 0.001` passed a sampler stopping short |
| sampleSinglePoint | OCCTBRepGraphSampleEdgeCurve | Edge sampling | single sample taken at mid-range (separate run) | ✅ :30 `points == [(-5, -5, -5)]` | ✅ | Strengthened: count alone checked; point pinned |
| sampleEdgeWithoutCurve | OCCTBRepGraphSampleEdgeCurve | Sampling guard | Swift ignores bridge result count | ✅ `points.isEmpty` | ✅ | Original also red |
| sampleZeroCount | OCCTBRepGraphSampleEdgeCurve | Sampling guard | zero count returns one point | ✅ `points.isEmpty` | ✅ | Original also red |
| sampleSphereEdge | OCCTBRepGraphSampleEdgeCurve | Edge sampling | step = range / count; result count ignored | ✅ pole edges not empty, `points[19].z == 5` | ✅ | Strengthened: radius check alone passed a sampler stopping short |
## Measured: Edge Wires/CoEdges, Explorers, Face Def and Face Geometry (#1986)
| **BRepGraph Edge Wires CoEdges** | edgeWires | Edge wires | every index reported as wire 0 |
| **BRepGraph Edge Wires CoEdges** | edgeCoEdges | Edge coedges | first coedge repeated |
| **BRepGraph Edge Wires CoEdges** | edgeFindCoEdge | CoEdge lookup | found index + 1 |
| **BRepGraph Explorers** | childExplorer | Child explorer | count starts at 1 |
| **BRepGraph Explorers** | parentExplorer | Parent explorer | count starts at 1 |
| **BRepGraph Face Def Details** | faceWireCount | Face wire count | NbWires + 1 |
| **BRepGraph Face Def Details** | faceVertexRefCount | Face vertex refs | always 0 |
| **BRepGraph Face Geometry** | faceTolerance | Face tolerance | tolerance x 10 |
| **BRepGraph Face Geometry** | faceHasSurface | Face surface | always false |
| **BRepGraph Face Geometry** | faceNaturalRestriction | Natural restriction | always true |
| **BRepGraph Face Geometry** | faceHasTriangulation | Triangulation presence | always false |
| edgeWires | OCCTBRepGraphEdgeWireIndices | Edge wires | every index reported as wire 0 | ✅ wire list mismatch | ✅ | Rewritten: `!isEmpty` + range check stayed green |
| edgeCoEdges | OCCTBRepGraphEdgeCoEdgeIndices | Edge coedges | first coedge repeated | ✅ coedge list mismatch | ✅ | Rewritten: `!isEmpty` + range check stayed green |
| edgeFindCoEdge | OCCTBRepGraphEdgeFindCoEdge | CoEdge lookup | found index + 1 | ✅ `edgeFindCoEdge(...) == coedges[i][0]` | ✅ | Rewritten: `!= nil` + range check passed an off-by-one |
| childExplorer | OCCTBRepGraphChildCount | Child explorer | count starts at 1 | ✅ `childCount(...) == 6` | ✅ | Original also red; root count pinned |
| parentExplorer | OCCTBRepGraphParentCount | Parent explorer | count starts at 1 | ✅ `parentCount(...) == 2` | ✅ | Rewritten: `parents > 0` stayed green |
| faceWireCount | OCCTBRepGraphFaceNbWires | Face wire count | NbWires + 1 | ✅ `faceWireCount(i) == 1` | ✅ | Rewritten: `>= 1` stayed green |
| faceVertexRefCount | OCCTBRepGraphFaceNbVertexRefs | Face vertex refs | always 0 | ✅ `faceVertexRefCount(0) == 1` | ✅ | Rewritten: `== 0` alone passed a counter stuck at 0 |
| faceTolerance | OCCTBRepGraphFaceTolerance | Face tolerance | tolerance x 10 | ✅ `faceTolerance(0) == 1e-7` | ✅ | Rewritten: `tol > 0` stayed green |
| faceHasSurface | OCCTBRepGraphFaceHasSurface | Face surface | always false | ✅ `faceHasSurface(i)` | ✅ | Original also red |
| faceNaturalRestriction | OCCTBRepGraphFaceIsNaturalRestriction | Natural restriction | always true | ✅ `!isFaceNaturalRestriction(0)` | ✅ | Rewritten: asserted nothing ("returns a bool without crashing") |
| faceHasTriangulation | OCCTBRepGraphFaceHasTriangulation | Triangulation presence | always false | ✅ `mg.faceHasTriangulation(0)` | ✅ | Rewritten: asserted nothing ("may or may not have triangulation") |
## Measured: Node Status, Occurrences, Poly Counts, Products, Refs, Root Nodes and SameDomain (#1986)
| **BRepGraph Node Status** | noRemovedNodes | Removal status | IsRemoved always false |
| **BRepGraph Occurrences** | occurrenceCountForPrimitive | Occurrence count | always 0 |
| **BRepGraph Poly Counts** | polyCounts | Poly count | triangulations always 0; polygons3D + 1 |
| **BRepGraph Products** | productCountForPrimitive | Product queries | NbProducts always 0 |
| **BRepGraph Products** | productQueriesOnSphere | Product queries | NbProducts always 0; NbComponents - 1 |
| **BRepGraph Products** | rootProductIndices | Root products | root product index + 1 (separate run) |
| **BRepGraph Ref Counts** | refCountsForBox | Ref counts | face/wire refs + 1, vertex refs - 8 |
| **BRepGraph Ref Counts** | refCountsConsistency | Ref counts | face/wire refs + 1 |
| **BRepGraph Ref Entry Queries** | refChildNode | Ref child | child index + 1 |
| **BRepGraph Ref Entry Queries** | refNotRemoved | Ref removal status | RefIsRemoved always false |
| **BRepGraph Ref Entry Queries** | refOrientation | Ref orientation | always FORWARD |
| **BRepGraph Root Nodes** | hasRoots | Root nodes | root count + 1 |
| **BRepGraph SameDomain** | boxNoSameDomain | Same-domain derivation | never same-domain |
| noRemovedNodes | OCCTBRepGraphIsRemoved | Removal status | IsRemoved always false | ✅ `isRemoved(.face, 5)` after removeNode | ✅ | Rewritten: a fresh box passes a constant false |
| occurrenceCountForPrimitive | OCCTBRepGraphNbOccurrences | Occurrence count | always 0 | ✅ `occurrenceCount == 1` | ✅ | Rewritten: `== 0` passed a counter stuck at 0 |
| polyCounts | OCCTBRepGraphNbTriangulations | Poly count | triangulations always 0; polygons3D + 1 | ✅ `polygon3DCount == 0`, `mg.triangulationCount == 6` | ✅ | Rewritten: both expectations were `>= 0` |
| productCountForPrimitive | OCCTBRepGraphNbProducts | Product queries | NbProducts always 0 | ✅ `productCount == 1` | ✅ | Rewritten: `productCount >= 0`, and the `if productCount > 0` block never ran |
| productQueriesOnSphere | OCCTBRepGraphProductNbComponents | Product queries | NbProducts always 0; NbComponents - 1 | ✅ `productCount == 1`, `productComponentCount(0) == 1` | ✅ | Rewritten: block never ran; its `componentCount == 0` for a part was wrong, the kernel reports 1 |
| rootProductIndices | OCCTBRepGraphRootProductIndices | Root products | root product index + 1 (separate run) | ✅ :54 `indices == [0]` | ✅ | Rewritten: no products, so the loop never ran |
| refCountsForBox | OCCTBRepGraphNbVertexRefs | Ref counts | face/wire refs + 1, vertex refs - 8 | ✅ face, wire and vertex count lines | ✅ | Rewritten: lower bounds; the vertex bound sat 8 below the real 24 |
| refCountsConsistency | OCCTBRepGraphNbFaceRefs | Ref counts | face/wire refs + 1 | ✅ `faceRefCount == faceCount` | ✅ | Rewritten: `>=` passed an overcount |
| refChildNode | OCCTBRepGraphRefChildNodeIndex | Ref child | child index + 1 | ✅ `refChildNodeIndex(.face, refIndex: 0) == 0` | ✅ | Rewritten: `idx >= 0` stayed green |
| refNotRemoved | OCCTBRepGraphRefIsRemoved | Ref removal status | RefIsRemoved always false | ✅ `isRefRemoved(.face, 0)` after removeRef | ✅ | Rewritten: a fresh box passes a constant false |
| refOrientation | OCCTBRepGraphRefOrientation | Ref orientation | always FORWARD | ✅ orientation list | ✅ | Rewritten: `0...3` accepted any orientation |
| hasRoots | OCCTBRepGraphRootNodes | Root nodes | root count + 1 | ✅ `roots.count == 1` | ✅ | Rewritten: `count > 0` passed a duplicate root |
| boxNoSameDomain | OCCTBRepGraphFaceSameDomainIndices | Same-domain derivation | never same-domain | ✅ `fg.sameDomainFaces(of: 1) == [5]` | ✅ | Rewritten: a box alone passes an always-empty answer; fused coplanar boxes added. Kernel side is the probe re-deriving the bridge rule from Tool::Face::Surface |
