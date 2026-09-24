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
| **BinTools Shape I/O Tests** | writeAndReadBinaryData | BinTools stream round trip | OCCTBinToolsWriteShape |
| **BinTools Shape I/O Tests** | writeAndReadBinaryFile | BinTools file round trip | OCCTBinToolsWriteShapeToFile |
| **BinTools Shape I/O Tests** | sphereRoundtrip | BinTools stream round trip | OCCTBinToolsWriteShape |
| **v0.115.0 - BRepAdaptor Exposure** | edgeDomain | Edge adaptor domain | OCCTEdgeAdaptorDomain |
| **v0.115.0 - BRepAdaptor Exposure** | edgeValue | Edge adaptor point | OCCTEdgeAdaptorValue |
| **v0.115.0 - BRepAdaptor Exposure** | edgeCurveType | Edge adaptor curve type | OCCTEdgeAdaptorCurveType |
| **v0.115.0 - BRepAdaptor Exposure** | faceBounds | Face adaptor bounds | OCCTFaceAdaptorBounds |
| **v0.115.0 - BRepAdaptor Exposure** | faceValue | Face adaptor point | OCCTFaceAdaptorValue |
| **v0.115.0 - BRepAdaptor Exposure** | faceSurfaceType | Face adaptor surface type | OCCTFaceAdaptorSurfaceType |

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
| writeAndReadBinaryData | OCCTBinToolsWriteShape | BinTools stream round trip | writer serialises TopoDS_Shape() instead of the input | ✅ | ✅ | Rewritten: went red only because a null stream is under 10 bytes |
| writeAndReadBinaryFile | OCCTBinToolsWriteShapeToFile | BinTools file round trip | file writer serialises TopoDS_Shape() | ✅ | ✅ | Rewritten: checks sat inside if-let, green under the injection |
| sphereRoundtrip | OCCTBinToolsWriteShape | BinTools stream round trip | writer serialises TopoDS_Shape() instead of the input | ✅ | ✅ | Rewritten: checks sat inside if-let, green under the injection |
| edgeDomain | OCCTEdgeAdaptorDomain | Edge adaptor domain | last = first + 1 | ✅ | ✅ | Rewritten: upper > lower passed a [0, 1] domain |
| edgeValue | OCCTEdgeAdaptorValue | Edge adaptor point | x + 1 | ✅ | ✅ | Rewritten: asserted |p| >= 0 |
| edgeCurveType | OCCTEdgeAdaptorCurveType | Edge adaptor curve type | GetType() + 1 | ✅ | ✅ |  |
| faceBounds | OCCTFaceAdaptorBounds | Face adaptor bounds | uMax = FirstUParameter() | ✅ | ✅ | Rewritten: accepted either direction non-empty |
| faceValue | OCCTFaceAdaptorValue | Face adaptor point | x + 1 | ✅ | ✅ | Rewritten: asserted |p| >= 0 |
| faceSurfaceType | OCCTFaceAdaptorSurfaceType | Face adaptor surface type | GetType() + 1 | ✅ | ✅ |  |

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
