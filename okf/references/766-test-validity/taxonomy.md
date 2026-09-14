# Test Defect Category Taxonomy

This taxonomy classifies each `@Test` by the **defect it exists to catch**. Used for Phase 0 categorization and Phase 1-3 prioritization.

## Categories

| Category | Code | Description | Examples |
|----------|------|-------------|----------|
| **Null Handle** | `NH` | Test catches null/unguarded OCCT handle dereference | `OCCTCurve3DRef`, `OCCTSurfaceRef` guard checks |
| **Out of Bounds** | `OOB` | Test catches parameter/index out of valid range | Edge parameter validation, array bounds |
| **Wrong Result** | `WR` | Test catches incorrect computed value (not crash) | Wrong area/volume, incorrect boolean result |
| **Crash/SIGSEGV** | `CR` | Test catches uncatchable OS signal (SIGSEGV/SIGABRT) | `gp_Dir` zero vector, `BRepFill_Filling` null handle |
| **Timeout/Hang** | `TO` | Test catches unbounded execution past deadline | Self-intersection timeout, infinite loops |
| **Contract Violation** | `CV` | Test catches API contract breach (precondition/postcondition) | `IsDone()` false when should be true |
| **Thread Safety** | `TS` | Test catches data race / deadlock / race condition | TSan-detected races, mutex correctness |
| **Degenerate Geometry** | `DG` | Test catches degenerate input (zero-length, coincident) | Zero-area face, coincident vertices |
| **Resource Leak** | `RL` | Test catches memory/handle leak | `OCCT*Ref` without `deinit`, borrowed handles |
| **Format/IO Error** | `IO` | Test catches STEP/IGES/OCAF read/write failure | Round-trip corruption, missing entities |
| **Refusal/Refusal Shape** | `RF` | Test catches correct refusal (Bool? vs Bool) | `checkOuterBound` returns `nil` for invalid input |
| **Mutation Gap** | `MG` | Test missing coverage revealed by mutation testing | #767 findings |

## Priority Order (for worklist)

1. **CR** — Crash/SIGSEGV (uncatchable, highest risk)
2. **NH** — Null Handle (leads to CR if unguarded)
3. **TS** — Thread Safety (TSan, concurrency)
4. **RL** — Resource Leak (borrowed handles)
5. **TO** — Timeout/Hang (self-intersection, etc.)
6. **DG** — Degenerate Geometry (common OCCT edge case)
7. **CV** — Contract Violation
8. **RF** — Refusal Shape (API clarity)
9. **WR** — Wrong Result (correctness)
10. **OOB** — Out of Bounds
11. **IO** — Format/IO Error
12. **MG** — Mutation Gap (Phase 3+)

## Mapping to Known OCCT Bugs (from CLAUDE.md)

| Bug | Category | Tests Targeting |
|-----|----------|-----------------|
| #341 theAutoNaming | CR/TS | XCAF, StressTests |
| #344 CDF_Directory | CR/TS | XCAF, IOTests |
| #345 gp_Dir | CR | Curve/Surface/Geom2d/Topology/Visualization |
| #349 OCAF driver | CR/TS | XCAF, IOTests |
| #353 CDM_MetaData | CR/TS | XCAF |
| #371 GetApplication | CR/TS | XCAF, Document |
| #374 Resource_Manager | CR/TS | XCAF, Document |
| #430 BRepFill_Filling | CR | Modeling, Surface |
| #522 AdvApp2Var | CR/WR | Surface, Modeling |
| #532 Cylindrical hole | WR | Modeling |
| #597 GeomFill_Sweep | WR | Surface, Modeling |
| #603 CPnts_AbscissaPoint | WR | Curve, Analysis |
| #643 GeomTools null | CR/NH | IO |
| #905/913 ThruSections | CR/WR | Modeling |

## Per-Domain Expected Distribution

| Domain | Primary Categories | Estimated Tests |
|--------|-------------------|-----------------|
| OCCTStressTests | TS, CR, TO | ~200 |
| OCCTModelingTests | CR, WR, DG, NH | ~500 |
| OCCTShapeHealingTests | DG, WR, CV | ~300 |
| OCCTSurfaceTests | CR, WR, DG | ~400 |
| OCCTCurveTests | CR, WR, DG | ~300 |
| OCCTGeom2dTests | CR, WR, DG | ~300 |
| OCCTIOTests | IO, CR, NH | ~200 |
| OCCTXCAFTests | CR, TS, RL, IO | ~400 |
| OCCTDrawingTests | WR, OOB | ~100 |
| OCCTAnalysisTests | WR, DG | ~150 |
| OCCTMathTests | WR, OOB | ~100 |
| OCCTMeshTests | WR, DG | ~100 |
| OCCTBRepGraphTests | TS, RL | ~100 |
| OCCTTopologyTests | WR, DG | ~200 |
| OCCTFoundationTests | WR, CV | ~50 |
| OCCTIntegrationTests | Multi | ~100 |
| OCCTMiscTests | Multi | ~50 |
| OCCTThreadTests | TS, CR | ~50 |

**Total**: ~3,600 (actual: 2,207 found by script — may miss parameterized tests)

## Usage

Each test in `inventory.json` gets a `category` field added during Phase 0.2.