---
nav_exclude: true
search_exclude: true
---

# OCCT Upgrade History

Documents breaking changes and migration steps for each OCCT version upgrade.

## Version Timeline

| OCCTSwift | OCCT Version | Date | Notes |
|-----------|-------------|------|-------|
| Unreleased | 8.0.1 | Aug 2026 | Current source pin: first 8.0 maintenance release, retired ten carried patches |
| v1.15.x | 8.0.0p1 | Jun 2026 | Hot-patch tag; the kernel every v1.15–v1.17 release was built from |
| v1.0.0 | 8.0.0 GA | May 2026 | SemVer-stable; PointSetLib removed, EdgeRegularity consolidated |
| v0.170.x | 8.0.0-beta2 | May 2026 | Last pre-GA release |
| v0.157.0 | 8.0.0-beta1 | May 2026 | BRepGraph BuilderView → EditorView reshape |
| v0.128.0+ | 8.0.0-rc5 | Apr 2026 | Analytical geometry, thread safety improvements |
| v0.27.0 | 8.0.0-rc4 | Feb 2026 | 111 improvements, 4 breaking changes |
| v0.26.0 | 8.0.0-rc3 | Feb 2026 | Initial OCCT 8.0 adoption |
| v0.16.0 | 7.8.1 | Feb 2026 | Original release |

---

## p1 to 8.0.1 (Unreleased)

