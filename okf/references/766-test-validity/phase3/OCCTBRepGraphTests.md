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

## Measured: Edge Wires/CoEdges, Explorers, Face Def and Face Geometry (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
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

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
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
