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

## Measured: Durable UID (#1986)

Measured on the pinned kernel: every row below was run red under the injection shown and
green once it was reverted. Probes and transcripts are under `Scripts/repro/766-brepgraph-*/`.

### Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
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

### Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
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
