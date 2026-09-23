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

## Measured: Face Queries, Face Shells, History and History Readback (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **BRepGraph Face Queries** | faceAdjacency | Face adjacency | face not excluded from its own adjacency |
| **BRepGraph Face Queries** | sharedEdges | Shared edges | edges of either face |
| **BRepGraph Face Queries** | outerWire | Outer wire | wire index + 1 |
| **BRepGraph Face Shells** | faceShells | Face shells | shell index + 1 |
| **BRepGraph Face Shells** | faceCompoundCount | Face compounds | count + 1 |
| **BRepGraph History** | historyDefaults | History state | IsEnabled negated |
| **BRepGraph History** | historyToggle | History state | IsEnabled negated |
| **BRepGraph History** | historyClear | History clear | Clear dropped |
| **v0.141 BRepGraph history record readback** | oneToOneReadback | History record | stray extra replacement recorded |
| **v0.141 BRepGraph history record readback** | splitMapping | History record | stray extra replacement recorded |
| **v0.141 BRepGraph history record readback** | deletionMapping | History record | stray extra replacement recorded |
| **v0.141 BRepGraph history record readback** | findDerivedWalksForward | History walk | stray extra replacement recorded |
| **v0.141 BRepGraph history record readback** | hasHistoryRecordDistinguishesNamedFromUntouched | History lookup (Swift) | Swift hasHistoryRecord reads first record only |
| **v0.141 BRepGraph history record readback** | findDerivedOrSelfDisambiguates | History lookup | stray extra replacement recorded |
| **v0.141 BRepGraph history record readback** | findDerivedOrSelfMatchesFindDerivedWhenNonEmpty | History lookup (Swift) | Swift findDerivedOrSelf appends original |
| **v0.141 BRepGraph history record readback** | findOriginalWalksBackward | History walk | original index + 1 |
| **v0.141 BRepGraph history record readback** | findOriginalPassthrough | History walk | original index + 1 |

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| faceAdjacency | OCCTBRepGraphFaceAdjacentIndices | Face adjacency | face not excluded from its own adjacency | ✅ :14 `adjacentFaces(of: 0) == [2, 3, 4, 5]` | ✅ | Original also red (count); list pinned |
| sharedEdges | OCCTBRepGraphFaceSharedEdgeIndices | Shared edges | edges of either face | ✅ :24 `sharedEdges(...) == [0]` | ✅ | Original also red; `if adj.count > 0` guard now #require |
| outerWire | OCCTBRepGraphFaceOuterWire | Outer wire | wire index + 1 | ✅ :31 outer wire list | ✅ | Rewritten: `wire >= 0` stayed green |
| faceShells | OCCTBRepGraphFaceShellIndices | Face shells | shell index + 1 | ✅ :17 `faceShells(i) == [0]` | ✅ | Original also red (range check); pinned |
| faceCompoundCount | OCCTBRepGraphFaceCompoundCount | Face compounds | count + 1 | ✅ :27 | ✅ | Original also red; #require only |
| historyDefaults | OCCTBRepGraphHistoryIsEnabled | History state | IsEnabled negated | ✅ :12 | ✅ | Original also red; #require only |
| historyToggle | OCCTBRepGraphHistorySetEnabled | History state | IsEnabled negated | ✅ :20, :22 | ✅ | Original also red; #require only |
| historyClear | OCCTBRepGraphHistoryClear | History clear | Clear dropped | ✅ :35 `historyRecordCount == 0` | ✅ | Rewritten: cleared an already-empty history |
| oneToOneReadback | OCCTBRepGraphHistoryRecord | History record | stray extra replacement recorded | ✅ :33 `rec.mapping[orig] == [repl]` | ✅ | Original also red |
| splitMapping | OCCTBRepGraphHistoryRecord | History record | stray extra replacement recorded | ✅ :54 | ✅ | Original also red |
| deletionMapping | OCCTBRepGraphHistoryRecord | History record | stray extra replacement recorded | ✅ :72 | ✅ | Original also red |
| findDerivedWalksForward | OCCTBRepGraphHistoryFindDerived | History walk | stray extra replacement recorded | ✅ :98 `derived == [a, b, c]` | ✅ | Rewritten: `isSuperset(of: [b, c])` passed a stray extra node; kernel returns the intermediate a too |
| hasHistoryRecordDistinguishesNamedFromUntouched | OCCTBRepGraphHistoryGetRecordOriginals | History lookup (Swift) | Swift hasHistoryRecord reads first record only | ✅ :124 | ✅ | Original also red |
| findDerivedOrSelfDisambiguates | OCCTBRepGraphHistoryFindDerived | History lookup | stray extra replacement recorded | ✅ :158 `deletedResult.isEmpty` | ✅ | Original also red. Untouched -> [self] is the Swift fallback; the kernel FindDerived is [] for it |
| findDerivedOrSelfMatchesFindDerivedWhenNonEmpty | OCCTBRepGraphHistoryFindDerived | History lookup (Swift) | Swift findDerivedOrSelf appends original | ✅ :189 | ✅ | Original also red |
| findOriginalWalksBackward | OCCTBRepGraphHistoryFindOriginal | History walk | original index + 1 | ✅ :211 | ✅ | Original also red |
| findOriginalPassthrough | OCCTBRepGraphHistoryFindOriginal | History walk | original index + 1 | ✅ :226 | ✅ | Original also red |
