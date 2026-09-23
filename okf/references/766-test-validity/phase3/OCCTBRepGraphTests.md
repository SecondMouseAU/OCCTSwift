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

## Measured: Node Status, Occurrences, Poly Counts, Products, Refs, Root Nodes and SameDomain (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
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

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
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
