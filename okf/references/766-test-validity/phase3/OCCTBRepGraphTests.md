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

## Measured: Edge Def and Edge Geometry (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
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

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
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
