# #3509: `BRepAlgoAPI_Check` faults on a face with no surface that carries a wire

After `0077` fixed `BRepCheck_Analyzer` for a face without a surface, `BRepAlgoAPI_Check` still
SIGSEGVs on the same shapes: a second, separate fault in the Boolean self-interference test.

```bash
Scripts/repro/3509/run.sh <OCCT.xcframework>                       # a kernel as shipped
Scripts/repro/3509/run.sh <OCCT.xcframework> <patched-object.o>    # the fix, override-linked
```

## The fault

```
IntTools_FaceFace.cxx: CorrectSurfaceBoundaries   aSurface = BRep_Tool::Surface(theFace);
                                                  aSurface->Bounds(...)   <- null
IntTools_FaceFace::Perform(face, face)
BOPAlgo_FaceSelfIntersect::Perform()
BOPAlgo_CheckerSI::CheckFaceSelfIntersection      skips plane, cylinder, cone, sphere only
BOPAlgo_ArgumentAnalyzer::TestSelfInterferences
BRepAlgoAPI_Check::Perform
```

A face with no surface is not one of the four types the checker skips, so it is intersected with
itself, and `IntTools_FaceFace::Perform` reads its surface and goes on to use it.

## Measured, `v4.0.0-kernel.8`, 2026-11-23

Each entry point in its own process on `Tests/OCCTStressTests/Fixtures/surfaceless-face-with-wire.brep`:

| entry point | `kernel.8` | with `0080` |
|---|---|---|
| `BRepAlgoAPI_Check(shape)` | **SIGSEGV, 139** | `IsValid` false |
| `BRepAlgoAPI_Check(box, shape, FUSE)` | **SIGSEGV, 139** | `IsValid` false |
| `BOPAlgo_CheckerSI`, level 5 | **SIGSEGV, 139** | no errors |
| `BRepAlgoAPI_Fuse` / `Common` / `Cut` / `Section` (box, shape) | done false, errors | same |

The issue's "not measured" row is answered: the four Boolean operations do not fault, because they
reject the argument before they intersect anything. The route is the self-interference test.

The 2789 harness agrees (`probe algocheck`, built with the patched object): `barewithwire`,
`withwire` and `surfaceless-face-with-wire.brep` answer `IsValid` false in place of 139, `box` is
true and `bare` false as before. With `OSD::SetSignal` installed (any bridge entry that calls
`occtEnsureSignals()` first) OCCT converts the fault and the unpatched kernel answers false too (the
issue's observation, not re-measured here); this probe installs nothing, so the fault is a plain
SIGSEGV.

## The two placements measured

A null test in `BOPAlgo_FaceSelfIntersect::Perform` (where upstream `IR` put its own) and one at
the top of `IntTools_FaceFace::Perform` give the same seven answers. The second was chosen: no
carried patch touches `IntTools_FaceFace.cxx`, so it applies to the pristine file, whereas patch
`0010` edits `BOPAlgo_FaceSelfIntersect::Perform` and a patch there would have to stack on it. It
also covers every other caller of the class, and it is still needed on `IR`, whose
`CorrectSurfaceBoundaries` is unchanged.

## What was not measured

`BRepOffset_Tool` and the Draw commands call `IntTools_FaceFace::Perform` directly; no input was
found that reaches them with a face that has no surface. `IR` was not built, so its closing of the
`BRepAlgoAPI_Check` route (#1640) is read from the source, not measured.
