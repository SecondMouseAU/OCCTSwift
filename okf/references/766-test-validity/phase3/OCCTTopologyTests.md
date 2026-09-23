# Phase 3: OCCTTopologyTests Injection Matrix

**Target**: `OCCTTopologyTests` (556 tests) — Topology traversal, exploration, edge/wire/vertex tests
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 P1 (topology traversal, crash fixes #317, #318)

---

## Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **Topology Traversal Tests** | Topology Traversal Tests | Topology traversal | Remove traversal |
| **Shape Exploration Tests** | Shape Exploration Tests | Shape exploration | Remove exploration |
| **Edge/Wire/Vertex Tests** | Edge/Wire/Vertex Tests | Edge/wire/vertex | Remove edge/wire/vertex ops |
| **Face/Shell/Solid Tests** | Face/Shell/Solid Tests | Face/shell/solid | Remove face/shell/solid |
| **Compound/CompSolid Tests** | Compound/CompSolid Tests | Compound/compsolid | Remove compound/compsolid |
| **Orientation Tests** | Orientation Tests | Orientation | Remove orientation |
| **Adjacency/Connectivity** | Adjacency/Connectivity | Adjacency/connectivity | Remove adjacency/connectivity |
| **Classification Tests** | Classification Tests | Classification | Remove classification |
| **Iterator/Explorer Tests** | Iterator/Explorer Tests | Iterator/explorer | Remove iterator |
| **Transient/Persistent Tests** | Transient/Persistent Tests | Transient/persistent | Remove transient/persistent |
| **History/Mapping Tests** | History/Mapping Tests | History/mapping | Remove history/mapping |
| **Naming/Label Tests** | Naming/Label Tests | Naming/label | Remove naming/label |
| **BRepCheck extended v0.112** | faceStatus | BRepCheck face status | OCCTCheckFaceStatus |
| **BRepCheck extended v0.112** | edgeStatus | BRepCheck edge status | OCCTCheckEdgeStatus |
| **BRepCheck extended v0.112** | vertexStatus | BRepCheck vertex status | OCCTCheckVertexStatus |
| **BRepCheck extended v0.112** | maxTolerance | Max vertex tolerance | OCCTShapeMaxTolerance |
| **BRepCheck extended v0.112** | minTolerance | Min vertex tolerance | OCCTShapeMinTolerance |
| **BRepCheck extended v0.112** | avgTolerance | Avg edge tolerance | OCCTShapeAvgTolerance |
| **BRepCheck extended v0.112** | fixTolerance | ShapeFix set tolerance | OCCTShapeFixTolerance |
| **BRepCheck extended v0.112** | limitMaxTolerance | ShapeFix limit tolerance | OCCTShapeLimitMaxTolerance |
| **BRepCheck SubShape Tests** | Check edge validity | BRepCheck_Edge Minimum | OCCTCheckEdge |
| **BRepCheck SubShape Tests** | Check wire validity | BRepCheck_Wire Minimum | OCCTCheckWire |
| **BRepCheck SubShape Tests** | Check shell validity | BRepCheck_Shell Minimum | OCCTCheckShell |
| **BRepCheck SubShape Tests** | Check vertex validity | BRepCheck_Vertex Minimum | OCCTCheckVertex |

---

## Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Topology Traversal Tests | OCCTTopologyTraversal | Topology traversal | Remove traversal | ✅ | ✅ |  |
| Shape Exploration Tests | OCCTShapeExploration | Shape exploration | Remove exploration | ✅ | ✅ |  |
| Edge/Wire/Vertex Tests | OCCTEdgeWireVertex | Edge/wire/vertex | Remove edge/wire/vertex | ✅ | ✅ |  |
| Face/Shell/Solid Tests | OCCTFaceShellSolid | Face/shell/solid | Remove face/shell/solid | ✅ | ✅ |  |
| Compound/CompSolid Tests | OCCTCompoundCompSolid | Compound/compsolid | Remove compound/compsolid | ✅ | ✅ |  |
| Orientation Tests | OCCTOrientation | Orientation | Remove orientation | ✅ | ✅ |  |
| Adjacency/Connectivity | OCCTAdjacencyConnectivity | Adjacency/connectivity | Remove adjacency/connectivity | ✅ | ✅ |  |
| Classification Tests | OCCTClassification | Classification | Remove classification | ✅ | ✅ |  |
| Iterator/Explorer Tests | OCCTIteratorExplorer | Iterator/explorer | Remove iterator/explorer | ✅ | ✅ |  |
| Transient/Persistent Tests | OCCTTransientPersistent | Transient/persistent | Remove transient/persistent | ✅ | ✅ |  |
| History/Mapping Tests | OCCTHistoryMapping | History/mapping | Remove history/mapping | ✅ | ✅ |  |
| Naming/Label Tests | OCCTNamingLabel | Naming/label | Remove naming/label | ✅ | ✅ |  |
| faceStatus | OCCTCheckFaceStatus | BRepCheck face status | status + 1 | ✅ | ✅ |  |
| edgeStatus | OCCTCheckEdgeStatus | BRepCheck edge status | status + 1 | ✅ | ✅ |  |
| vertexStatus | OCCTCheckVertexStatus | BRepCheck vertex status | status + 1 | ✅ | ✅ |  |
| maxTolerance | OCCTShapeMaxTolerance | Max vertex tolerance | result x 2 | ✅ | ✅ | Rewritten: 0 < tol < 1 passed a doubled tolerance |
| minTolerance | OCCTShapeMinTolerance | Min vertex tolerance | result x 2 | ✅ | ✅ |  |
| avgTolerance | OCCTShapeAvgTolerance | Avg edge tolerance | result x 2 | ✅ | ✅ |  |
| fixTolerance | OCCTShapeFixTolerance | ShapeFix set tolerance | skip SetTolerance, still return true | ✅ | ✅ | Rewritten: asserted only the returned true |
| limitMaxTolerance | OCCTShapeLimitMaxTolerance | ShapeFix limit tolerance | cap passed as maxTol x 10 | ✅ | ✅ | Rewritten: asserted ok || !ok |
| Check edge validity | OCCTCheckEdge | BRepCheck_Edge Minimum | checkSubShape reports isValid = false | ✅ | ✅ |  |
| Check wire validity | OCCTCheckWire | BRepCheck_Wire Minimum | checkSubShape reports isValid = false | ✅ | ✅ |  |
| Check shell validity | OCCTCheckShell | BRepCheck_Shell Minimum | checkSubShape reports isValid = false | ✅ | ✅ |  |
| Check vertex validity | OCCTCheckVertex | BRepCheck_Vertex Minimum | checkSubShape reports isValid = false | ✅ | ✅ |  |

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
| Topology Traversal Tests | ✅ | ✅ | ✅ |
| Shape Exploration Tests | ✅ | ✅ | ✅ |
| Edge/Wire/Vertex Tests | ✅ | ✅ | ✅ |
| Face/Shell/Solid Tests | ✅ | ✅ | ✅ |
| Compound/CompSolid Tests | ✅ | ✅ | ✅ |
| Orientation Tests | ✅ | ✅ | ✅ |
| Adjacency/Connectivity | ✅ | ✅ | ✅ |
| Classification Tests | ✅ | ✅ | ✅ |
| Iterator/Explorer Tests | ✅ | ✅ | ✅ |
| Transient/Persistent Tests | ✅ | ✅ | ✅ |
| History/Mapping Tests | ✅ | ✅ | ✅ |
| Naming/Label Tests | ✅ | ✅ | ✅ |

**Total**: 556 tests
