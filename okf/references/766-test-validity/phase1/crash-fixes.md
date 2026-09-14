# Phase 1: OCCT Crash Fixes Injection Matrix

**Source**: CLAUDE.md "Known OCCT Bugs" section — 14 fixed crashes with kernel patches

**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail → restore → confirm pass
**Policy**: `upstream-occt-patch-process.md` — if kernel crash found: file upstream issue with reproducer, prefer kernel fix

---

## Crash Fixes Inventory

| # | Issue | Crash | Kernel Patch | Bridge Tests | Injection Target |
|---|-------|-------|--------------|--------------|------------------|
| 1 | #341 | `XCAFDoc_ShapeTool::theAutoNaming` (static bool race) | `0011` | XCAFTests, StressTests | Remove mutex/atomic |
| 2 | #344 | `CDF_Directory::Add/Remove/Contains` (NCollection_List race) | `0012` | StressTests: parallelDocumentCreate | Remove mutex |
| 3 | #345 | `gp_Dir`/`Geom_Direction` zero vector (uncaught exception) | Bridge fix (try/catch) | StressTests: mirrorAxisZeroDirection, etc. | Remove try/catch |
| 4 | #349 | `BinLDrivers_DocumentStorageDriver::Write` (shared driver race) | `0014` | XCAFTests, StressTests | Remove ocafStoreMutex |
| 5 | #353 | `CDM_Application::myMetaDataLookUpTable` race | `0015` | XCAFTests | Remove mutex |
| 6 | #371 | `XCAFApp_Application::GetApplication()` singleton race | Bridge fix (private app) | XCAFTests, StressTests | Revert to singleton |
| 7 | #374 | `Resource_Manager::Debug` + `Storage_Schema::ICurrentData()` races | `0016` | FoundationTests: Resource_Manager Tests | Remove atomic/mutex |
| 8 | #430 | `BRepFill_Filling::AddConstraints` untrimmed pcurve | Bridge fix (support face) | ModelingTests, SurfaceTests | Remove support face synthesis |
| 9 | #522 | `AdvApp2Var_ApproxF2var::mma2ce1_` U buffer overflow | `0019` | SurfaceTests, ModelingTests | Revert patch |
| 10 | #532 | `BRepFeat_MakeCylindricalHole` part selection | `0020` | ModelingTests: Issue532 | Revert to SetOperation(Fuse) |
| 11 | #597 | `GeomFill_Sweep::BuildAll` SError overwrite | `0025` | SurfaceTests, ModelingTests | Revert SError = ConvertApprox.MaxError() |
| 12 | #603 | `CPnts_AbscissaPoint::Length` single quadrature | `0021` + bridge | CurveTests: Arc length stops... | Remove adaptive quadrature |
| 13 | #643 | `GeomTools_Curve2dSet/SurfaceSet::Add` null handle | `0023` | IOTests | Remove null guard |
| 14 | #905/#913 | `BRepOffsetAPI_ThruSections` capping/count mismatch | `0026`/`0027` | ModelingTests | Revert patches |

---

## Injection Strategy per Crash

### #341: theAutoNaming Race
- **Test**: `OCCTStressTests: Stress: Concurrent Document Creation (#344)` → `parallelDocumentCreate`
- **Injection**: Remove `std::atomic<bool>` from `theAutoNaming` in kernel, or revert bridge to singleton
- **Expected**: TSan race or SIGSEGV

### #344: CDF_Directory Race
- **Test**: `OCCTStressTests: Stress: Concurrent Document Creation (#344)` → `parallelDocumentCreate`
- **Injection**: Remove mutex from `CDF_Directory::Add/Remove/Contains`
- **Expected**: TSan race on `NCollection_BaseList::PAppend`

### #345: gp_Dir Zero Vector
- **Tests**: `OCCTStressTests: Stress: Invalid Parameters` → `mirrorAxisZeroDirection`, `mirrorPlaneZeroNormal`, `geomDirectionZeroVector`
- **Injection**: Remove `try { } catch (...) { }` wrapper in bridge functions
- **Expected**: SIGABRT (uncaught exception → std::terminate)

### #349: OCAF Driver Race
- **Test**: `OCCTStressTests` concurrent Save/Load
- **Injection**: Remove `ocafStoreMutex()` from bridge
- **Expected**: TSan race on `BinMDF_ADriverTable::AssignIds`

