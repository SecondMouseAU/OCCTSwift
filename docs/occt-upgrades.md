---
nav_exclude: true
search_exclude: true
---

# OCCT Upgrade History

Documents breaking changes and migration steps for each OCCT version upgrade.

## Version Timeline

| OCCTSwift | OCCT Version | Date | Notes |
|-----------|-------------|------|-------|
| Unreleased | 8.0.2 | Nov 2026 | Surveyed 2026-11-23, not yet the source pin: retires ten carried patches, rebases three; ships as two kernel flavours (hardened default, LTS opt-in), see "Kernel flavours" |
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

## 8.0.1 to 8.0.2 (surveyed, not yet the pin)

[OCCT 8.0.2](https://github.com/Open-Cascade-SAS/OCCT/releases/tag/V8_0_2) (tag `V8_0_2`, 2026-11-21,
a lightweight tag on `83f9abe947`) is the second 8.0 maintenance release. `V8_0_1` is an ancestor
of it: **36 commits, 184 files**. It is a selective backport from upstream `IR`, and several pull
requests were taken in part (#1470, #1472, #1512, #1514, #1611, #1620, #1634, #1640, #1644, #1647,
#1653, #1741), so a pull request number in the release notes does not say which files reached the
tag. Every verdict below was taken from the files, not from the notes.

This section is the survey that [`v4.0.0-plan.md`](v4.0.0-plan.md) family E requires before any
build. The kernel is still `V8_0_1`; nothing here has been built yet, apart from the two
translation units measured under "Upstream's forms, measured".

### No API or ABI break

No public header was added, removed or renamed, and no `Standard_DEPRECATED` was added. Six public
headers changed, and only one in code: `gp_Hypr`'s default constructor sets the minor radius to
`RealLast()` instead of `RealFirst()` (#1538). The bridge's one default-built `gp_Hypr` is an unused
local. The others are comment changes in `BRepTools.hxx`, `Extrema_ExtCS.hxx`, `Extrema_ExtSS.hxx`,
`GeomTools.hxx` and `NCollection_UtfIterator.lxx`. The XCAF stream I/O (#1611) and companion stream
(#1647) APIs were not backported; only fixes inside existing `.cxx` files were. **No migration is
required for the OCCT API.**

Two existing calls now behave differently:

- `Extrema_ExtCS::Points` and `Extrema_ExtSS::Points` throw `StdFail_NotDone` when the extremum is
  not done. The merged form of #1596 has that check; patch `0044`, our submitted form, did not.
  `NbExt()` already threw in that state, so a caller that reads `NbExt()` first is unaffected.
- `BRepTools::Read` returns `false` when the stream fails (#1786).

### Build

`adm/cmake/version.cmake` moves to maintenance version 2. The static-link licence warning moved
into a new `adm/cmake/OpenCASCADELicense.cmake` with new text. Install destinations became relative,
which is equivalent here because `CMakeLists.txt` forces `CMAKE_INSTALL_PREFIX` to `INSTALL_DIR`.
Neither build script reads any of these. `OCCT_VERSION` is set separately in `build-occt.sh` and
`build-occt-wasm.sh`, and both must move.

### Carried patches: ten retire, three rebase, 48 unchanged

Checked by applying every patch to a pristine `V8_0_2` checkout, alone and as the ordered stack.
The ten retirements were then confirmed against their upstream commits, each an ancestor of the tag.
The 51 patches that remain, with the three rebased ones in place, apply in order to pristine
`V8_0_2` with plain `git apply`. The result is identical to the patch-by-patch replay, and all 11
`Scripts/patches-wasi/` patches apply on top of it. The patched files they touch are byte-identical
between the two tags.

| Patch | Verdict | Evidence |
|---|---|---|
| `0019` | retire | #1418, `eb9e347af9`; reverse-applies to `V8_0_2` |
| `0029` | retire | #1483, `784c1ad96d`; reverse-applies |
| `0045` | retire | #1593, `1fdabe7c7e`; reverse-applies |
| `0034` | retire | #1550, `d241c9fa88`; patched source equals `V8_0_2` with comments and blank lines removed |
| `0043` | retire | #1587, `00e6b907ac`; same code |
| `0048` | retire | #1601, `3958f18267`; same code, both files |
| `0044` | retire | #1596, `55ff78f397`; same code plus the `StdFail_NotDone` check above |
| `0054` | retire, take upstream's form | #1708, `406228f881`, where GeeBee2's fix sets `ChFiDS_StartsolFailure` and throws; ours dropped the obstacle and returned. Measured below |
| `0064` | retire, take upstream's form | #1787, `d58691494b`, which advances the iterator before `Remove`; ours collected the edges first. Measured below |
| `0052` | retire | Doc comment only (#1602, on `IR`, not in `V8_0_2`); it changes no binary |
| `0053` | rebase | Source hunk unchanged. The GTest hunk now sits beside the tests #1453 added to the same file; both sides kept |
| `0073` | rebase | Its `GetReal` hunk is superseded by #1786, which reads a long real into a 512-byte buffer; dropped, so the patch no longer touches `GeomTools.cxx`. Where #1786 returns on a failed stream before building a trimmed or offset curve or surface, `0073`'s null-basis check stays beside it: an unknown type record yields a null basis without failing the stream. Three-way merged otherwise |
| `0074` | rebase | Three-way merge onto the rebased `0073`, no hand edits |
| `0076` | unchanged | Conflicted only because `0074` had not applied; applies as it is on the rebased `0074` |
| the other 47 | unchanged | Apply as they are, in order |

`0028` stays. Its file is unchanged in `V8_0_2`. Upstream fixed the uninitialised members on `IR`
in #1620 with a different contract for a plate built from point constraints alone (zero, where
`0028` reports the measured deviation). No OCCTSwift entry point builds such a plate: the
deviations reach the Swift API only through `BRepFill_Filling`, which always has a curve
constraint, so the two forms answer the same for every caller. It retires with the move to 8.1.

`Scripts/lib/apply-patches.sh` treats a patch that reverse-applies as already applied, so leaving an
absorbed patch in place would not fail the build. The retirements are therefore recorded here and
in `Scripts/patches/README.md`, not inferred from a build log.

### Upstream's forms, measured

`ChFi3d_Builder_2.cxx` and `TopOpeBRepBuild_Merge.cxx` are each changed by one commit between the
tags (#1708 and #1787) and by one carried patch (`0054` and `0064`). So the `V8_0_2` source of each
file is exactly the `kernel.9` source with our patch replaced by upstream's. Both were compiled with
`kernel.9`'s own flags and swapped into its macOS archive (symbol sets identical), which was
restored afterwards. The test binaries were relinked after the swap and carry #1708's new error
string.

- **OCCTSwift's fillet, chamfer and blend suites** (259 tests, including `FilletObstacleTests` and
  `FilletMergeWireRemovalTests`): all pass on both. The obstacle model still fillets 20 of 42
  edges at radius 1.0 and 12 of 42 at 1.5.
- **The 43 cases of [`Scripts/repro/fillet-open-set`](../Scripts/repro/fillet-open-set/README.md)**:
  42 identical. OCCT#1421's model (#3336) changes from done but invalid (two solids, 139
  `bopcheck` faults) to not done with one faulty contour, a refusal where the caller used to be
  handed a broken solid.

### Behaviour changes to watch

None of these breaks compilation. Each changes results, and the repin classifies every test whose
expectation moves against both kernels.

| Upstream | Change | Reaches us through |
|---|---|---|
| #1708, #1710, #1501 | Fillet: a missing obstacle edge refuses; the two-corner check moved; knots on a G2-closed spine are kept | `Shape.filleted`, `FilletBuilder` |
| #1453 | A circular wire offset that collapses is not done, where it fell through to the general algorithm | `Shape.offsetWire` and its family |
| #1783, #1784, #1785 | Closed lofts keep the last section's history; an unbounded section is refused; a null auxiliary spine throws `Standard_ConstructionError` | `ThruSections`, `PipeShell` |
| #1620 (part) | Booleans: section splits limited to common vertices, a 2D intersection length fixed | Boolean, section and mesh-boolean counts |
| #1634, #1640, #1741 (parts) | HLR sampling and B-spline handling, projection knots, `BRepMesh` and `GCPnts_TangentialDeflection` | exact mesh, HLR and sampling counts |
| #1786 | Long reals in BREP text, readers stop on a failed stream | the BREP readers; the bridge's #3487 stream guards stay, since #1786 bounds only `GetReal` |
| #1470, #1514, #1611, #1647, #1644 (parts) | STEP writer field kinds, cyclic oriented edges, PMI units, tessellated vertex order | STEP read and write |

### Kernel flavours (planned for v4.0.0)

Decided 2026-11-24, and not shipped yet: the carry kernel is #3535, the vanilla kernel #3544 and the
trait that selects it #3545. The plan is in [`v4.0.0-plan.md`](v4.0.0-plan.md) family E. This table is
the contract skeleton; once the fix ledger exists (#3543) it is generated from the ledger rather
than written by hand, so it cannot go stale.

| Flavour | Kernel | Selected |
|---|---|---|
| **Hardened** | `V8_0_2` plus 51 carried patches (native), and the 11 WASI patches on wasm | By default |
| **LTS** | `V8_0_2` with no carried patches (native), and the 11 WASI patches on wasm | An explicit opt-in |

LTS means provenance, not robustness: exactly what Open Cascade ships, so a defect is upstream's. On
a vanilla kernel the results-neutral patches below become races and crashes where the hardened
kernel refuses or serialises.

| Patch group | Patches | Hardened | LTS |
|---|---|---|---|
| Thread safety and races | 14 | Fixed; the ThreadSanitizer claim in [`thread-safety.md`](thread-safety.md) holds | Not fixed; no ThreadSanitizer-clean claim |
| Damaged-input hardening | 12 | Damaged BREP, STEP and OCAF input is refused | Not safe for untrusted input |
| Crash and hang guards | 13 | The call refuses or returns | The process can crash or hang; no guard promise |
| Wrong-answer fixes | 11 | The answer is right | The answer is upstream's, which can be wrong where the patch says so |
| Behaviour ahead of upstream (`0059`) | 1 | Fillets that meet exactly are built | Upstream's behaviour |

An upstream release shrinks the difference: a fix in 8.0.3 or 8.1 retires its patch from the
hardened flavour and its guard from LTS, and the generated table loses the row.

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

Patch numbers are **not** reused, and the gaps in the carried sequence are the retirements.
[`Scripts/patches/README.md`](../Scripts/patches/README.md) states the range and is canonical. The
range itself used to be restated here too; that copy went seven patches stale before #1018 noticed
it, and stale again afterwards, so it is deleted rather than kept in step a third time. This line
gives its own instruction from before the second drift: delete the copy rather than let it drift.

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
| `PointSetLib_Props` / `PointSetLib_Equation` removed | Module rolled back before GA. Swift `PointSetLib` enum + bridge wrappers deleted. No upstream replacement, port consumers to NumPy/Accelerate. |
| `BRepGraph::EditorView::CoEdgeOps::SetContinuity` removed | Replaced by `EditorView::EdgeOps::SetRegularity(edge, face1, face2, continuity)`. Continuity now lives on `BRepGraph_LayerRegularity` (per `(edge, face1, face2)`), not per coedge. |
| `BRepGraph::EditorView::CoEdgeOps::SetSeamContinuity` removed | Use `SetRegularity(edge, face, face, continuity)`, `face1 == face2` expresses seam continuity across a closed-surface seam. |
| `BRepGraph::EditorView::CoEdgeOps::SetSeamPairId` removed | No setter, seam-pair-id is structural in GA (two coedges on same `(edge, face)` with opposite orientations). Read via `BRepGraph_Tool::CoEdge::SeamPair`. |
| `TopTools_IndexedMapOfShape` deprecated (warning only) | Use `NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>`. Not yet migrated; warning is non-blocking. |
| `Standard_True` / `Standard_False` deprecated (warning only) | Use C++ `true` / `false` directly. Bridge call sites flagged but not yet migrated; warnings non-blocking. |

### New APIs in GA

The headline GA additions (BRepGraph, Gordon Surfaces, TKHelix, ExtremaPC) all landed in earlier RCs/betas and are already wrapped. GA itself was a stabilization release, see [OCCT discussion #1275](https://github.com/Open-Cascade-SAS/OCCT/discussions/1275).

### Stability

- **STEP read/write**: now safe under the contract of one reader or writer per thread (per the GA announcement).
- **SEGV fixes**: chamfer, fillet, and pipe-shell operations received multiple stability patches in the rc5→GA window.

### OCCTSwift API consolidation in v1.0.0

| Pre-1.0 | v1.0.0 |
|---------|--------|
| `setCoEdgeContinuity(_:continuity:)` | `setEdgeRegularity(_:face1:face2:continuity:) -> Bool` |
| `setCoEdgeSeamContinuity(_:continuity:)` | `setEdgeRegularity(_:face1:face2:continuity:)` (face1 == face2) |
| `setCoEdgeSeamPairId(_:seamPairCoedgeIndex:)` | Removed, seam-pair-id is structural; read via `coedgeSeamPair` |
| `occurrenceParentOccurrence(_:)` | `occurrenceParentProduct(_:)` (deprecated since v0.157.0) |
| `PointSetLib.{properties,inertiaMatrix,barycentre,equation}` | Removed, no OCCT replacement |

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
