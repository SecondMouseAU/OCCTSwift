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
| **packSIMD3 shared helper** | exactMapping | SIMD3 packing | y/z swapped |
| **packSIMD3 shared helper** | emptyInputIsEmpty | SIMD3 packing | empty input yields a zero |
| **packSIMD3 shared helper** | floatScalarBuffer | SIMD3 packing | y/z swapped |
| **packSIMD3 shared helper** | roundTripsThroughUnpack | SIMD3 packing | y/z swapped in pack, x/y in unpack |
| **unpackSIMD3 shared helper** | exactMapping | SIMD3 unpacking | x/y swapped |
| **unpackSIMD3 shared helper** | zeroCountIsEmpty | SIMD3 unpacking | count ignored |
| **unpackSIMD3 shared helper** | stopsAtActualCountNotBufferLength | SIMD3 unpacking | count ignored |
| **unpackSIMD3 shared helper** | floatScalarBuffer | SIMD3 unpacking | x/y swapped |
| **unpackSIMD3 shared helper** | unsafeBufferPointerBuffer | SIMD3 unpacking | x/y swapped |

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
| exactMapping | none (pure Swift: packSIMD3) | SIMD3 packing | append x, z, y | ✅ | ✅ |  |
| emptyInputIsEmpty | none (pure Swift: packSIMD3) | SIMD3 packing | if values.isEmpty append 0 (Double only) | ✅ | ✅ |  |
| floatScalarBuffer | none (pure Swift: packSIMD3) | SIMD3 packing | append x, z, y | ✅ | ✅ |  |
| roundTripsThroughUnpack | none (pure Swift: packSIMD3 / unpackSIMD3) | SIMD3 packing | both helpers' swaps (they do not cancel) | ✅ | ✅ |  |
| exactMapping | none (pure Swift: unpackSIMD3) | SIMD3 unpacking | count guard removed, reads buffer.count / 3, x/y swapped | ✅ | ✅ |  |
| zeroCountIsEmpty | none (pure Swift: unpackSIMD3) | SIMD3 unpacking | same | ✅ | ✅ |  |
| stopsAtActualCountNotBufferLength | none (pure Swift: unpackSIMD3) | SIMD3 unpacking | same | ✅ | ✅ |  |
| floatScalarBuffer | none (pure Swift: unpackSIMD3) | SIMD3 unpacking | same | ✅ | ✅ |  |
| unsafeBufferPointerBuffer | none (pure Swift: unpackSIMD3) | SIMD3 unpacking | same | ✅ | ✅ |  |

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
| packSIMD3 exactMapping | ✅ | ✅ | ✅ |
| packSIMD3 emptyInputIsEmpty | ✅ | ✅ | ✅ |
| packSIMD3 floatScalarBuffer | ✅ | ✅ | ✅ |
| packSIMD3 roundTripsThroughUnpack | ✅ | ✅ | ✅ |
| unpackSIMD3 exactMapping | ✅ | ✅ | ✅ |
| unpackSIMD3 zeroCountIsEmpty | ✅ | ✅ | ✅ |
| unpackSIMD3 stopsAtActualCountNotBufferLength | ✅ | ✅ | ✅ |
| unpackSIMD3 floatScalarBuffer | ✅ | ✅ | ✅ |
| unpackSIMD3 unsafeBufferPointerBuffer | ✅ | ✅ | ✅ |

**Total**: 27 tests