[OCCT 8.0.1](https://github.com/Open-Cascade-SAS/OCCT/releases/tag/V8.0.1) (tag `V8_0_1`, 2026-07-30)
is the first maintenance release in the 8.0 series. Against our previous `V8_0_0_p1` pin it is a
clean fast-forward: **23 commits, 74 files, nothing reverted** (`behind_by = 0`), so there is no
divergent release branch to reconcile.

### No API or ABI break

Upstream states the 8.0.0p1 C++ API/ABI baseline is unchanged, and that was checked rather than
taken on trust: the only public header in the whole diff is `ShapeAnalysis_FreeBounds.hxx`, whose
change is a single comment line. **No migration is required for the OCCT API itself.**

### Ten carried patches retired

8.0.1 ships our own upstream contributions, so `Scripts/patches/` shrinks from 21 files to 11.
Retired: `0001`–`0009` and `0013`, covering OCCTSwift issues #263, #280, #298, #310, #317, #318,
#323 (three patches), and #348. Each merge commit was confirmed an **ancestor of the tag** rather
than merely merged to master, and each patch was diffed against its as-merged form before deletion.

Nine came back unchanged. `0001` did not: upstream's merged form also guards a *removed* face
(`anApplied.IsNull() ||`), which ours did not, so that retirement is a strict upgrade. Full
per-patch verdicts are in [`Scripts/patches/README.md`](../Scripts/patches/README.md) under
"Retired patches".

Patch numbers are **not** reused: the carried sequence now reads 0010-0012, 0014-0029, and the
gaps are the retirements. `Scripts/patches/README.md:11` states the same range in its own words,
and this copy was seven patches stale until #1018 noticed. That file is canonical; keep this line in
step with the range it gives, or delete this line rather than let a second copy drift again.

### Behaviour changes to watch

None of these break compilation; they change results. They are being measured against the wrapper
surface rather than assumed inert, because two of them sit in code the OCCTSwift suite cannot see:
there are no tests using INTERNAL/EXTERNAL edge orientation, and #645 records that the
Gordon-family tests assert only status ordinals and never build a surface.

| Upstream | Change | Reaches us through |
|---|---|---|
| [#1408](https://github.com/Open-Cascade-SAS/OCCT/pull/1408) + the merged form of [#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) | `ShapeAnalysis_FreeBounds` skips INTERNAL/EXTERNAL edges, seeds from the first wire that has edges, and drops `isUsedManifoldMode` along with its separate non-manifold closure detection | `Shape.freeBounds*` |
| [#1402](https://github.com/Open-Cascade-SAS/OCCT/pull/1402) | `BRep_Tool::CurveOnPlane` validates the edge range and returns a **null pcurve** where p1 threw a catchable `Geom_TrimmedCurve::parameters out of range` | any planar-face pcurve read |
| [#1335](https://github.com/Open-Cascade-SAS/OCCT/pull/1335) | `GeomFill_Gordon` rework: exact rational reparametrization, preserved homogeneous weights, stronger deviation validation, grid-evaluator fallback | `Surface.gordon(profiles:guides:tolerance:)` and `Surface.gordonReport(...)` |
| [#1407](https://github.com/Open-Cascade-SAS/OCCT/pull/1407) | `ChFi3d_Builder::StartSol` hardened, so invalid chamfer input now ends with `IsDone() == false` instead of crashing | the chamfer family |
| [#1338](https://github.com/Open-Cascade-SAS/OCCT/pull/1338) | `BRepMesh_BaseMeshAlgo` creates seam constraints only for the current wire occurrence's pcurve | meshing at periodic seams |
| [#1375](https://github.com/Open-Cascade-SAS/OCCT/pull/1375) / [#1373](https://github.com/Open-Cascade-SAS/OCCT/pull/1373) | `BRepCheck_Face::ClassifyWires` and `GeomLib_CheckCurveOnSurface` fast paths, both claimed result-neutral | validity checks, boolean workloads |

One release-note claim does not survive checking: #1375 is described as giving
`GeomLib_Tool::Parameter()` closed-form evaluation, but `GeomLib_Tool.cxx` is not in the 74-file
diff at all. The `ALLOWED` exemption for it in `Scripts/repro/556-null-handle-guard-sweep`
therefore still holds.

### Fixes we get for free

Beyond our own retired patches, 8.0.1 also brings `ChFi3d_Builder::StartSol` hardening (#1407),
an ~8× speedup for `BRepCheck_Face` on faces with many holes (#1375), a 17–20% boolean improvement
from the `GeomLib_CheckCurveOnSurface` fast path (#1373), and the periodic-seam meshing fix (#1338).

---

## Beta2 to GA (v0.170.x → v1.0.0)

### Breaking Changes

| Change | Migration |
|--------|-----------|
| `PointSetLib_Props` / `PointSetLib_Equation` removed | Module rolled back before GA. Swift `PointSetLib` enum + bridge wrappers deleted. No upstream replacement — port consumers to NumPy/Accelerate. |
| `BRepGraph::EditorView::CoEdgeOps::SetContinuity` removed | Replaced by `EditorView::EdgeOps::SetRegularity(edge, face1, face2, continuity)`. Continuity now lives on `BRepGraph_LayerRegularity` (per `(edge, face1, face2)`), not per coedge. |
| `BRepGraph::EditorView::CoEdgeOps::SetSeamContinuity` removed | Use `SetRegularity(edge, face, face, continuity)` — `face1 == face2` expresses seam continuity across a closed-surface seam. |
| `BRepGraph::EditorView::CoEdgeOps::SetSeamPairId` removed | No setter — seam-pair-id is structural in GA (two coedges on same `(edge, face)` with opposite orientations). Read via `BRepGraph_Tool::CoEdge::SeamPair`. |
| `TopTools_IndexedMapOfShape` deprecated (warning only) | Use `NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>`. Not yet migrated; warning is non-blocking. |
| `Standard_True` / `Standard_False` deprecated (warning only) | Use C++ `true` / `false` directly. Bridge call sites flagged but not yet migrated; warnings non-blocking. |

### New APIs in GA

The headline GA additions (BRepGraph, Gordon Surfaces, TKHelix, ExtremaPC) all landed in earlier RCs/betas and are already wrapped. GA itself was a stabilization release — see [OCCT discussion #1275](https://github.com/Open-Cascade-SAS/OCCT/discussions/1275).

### Stability

- **STEP read/write**: now safe under the contract of one reader or writer per thread (per the GA announcement).
- **SEGV fixes**: chamfer, fillet, and pipe-shell operations received multiple stability patches in the rc5→GA window.

### OCCTSwift API consolidation in v1.0.0

| Pre-1.0 | v1.0.0 |
|---------|--------|
| `setCoEdgeContinuity(_:continuity:)` | `setEdgeRegularity(_:face1:face2:continuity:) -> Bool` |
| `setCoEdgeSeamContinuity(_:continuity:)` | `setEdgeRegularity(_:face1:face2:continuity:)` (face1 == face2) |
| `setCoEdgeSeamPairId(_:seamPairCoedgeIndex:)` | Removed — seam-pair-id is structural; read via `coedgeSeamPair` |
| `occurrenceParentOccurrence(_:)` | `occurrenceParentProduct(_:)` (deprecated since v0.157.0) |
| `PointSetLib.{properties,inertiaMatrix,barycentre,equation}` | Removed — no OCCT replacement |

---

## RC4 to RC5

### Breaking Changes

| Change | Migration |
|--------|-----------|
| `GeomGridEval_Curve` renamed to `GeomEval_RepCurveDesc` | Updated bridge includes |
| `LProp3d` module absorbed into `BRepLProp` | Changed `LProp3d_CLProps.hxx` to `BRepLProp_CLProps.hxx` |
| `Geom2dLProp_CLProps2d` constructor parameter reordering | Verified constructor calls match RC5 signatures |
| `TColGeom_Array1OfCurve` typedefs removed | Already using `NCollection_Array1<Handle(Geom_Curve)>` |
| `.pxx` implementation headers not shipped in xcframework | `GeomBndLib` wrapping deferred |

### New APIs in RC5

- **GeomEval analytical curves**: CircularHelixCurve, SineWaveCurve
- **GeomEval analytical surfaces**: Ellipsoid, Hyperboloid, Paraboloid, Helicoid, HypParaboloid
- **Geom2dEval spirals**: Archimedean, Logarithmic, CircleInvolute, SineWave
- **GeomFill_Gordon**: Transfinite interpolation surface from crossing curve networks
- **PointSetLib**: Point cloud centroid, inertia tensor, PCA analysis
- **Approx_BSplineApproxInterp**: Constrained least-squares B-spline fitting
- **GeomEval TBezier/AHTBezier**: Trigonometric and algebraic-hyperbolic-trigonometric basis curves/surfaces
- **GeomAdaptor_TransformedCurve**: Rigid transformation adaptor for curves

### Thread Safety Improvements

- Reduced mutable global state in geometry evaluators
- `final` keyword on evaluation methods enables devirtualization
- Grid evaluation batch methods avoid per-call virtual dispatch

### Not Wrappable

- **GeomBndLib**: `.pxx` implementation headers not distributed in xcframework. Deferred until OCCT ships them.

---

## RC3 to RC4

### Breaking Changes

| Change | Migration |
|--------|-----------|
| `SelectMgr_ViewerSelector3d` removed | Replaced with `SelectMgr_ViewerSelector.hxx` |
| `TopTools_ListIteratorOfListOfShape` removed | Replaced with `TopTools_ListOfShape::Iterator` |
| `BRepExtrema_MapOfIntegerPackedMapOfInteger` removed | Migrated to `NCollection_DataMap<int, TColStd_PackedMapOfInteger>` |
| `TColStd_MapIteratorOfPackedMapOfInteger` removed | Replaced with `TColStd_PackedMapOfInteger::Iterator` |
| `RWObj_CafWriter::Perform()` signature changed | Migrated to 5-arg overload |
| `RWPly_CafWriter::Perform()` signature changed | Same fix as OBJ |

### Deprecated Typedefs

OCCT 8.0 deprecates many collection typedefs. Key replacements:

| Deprecated | Replacement |
|------------|-------------|
| `TColgp_Array1OfPnt` | `NCollection_Array1<gp_Pnt>` |
| `TColStd_Array1OfReal` | `NCollection_Array1<double>` |
| `TopTools_ListOfShape` | `NCollection_List<TopoDS_Shape>` |
| `TopTools_IndexedMapOfShape` | `NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>` |
| `Standard_Integer` / `Standard_Real` / `Standard_Boolean` | `int` / `double` / `bool` |

Full list of deprecated typedefs is available in the OCCT 8.0 migration scripts at `Libraries/occt-src/adm/scripts/migration_800/`.

### Performance Improvements (automatic)

- Devirtualized geometry evaluation on hot paths
- Direct array members in BSpline/Bezier (no heap indirection)
- Thread-local error handling
- Contiguous TShape child storage
- Robin Hood hash maps for internal collections

---

## Rebuilding After Upgrade

```bash
cd Libraries
rm -rf occt-src occt-build-* occt-install-*
cd ../Scripts && ./build-occt.sh
```

Removing `occt-src` is the load-bearing step, not housekeeping. `build-occt.sh` reuses an existing
tree only when its `HEAD` is at the tag the script names, and **aborts** otherwise rather than
building the wrong kernel under the new version's name, which is what it silently did until the
8.0.1 re-pin, when it tested only whether the directory existed. If the abort fires, check
`git -C Libraries/occt-src status --porcelain` for work worth keeping (a diagnostic probe from an
investigation, a half-written patch) before deleting.

Build time: ~30-60 minutes. See [guides/building-occt.md](guides/building-occt.md) for details.
