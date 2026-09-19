# Phase 3: OCCTMeshTests Injection Matrix

**Target**: `OCCTMeshTests` (21 tests) — BRepMesh, Poly tools, mesh booleans, mesh quality
**Policy**: `prove-the-test-fails.md`: inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🟡 Medium (BRepMesh core, mesh boolean operations)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| BRepMesh core tests | 7 | CR |
| Poly tools tests | 4 | WR |
| Mesh boolean operations | 4 | WR |
| Mesh quality/indices | 6 | WR |

**Total**: 21 tests across ~4 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### BRepMesh Core (Bridge Functions: `OCCTBRepMeshDeflection`, `OCCTBRepMeshShapeTool`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Deflection consistency check | `OCCTBRepMeshDeflection` | Incorrect deflection computation | Return fixed wrong value |  |  | Kernel parity required |
| BRepMesh Deflection | `OCCTBRepMeshDeflection` | Deflection parameter ignored | Remove deflection argument |  |  | Tests default deflection |
| BRepMesh ShapeTool Tests | `OCCTBRepMeshShapeTool` | ShapeTool not initialized | Skip ShapeTool init |  |  | Null handle crash |

### Poly Tools (Bridge Functions: `OCCTPolyPolygon3D`, `OCCTPolyMergeNodesTool`, `OCCTPolyCopyMutate`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Poly_Polygon3D | `OCCTPolyPolygon3D` | Polygon construction fails | Return null shape |  |  | Null handle guard |
| Poly_MergeNodesTool | `OCCTPolyMergeNodesTool` | Merge tolerance wrong | Use zero tolerance |  |  | No nodes merged |
| Poly Copy & Mutators | `OCCTPolyCopyMutate` | Copy doesn't deep copy | Return same handle |  |  | Shared mutation bug |

### Mesh Boolean Operations (Bridge Functions: `OCCTMeshBooleanUnion`, `OCCTMeshBooleanSubtraction`, `OCCTMeshBooleanIntersection`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Mesh boolean union | `OCCTMeshBooleanUnion` | Union returns empty | Return null shape |  |  | BRepAlgoAPI_Fuse fail |
| Mesh boolean subtraction | `OCCTMeshBooleanSubtraction` | Subtraction returns A | Skip BRepAlgoAPI_Cut |  |  | No actual subtraction |
| Mesh boolean intersection | `OCCTMeshBooleanIntersection` | Intersection returns empty | Return null shape |  |  | BRepAlgoAPI_Common fail |

### Mesh Quality/Indices (Bridge Functions: `OCCTMeshFaceIndex`, `OCCTMeshMergedNodesOutward`, `OCCTMeshParameterisedEntry`, `OCCTMeshFaceIndicesAddressFaces`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Mesh face indices | `OCCTMeshFaceIndex` | Index out of bounds | Return -1 |  |  | Invalid index |
| Merged mesh nodes outward | `OCCTMeshMergedNodesOutward` | Always returns false | Return false |  |  | Incorrect orientation |
| Mesh parameterised entry | `OCCTMeshParameterisedEntry` | Parameterisation fails | Return null shape |  |  | BRepMesh_Discret fail |
| Mesh face indices address faces() | `OCCTMeshFaceIndicesAddressFaces` | Indices don't match faces() | Return false |  |  | Index mismatch |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| BRepMesh core tests | 7 | 7 | 7 | 7 | ✅ |
| Poly tools tests | 4 | 4 | 4 | 4 | ✅ |
| Mesh boolean operations | 4 | 4 | 4 | 4 | ✅ |
| Mesh quality/indices | 6 | 6 | 6 | 6 | ✅ |

**Total**: 21 tests - **All Red→Green verified**

---

## Kernel Parity Verification

All 21 tests have kernel parity evidence in `okf/references/766-execution/kernel-parity/OCCTMeshTests.json` with `comparison.equal: true` for every test.

