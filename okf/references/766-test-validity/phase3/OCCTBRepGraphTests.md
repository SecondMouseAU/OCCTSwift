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
| **BRepGraph Stats** | boxStats | Graph statistics | totalNodes + 1 |
| **BRepGraph Supplement Vertices** | faceDirectVertexAttachCountRemove | Supplement attachments | face-direct count + 1 |
| **BRepGraph Supplement Vertices** | edgeInternalVertexAttach | Supplement attachments | attach reports failure |
| **BRepGraph Supplement Vertices** | boxFacesNotNaturalRestriction | Face natural restriction | NbWires test inverted |
| **BRepGraph Transform** | translateGraph | Graph transform | translation drops dz |
| **BRepGraph Transform** | translateLightCopy | Graph transform | light copy returns nil |
| **BRepGraph Validate** | boxIsValid | Graph validation | IsValid negated, errors + 1 |
| **BRepGraph Vertex Geometry** | vertexPoint | Vertex geometry | X and Y swapped |
| **BRepGraph Vertex Geometry** | vertexTolerance | Vertex geometry | tolerance x 10 |
| **BRepGraph Vertex Queries** | vertexEdges | Vertex adjacency | edge count + 1 |
| **BRepGraph UV Grid** | sampleBoxFace | Face UV sampling | normals negated |
| **BRepGraph UV Grid** | sampleSphereFace | Face UV sampling | Gaussian curvature doubled |
| **BRepGraph UV Grid** | sampleSinglePoint | Face UV sampling | position X + 1 |
| **BRepGraph UV Grid** | sampleInvalidFace | Face UV sampling | face 999 clamped to face 0 |
| **BRepGraph UV Grid** | sampleZeroCounts | Face UV sampling | zero count clamped to one |
| **BRepGraph Wire Extended** | wireIsClosed | Wire closure | IsClosed negated |
| **BRepGraph Wire Extended** | wireCoEdgeCount | Wire coedges | coedge count + 1 |
| **BRepGraph Wire Extended** | wireFaces | Wire parents | face index + 1 |

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
| boxStats | OCCTBRepGraphGetStats | Graph statistics | totalNodes = NbNodes() + 1 | ✅ | ✅ | Strengthened: `totalNodes > 0` passed an off-by-one; now pins 58 |
| faceDirectVertexAttachCountRemove | OCCTBRepGraphFaceNbVertexRefs | Supplement attachments | return 1 + count | ✅ | ✅ | `>= 1` tightened to `== 1` |
| edgeInternalVertexAttach | OCCTBRepGraphEdgeAddInternalVertex | Supplement attachments | uid test inverted (returns -1) | ✅ | ✅ |  |
| boxFacesNotNaturalRestriction | OCCTBRepGraphFaceIsNaturalRestriction | Face natural restriction | NbWires != 0 | ✅ | ✅ |  |
| translateGraph | OCCTBRepGraphTransformTranslation | Graph transform | gp_Vec(dx, dy, 0) | ✅ | ✅ |  |
| translateLightCopy | OCCTBRepGraphTransformTranslation | Graph transform | return nullptr when !copyGeom | ✅ | ✅ | Kernel: GeomPolicy::Share leaves vertex 0 at (-5,-5,-5) after a dx=10 translation; not pinned, reported |
| boxIsValid | OCCTBRepGraphValidate | Graph validation | !IsValid(); errorCount + 1 in OCCTBRepGraphValidateDetailed | ✅ | ✅ |  |
| vertexPoint | OCCTBRepGraphVertexPoint | Vertex geometry | outX = Y, outY = X | ✅ | ✅ | Rewritten: isFinite passed swapped coordinates; now pins (-5,-10,-15) |
| vertexTolerance | OCCTBRepGraphVertexTolerance | Vertex geometry | 10 * Tolerance() | ✅ | ✅ | Rewritten: 0 < tol < 1 passed a x10 tolerance; now pins 1e-7 |
| vertexEdges | OCCTBRepGraphVertexEdgeCount | Vertex adjacency | Size() + 1 | ✅ | ✅ |  |
| sampleBoxFace | OCCTBRepGraphSampleFaceUVGrid | Face UV sampling | normal negated; position X + 1 | ✅ | ✅ | Rewritten: unit length passed a flipped normal; now pins normal, curvatures and corners |
| sampleSphereFace | OCCTBRepGraphSampleFaceUVGrid | Face UV sampling | 2 * GaussianCurvature() | ✅ | ✅ | Rewritten: `some K != 0` passed a doubled K; now pins 0.04 / 0 per slot |
| sampleSinglePoint | OCCTBRepGraphSampleFaceUVGrid | Face UV sampling | outPositions X + 1 | ✅ | ✅ | Strengthened: count alone passed a moved sample; now pins its position |
| sampleInvalidFace | OCCTBRepGraphSampleFaceUVGrid | Face UV sampling | faceIndex >= Nb -> 0 | ✅ | ✅ |  |
| sampleZeroCounts | OCCTBRepGraphSampleFaceUVGrid | Face UV sampling | BRepGraph.sampleFaceUVGrid: uSamples = max(uSamples, 1) | ✅ | ✅ |  |
| wireIsClosed | OCCTBRepGraphWireIsClosed | Wire closure | !IsClosed | ✅ | ✅ |  |
| wireCoEdgeCount | OCCTBRepGraphWireNbCoEdges | Wire coedges | NbCoEdges + 1 | ✅ | ✅ |  |
| wireFaces | OCCTBRepGraphWireFaceIndices | Wire parents | outIndices[i] = Index + 1 | ✅ | ✅ | Strengthened: faces.count passed a wrong index; now pins [0] |

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