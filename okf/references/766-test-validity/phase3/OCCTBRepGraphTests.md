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

## Measured: Builder mutations (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **BRepGraph Builder AppendShape** | appendFlattenedShape | Append shape | Shapes().Add dropped |
| **BRepGraph Builder AppendShape** | appendFullShape | Append shape | Shapes().Add dropped |
| **BRepGraph Builder ClearMesh** | clearFaceMesh | Mesh cache clear | Faces().Clear dropped |
| **BRepGraph Builder ClearMesh** | clearEdgePolygon3D | Mesh cache clear | Edges().Clear dropped |
| **BRepGraph Builder CommitMutation** | commitAfterAdd | Mutation commit | CommitMutation -> BeginDeferredInvalidation |
| **BRepGraph Builder Deferred** | deferredModeToggle | Deferred mode | BeginDeferredInvalidation dropped |
| **BRepGraph Builder Deferred** | deferredModeWithMutations | Deferred mode | Begin dropped + Commit -> Begin |
| **BRepGraph Builder RemoveNode** | removeVertex | Node removal | RemoveNode dropped |
| **BRepGraph Builder RemoveNode** | removeSubgraph | Node removal | RemoveSubgraph dropped |
| **BRepGraph Builder RemoveRef** | removeShellRef | Ref removal | RemoveRef dropped, returns false |

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| appendFlattenedShape | OCCTBRepGraphBuilderAppendFlattenedShape | Append shape | Shapes().Add dropped | ✅ :19 `faceCount == origFaces + 1` | ✅ | Original also red (`>`); count pinned |
| appendFullShape | OCCTBRepGraphBuilderAppendFullShape | Append shape | Shapes().Add dropped | ✅ :29 `faceCount == origFaces + 3` | ✅ | Original also red (`>`); count pinned |
| clearFaceMesh | OCCTBRepGraphBuilderClearFaceMesh | Mesh cache clear | Faces().Clear dropped | ✅ :30 `!cachedFaceMeshIsPresent(0)` | ✅ | Rewritten: asserted nothing ("should not crash"); cache now seeded then cleared |
| clearEdgePolygon3D | OCCTBRepGraphBuilderClearEdgePolygon3D | Mesh cache clear | Edges().Clear dropped | ✅ :49, :50 | ✅ | Rewritten: asserted nothing; cache now seeded then cleared |
| commitAfterAdd | OCCTBRepGraphBuilderCommitMutation | Mutation commit | CommitMutation -> BeginDeferredInvalidation | ✅ :20 `!isDeferredMode` | ✅ | Rewritten: `vertexCount > 0` held for the box alone |
| deferredModeToggle | OCCTBRepGraphBuilderBeginDeferred | Deferred mode | BeginDeferredInvalidation dropped | ✅ :14 `isDeferredMode` | ✅ | Original also red; #require only |
| deferredModeWithMutations | OCCTBRepGraphBuilderBeginDeferred | Deferred mode | Begin dropped + Commit -> Begin | ✅ :26 `isDeferredMode`, :31 | ✅ | Strengthened: original asserted only the final mode (red via the commit injection, blind to begin) |
| removeVertex | OCCTBRepGraphBuilderRemoveNode | Node removal | RemoveNode dropped | ✅ :16, :17 | ✅ | Original also red; active count added |
| removeSubgraph | OCCTBRepGraphBuilderRemoveSubgraph | Node removal | RemoveSubgraph dropped | ✅ :26, :27 | ✅ | Original also red; active count added |
| removeShellRef | OCCTBRepGraphBuilderRemoveRef | Ref removal | RemoveRef dropped, returns false | ✅ :18 `removed`, :19 | ✅ | Rewritten: asserted `removed || !removed` |
