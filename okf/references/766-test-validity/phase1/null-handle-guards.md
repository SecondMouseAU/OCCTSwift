# Phase 1: Null-Handle Guards Injection Matrix

**Script**: `Scripts/check-null-handle-guards.py` — 36 entry points dereferencing `OCCTCurve3DRef`/`SurfaceRef` handles

**Policy**: `prove-the-test-fails.md` — For each test: inject defect → confirm fail (red) → restore → confirm pass (green) → report both

---

## Test Coverage for Null-Handle Guards

From the gate script's ALLOWED table and CLAUDE.md's known OCCT bugs, the following bridge functions require null-handle guards:

| # | Bridge Function | File | Handle Type | OCCT Call | Test Coverage | Injection Status |
|---|-----------------|------|-------------|-----------|---------------|------------------|
| 1 | `OCCTGeomLibToolParameter3D` | OCCTBridge_Curve3D.mm | OCCTCurve3DRef | GeomLib_Tool::Parameter | AnalysisTests: Curve3D Local Properties | |
| 2 | `OCCTGeomLibToolParameter2D` | OCCTBridge_Geom2d.mm | OCCTCurve2DRef | GeomLib_Tool::Parameter | Geom2dTests | |
| 3 | `OCCTGeomLibToolParametersSurface` | OCCTBridge_Surface.mm | OCCTSurfaceRef | GeomLib_Tool::Parameters | SurfaceTests | |
| 4 | `OCCTGeomConvertIsCanonical` | OCCTBridge_Surface.mm | OCCTSurfaceRef | GeomConvert_SurfToAnaSurf::IsCanonical | SurfaceTests | |
| 5 | `OCCTApproxSameParameter` | OCCTBridge_Curve3D.mm | OCCTCurve3DRef (3x) | Approx_SameParameter | CurveTests | |
| 6 | `OCCTExtremaExtCC` | OCCTBridge_Curve3D.mm | OCCTCurve3DRef | GeomAdaptor_Curve | AnalysisTests: Extrema_ExtCC | |
| 7 | `OCCTExtremaExtCCPoint` | OCCTBridge_Curve3D.mm | OCCTCurve3DRef | GeomAdaptor_Curve | AnalysisTests: Extrema_ExtCC | |
| 8 | `OCCTExtremaExtCS` | OCCTBridge_Curve3D.mm | OCCTCurve3DRef + OCCTSurfaceRef | GeomAdaptor_Curve/Surface | AnalysisTests: Extrema_ExtCS | |
| 9 | `OCCTExtremaExtCSPoint` | OCCTBridge_Curve3D.mm | OCCTCurve3DRef + OCCTSurfaceRef | GeomAdaptor_Curve/Surface | AnalysisTests: Extrema_ExtCS | |
| 10 | `OCCTExtremaLocateExtCC` | OCCTBridge_Curve3D.mm | OCCTCurve3DRef | GeomAdaptor_Curve | AnalysisTests: Extrema_ExtCC | |
| 11 | `OCCTExtremaLocateExtCC2d` | OCCTBridge_Geom2d.mm | OCCTCurve2DRef | Geom2dAdaptor_Curve | Geom2dTests | |
| 12 | `OCCTGeom2dConvertApproxArcsSegments` | OCCTBridge_Geom2d.mm | OCCTCurve2DRef | Geom2dAdaptor_Curve | Geom2dTests | |
| 13 | `OCCTGeomLibIsPlanarSurface` | OCCTBridge_Surface.mm | OCCTSurfaceRef | GeomLib_IsPlanarSurface | SurfaceTests | |
| 14 | `OCCTGeomLibPlanarSurfacePlane` | OCCTBridge_Surface.mm | OCCTSurfaceRef | GeomLib_IsPlanarSurface | SurfaceTests | |
| 15 | `OCCTExtremaExtPS` | OCCTBridge_Surface.mm | OCCTSurfaceRef | GeomAdaptor_Surface | AnalysisTests: Extrema_ExtPS | |
| 16 | `OCCTExtremaExtPSPoint` | OCCTBridge_Surface.mm | OCCTSurfaceRef | GeomAdaptor_Surface | AnalysisTests: Extrema_ExtPS | |
| 17 | `OCCTExtremaExtSS` | OCCTBridge_Surface.mm | OCCTSurfaceRef (2x) | GeomAdaptor_Surface | AnalysisTests: Extrema_ExtSS | |
| 18 | `OCCTExtremaExtSSPoint` | OCCTBridge_Surface.mm | OCCTSurfaceRef (2x) | GeomAdaptor_Surface | AnalysisTests: Extrema_ExtSS | |
| 19 | `OCCTGeomFillCoonsAlgPatchEval` | OCCTBridge_Surface.mm | Local Handle (BRep_Tool::Curve) | GeomAdaptor_Curve ctor | StressTests: evalAndUpdateTolerance Null PCurve | |
| 20 | `OCCTBRepToolsEvalAndUpdateTol` | OCCTBridge_Topology.mm | Local Handle (BRep_Tool::CurveOnSurface) | BRepTools::EvalAndUpdateTol | StressTests: evalAndUpdateTolerance Null PCurve | |

