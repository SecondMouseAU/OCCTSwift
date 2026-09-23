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