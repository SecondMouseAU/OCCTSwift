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

## Measured: Edge Queries and Edge Sampling (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
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

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
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