---

## Additional Bridge Functions Requiring Guards (from check-null-handle-guards.py's detection)

The gate script identifies 36 entry points across these domains:

| Domain | Functions | Status |
|--------|-----------|--------|
| Curve3D | 14 | Need injection matrix |
| Geom2d | 8 | Need injection matrix |
| Surface | 14 | Need injection matrix |
| Topology | Local handles from BRep_Tool:: | Need injection matrix |

---

## Injection Procedure per Test

For each test exercising a bridge function above:

```bash
# 1. Identify the bridge function and its null-handle guard
# 2. Create injection by REMOVING the guard:
#    - Remove: `if (!x || x->curve.IsNull()) return fallback;`
#    - Or remove: `if (!x || x->surface.IsNull()) return fallback;`
# 3. Run focused test: swift test --filter <TestStructName>
# 4. Confirm FAIL (red) - should crash or return error
# 5. Restore guard
# 6. Confirm PASS (green)
# 7. Record in matrix below
```

---

## Injection Matrix Template

| Test Target | Suite | Test | Bridge Function | Guard Removed | Red? | Green? | Notes |
|-------------|-------|------|-----------------|---------------|------|--------|-------|
| OCCTAnalysisTests | Curve3D Local Properties Tests | Curvature of circle is 1/r | OCCTGeomLibToolParameter3D | curve.IsNull() |  |  | |
| OCCTAnalysisTests | Extrema_ExtCC Tests | curveSurfaceParallel | OCCTExtremaExtCC | curve.IsNull() |  |  | |
| OCCTGeom2dTests | (find relevant) | | OCCTGeomLibToolParameter2D | curve.IsNull() |  |  | |
| OCCTSurfaceTests | (find relevant) | | OCCTGeomLibToolParametersSurface | surface.IsNull() |  |  | |
| OCCTStressTests | Stress: evalAndUpdateTolerance Null PCurve | edgePairedWithUnrelatedCylindricalFaceDoesNotCrash | OCCTBRepToolsEvalAndUpdateTol | local handle IsNull() |  |  | |
| OCCTStressTests | Stress: evalAndUpdateTolerance Null PCurve | edgePairedWithAnUnrelatedPlanarFaceDoesNotCrash | OCCTBRepToolsEvalAndUpdateTol | local handle IsNull() |  |  | |

---

## Gate Script Self-Test Removal Matrix

Per `prove-the-test-fails.md`, the script's `--self-test` must also be proven:

| Self-Test Fixture | Guard Removed | Case Count Before | Case Count After | Isolated Mechanism |
|-------------------|---------------|-------------------|------------------|-------------------|
| fixture A (wrapper direct) | wrapper `IsNull()` | N | N-1 | Direct wrapper argument guard |
| fixture B (cast) | cast->field guard | N | N-1 | Cast indirection guard |
| fixture C (pointer alias) | alias->field guard | N | N-1 | Pointer alias guard |
| fixture D (handle alias) | local handle.IsNull() | N | N-1 | Handle alias guard |
| fixture E (bridge helper) | helper's guard | N | N-1 | Bridge helper guard |
| fixture F (local BRep_Tool::) | local handle.IsNull() | N | N-1 | Local handle guard |
| fixture G (extern "C" block) | wrapper IsNull() | N | N-1 | extern "C" block parsing |
| fixture H (DownCast) | (not a use) | N | N | DownCast exclusion |
| fixture I (ALLOWED entry) | (exempted) | N | N | Measured-safe call |
| fixture J (local handle constructor-init) | local handle.IsNull() | N | N-1 | Constructor-init form |

Run: `python3 Scripts/check-null-handle-guards.py --self-test`

---

## Next Steps

1. Map each bridge function to its test coverage (using inventory.json)
2. For each test, create injection and verify fail/pass
2. Document results in matrix above
3. Run gate script `--self-test` with guard removals to verify each case