### #353: CDM_MetaData Race
- **Test**: `OCCTStressTests` concurrent document operations
- **Injection**: Remove mutex from `CDM_Application` and `CDM_MetaData`
- **Expected**: TSan race + SIGABRT

### #371: GetApplication Singleton
- **Test**: `OCCTStressTests: Stress: Concurrent Document Creation` + XCAFTests
- **Injection**: Revert bridge to use `XCAFApp_Application::GetApplication()`
- **Expected**: TSan race on `locApp` construction

### #374: Resource_Manager/Storage_Schema Races
- **Test**: `OCCTFoundationTests: Resource_Manager Tests` + concurrent Save/Load
- **Injection**: Remove `std::atomic<bool>` from `Debug`, remove mutex from `Storage_Schema`
- **Expected**: TSan race on `Debug` write + `ICurrentData()` nullify

### #430: BRepFill_Filling Untrimmed Pcurve
- **Test**: `OCCTModelingTests` / `OCCTSurfaceTests` filling operations
- **Injection**: Remove `occtFillingSupportFaceFromPCurve` / `occtFillingAddConstraint` support face synthesis
- **Expected**: SIGSEGV on non-C0 surface (cylinder/sphere/cone)

### #522: AdvApp2Var U Buffer Overflow
- **Test**: `OCCTSurfaceTests` / `OCCTModelingTests` approximation at C0
- **Injection**: Revert kernel patch `0019` (target `ipt4` from U call)
- **Expected**: Wrong surface (degree collapse), wrong MaxError()

### #532: Cylindrical Hole Part Selection
- **Test**: `OCCTModelingTests: Issue532 cylindrical hole part selection` (6 tests)
- **Injection**: Revert kernel patch `0020` (change `SetOperation(myFuse, bFlag)` back to `SetOperation(Fuse)`)
- **Expected**: Zero volume removed (wrong part kept)

### #597: GeomFill_Sweep SError Overwrite
- **Test**: `OCCTSurfaceTests` / `OCCTModelingTests` pipe/sweep with ForceApproxC1
- **Injection**: Revert `SError = ConvertApprox.MaxError()` to `SError = theTol`
- **Expected**: Wrong error reported (0.0001 vs actual 2.5+)

### #603: CPnts Single Quadrature
- **Test**: `OCCTCurveTests: Arc length stops being one quadrature per span (#603)` (14 tests)
- **Injection**: Remove adaptive quadrature in bridge (`occtAdaptorArcLength`/`occtArcWalkToLength`)
- **Expected**: Arc length errors up to 1.7% (ellipse) / 3% (parabola)

### #643: GeomTools Null Write
- **Test**: `OCCTIOTests` / `OCCTGeom2dTests` / `OCCTSurfaceTests` GeomTools round-trip
- **Injection**: Remove null guard in bridge before `GeomTools_Curve2dSet::Add` / `SurfaceSet::Add`
- **Expected**: SIGSEGV on `Write()` → `PrintCurve2d`/`PrintSurface` → `DynamicType()`

### #905/#913: ThruSections Capping/Count
- **Test**: `OCCTModelingTests` loft/thru-sections tests
- **Injection**: Revert kernel patches `0026`/`0027`
- **Expected**: SIGSEGV/SIGBUS on count mismatch; wrong capping on non-planar

---

## Injection Matrix Template

