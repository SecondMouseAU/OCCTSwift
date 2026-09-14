# Phase 3: Remaining Domains Injection Matrices

**Targets**: OCCTDrawingTests (194), OCCTAnalysisTests (526), OCCTMathTests (342), OCCTMeshTests (86), OCCTBRepGraphTests (200), OCCTTopologyTests (554), OCCTFoundationTests (200), OCCTIntegrationTests (19), OCCTMiscTests (85), OCCTThreadTests (67)

**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)

---

## OCCTDrawingTests (194 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Drawing Projection Tests | 52 | #636 (extrema) | Remove `isParallel` guard |
| HLR Tests | 38 | #345 (gp_Dir) | Remove `try/catch` |
| Hidden Line Removal | 28 | #603 (arc length) | Remove adaptive quadrature |
| Drawing Wireframe | 24 | | |
| Drawing Face/Edge Queries | 22 | | |
| Drawing Clipping | 18 | | |
| Drawing Color/Style | 16 | | |

**Total**: 194 tests

---

## OCCTAnalysisTests (526 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Shape Analysis Tests | 86 | #318 (BRepGProp) | Remove degenerate edge skip |
| Free Bounds Tests | 68 | #310, #655 (FreeBounds) | Remove INTERNAL check |
| Self-Intersection Tests | 58 | #319 (timeout) | Revert kernel patch `0010` |
| Edge Analysis Tests | 52 | #318 (BRepGProp) | Remove degenerate edge skip |
| Wire Analysis Tests | 48 | #1058 (checkOuterBound) | Remove wire checks |
| Surface Analysis Tests | 42 | #266 (surface analysis) | Remove analysis guards |
| Tolerance Analysis Tests | 38 | | |
| Volume/Property Tests | 36 | #477 (arc length) | Remove adaptive quadrature |
| Curve/Surface Proximity | 32 | #636 (extrema) | Remove `isParallel` guard |
| Mass/Inertia Properties | 30 | | |
| Curve Continuity | 28 | | |
| Surface Continuity | 28 | | |

**Total**: 526 tests

---

## OCCTMathTests (342 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| gp Primitives Tests | 68 | #345 (gp_Dir) | Remove `try/catch` |
| Geom2d Primitives Tests | 52 | | |
| Geom Primitives Tests | 48 | | |
| Algebra/Linear Tests | 42 | | |
| GeomAbs/Shape Tests | 38 | | |
| Continuity/Order Tests | 32 | | |
| Interval/Range Tests | 28 | | |
| Matrix/Transform Tests | 26 | | |

**Total**: 342 tests

---

## OCCTMeshTests (86 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Mesh Generation Tests | 28 | | |
| Mesh Quality Tests | 22 | | |
| Mesh Export Tests | 18 | | |
| Mesh Import Tests | 12 | | |
| Mesh Modification Tests | 6 | | |

**Total**: 86 tests

---

## OCCTBRepGraphTests (200 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| BRepGraph Traversal | 48 | #341 (AutoNaming) | Revert to singleton |
| Graph Edge/Vertex Queries | 42 | | |
| Graph Algorithms | 38 | | |
| Graph Attributes | 32 | | |
| Graph Serialization | 22 | | |
| Graph Thread Safety | 18 | #341 (AutoNaming) | Revert to singleton |

**Total**: 200 tests

---

## OCCTTopologyTests (554 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Topology Traversal Tests | 86 | | |
| Shape Exploration Tests | 72 | | |
| Edge/Wire/Vertex Tests | 68 | #318 (BRepGProp) | Remove degenerate edge skip |
| Face/Shell/Solid Tests | 62 | #317 (ShapeFix_Face) | Remove SetContext |
| Compound/CompSolid Tests | 58 | | |
| Orientation Tests | 52 | | |
| Adjacency/Connectivity | 50 | | |
| Classification Tests | 48 | | |
| Iterator/Explorer Tests | 38 | | |
| Transient/Persistent Tests | 30 | | |
| History/Mapping Tests | 24 | | |
| Naming/Label Tests | 16 | | |

**Total**: 554 tests

---

## OCCTFoundationTests (200 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Core Types Tests | 52 | | |
| Handle/Reference Tests | 42 | #965 (borrowed handles) | Revert to raw handle |
| Sendable/Concurrency Tests | 38 | #341, #371 | Revert to singleton |
| Memory/Resource Tests | 28 | #965 (borrowed handles) | Revert to raw handle |
| Error Handling Tests | 22 | | |
| Serialization Tests | 12 | | |
| Utility/Helper Tests | 8 | | |

**Total**: 200 tests

---

## OCCTIntegrationTests (19 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Cross-Domain Integration | 8 | | |
| End-to-End Workflows | 6 | | |
| Performance Regression | 5 | | |

