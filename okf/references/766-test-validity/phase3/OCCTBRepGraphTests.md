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