| Issue | Test Target | Suite | Test | Bridge Function | Injection | Red? | Green? | Notes |
|-------|-------------|-------|------|-----------------|-----------|------|--------|-------|
| #341 | OCCTStressTests | Stress: Concurrent Document Creation | parallelDocumentCreate | OCCTDocumentCreate | Remove atomic/revert to singleton |  |  | |
| #344 | OCCTStressTests | Stress: Concurrent Document Creation | parallelDocumentCreate | CDF_Directory access | Remove mutex |  |  | |
| #345 | OCCTStressTests | Stress: Invalid Parameters | mirrorAxisZeroDirection | gp_Dir constructors | Remove try/catch |  |  | |
| #345 | OCCTStressTests | Stress: Invalid Parameters | mirrorPlaneZeroNormal | gp_Dir constructors | Remove try/catch |  |  | |
| #345 | OCCTStressTests | Stress: Invalid Parameters | geomDirectionZeroVector | Geom_Direction | Remove try/catch |  |  | |
| #349 | OCCTStressTests | (find) | concurrent Save/Load | ocafStoreMutex | Remove mutex |  |  | |
| #353 | OCCTStressTests | (find) | concurrent doc ops | CDM_MetaData | Remove mutex |  |  | |
| #371 | OCCTStressTests | Stress: Concurrent Document Creation | parallelDocumentCreate | XCAFApp_Application::GetApplication | Revert to singleton |  |  | |
| #374 | OCCTFoundationTests | Resource_Manager Tests | setAndGetString | Resource_Manager/Storage_Schema | Remove atomic/mutex |  |  | |
| #430 | OCCTModelingTests | (find filling) | BRepFill_Filling::AddConstraints | Remove support face synthesis |  |  |  | |
| #430 | OCCTSurfaceTests | (find filling) | BRepFill_Filling::AddConstraints | Remove support face synthesis |  |  |  | |
| #522 | OCCTSurfaceTests | (find approx C0) | GeomConvert_ApproxSurface | Revert ipt4 target |  |  |  | |
| #532 | OCCTModelingTests | Issue532 cylindrical hole part selection | untilEnd and a stack... | BRepFeat_MakeCylindricalHole | Revert SetOperation |  |  | |
| #532 | OCCTModelingTests | Issue532 cylindrical hole part selection | blind drills its depth... | BRepFeat_MakeCylindricalHole | Revert SetOperation |  |  | |
| #532 | OCCTModelingTests | Issue532 cylindrical hole part selection | A three-plate stack... | BRepFeat_MakeCylindricalHole | Revert SetOperation |  |  | |
| #532 | OCCTModelingTests | Issue532 cylindrical hole part selection | A single solid the bore... | BRepFeat_MakeCylindricalHole | Revert SetOperation |  |  | |
| #532 | OCCTModelingTests | Issue532 cylindrical hole part selection | A single plate is... | BRepFeat_MakeCylindricalHole | Revert SetOperation |  |  | |
| #532 | OCCTModelingTests | Issue532 cylindrical hole part selection | A hollow box drills... | BRepFeat_MakeCylindricalHole | Revert SetOperation |  |  | |
| #532 | OCCTModelingTests | Issue532 cylindrical hole part selection | A range naming no face... | BRepFeat_MakeCylindricalHole | Revert SetOperation |  |  | |
| #597 | OCCTSurfaceTests | (find sweep/pipe) | GeomFill_Sweep::BuildAll | Revert SError fix |  |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A whole ellipse... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A parabola over a wide... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A hyperbola over a wide... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A whipping cubic Bezier... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | The closed forms stay... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | Accurate sub-ranges... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A wound range winds... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A fraction of the length... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A negative abscissa... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A 2D ellipse measures... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | An elliptical edge... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | A wire containing... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | An EdgeCurve measures... | occtAdaptorArcLength | Remove adaptive quadrature |  |  | |
| #603 | OCCTCurveTests | Arc length stops... (#603) | parameterAtLength... | occtArcWalkToLength | Remove adaptive quadrature |  |  | |
| #643 | OCCTIOTests | (find GeomTools) | GeomTools_Curve2dSet::Write | Remove null guard |  |  |  | |
| #905 | OCCTModelingTests | (find ThruSections) | BRepOffsetAPI_ThruSections | Revert capping throw |  |  |  | |
| #913 | OCCTModelingTests | (find ThruSections) | BRepOffsetAPI_ThruSections | Revert count check |  |  |  | |

---

## If Kernel Crash Found During Injection

**Per `upstream-occt-patch-process.md`:**
1. Create reproducer in `Scripts/repro/766-crash-<issue>/`
2. File upstream issue with reproducer
3. **Do NOT attempt bridge fix** — prefer kernel fix
4. Note existing TSan issues waiting to be fixed
5. Link to #766

---

## Next Steps

1. Map each crash fix to its exact test coverage (using inventory.json)
2. For each test, create injection (remove guard/revert patch/revert bridge fix)
3. Run test → confirm FAIL (red) → restore → confirm PASS (green)
4. Document in matrix above
5. If kernel crash: file upstream issue with reproducer