**Total**: 19 tests

---

## OCCTMiscTests (85 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Miscellaneous Edge Cases | 28 | | |
| Deprecated/Obsolete Tests | 22 | | |
| Experimental Features | 18 | | |
| Backwards Compatibility | 12 | | |
| Documentation Examples | 5 | | |

**Total**: 85 tests

---

## OCCTThreadTests (67 tests)

| Suite | Tests | Key Crash Fixes | Injection Targets |
|-------|-------|-----------------|-------------------|
| Thread Safety Tests | 28 | #341, #344, #349, #353, #371, #374 | Revert mutexes/atomics |
| Sendable Boundary Tests | 18 | #341, #371 | Revert to singleton |
| Concurrent Access Tests | 12 | #344, #349, #353 | Remove mutexes |
| Parallel Execution Tests | 9 | #319 (timeout) | Revert kernel patch `0010` |

**Total**: 67 tests

---

## Summary: All 18 Domains

| Domain | Tests | Priority | Key Crash Fixes |
|--------|-------|----------|-----------------|
| OCCTStressTests | 366 | 🔴 Critical | #341, #344, #345, #349, #353, #371, #374 |
| OCCTModelingTests | 654 | 🔴 Critical | #430, #522, #532, #597, #905, #913 |
| OCCTShapeHealingTests | 320 | 🔴 Critical | #263, #317, #318, #319, #438, #442, #443, #484, #522, #570, #597, #837, #1058 |
| OCCTSurfaceTests | 552 | 🔴 Critical | #430, #437, #522, #571, #572, #597, #438 |
| OCCTCurveTests | 530 | 🔴 Critical | #345, #408, #477, #539, #548, #600, #603, #615, #636 |
| OCCTGeom2dTests | 545 | 🔴 Critical | #345, #477, #603, #636 |
| OCCTAnalysisTests | 526 | 🔴 Critical | #310, #318, #319, #603, #636, #655 |
| OCCTTopologyTests | 554 | 🟠 High | #317, #318 |
| OCCTXCAFTests | 422 | 🔴 Critical | #341, #344, #349, #353, #371, #374 |
| OCCTMathTests | 342 | 🟠 High | #345 |
| OCCTDrawingTests | 194 | 🟠 High | #345, #603, #636 |
| OCCTMeshTests | 86 | 🟢 Low | |
| OCCTBRepGraphTests | 200 | 🟠 High | #341 |
| OCCTFoundationTests | 200 | 🟠 High | #965, #341, #371 |
| OCCTThreadTests | 67 | 🔴 Critical | #341, #344, #349, #353, #371, #374, #319 |
| OCCTIOTests | 166 | 🔴 Critical | #643, #341, #344, #349, #353, #371, #374 |
| OCCTIntegrationTests | 19 | 🟢 Low | |
| OCCTMiscTests | 85 | 🟢 Low | |

**Grand Total**: 5,828 tests (vs 5,484 cited in issue)

---

## Sequential Execution Order

1. **OCCTStressTests** — 366 tests (concurrency, TSan, crash reproduction)
2. **OCCTModelingTests** — 654 tests (boolean ops, fillets, holes)
3. **OCCTShapeHealingTests** — 320 tests (fix/heal, degenerate geometry)
4. **OCCTSurfaceTests** — 552 tests (geometry evaluation)
5. **OCCTCurveTests** — 530 tests (3D curves)
6. **OCCTGeom2dTests** — 545 tests (2D geometry)
7. **OCCTAnalysisTests** — 526 tests (shape analysis)
8. **OCCTTopologyTests** — 554 tests (topology traversal)
9. **OCCTXCAFTests** — 422 tests (XCAF document operations)
10. **OCCTMathTests** — 342 tests (math/geometry primitives)
11. **OCCTDrawingTests** — 194 tests (2D drawing/projection)
12. **OCCTMeshTests** — 86 tests (meshing)
13. **OCCTBRepGraphTests** — 200 tests (topology graph)
14. **OCCTTopologyTests** — 554 tests (topology traversal)
15. **OCCTFoundationTests** — 200 tests (core types)
16. **OCCTIntegrationTests** — 19 tests (cross-domain)
17. **OCCTMiscTests** — 85 tests (miscellaneous)
18. **OCCTThreadTests** — 67 tests (thread safety)

---

## Notes

- Each domain's injection matrix follows the same format: Test | Bridge Function | Defect | Injection | Red? | Green? | Notes
- Critical crash fixes have been verified for: #341, #344, #345, #349, #353, #371, #374, #430, #522, #532, #597, #603, #636, #643, #837, #905, #913
- Borrowed handles (#965) and null-handle guards documented for all relevant entry points
- Kernel crash protocol: if injection triggers kernel crash → file upstream issue with reproducer, no bridge fix